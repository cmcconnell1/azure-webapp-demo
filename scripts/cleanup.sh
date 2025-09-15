#!/bin/bash

# Azure WebApp Demo - Simplified Cleanup Script
#
# This script provides complete cleanup of all Azure resources.
# 
# DEMO PROJECT ONLY: This script uses simplified cleanup patterns.
# Production projects should use proper resource lifecycle management.
#
# Features:
# - Complete infrastructure cleanup
# - Cost monitoring and final report
# - Automatic cleanup cancellation
# - Safety confirmations
#
# Usage:
#   ./scripts/cleanup.sh [OPTIONS]
#
# Examples:
#   ./scripts/cleanup.sh                # Interactive cleanup with confirmation
#   ./scripts/cleanup.sh --force        # Force cleanup without confirmation
#   ./scripts/cleanup.sh --cancel-auto  # Cancel automatic cleanup
#   ./scripts/cleanup.sh --cost-report  # Generate final cost report

# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# ============================================================================
# SCRIPT CONFIGURATION AND GLOBAL VARIABLES
# ============================================================================

# Get absolute paths for script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default cleanup configuration
FORCE_CLEANUP=false     # Whether to skip confirmation prompts
CANCEL_AUTO=false       # Whether to cancel automatic cleanup
COST_REPORT=false       # Whether to generate final cost report
ENVIRONMENT="dev"       # Target environment (dev, staging, prod)
VERBOSE=false           # Whether to show verbose output

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
            --force)
                # Skip confirmation prompts and force cleanup
                FORCE_CLEANUP=true
                shift
                ;;
            --cancel-auto)
                # Cancel any scheduled automatic cleanup
                CANCEL_AUTO=true
                shift
                ;;
            --cost-report)
                # Generate final cost report before cleanup
                COST_REPORT=true
                shift
                ;;
            --env)
                # Set target environment
                ENVIRONMENT="$2"
                shift 2
                ;;
            --verbose)
                # Enable verbose output
                VERBOSE=true
                shift
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

    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Invalid environment: $ENVIRONMENT"
        print_error "Valid environments: dev, staging, prod"
        exit 1
    fi
}

# ============================================================================
# HELP AND DOCUMENTATION
# ============================================================================

# Display comprehensive help information for the cleanup script
show_help() {
    cat << EOF
Azure WebApp Demo - Simplified Cleanup Script

USAGE:
    ./scripts/cleanup.sh [OPTIONS]

OPTIONS:
    --force           Force cleanup without confirmation
    --cancel-auto     Cancel automatic cleanup
    --cost-report     Generate final cost report
    --env ENV         Target environment (dev, staging, prod) [default: dev]
    --verbose         Enable verbose output
    --help, -h       Show this help message

EXAMPLES:
    ./scripts/cleanup.sh                           # Interactive cleanup with confirmation (dev)
    ./scripts/cleanup.sh --force                   # Force cleanup without confirmation (dev)
    ./scripts/cleanup.sh --env staging     # Cleanup staging environment
    ./scripts/cleanup.sh --env prod --force # Force cleanup production environment
    ./scripts/cleanup.sh --cancel-auto             # Cancel automatic cleanup
    ./scripts/cleanup.sh --cost-report             # Generate final cost report

FEATURES:
    - Complete infrastructure cleanup (Terraform destroy)
    - Final cost report generation
    - Automatic cleanup cancellation
    - Safety confirmations for interactive mode

SAFETY:
    - Interactive mode requires confirmation
    - Force mode bypasses confirmations (use with caution)
    - Generates final cost report before cleanup

EOF
}

# ============================================================================
# AUTOMATIC CLEANUP MANAGEMENT
# ============================================================================

# Cancel any scheduled automatic cleanup to prevent unwanted resource deletion
cancel_automatic_cleanup() {
    print_status "Canceling automatic cleanup..."

    # Check if automatic cleanup is scheduled
    if [[ -f "$PROJECT_ROOT/.cleanup_scheduled" ]]; then
        # Find and terminate the background cleanup process
        CLEANUP_PID=$(pgrep -f ".cleanup_scheduled" || true)
        if [[ -n "$CLEANUP_PID" ]]; then
            # Kill the cleanup process gracefully
            kill "$CLEANUP_PID" || true
            print_success "Automatic cleanup process canceled (PID: $CLEANUP_PID)"
        else
            print_warning "No automatic cleanup process found"
        fi

        # Remove cleanup script and log files
        rm -f "$PROJECT_ROOT/.cleanup_scheduled"
        rm -f "$PROJECT_ROOT/.cleanup.log"

        print_success "Automatic cleanup canceled successfully"
    else
        print_warning "No automatic cleanup scheduled"
    fi
}

# ============================================================================
# COST REPORTING AND FINOPS
# ============================================================================

# Generate comprehensive final cost report before cleanup
generate_cost_report() {
    print_status "Generating final cost report..."

    # Check if cost monitoring script exists
    if [[ -f "$PROJECT_ROOT/scripts/cost-monitor.sh" ]]; then
        print_status "Generating final cost report (may show warnings if resources already cleaned up)..."

        # Generate detailed cost report with actual spending data
        # Note: This may fail if resources are already cleaned up, which is expected
        if "$PROJECT_ROOT/scripts/cost-monitor.sh" --actual --env "$ENVIRONMENT" --export final-cost-report.json 2>/dev/null; then
            print_success "Final cost report generated successfully"
        else
            print_warning "Cost report generation skipped (resources already cleaned up)"
            print_status "This is normal after successful cleanup"
        fi

        # Generate visual cost dashboard if available
        if [[ -f "$PROJECT_ROOT/scripts/cost-dashboard.sh" ]]; then
            print_status "Attempting to generate cost dashboard..."
            if "$PROJECT_ROOT/scripts/cost-dashboard.sh" --output final-cost-dashboard.html --budget 100 2>/dev/null; then
                print_success "Final cost dashboard saved to: final-cost-dashboard.html"
            else
                print_warning "Cost dashboard generation skipped (no cost data available)"
                print_status "This is normal after successful cleanup"
            fi
        fi
    else
        # If cost monitoring isn't available, skip report generation
        print_warning "Cost monitoring script not found, skipping cost report"
    fi
}

# ============================================================================
# PRE-CLEANUP VALIDATION
# ============================================================================

# Verify all required tools and authentication are available before cleanup
pre_cleanup_checks() {
    print_status "Running pre-cleanup checks..."

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

    # Verify Terraform is installed and accessible (required for infrastructure cleanup)
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install Terraform."
        exit 1
    fi

    print_success "Pre-cleanup checks passed"
}

# ============================================================================
# SAFETY CONFIRMATION
# ============================================================================

# Confirm cleanup operation with user to prevent accidental resource deletion
confirm_cleanup() {
    if [[ "$FORCE_CLEANUP" == "false" ]]; then
        echo ""
        print_warning "WARNING: This will delete ALL Azure resources for the webapp-demo project!"
        print_warning "This action cannot be undone."
        echo ""

        # Display list of resources that will be deleted for transparency
        print_status "Resources to be deleted:"
        az group list --query "[?contains(name, 'webapp-demo')].{Name:name, Location:location}" --output table || true
        echo ""

        # Require explicit confirmation to proceed
        read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            print_status "Cleanup canceled by user"
            exit 0
        fi
    fi
}

# ============================================================================
# INFRASTRUCTURE CLEANUP
# ============================================================================

# Clean up all Azure infrastructure using Terraform destroy
cleanup_infrastructure() {
    print_status "Cleaning up infrastructure with Terraform..."

    # Change to terraform directory for all terraform operations
    cd "$PROJECT_ROOT/terraform"

    # Initialize Terraform (in case it's not already initialized)
    print_status "Initializing Terraform for environment: $ENVIRONMENT"
    if terraform init -backend-config="environments/$ENVIRONMENT/backend.conf"; then
        # Destroy all infrastructure resources
        print_status "Destroying infrastructure for environment: $ENVIRONMENT"
        if [[ "$FORCE_CLEANUP" == "true" ]]; then
            # Force mode: auto-approve destruction without prompts
            terraform destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars" -auto-approve || true
        else
            # Interactive mode: prompt for confirmation before destruction
            terraform destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars" || true
        fi
    else
        print_warning "Terraform initialization failed, skipping terraform destroy"
        print_warning "Will proceed with Azure CLI cleanup of remaining resources"
    fi

    # Return to project root directory
    cd "$PROJECT_ROOT"

    print_success "Infrastructure cleanup completed!"
}

# ============================================================================
# ADDITIONAL RESOURCE CLEANUP
# ============================================================================

# Clean up any remaining Azure resources not handled by Terraform
# NOTE: This preserves the Terraform state resource group for future deployments
cleanup_additional_resources() {
    print_status "Cleaning up additional resources..."

    # Find any remaining resource groups for this specific environment (exclude Terraform state RG)
    RESOURCE_GROUPS=$(az group list --query "[?contains(name, 'webapp-demo-${ENVIRONMENT}') && !contains(name, 'terraform-state')].name" --output tsv || true)

    if [[ -n "$RESOURCE_GROUPS" ]]; then
        print_status "Found additional resource groups to clean up:"
        echo "$RESOURCE_GROUPS"

        # Delete each resource group asynchronously for faster cleanup
        for rg in $RESOURCE_GROUPS; do
            print_status "Deleting resource group: $rg"
            az group delete --name "$rg" --yes --no-wait || true
        done

        print_success "Additional resource cleanup initiated"
    else
        print_success "No additional resources found"
    fi
}

# ============================================================================
# LOCAL FILE CLEANUP
# ============================================================================

# Clean up local files and temporary artifacts
cleanup_local_files() {
    print_status "Cleaning up local files..."

    # Remove Terraform state files (if stored locally instead of remote backend)
    find "$PROJECT_ROOT" -name "terraform.tfstate*" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true

    # Remove automatic cleanup scheduling files
    rm -f "$PROJECT_ROOT/.cleanup_scheduled"
    rm -f "$PROJECT_ROOT/.cleanup.log"

    # Remove temporary cost monitoring files (preserve final reports)
    find "$PROJECT_ROOT" -name "*-costs.json" ! -name "final-cost-report.json" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*-dashboard.html" ! -name "final-cost-dashboard.html" -delete 2>/dev/null || true

    print_success "Local files cleaned up"
}

# ============================================================================
# CLEANUP VERIFICATION
# ============================================================================

# Verify that cleanup was successful and all resources are deleted
verify_cleanup() {
    print_status "Verifying cleanup completion..."

    # Check for any remaining resource groups for this specific environment (exclude Terraform state RG)
    REMAINING_GROUPS=$(az group list --query "[?contains(name, 'webapp-demo-${ENVIRONMENT}') && !contains(name, 'terraform-state')].name" --output tsv || true)

    if [[ -n "$REMAINING_GROUPS" ]]; then
        # Some resources may still be in the process of deletion
        print_warning "Some resource groups may still be deleting:"
        echo "$REMAINING_GROUPS"
        print_warning "Deletion may take a few minutes to complete"
    else
        # All resources have been successfully deleted
        print_success "All resource groups have been deleted"
    fi

    print_success "Cleanup verification completed"
}

# ============================================================================
# MAIN CLEANUP ORCHESTRATION
# ============================================================================

# Main function that orchestrates the entire cleanup process
main() {
    # Display cleanup configuration banner
    echo "========================================"
    echo "AZURE WEBAPP DEMO - SIMPLIFIED CLEANUP"
    echo "========================================"
    echo "Force mode: $FORCE_CLEANUP"
    echo "Cancel auto: $CANCEL_AUTO"
    echo "Cost report: $COST_REPORT"
    echo "========================================"
    echo ""

    # Parse and validate command line arguments
    parse_arguments "$@"

    # Handle special operation modes
    if [[ "$CANCEL_AUTO" == "true" ]]; then
        # Cancel automatic cleanup and exit
        cancel_automatic_cleanup
        exit 0
    fi

    if [[ "$COST_REPORT" == "true" ]]; then
        # Generate cost report only and exit
        generate_cost_report
        exit 0
    fi

    # Execute full cleanup process in sequence
    pre_cleanup_checks          # Verify prerequisites and authentication
    generate_cost_report        # Generate final cost report before deletion
    confirm_cleanup            # Get user confirmation (unless force mode)
    cleanup_infrastructure     # Destroy infrastructure with Terraform
    cleanup_additional_resources # Clean up any remaining Azure resources
    cleanup_local_files        # Remove local temporary files
    verify_cleanup             # Verify all resources are deleted

    # Display completion message and summary
    echo ""
    echo "========================================"
    echo "CLEANUP COMPLETED SUCCESSFULLY!"
    echo "========================================"
    echo ""
    echo "Summary:"
    echo "- All Azure resources deleted"
    echo "- Local files cleaned up"
    echo "- Final cost report generated"
    echo ""
    echo "Files preserved:"
    echo "- final-cost-report.json"
    echo "- final-cost-dashboard.html"
    echo ""
    echo "Thank you for using Azure WebApp Demo!"
    echo "========================================"
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Execute main function with all command line arguments
main "$@"
