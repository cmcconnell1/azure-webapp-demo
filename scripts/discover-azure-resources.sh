#!/bin/bash

# Azure Resource Discovery Script
# 
# This script dynamically discovers Azure resources for the webapp-demo project
# making other scripts idempotent and resilient to terraform destroy/apply cycles.
#
# Usage:
#   source ./scripts/discover-azure-resources.sh [ENVIRONMENT]
#   echo $WEBAPP_URL
#   echo $RESOURCE_GROUP
#   echo $SQL_SERVER
#
# Or:
#   ./scripts/discover-azure-resources.sh dev --export-json > resources.json

set -e

# Default configuration
PROJECT_NAME="webapp-demo"
ENVIRONMENT="${1:-dev}"
EXPORT_FORMAT="${2:-env}"  # env, json, or terraform

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

show_help() {
    echo "Azure Resource Discovery Script"
    echo
    echo "Usage: $0 [ENVIRONMENT] [FORMAT]"
    echo
    echo "Arguments:"
    echo "  ENVIRONMENT    Environment name (dev, staging, prod) - default: dev"
    echo "  FORMAT         Output format (env, json, terraform) - default: env"
    echo
    echo "Formats:"
    echo "  env            Export as environment variables (for sourcing)"
    echo "  json           Export as JSON object"
    echo "  terraform      Show terraform output format"
    echo "  --export-json  Same as json format"
    echo
    echo "Examples:"
    echo "  $0 dev                    # Discover dev resources, output env vars"
    echo "  $0 prod json             # Discover prod resources as JSON"
    echo "  source $0 dev            # Source env vars into current shell"
    echo "  $0 dev --export-json > resources.json"
}

check_azure_cli() {
    if ! command -v az >/dev/null 2>&1; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    
    if ! az account show >/dev/null 2>&1; then
        print_error "Not logged in to Azure. Please run 'az login' first"
        exit 1
    fi
}

discover_resources() {
    local env="$1"

    print_status "Discovering Azure resources for environment: $env"

    # Try terraform output first if available
    if [[ -f "terraform/terraform.tfstate" ]] || [[ -d "terraform/.terraform" ]]; then
        if discover_from_terraform "$env"; then
            print_success "Resources discovered from Terraform state"
            return 0
        fi
    fi

    # Fallback to Azure CLI discovery
    discover_from_azure_cli "$env"
}

discover_from_terraform() {
    local env="$1"

    print_status "Attempting to discover resources from Terraform..."

    # Change to terraform directory if it exists
    local terraform_dir="terraform"
    if [[ -d "$terraform_dir" ]]; then
        cd "$terraform_dir"
    fi

    # Try to get terraform output
    if terraform output >/dev/null 2>&1; then
        export RESOURCE_GROUP=$(terraform output -raw resource_group 2>/dev/null || echo "")
        export WEBAPP_NAME=$(terraform output -raw webapp_name 2>/dev/null || echo "")
        export SQL_SERVER=$(terraform output -raw sql_server 2>/dev/null || echo "")
        export SQL_DATABASE=$(terraform output -raw sql_database 2>/dev/null || echo "")
        export KEY_VAULT_NAME=$(terraform output -raw key_vault_name 2>/dev/null || echo "")
        export ACR_NAME=$(terraform output -raw acr_name 2>/dev/null || echo "")
        export ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server 2>/dev/null || echo "")

        # Construct webapp URL
        local webapp_url_base=$(terraform output -raw webapp_url 2>/dev/null || echo "")
        if [[ -n "$webapp_url_base" ]]; then
            export WEBAPP_URL="https://$webapp_url_base"
        fi

        # Get subscription ID
        export AZURE_SUBSCRIPTION_ID=$(az account show --query "id" -o tsv 2>/dev/null || echo "")
        export PROJECT_NAME="$PROJECT_NAME"
        export ENVIRONMENT="$env"

        # Return to original directory
        cd - >/dev/null

        # Validate we got the critical resources
        if [[ -n "$RESOURCE_GROUP" && -n "$WEBAPP_NAME" && -n "$WEBAPP_URL" ]]; then
            return 0
        fi
    fi

    # Return to original directory if we changed
    if [[ -d "$terraform_dir" ]]; then
        cd - >/dev/null 2>&1 || true
    fi

    return 1
}

discover_from_azure_cli() {
    local env="$1"

    print_status "Discovering resources via Azure CLI..."

    # Discover resource group
    local resource_group=$(timeout 10 az group list --query "[?contains(name, '$PROJECT_NAME-$env')].name" -o tsv 2>/dev/null | head -1 || echo "")

    if [[ -z "$resource_group" ]]; then
        print_error "No resource group found for $PROJECT_NAME-$env"
        return 1
    fi

    print_status "Found resource group: $resource_group"
    
    # Discover web app with timeout
    local webapp_name=$(timeout 10 az webapp list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    local webapp_url=""

    if [[ -n "$webapp_name" ]]; then
        webapp_url=$(timeout 10 az webapp show --name "$webapp_name" --resource-group "$resource_group" --query "defaultHostName" -o tsv 2>/dev/null || echo "")
        if [[ -n "$webapp_url" ]]; then
            webapp_url="https://$webapp_url"
        fi
    fi
    
    # Discover SQL server with timeout
    local sql_server=$(timeout 10 az sql server list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    local sql_database=""

    if [[ -n "$sql_server" ]]; then
        sql_database=$(timeout 10 az sql db list --server "$sql_server" --resource-group "$resource_group" --query "[?name != 'master'].name" -o tsv 2>/dev/null | head -1 || echo "")
    fi

    # Discover other resources with timeout
    local key_vault=$(timeout 10 az keyvault list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    local acr_name=$(timeout 10 az acr list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    local acr_login_server=""

    if [[ -n "$acr_name" ]]; then
        acr_login_server=$(timeout 10 az acr show --name "$acr_name" --resource-group "$resource_group" --query "loginServer" -o tsv 2>/dev/null || echo "")
    fi

    # Discover App Service Plan
    local app_service_plan=$(timeout 10 az appservice plan list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")

    # Discover Application Insights
    local app_insights=$(timeout 10 az monitor app-insights component show --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null || echo "")
    
    # Get subscription ID
    local subscription_id=$(az account show --query "id" -o tsv)
    
    # Export discovered resources
    export AZURE_SUBSCRIPTION_ID="$subscription_id"
    export PROJECT_NAME="$PROJECT_NAME"
    export ENVIRONMENT="$env"
    export RESOURCE_GROUP="$resource_group"
    export WEBAPP_NAME="$webapp_name"
    export WEBAPP_URL="$webapp_url"
    export SQL_SERVER="$sql_server"
    export SQL_DATABASE="$sql_database"
    export KEY_VAULT_NAME="$key_vault"
    export ACR_NAME="$acr_name"
    export ACR_LOGIN_SERVER="$acr_login_server"
    export APP_SERVICE_PLAN="$app_service_plan"
    export APPLICATION_INSIGHTS="$app_insights"
    
    # Validate critical resources
    local missing_resources=()
    
    if [[ -z "$resource_group" ]]; then missing_resources+=("resource_group"); fi
    if [[ -z "$webapp_name" ]]; then missing_resources+=("webapp"); fi
    if [[ -z "$webapp_url" ]]; then missing_resources+=("webapp_url"); fi
    
    if [[ ${#missing_resources[@]} -gt 0 ]]; then
        print_warning "Missing critical resources: ${missing_resources[*]}"
        print_warning "Some scripts may not work properly"
    else
        print_success "All critical resources discovered successfully"
    fi
}

output_env_format() {
    cat << EOF
# Azure Resource Discovery - Environment Variables
# Source this file: source ./scripts/discover-azure-resources.sh $ENVIRONMENT

export AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
export PROJECT_NAME="$PROJECT_NAME"
export ENVIRONMENT="$ENVIRONMENT"
export RESOURCE_GROUP="$RESOURCE_GROUP"
export WEBAPP_NAME="$WEBAPP_NAME"
export WEBAPP_URL="$WEBAPP_URL"
export SQL_SERVER="$SQL_SERVER"
export SQL_DATABASE="$SQL_DATABASE"
export KEY_VAULT_NAME="$KEY_VAULT_NAME"
export ACR_NAME="$ACR_NAME"
export ACR_LOGIN_SERVER="$ACR_LOGIN_SERVER"
export APP_SERVICE_PLAN="$APP_SERVICE_PLAN"
export APPLICATION_INSIGHTS="$APPLICATION_INSIGHTS"
EOF
}

output_json_format() {
    cat << EOF
{
  "subscription_id": "$AZURE_SUBSCRIPTION_ID",
  "project_name": "$PROJECT_NAME",
  "environment": "$ENVIRONMENT",
  "resource_group": "$RESOURCE_GROUP",
  "webapp": {
    "name": "$WEBAPP_NAME",
    "url": "$WEBAPP_URL"
  },
  "database": {
    "server": "$SQL_SERVER",
    "database": "$SQL_DATABASE"
  },
  "key_vault": {
    "name": "$KEY_VAULT_NAME"
  },
  "container_registry": {
    "name": "$ACR_NAME",
    "login_server": "$ACR_LOGIN_SERVER"
  },
  "app_service_plan": "$APP_SERVICE_PLAN",
  "application_insights": "$APPLICATION_INSIGHTS",
  "discovered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

output_terraform_format() {
    echo "# Terraform Output Equivalent"
    echo "# Run: terraform output"
    echo
    echo "acr_login_server = \"$ACR_LOGIN_SERVER\""
    echo "acr_name = \"$ACR_NAME\""
    echo "key_vault_name = \"$KEY_VAULT_NAME\""
    echo "resource_group = \"$RESOURCE_GROUP\""
    echo "sql_database = \"$SQL_DATABASE\""
    echo "sql_server = \"$SQL_SERVER\""
    echo "webapp_name = \"$WEBAPP_NAME\""
    echo "webapp_url = \"${WEBAPP_URL#https://}\""
}

main() {
    # Parse arguments
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --export-json)
            EXPORT_FORMAT="json"
            ENVIRONMENT="${2:-dev}"
            ;;
        *)
            if [[ "$2" == "--export-json" ]]; then
                EXPORT_FORMAT="json"
            elif [[ -n "$2" ]]; then
                EXPORT_FORMAT="$2"
            fi
            ;;
    esac
    
    # Validate format
    case "$EXPORT_FORMAT" in
        env|json|terraform) ;;
        *)
            print_error "Invalid format: $EXPORT_FORMAT"
            show_help
            exit 1
            ;;
    esac
    
    check_azure_cli
    discover_resources "$ENVIRONMENT"
    
    # Output in requested format
    case "$EXPORT_FORMAT" in
        env)
            output_env_format
            ;;
        json)
            output_json_format
            ;;
        terraform)
            output_terraform_format
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
else
    # Script is being sourced, just discover and export variables
    check_azure_cli >/dev/null 2>&1
    discover_resources "$ENVIRONMENT" >/dev/null 2>&1
fi
