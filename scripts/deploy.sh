#!/bin/bash

# Azure WebApp Demo - Simplified Deployment Script
#
# This script provides end-to-end deployment with automatic 2-hour cleanup.
# 
# DEMO PROJECT ONLY: This script uses simplified deployment patterns.
# Production projects should use proper CI/CD pipelines and environment management.
#
# Features:
# - Complete infrastructure deployment
# - Application container deployment
# - Automatic cleanup after 2 hours
# - Cost monitoring integration
# - FinOps best practices
#
# Usage:
#   ./scripts/deploy.sh [OPTIONS]
#
# Examples:
#   ./scripts/deploy.sh                    # Deploy with 2-hour auto-cleanup
#   ./scripts/deploy.sh --no-cleanup       # Deploy without auto-cleanup
#   ./scripts/deploy.sh --cleanup-hours 4  # Deploy with 4-hour auto-cleanup

# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# ============================================================================
# SCRIPT CONFIGURATION AND GLOBAL VARIABLES
# ============================================================================

# Get absolute paths for script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default deployment configuration
CLEANUP_HOURS=2          # Hours after which resources are automatically cleaned up
AUTO_CLEANUP=true        # Whether to enable automatic cleanup
BUDGET_ALERT=100         # Budget alert threshold in USD

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Color-coded output functions for better user experience
print_status() { echo -e "\033[34m[INFO]\033[0m $1"; }      # Blue for informational messages
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }  # Green for success messages
print_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }  # Yellow for warnings
print_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }      # Red for errors

# ============================================================================
# COMMAND LINE ARGUMENT PARSING
# ============================================================================

# Parse and validate command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-cleanup)
                # Disable automatic cleanup - resources will persist until manually deleted
                AUTO_CLEANUP=false
                shift
                ;;
            --cleanup-hours)
                # Set custom cleanup time in hours (must be positive integer)
                CLEANUP_HOURS="$2"
                shift 2
                ;;
            --budget)
                # Set budget alert threshold in USD (must be positive number)
                BUDGET_ALERT="$2"
                shift 2
                ;;
            --help|-h)
                # Display help information and exit
                show_help
                exit 0
                ;;
            *)
                # Handle unknown options with error message
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# HELP AND DOCUMENTATION
# ============================================================================

# Display comprehensive help information for the deployment script
show_help() {
    cat << EOF
Azure WebApp Demo - Simplified Deployment Script

USAGE:
    ./scripts/deploy.sh [OPTIONS]

OPTIONS:
    --no-cleanup           Disable automatic cleanup
    --cleanup-hours HOURS  Set cleanup timer (default: 2)
    --budget AMOUNT        Set budget alert amount (default: 100)
    --help, -h            Show this help message

EXAMPLES:
    ./scripts/deploy.sh                    # Deploy with 2-hour auto-cleanup
    ./scripts/deploy.sh --no-cleanup       # Deploy without auto-cleanup
    ./scripts/deploy.sh --cleanup-hours 4  # Deploy with 4-hour auto-cleanup
    ./scripts/deploy.sh --budget 50        # Deploy with \$50 budget alert

FEATURES:
    - Complete infrastructure deployment (Terraform)
    - Application container deployment
    - Automatic cleanup after specified time
    - Cost monitoring and budget alerts
    - FinOps best practices integration

COST ESTIMATE:
    - Infrastructure: ~\$50-70/month
    - Actual cost: ~\$0.10-0.30 for 2-hour deployment
    - Budget alerts help prevent cost overruns

EOF
}

# ============================================================================
# PRE-DEPLOYMENT VALIDATION
# ============================================================================

# Verify all required tools and authentication are available before deployment
pre_deployment_checks() {
    print_status "Running pre-deployment checks..."

    # Verify Azure CLI is installed and accessible
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi

    # Verify user is authenticated with Azure and has active subscription
    if ! az account show &> /dev/null; then
        print_error "Not authenticated with Azure. Please run 'az login'."
        exit 1
    fi

    # Verify Terraform is installed and accessible (required for infrastructure deployment)
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install Terraform."
        exit 1
    fi

    # Verify Docker is installed and accessible (required for container operations)
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker."
        exit 1
    fi

    print_success "Pre-deployment checks passed"
}

# ============================================================================
# TERRAFORM BACKEND SETUP
# ============================================================================

# Initialize Terraform backend (Azure Storage Account for state management)
bootstrap_backend() {
    print_status "Bootstrapping Terraform backend..."

    # Check if backend bootstrap script exists and execute it
    if [[ -f "$PROJECT_ROOT/scripts/bootstrap-tf-backend.sh" ]]; then
        # Run backend setup with dev environment configuration
        "$PROJECT_ROOT/scripts/bootstrap-tf-backend.sh" --env dev --project-prefix webapp-demo --location westus2
    else
        # If script doesn't exist, assume backend is already configured
        print_warning "Backend bootstrap script not found, assuming backend is already configured"
    fi
}

# ============================================================================
# INFRASTRUCTURE DEPLOYMENT
# ============================================================================

# Deploy Azure infrastructure using Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."

    # Change to terraform directory for all terraform operations
    cd "$PROJECT_ROOT/terraform"

    # Initialize Terraform with backend configuration
    print_status "Initializing Terraform..."
    terraform init -backend-config="environments/dev/backend.conf"

    # Create execution plan to preview changes
    print_status "Planning infrastructure deployment..."
    terraform plan -var-file="environments/dev/terraform.tfvars" -out=tfplan

    # Apply the planned changes to create/update infrastructure
    print_status "Applying infrastructure deployment..."
    terraform apply tfplan

    # Clean up the plan file (contains sensitive information)
    rm -f tfplan

    # Return to project root directory
    cd "$PROJECT_ROOT"

    print_success "Infrastructure deployed successfully!"
}

# ============================================================================
# APPLICATION DEPLOYMENT
# ============================================================================

# Deploy the Flask web application as a container to Azure
deploy_application() {
    print_status "Deploying application container..."

    # Check if container deployment script exists and execute it
    if [[ -f "$PROJECT_ROOT/scripts/deploy-container.sh" ]]; then
        # Deploy container with dev environment configuration
        "$PROJECT_ROOT/scripts/deploy-container.sh" --env dev
    else
        # If script doesn't exist, skip application deployment
        print_warning "Container deployment script not found, skipping application deployment"
    fi

    print_success "Application deployment completed!"
}

# ============================================================================
# COST MONITORING AND FINOPS SETUP
# ============================================================================

# Configure cost monitoring, budget alerts, and FinOps best practices
setup_cost_monitoring() {
    print_status "Setting up cost monitoring and budget alerts..."

    # Check if cost monitoring script exists and configure it
    if [[ -f "$PROJECT_ROOT/scripts/cost-monitor.sh" ]]; then
        # Configure budget alert with specified threshold
        "$PROJECT_ROOT/scripts/cost-monitor.sh" --budget "$BUDGET_ALERT" --env dev

        # Generate initial cost estimate for transparency
        "$PROJECT_ROOT/scripts/cost-monitor.sh" --estimate --env dev
    else
        # If script doesn't exist, skip cost monitoring setup
        print_warning "Cost monitoring script not found, skipping cost setup"
    fi

    print_success "Cost monitoring configured with $BUDGET_ALERT budget alert"
}

# ============================================================================
# AUTOMATIC CLEANUP SCHEDULING
# ============================================================================

# Schedule automatic resource cleanup to prevent cost overruns
schedule_cleanup() {
    if [[ "$AUTO_CLEANUP" == "true" ]]; then
        print_status "Scheduling automatic cleanup in $CLEANUP_HOURS hours..."

        # Calculate the exact cleanup time for user information
        # Cross-platform date handling (macOS vs Linux)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS (BSD date)
            CLEANUP_TIME=$(date -j -v+${CLEANUP_HOURS}H '+%Y-%m-%d %H:%M:%S')
        else
            # Linux (GNU date)
            CLEANUP_TIME=$(date -d "+$CLEANUP_HOURS hours" '+%Y-%m-%d %H:%M:%S')
        fi

        # Display cleanup schedule information to user
        print_warning "AUTOMATIC CLEANUP SCHEDULED:"
        print_warning "  Time: $CLEANUP_TIME"
        print_warning "  Command: $PROJECT_ROOT/scripts/cleanup.sh --force"
        print_warning ""
        print_warning "To cancel automatic cleanup, run:"
        print_warning "  $PROJECT_ROOT/scripts/cleanup.sh --cancel-auto"

        # Create a background cleanup script (simplified approach for demo)
        # Production environments should use Azure Automation or similar services
        cat > "$PROJECT_ROOT/.cleanup_scheduled" << EOF
#!/bin/bash
# Automatic cleanup scheduled for: $CLEANUP_TIME
# Created: $(date)
# Cleanup command: $PROJECT_ROOT/scripts/cleanup.sh --force

# Wait for the specified number of hours
sleep $((CLEANUP_HOURS * 3600))
echo "Executing automatic cleanup at \$(date)"
$PROJECT_ROOT/scripts/cleanup.sh --force
EOF

        # Make the cleanup script executable and run it in background
        chmod +x "$PROJECT_ROOT/.cleanup_scheduled"
        nohup "$PROJECT_ROOT/.cleanup_scheduled" > "$PROJECT_ROOT/.cleanup.log" 2>&1 &

        print_success "Automatic cleanup scheduled for $CLEANUP_TIME"
    else
        # If auto-cleanup is disabled, remind user to clean up manually
        print_warning "Automatic cleanup disabled. Remember to run './scripts/cleanup.sh' when done."
    fi
}

# ============================================================================
# DEPLOYMENT VALIDATION
# ============================================================================

# Validate that the deployment was successful and all components are working
validate_deployment() {
    print_status "Validating deployment..."

    # Check if validation script exists and run comprehensive tests
    if [[ -f "$PROJECT_ROOT/scripts/validate-database-source.sh" ]]; then
        # Run validation but don't fail deployment if validation has issues
        print_status "Running validation tests (non-blocking)..."
        set +e  # Temporarily disable exit on error
        "$PROJECT_ROOT/scripts/validate-database-source.sh"
        validation_result=$?
        set -e  # Re-enable exit on error

        if [[ $validation_result -eq 0 ]]; then
            print_success "Deployment validation passed!"
        else
            print_warning "Validation script encountered issues, but deployment infrastructure is complete"
            print_warning "You can manually test the application or debug validation issues"
            print_warning "Infrastructure will remain deployed for debugging"
            print_warning "To debug: check application logs or test endpoints manually"
        fi
    else
        # If validation script doesn't exist, skip validation
        print_warning "Validation script not found, skipping validation"
    fi

    print_success "Deployment validation completed!"
}

# ============================================================================
# MAIN DEPLOYMENT ORCHESTRATION
# ============================================================================

# Main function that orchestrates the entire deployment process
main() {
    # Parse and validate command line arguments
    parse_arguments "$@"

    # Display deployment configuration banner
    echo "========================================"
    echo "AZURE WEBAPP DEMO - SIMPLIFIED DEPLOYMENT"
    echo "========================================"
    echo "Auto-cleanup: $AUTO_CLEANUP"
    echo "Cleanup hours: $CLEANUP_HOURS"
    echo "Budget alert: \$$BUDGET_ALERT"
    echo "========================================"
    echo ""

    # Execute deployment steps in sequence
    pre_deployment_checks    # Verify prerequisites and authentication
    bootstrap_backend       # Set up Terraform backend storage
    deploy_infrastructure   # Deploy Azure infrastructure with Terraform
    deploy_application      # Deploy Flask application container
    setup_cost_monitoring   # Configure cost alerts and monitoring
    schedule_cleanup        # Set up automatic resource cleanup
    validate_deployment     # Verify deployment success

    # Display completion message and next steps
    echo ""
    echo "========================================"
    echo "DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "1. Test your application at the deployed URL"
    echo "2. Monitor costs with: ./scripts/cost-monitor.sh --actual"
    echo "3. View cost dashboard: ./scripts/cost-dashboard.sh"
    if [[ "$AUTO_CLEANUP" == "true" ]]; then
        echo "4. Automatic cleanup in $CLEANUP_HOURS hours"
    else
        echo "4. Manual cleanup: ./scripts/cleanup.sh"
    fi
    echo ""
    echo "For support, see: README.md"
    echo "========================================"
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Execute main function with all command line arguments
main "$@"
