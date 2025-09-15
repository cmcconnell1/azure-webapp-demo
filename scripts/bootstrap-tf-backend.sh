#!/usr/bin/env bash

# ============================================================================
# TERRAFORM BACKEND BOOTSTRAP SCRIPT
# ============================================================================
#
# Purpose: Create Azure Resource Group + Storage Account + tfstate container
#          and generate terraform/environments/<env>/backend.conf automatically.
#
# Security Features:
# - Enforces TLS 1.2+ for all storage operations
# - HTTPS-only access to storage account
# - Blob versioning enabled for state file history
# - Soft delete protection for accidental deletions
# - Unique storage account names to prevent conflicts
#
# Required Arguments:
#   --env <dev|stage|prod>    Environment name for backend configuration
#
# Optional Arguments:
#   --project-prefix <name>   Project identifier (default: webapp-demo)
#   --location <azure-region> Azure region (default: westus2)
#   --rg-name <name>          Resource group name (auto-generated if omitted)
#   --sa-name <name>          Storage account name (auto-generated if omitted)
#   --container <name>        Container name for tfstate (default: tfstate)
#
# Example Usage:
#   ./scripts/bootstrap-tf-backend.sh --env dev --project-prefix webapp-demo --location westus2
#
# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# ============================================================================
# SCRIPT CONFIGURATION AND GLOBAL VARIABLES
# ============================================================================

# ANSI color codes for enhanced output formatting
BLUE='\033[0;34m'     # Blue for informational messages
GREEN='\033[0;32m'    # Green for success messages
YELLOW='\033[1;33m'   # Yellow for warnings
RED='\033[0;31m'      # Red for errors
NC='\033[0m'          # No color (reset)

# Color-coded logging functions for better user experience
log() { echo -e "${BLUE}[INFO]${NC} $*"; }       # Informational messages
ok() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }    # Success confirmations
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; } # Warning messages
err() { echo -e "${RED}[ERROR]${NC} $*"; }       # Error messages

# Default configuration values
ENV_NAME=""                    # Environment name (required via command line)
PROJECT_PREFIX="webapp-demo"   # Project identifier for resource naming
LOCATION="westus2"            # Default Azure region
RG_NAME=""                    # Resource group name (auto-generated if empty)
SA_NAME=""                    # Storage account name (auto-generated if empty)
CONTAINER="tfstate"           # Container name for Terraform state files

usage() {
  cat <<USAGE
Usage: $0 --env <dev|stage|prod> [--project-prefix <name>] [--location <region>] [--rg-name <name>] [--sa-name <name>] [--container <name>]
USAGE
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="$2"; shift 2;;
    --project-prefix) PROJECT_PREFIX="$2"; shift 2;;
    --location) LOCATION="$2"; shift 2;;
    --rg-name) RG_NAME="$2"; shift 2;;
    --sa-name) SA_NAME="$2"; shift 2;;
    --container) CONTAINER="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) err "Unknown argument: $1"; usage; exit 1;;
  esac
done

if [[ -z "$ENV_NAME" ]]; then
  err "--env is required (dev|stage|prod)."
  usage; exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  err "Azure CLI not found. Install and run 'az login' first."
  exit 1
fi

# Normalize names
sanitize() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]//g'; }
PROJECT_PREFIX=$(sanitize "$PROJECT_PREFIX")
RG_NAME=${RG_NAME:-"${PROJECT_PREFIX}-terraform-state-rg"}

# Storage account name constraints: 3-24 chars, lowercase letters and numbers only, globally unique
mk_sa_name() {
  local base="$1" env="$2"
  local short=$(echo "$base" | tr -cd 'a-z0-9' | cut -c1-12)
  local rnd
  if command -v openssl >/dev/null 2>&1; then
    rnd=$(openssl rand -hex 3)
  else
    rnd=$(hexdump -vn3 -e '3/1 "%02x"' /dev/urandom 2>/dev/null || printf '%06x' $RANDOM)
  fi
  echo "${short}tf${env}${rnd}" | cut -c1-24
}

if [[ -z "$SA_NAME" ]]; then
  SA_NAME=$(mk_sa_name "$PROJECT_PREFIX" "$ENV_NAME")
fi

log "Ensuring resource group: $RG_NAME in $LOCATION"
az group create --name "$RG_NAME" --location "$LOCATION" >/dev/null

log "Creating storage account: $SA_NAME (may take ~1 min)"
# Try create; if name taken, advise override
set +e
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --https-only true \
  --allow-blob-public-access false \
  >/dev/null 2>&1
CREATE_RC=$?
set -e
if [[ $CREATE_RC -ne 0 ]]; then
  err "Failed to create storage account '$SA_NAME' (likely name is not globally unique)."
  echo "Provide a name with --sa-name or rerun to generate a different one."
  exit 1
fi
ok "Storage account ready: $SA_NAME"

log "Enabling blob versioning and soft delete"
az storage account blob-service-properties update \
  --account-name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --enable-versioning true >/dev/null
az storage account blob-service-properties update \
  --account-name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --enable-delete-retention true --delete-retention-days 14 >/dev/null

log "Ensuring container: $CONTAINER"
az storage container create --name "$CONTAINER" --account-name "$SA_NAME" --auth-mode login >/dev/null

TARGET_DIR="terraform/environments/$ENV_NAME"
mkdir -p "$TARGET_DIR"
BACKEND_FILE="$TARGET_DIR/backend.conf"
cat > "$BACKEND_FILE" <<EOF
resource_group_name  = "$RG_NAME"
storage_account_name = "$SA_NAME"
container_name       = "$CONTAINER"
key                  = "$ENV_NAME/terraform.tfstate"
EOF

ok "Wrote $BACKEND_FILE"

cat <<OUT
Next steps:
  cd terraform
  terraform init -backend-config=environments/$ENV_NAME/backend.conf
  terraform plan -var-file=environments/$ENV_NAME/terraform.tfvars
OUT

