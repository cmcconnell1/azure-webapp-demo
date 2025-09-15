#!/bin/bash

# Setup Automatic Cleanup for Current Deployment - Azure WebApp Demo
#
# This script automatically detects the current deployment (from Terraform state)
# and sets up Azure Automation cleanup for those specific resources.
#
# DEMO PROJECT ONLY: This creates automation for the current deployment.
# Production projects should use proper resource lifecycle management.
#
# What this script does:
# 1. Reads current Terraform state to get deployment details
# 2. Gets current Azure subscription from CLI context
# 3. Sets up Azure Automation Account for cleanup
# 4. Schedules cleanup for the detected resources
#
# Prerequisites:
# - Azure CLI authenticated (az login)
# - Terraform deployment completed (terraform state exists)
# - Contributor permissions on Azure subscription
#
# Usage:
#   ./scripts/setup-auto-cleanup-current.sh [--cleanup-hours HOURS] [--webhook-url URL]
#
# Examples:
#   ./scripts/setup-auto-cleanup-current.sh
#   ./scripts/setup-auto-cleanup-current.sh --cleanup-hours 4
#   ./scripts/setup-auto-cleanup-current.sh --cleanup-hours 2 --webhook-url https://hooks.slack.com/...

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
CLEANUP_HOURS=2
WEBHOOK_URL=""

# Color output functions
print_status() { echo -e "\033[34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup-hours)
                CLEANUP_HOURS="$2"
                shift 2
                ;;
            --webhook-url)
                WEBHOOK_URL="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help message
show_help() {
    cat << EOF
Setup Automatic Cleanup for Current Deployment - Azure WebApp Demo

USAGE:
    ./scripts/setup-auto-cleanup-current.sh [OPTIONS]

OPTIONS:
    --cleanup-hours HOURS  Auto-cleanup after X hours (default: 2)
    --webhook-url URL      Webhook URL for notifications (optional)
    --help, -h            Show this help message

EXAMPLES:
    ./scripts/setup-auto-cleanup-current.sh
    ./scripts/setup-auto-cleanup-current.sh --cleanup-hours 4
    ./scripts/setup-auto-cleanup-current.sh --cleanup-hours 2 --webhook-url https://hooks.slack.com/...

FEATURES:
    - Automatically detects current deployment from Terraform state
    - Gets current Azure subscription from CLI context
    - Sets up Azure Automation Account for cleanup
    - Schedules cleanup for the detected resources

REQUIREMENTS:
    - Azure CLI authenticated with sufficient permissions
    - Terraform deployment completed (terraform state exists)
    - Contributor access to subscription for Automation Account creation

EOF
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi
    
    # Check Azure authentication
    if ! az account show &> /dev/null; then
        print_error "Not authenticated with Azure. Please run 'az login'."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install Terraform."
        exit 1
    fi
    
    # Check if we're in a Terraform directory
    if [[ ! -f "$PROJECT_ROOT/terraform/main.tf" ]]; then
        print_error "Terraform configuration not found. Please run from project root."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Detect current deployment
detect_current_deployment() {
    print_status "Detecting current deployment from Terraform state..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Check if Terraform state exists
    if ! terraform state list &> /dev/null; then
        print_error "No Terraform state found. Please deploy first with './scripts/deploy.sh'"
        exit 1
    fi
    
    # Get deployment details from Terraform outputs
    RESOURCE_GROUP=$(terraform output -raw resource_group 2>/dev/null || echo "")
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    
    if [[ -z "$RESOURCE_GROUP" ]]; then
        print_error "Could not detect resource group from Terraform state"
        exit 1
    fi
    
    print_success "Current deployment detected:"
    print_status "  Resource Group: $RESOURCE_GROUP"
    print_status "  Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
    
    cd "$PROJECT_ROOT"
}

# Setup Azure Automation for current deployment
setup_automation_for_current() {
    print_status "Setting up Azure Automation for current deployment..."
    
    # Prepare automation setup arguments
    AUTOMATION_ARGS=(
        "--cleanup-hours" "$CLEANUP_HOURS"
    )
    
    if [[ -n "$WEBHOOK_URL" ]]; then
        AUTOMATION_ARGS+=("--webhook-url" "$WEBHOOK_URL")
    fi
    
    # Run the automation setup script
    print_status "Running Azure Automation setup..."
    "$PROJECT_ROOT/scripts/setup-azure-automation.sh" "${AUTOMATION_ARGS[@]}"
    
    print_success "Azure Automation setup completed"
}

# Schedule cleanup for current deployment
schedule_current_cleanup() {
    print_status "Scheduling cleanup for current deployment..."
    
    # Calculate cleanup time
    # Cross-platform date handling (macOS vs Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD date)
        CLEANUP_TIME=$(date -j -v+${CLEANUP_HOURS}H '+%Y-%m-%dT%H:%M:%S')
    else
        # Linux (GNU date)
        CLEANUP_TIME=$(date -d "+$CLEANUP_HOURS hours" '+%Y-%m-%dT%H:%M:%S')
    fi
    
    # Get automation account details (using defaults from setup script)
    AUTOMATION_RG="rg-webapp-demo-automation"
    AUTOMATION_ACCOUNT="aa-webapp-demo-cleanup"
    
    # Create unique schedule name
    SCHEDULE_NAME="cleanup-$(echo "$RESOURCE_GROUP" | tr '[:upper:]' '[:lower:]')-$(date +%s)"
    
    print_status "Creating cleanup schedule: $SCHEDULE_NAME"
    print_status "Cleanup time: $CLEANUP_TIME"
    print_status "Target resource group: $RESOURCE_GROUP"
    
    # Create schedule
    az automation schedule create \
        --resource-group "$AUTOMATION_RG" \
        --automation-account-name "$AUTOMATION_ACCOUNT" \
        --name "$SCHEDULE_NAME" \
        --description "Automatic cleanup for $RESOURCE_GROUP" \
        --start-time "$CLEANUP_TIME" \
        --frequency "OneTime"
    
    # Link schedule to runbook with parameters
    WEBHOOK_PARAM=""
    if [[ -n "$WEBHOOK_URL" ]]; then
        WEBHOOK_PARAM="WebhookUrl=\"$WEBHOOK_URL\""
    fi
    
    az automation job-schedule create \
        --resource-group "$AUTOMATION_RG" \
        --automation-account-name "$AUTOMATION_ACCOUNT" \
        --runbook-name "WebAppDemoCleanup" \
        --schedule-name "$SCHEDULE_NAME" \
        --parameters "ResourceGroupName=\"$RESOURCE_GROUP\" SubscriptionId=\"$SUBSCRIPTION_ID\" $WEBHOOK_PARAM"
    
    print_success "Cleanup scheduled successfully!"
    
    echo ""
    echo "========================================"
    echo "AUTOMATIC CLEANUP SCHEDULED"
    echo "========================================"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Cleanup Time: $CLEANUP_TIME"
    echo "Schedule Name: $SCHEDULE_NAME"
    echo "Automation Account: $AUTOMATION_ACCOUNT"
    echo ""
    echo "To cancel cleanup:"
    echo "  az automation schedule delete \\"
    echo "    --resource-group $AUTOMATION_RG \\"
    echo "    --automation-account-name $AUTOMATION_ACCOUNT \\"
    echo "    --name $SCHEDULE_NAME"
    echo ""
    echo "To monitor cleanup:"
    echo "  az automation job list \\"
    echo "    --resource-group $AUTOMATION_RG \\"
    echo "    --automation-account-name $AUTOMATION_ACCOUNT"
    echo ""
}

# Main execution
main() {
    parse_arguments "$@"
    
    echo "========================================"
    echo "SETUP AUTOMATIC CLEANUP FOR CURRENT DEPLOYMENT"
    echo "========================================"
    echo "Cleanup Hours: $CLEANUP_HOURS"
    if [[ -n "$WEBHOOK_URL" ]]; then
        echo "Webhook URL: $WEBHOOK_URL"
    fi
    echo "========================================"
    echo ""
    
    check_prerequisites
    detect_current_deployment
    setup_automation_for_current
    schedule_current_cleanup
    
    echo ""
    echo "========================================"
    echo "SETUP COMPLETE"
    echo "========================================"
    echo ""
    print_success "Automatic cleanup configured for current deployment!"
    echo ""
    print_status "Next steps:"
    echo "1. Your resources will be automatically cleaned up in $CLEANUP_HOURS hours"
    echo "2. Monitor progress in Azure portal or with Azure CLI"
    echo "3. Cancel cleanup if needed using the commands shown above"
    echo ""
}

# Execute main function
main "$@"
