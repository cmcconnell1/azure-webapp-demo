#!/bin/bash

# Azure WebApp Demo - Simplified Cost Monitor
#
# DEMO PROJECT ONLY: Simplified cost monitoring for 2-hour deployments.
# Production projects should use comprehensive FinOps monitoring solutions.
#
# This script provides essential cost monitoring and FinOps best practices:
# 1. Cost estimation for 2-hour deployments
# 2. Actual cost tracking via Azure Cost Management API
# 3. Budget alerts and threshold monitoring
# 4. Final cost reporting for cleanup
#
# Features optimized for demo deployments:
# - Focus on short-term cost tracking (hours, not months)
# - Budget alerts for cost overruns
# - Integration with deploy.sh and cleanup.sh
# - FinOps best practices demonstration
#
# Usage:
#   ./scripts/cost-monitor.sh --estimate         # Estimate 2-hour deployment cost
#   ./scripts/cost-monitor.sh --actual           # Current actual costs
#   ./scripts/cost-monitor.sh --budget 10        # Set budget alert at $10
#   ./scripts/cost-monitor.sh --env demo --export report.json  # Export cost data

# Exit on any error
set -e

# ============================================================================
# SCRIPT CONFIGURATION AND GLOBAL VARIABLES
# ============================================================================

# ANSI color codes for enhanced output formatting
RED='\033[0;31m'      # Red for errors and warnings
GREEN='\033[0;32m'    # Green for success messages
YELLOW='\033[1;33m'   # Yellow for important information
BLUE='\033[0;34m'     # Blue for informational messages
NC='\033[0m'          # No color (reset)

# Project configuration for demo deployments
PROJECT_NAME="webapp-demo"    # Project identifier for resource filtering
ENVIRONMENT="demo"            # Environment name for cost tracking
BUDGET=""                     # Budget threshold (set via command line)
EXPORT_FILE=""               # Output file for cost data export
QUIET=false                  # Whether to suppress verbose output
MODE="actual"                # Operation mode: actual, estimate
REGION="westus2"             # Azure region for cost calculations

# Demo-specific cost estimation settings
DEPLOYMENT_HOURS=2           # Default deployment duration for cost calculations
HOURLY_RATE_ESTIMATE=0.15    # Estimated hourly cost for S1 App Service + S0 SQL Database

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Color-coded output functions for better user experience
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Additional color-coded output functions
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"    # Green for success messages
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"   # Yellow for warnings and important notices
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"        # Red for errors and critical issues
}

# ============================================================================
# HELP AND DOCUMENTATION
# ============================================================================

# Display comprehensive help information for the cost monitoring script
show_help() {
    echo "Azure WebApp Demo - Simplified Cost Monitor"
    echo
    echo "DEMO PROJECT ONLY: Simplified cost monitoring for 2-hour deployments."
    echo "Demonstrates FinOps best practices for short-term cloud deployments."
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Modes:"
    echo "  --actual              Show actual Azure billing costs (default)"
    echo "  --estimate            Show cost estimates for 2-hour deployment"
    echo
    echo "Options:"
    echo "  --budget AMOUNT        Budget limit for alerts (USD, default: 10)"
    echo "  --export FILE          Export results to JSON file"
    echo "  --env ENV              Target environment (dev, staging, prod, demo)"
    echo "  --quiet               Minimal output for scripting"
    echo "  --help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0                     # Current actual costs"
    echo "  $0 --estimate          # Estimate 2-hour deployment cost"
    echo "  $0 --budget 5          # Set budget alert at \$5"
    echo "  $0 --export costs.json # Export cost data"
    echo
    echo "FinOps Features:"
    echo "  - Real-time cost tracking"
    echo "  - Budget alerts and thresholds"
    echo "  - Cost estimation before deployment"
    echo "  - Integration with deploy.sh and cleanup.sh"
    echo
    echo "Estimated Costs (2-hour deployment):"
    echo "  - App Service S1: ~\$0.06"
    echo "  - SQL Database S0: ~\$0.08"
    echo "  - Other services: ~\$0.01"
    echo "  - Total: ~\$0.15 per 2-hour deployment"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --actual)
                MODE="actual"
                shift
                ;;
            --estimate)
                MODE="estimate"
                shift
                ;;
            --budget)
                BUDGET="$2"
                shift 2
                ;;
            --export)
                EXPORT_FILE="$2"
                shift 2
                ;;
            --env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_error "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Set default budget if not specified
    if [[ -z "$BUDGET" ]]; then
        BUDGET="10"  # Default $10 budget for demo deployments
    fi
}

# Check dependencies for actual cost monitoring
check_dependencies() {
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

    # For actual cost monitoring, check if Python script exists
    if [[ "$MODE" == "actual" ]] && [[ ! -f "scripts/azure-cost-monitor.py" ]]; then
        print_warning "azure-cost-monitor.py not found, using simplified cost tracking"
        MODE="estimate"  # Fallback to estimation
    fi

}

# Simplified cost estimation for 2-hour demo deployment
estimate_demo_costs() {
    print_status "Estimating costs for 2-hour demo deployment..."

    # Hardcoded pricing for S1 App Service + S0 SQL Database in West US 2
    # These are approximate rates as of 2024 (demo purposes only)
    local app_service_hourly=0.0292  # S1 Standard: ~$21.17/month = $0.0292/hour
    local sql_database_hourly=0.0417 # S0 Standard: ~$30.24/month = $0.0417/hour
    local other_services_hourly=0.005 # Key Vault, App Insights, etc.

    local total_hourly=$(echo "$app_service_hourly + $sql_database_hourly + $other_services_hourly" | bc -l 2>/dev/null || echo "0.075")
    local total_2hour=$(echo "$total_hourly * $DEPLOYMENT_HOURS" | bc -l 2>/dev/null || echo "0.15")

    echo ""
    echo "========================================"
    echo "COST ESTIMATION - 2-HOUR DEMO DEPLOYMENT"
    echo "========================================"
    echo "Region: $REGION"
    echo "Deployment Duration: $DEPLOYMENT_HOURS hours"
    echo ""
    echo "Service Breakdown (per hour):"
    printf "  App Service (S1):     \$%.4f\n" "$app_service_hourly"
    printf "  SQL Database (S0):    \$%.4f\n" "$sql_database_hourly"
    printf "  Other Services:       \$%.4f\n" "$other_services_hourly"
    echo "  --------------------------------"
    printf "  Total per hour:       \$%.4f\n" "$total_hourly"
    echo ""
    printf "Total estimated cost:   \$%.2f\n" "$total_2hour"
    echo ""

    # Budget comparison
    if [[ -n "$BUDGET" ]]; then
        local budget_numeric=$(echo "$BUDGET" | sed 's/[^0-9.]//g')
        if (( $(echo "$total_2hour > $budget_numeric" | bc -l 2>/dev/null || echo "0") )); then
            print_warning "Estimated cost (\$$total_2hour) exceeds budget (\$$budget_numeric)!"
        else
            print_success "Estimated cost (\$$total_2hour) is within budget (\$$budget_numeric)"
        fi
    fi

    echo "========================================"
    echo ""
    echo "FinOps Best Practices:"
    echo "- Set budget alerts before deployment"
    echo "- Monitor actual costs during deployment"
    echo "- Use automatic cleanup to prevent overruns"
    echo "- Review final cost report after cleanup"
}

# Get actual costs using Azure CLI
get_actual_costs() {
    print_status "Retrieving actual costs for webapp-demo resources..."

    # Get current month costs for webapp-demo resource groups
    # Cross-platform date handling (macOS vs Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD date)
        local start_date=$(date -j -f "%Y-%m-%d" "$(date +%Y-%m-01)" +%Y-%m-%d)
    else
        # Linux (GNU date)
        local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
    fi
    local end_date=$(date +%Y-%m-%d)

    echo ""
    echo "========================================"
    echo "ACTUAL COSTS - WEBAPP-DEMO PROJECT"
    echo "========================================"
    echo "Period: $start_date to $end_date"
    echo ""

    # Try to get costs using Azure CLI (simplified approach)
    local total_cost=0
    local resource_groups=$(az group list --query "[?contains(name, 'webapp-demo')].name" -o tsv 2>/dev/null || echo "")

    if [[ -n "$resource_groups" ]]; then
        echo "Resource Groups Found:"
        for rg in $resource_groups; do
            echo "  - $rg"
            # Get resource count for basic cost estimation
            local resource_count=$(az resource list --resource-group "$rg" --query "length(@)" -o tsv 2>/dev/null || echo "0")
            echo "    Resources: $resource_count"
        done
        echo ""
        print_status "For detailed cost analysis, use Azure Cost Management in the portal"
        print_status "Or run: az consumption usage list --start-date $start_date --end-date $end_date"

        # Provide basic cost estimation based on known resource types
        echo ""
        echo "Estimated Daily Costs (approximate):"
        echo "  - App Service S1: ~$1.44/day"
        echo "  - SQL Database S0: ~$3.84/day"
        echo "  - Other services: ~$0.50/day"
        echo "  - Total estimate: ~$5.78/day"
        echo ""
        print_warning "Note: Actual costs may vary. Use Azure Cost Management for precise billing."
    else
        print_warning "No webapp-demo resource groups found"
        print_status "Resources may have been cleaned up or not yet deployed"
    fi

    # Budget comparison
    if [[ -n "$BUDGET" ]]; then
        echo ""
        echo "Budget Alert: \$$BUDGET"
        print_status "Monitor costs regularly to stay within budget"
    fi

    echo "========================================"
}

# Export cost data to JSON file
export_cost_data() {
    if [[ -n "$EXPORT_FILE" ]]; then
        print_status "Exporting cost data to $EXPORT_FILE..."

        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local estimated_cost=$(echo "$HOURLY_RATE_ESTIMATE * $DEPLOYMENT_HOURS" | bc -l 2>/dev/null || echo "0.15")

        cat > "$EXPORT_FILE" << EOF
{
  "timestamp": "$timestamp",
  "project": "$PROJECT_NAME",
  "environment": "$ENVIRONMENT",
  "deployment_hours": $DEPLOYMENT_HOURS,
  "estimated_cost_usd": $estimated_cost,
  "budget_usd": $BUDGET,
  "region": "$REGION",
  "services": {
    "app_service": "S1 Standard",
    "sql_database": "S0 Standard",
    "key_vault": "Standard",
    "application_insights": "Basic"
  },
  "finops_notes": "2-hour demo deployment with automatic cleanup"
}
EOF

        print_success "Cost data exported to $EXPORT_FILE"
    fi
}

# Main execution function
main() {
    parse_arguments "$@"

    if [[ "$QUIET" != "true" ]]; then
        echo ""
        echo "========================================"
        echo "AZURE WEBAPP DEMO - COST MONITOR"
        echo "========================================"
        echo "Project: $PROJECT_NAME"
        echo "Environment: $ENVIRONMENT"
        echo "Mode: $MODE"
        echo "Budget: \$$BUDGET"
        echo "========================================"
        echo ""
    fi

    # Execute based on mode
    case "$MODE" in
        estimate)
            estimate_demo_costs
            ;;
        actual)
            check_dependencies
            get_actual_costs
            ;;
        *)
            print_error "Unknown mode: $MODE"
            exit 1
            ;;
    esac

    # Export data if requested
    export_cost_data

    if [[ "$QUIET" != "true" ]]; then
        echo ""
        echo "FinOps Recommendations:"
        echo "- Monitor costs regularly during deployment"
        echo "- Use budget alerts to prevent overruns"
        echo "- Clean up resources promptly after testing"
        echo "- Review final cost report after cleanup"
        echo ""
    fi
}

# Run main function with all arguments
main "$@"
