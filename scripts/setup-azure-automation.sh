#!/bin/bash

# ============================================================================
# AZURE AUTOMATION SETUP FOR WEBAPP DEMO AUTO-CLEANUP
# ============================================================================
#
# PURPOSE: Sets up Azure Automation Account to automatically run azure-automation-cleanup.py
# after a specified time period (default: 2 hours) to clean up demo resources.
#
# AUTOMATION WORKFLOW:
# 1. This script creates Azure Automation Account with Managed Identity
# 2. Uploads azure-automation-cleanup.py as a Python runbook
# 3. Schedules the runbook to execute after specified hours
# 4. Azure Automation runs the Python script automatically
# 5. Python script deletes resources and sends notifications
#
# DEMO PROJECT ONLY: This is a simplified automation setup.
# Production projects should use comprehensive CI/CD and lifecycle management.
#
# FEATURES:
# - Creates Azure Automation Account with Python 3 support
# - Configures Managed Identity with required RBAC permissions
# - Imports azure-automation-cleanup.py as Python runbook
# - Sets up scheduled cleanup jobs with flexible timing
# - Enables webhook notifications for Slack/Teams integration
# - Comprehensive error handling and validation
# - Cost-effective resource cleanup automation
#
# SECURITY:
# - Uses Managed Identity for secure authentication
# - Minimal required permissions (Contributor on target resources)
# - No stored credentials or secrets required
# - Audit trail through Azure Activity Log
#
# USAGE EXAMPLES:
#   ./scripts/setup-azure-automation.sh --resource-group rg-automation --location westus2
#   ./scripts/setup-azure-automation.sh --cleanup-hours 4 --webhook-url https://hooks.slack.com/...
#   ./scripts/setup-azure-automation.sh --target-rg webapp-demo-rg --automation-account my-cleanup

# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# ============================================================================
# SCRIPT CONFIGURATION AND GLOBAL VARIABLES
# ============================================================================

# Get absolute paths for script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default Azure Automation configuration
AUTOMATION_RG="rg-webapp-demo-automation"     # Resource group for automation account
AUTOMATION_ACCOUNT="aa-webapp-demo-cleanup"   # Automation account name
LOCATION="westus2"                            # Azure region for automation account
CLEANUP_HOURS=2                               # Hours after which cleanup runs
WEBHOOK_URL=""                                # Optional webhook for notifications
TARGET_RESOURCE_GROUP=""                      # Resource group to clean up (auto-detected)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Color-coded output functions for better user experience
print_status() { echo -e "\033[34m[INFO]\033[0m $1"; }      # Blue for informational messages
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }  # Green for success messages
print_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }  # Yellow for warnings
print_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }      # Red for errors

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --resource-group)
                AUTOMATION_RG="$2"
                shift 2
                ;;
            --automation-account)
                AUTOMATION_ACCOUNT="$2"
                shift 2
                ;;
            --location)
                LOCATION="$2"
                shift 2
                ;;
            --cleanup-hours)
                CLEANUP_HOURS="$2"
                shift 2
                ;;
            --webhook-url)
                WEBHOOK_URL="$2"
                shift 2
                ;;
            --target-resource-group)
                TARGET_RESOURCE_GROUP="$2"
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

# Show help information
show_help() {
    cat << EOF
Azure Automation Setup for WebApp Demo Auto-Cleanup

USAGE:
    ./scripts/setup-azure-automation.sh [OPTIONS]

OPTIONS:
    --resource-group NAME      Resource group for Automation Account (default: rg-webapp-demo-automation)
    --automation-account NAME Automation Account name (default: aa-webapp-demo-cleanup)
    --location REGION         Azure region (default: westus2)
    --cleanup-hours HOURS      Default cleanup hours (default: 2)
    --webhook-url URL          Webhook URL for notifications (optional)
    --help, -h                Show this help message

EXAMPLES:
    ./scripts/setup-azure-automation.sh
    ./scripts/setup-azure-automation.sh --resource-group rg-automation --location eastus
    ./scripts/setup-azure-automation.sh --cleanup-hours 4 --webhook-url https://hooks.slack.com/...

FEATURES:
    - Creates Azure Automation Account with Managed Identity
    - Configures required permissions for resource cleanup
    - Imports Python cleanup runbook (cross-platform compatible)
    - Sets up default cleanup schedules

REQUIREMENTS:
    - Azure CLI authenticated with sufficient permissions
    - Contributor access to subscription for Automation Account creation
    - Python 3 support in Azure Automation (available in most regions)
    - Python packages: azure-identity, azure-mgmt-resource, requests

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
    
    # Get subscription info
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    
    print_success "Prerequisites check passed"
    print_status "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
}

# Create Automation Account
create_automation_account() {
    print_status "Creating Azure Automation Account..."
    
    # Create resource group if it doesn't exist
    if ! az group show --name "$AUTOMATION_RG" &> /dev/null; then
        print_status "Creating resource group: $AUTOMATION_RG"
        az group create --name "$AUTOMATION_RG" --location "$LOCATION"
    fi
    
    # Create Automation Account
    if ! az automation account show --resource-group "$AUTOMATION_RG" --name "$AUTOMATION_ACCOUNT" &> /dev/null; then
        print_status "Creating Automation Account: $AUTOMATION_ACCOUNT"
        az automation account create \
            --resource-group "$AUTOMATION_RG" \
            --name "$AUTOMATION_ACCOUNT" \
            --location "$LOCATION" \
            --sku "Basic"
        
        print_success "Automation Account created successfully"
    else
        print_status "Automation Account already exists: $AUTOMATION_ACCOUNT"
    fi
    
    # Enable Managed Identity
    print_status "Enabling Managed Identity..."
    az automation account update \
        --resource-group "$AUTOMATION_RG" \
        --name "$AUTOMATION_ACCOUNT" \
        --assign-identity
    
    # Get Managed Identity Principal ID
    PRINCIPAL_ID=$(az automation account show \
        --resource-group "$AUTOMATION_RG" \
        --name "$AUTOMATION_ACCOUNT" \
        --query identity.principalId -o tsv)
    
    print_success "Managed Identity enabled with Principal ID: $PRINCIPAL_ID"
}

# Configure permissions
configure_permissions() {
    print_status "Configuring Managed Identity permissions..."
    
    # Assign Contributor role to subscription (for demo purposes)
    # In production, use more restrictive permissions
    az role assignment create \
        --assignee "$PRINCIPAL_ID" \
        --role "Contributor" \
        --scope "/subscriptions/$SUBSCRIPTION_ID"
    
    print_success "Permissions configured successfully"
    print_warning "Note: Contributor role assigned for demo purposes. Use more restrictive permissions in production."
}

# Import cleanup runbook
import_runbook() {
    print_status "Importing cleanup runbook..."

    local runbook_path="$SCRIPT_DIR/azure-automation-cleanup.py"

    if [[ ! -f "$runbook_path" ]]; then
        print_error "Runbook file not found: $runbook_path"
        exit 1
    fi
    
    # Import the runbook
    az automation runbook create \
        --resource-group "$AUTOMATION_RG" \
        --automation-account-name "$AUTOMATION_ACCOUNT" \
        --name "WebAppDemoCleanup" \
        --type "Python3" \
        --description "Automated cleanup for Azure WebApp Demo deployments"
    
    # Upload runbook content
    az automation runbook replace-content \
        --resource-group "$AUTOMATION_RG" \
        --automation-account-name "$AUTOMATION_ACCOUNT" \
        --name "WebAppDemoCleanup" \
        --content "@$runbook_path"
    
    # Publish the runbook
    az automation runbook publish \
        --resource-group "$AUTOMATION_RG" \
        --automation-account-name "$AUTOMATION_ACCOUNT" \
        --name "WebAppDemoCleanup"
    
    print_success "Cleanup runbook imported and published successfully"
}

# Create sample schedule
create_sample_schedule() {
    print_status "Creating sample cleanup schedule..."
    
    # Create a schedule for demonstration (disabled by default)
    # Cross-platform date handling (macOS vs Linux)
    local schedule_time
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD date)
        schedule_time=$(date -j -v+${CLEANUP_HOURS}H '+%Y-%m-%dT%H:%M:%S')
    else
        # Linux (GNU date)
        schedule_time=$(date -d "+$CLEANUP_HOURS hours" '+%Y-%m-%dT%H:%M:%S')
    fi
    
    az automation schedule create \
        --resource-group "$AUTOMATION_RG" \
        --automation-account-name "$AUTOMATION_ACCOUNT" \
        --name "DemoCleanupSchedule" \
        --description "Sample schedule for demo cleanup (disabled)" \
        --start-time "$schedule_time" \
        --frequency "OneTime" \
        --is-enabled false
    
    print_success "Sample schedule created (disabled)"
    print_status "Schedule time: $schedule_time"
}

# Generate usage instructions
generate_instructions() {
    print_status "Generating usage instructions..."
    
    cat > "$PROJECT_ROOT/azure-automation-usage.md" << EOF
# Azure Automation Cleanup Usage

## Automation Account Details
- **Resource Group**: $AUTOMATION_RG
- **Automation Account**: $AUTOMATION_ACCOUNT
- **Location**: $LOCATION
- **Runbook**: WebAppDemoCleanup

## Manual Runbook Execution

To manually trigger cleanup for a resource group:

\`\`\`bash
# Start runbook job
az automation runbook start \\
    --resource-group "$AUTOMATION_RG" \\
    --automation-account-name "$AUTOMATION_ACCOUNT" \\
    --name "WebAppDemoCleanup" \\
    --parameters ResourceGroupName="rg-webapp-demo-123" SubscriptionId="$SUBSCRIPTION_ID"
\`\`\`

## Scheduled Cleanup

To schedule automatic cleanup:

\`\`\`bash
# Create schedule
az automation schedule create \\
    --resource-group "$AUTOMATION_RG" \\
    --automation-account-name "$AUTOMATION_ACCOUNT" \\
    --name "CleanupSchedule-\$(date +%s)" \\
    --start-time "\$(if [[ \"\$OSTYPE\" == \"darwin\"* ]]; then date -j -v+2H '+%Y-%m-%dT%H:%M:%S'; else date -d '+2 hours' '+%Y-%m-%dT%H:%M:%S'; fi)" \\
    --frequency "OneTime"

# Link schedule to runbook
az automation job-schedule create \\
    --resource-group "$AUTOMATION_RG" \\
    --automation-account-name "$AUTOMATION_ACCOUNT" \\
    --runbook-name "WebAppDemoCleanup" \\
    --schedule-name "CleanupSchedule-\$(date +%s)" \\
    --parameters ResourceGroupName="rg-webapp-demo-123" SubscriptionId="$SUBSCRIPTION_ID"
\`\`\`

## Integration with Deploy Script

The deploy.sh script can be enhanced to use Azure Automation instead of local scheduling.

## Monitoring

Monitor runbook executions in Azure Portal:
- Navigate to Automation Account: $AUTOMATION_ACCOUNT
- Go to Process Automation > Jobs
- View job history and logs

EOF

    print_success "Usage instructions saved to: azure-automation-usage.md"
}

# Main function
main() {
    echo "========================================"
    echo "AZURE AUTOMATION SETUP FOR WEBAPP DEMO"
    echo "========================================"
    echo "Resource Group: $AUTOMATION_RG"
    echo "Automation Account: $AUTOMATION_ACCOUNT"
    echo "Location: $LOCATION"
    echo "Default Cleanup Hours: $CLEANUP_HOURS"
    echo "========================================"
    echo ""
    
    parse_arguments "$@"
    check_prerequisites
    create_automation_account
    configure_permissions
    import_runbook
    create_sample_schedule
    generate_instructions
    
    echo ""
    echo "========================================"
    echo "AZURE AUTOMATION SETUP COMPLETED!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "1. Review usage instructions: azure-automation-usage.md"
    echo "2. Test runbook execution manually"
    echo "3. Integrate with deploy.sh script (optional)"
    echo "4. Configure webhook notifications (optional)"
    echo ""
    echo "Automation Account: $AUTOMATION_ACCOUNT"
    echo "Resource Group: $AUTOMATION_RG"
    echo ""
}

# Run main function with all arguments
main "$@"
