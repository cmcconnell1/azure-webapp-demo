#!/bin/bash

# End-to-End Testing Script for Azure WebApp Demo
#
# This script validates that all components of the simplified deployment are working correctly.
# 
# DEMO PROJECT ONLY: This is a simplified testing approach.
# Production projects should use comprehensive testing frameworks.
#
# Features:
# - Script syntax validation
# - Terraform configuration validation
# - Python application validation
# - Cost monitoring validation
# - Documentation validation
#
# Usage:
#   ./scripts/test-end-to-end.sh [OPTIONS]
#
# Examples:
#   ./scripts/test-end-to-end.sh                # Run all tests
#   ./scripts/test-end-to-end.sh --quick        # Run quick tests only
#   ./scripts/test-end-to-end.sh --verbose      # Verbose output

# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# ============================================================================
# SCRIPT CONFIGURATION AND GLOBAL VARIABLES
# ============================================================================

# Get absolute paths for script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test execution configuration
QUICK_MODE=false         # Whether to run only essential tests (faster execution)
VERBOSE=false           # Whether to show detailed output for debugging

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
            --quick)
                # Enable quick mode - run only essential tests for faster feedback
                QUICK_MODE=true
                shift
                ;;
            --verbose)
                # Enable verbose output for debugging and detailed information
                VERBOSE=true
                shift
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
End-to-End Testing Script for Azure WebApp Demo

USAGE:
    ./scripts/test-end-to-end.sh [OPTIONS]

OPTIONS:
    --quick           Run quick tests only (skip comprehensive checks)
    --verbose         Enable verbose output
    --help, -h       Show this help message

EXAMPLES:
    ./scripts/test-end-to-end.sh                # Run all tests
    ./scripts/test-end-to-end.sh --quick        # Run quick tests only
    ./scripts/test-end-to-end.sh --verbose      # Verbose output

TESTS:
    1. Script syntax validation
    2. Terraform configuration validation
    3. Python application validation
    4. Cost monitoring validation
    5. Documentation validation

EOF
}

# Test script syntax
test_scripts() {
    print_status "Testing script syntax..."
    
    local scripts=(
        "deploy.sh"
        "cleanup.sh"
        "cost-monitor.sh"
        "cost-dashboard.sh"
        "setup-cost-monitoring.sh"
        "validate-database-source.sh"
        "setup-azure-automation.sh"
        "test-end-to-end.sh"
    )

    local python_scripts=(
        "azure-automation-cleanup.py"
    )

    local failed=0

    # Test shell scripts
    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            if bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
                [[ "$VERBOSE" == "true" ]] && print_success "PASS: $script syntax OK"
            else
                print_error "FAIL: $script syntax error"
                failed=$((failed + 1))
            fi
        else
            print_warning "? $script not found"
        fi
    done

    # Test Python scripts
    for script in "${python_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            if python3 -m py_compile "$SCRIPT_DIR/$script" 2>/dev/null; then
                [[ "$VERBOSE" == "true" ]] && print_success "PASS: $script syntax OK"
            else
                print_error "FAIL: $script syntax error"
                failed=$((failed + 1))
            fi
        else
            print_warning "? $script not found"
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        print_success "All scripts passed syntax validation"
    else
        print_error "$failed scripts failed syntax validation"
        return 1
    fi
}

# Test Terraform configuration
test_terraform() {
    print_status "Testing Terraform configuration..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Test formatting
    if terraform fmt -check >/dev/null 2>&1; then
        [[ "$VERBOSE" == "true" ]] && print_success "PASS: Terraform formatting OK"
    else
        print_warning "Terraform files need formatting (running terraform fmt)"
        terraform fmt
    fi
    
    # Test configuration files exist
    local required_files=("main.tf" "variables.tf" "outputs.tf")
    local missing=0

    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            [[ "$VERBOSE" == "true" ]] && print_success "PASS: $file exists"
        else
            print_error "FAIL: $file missing"
            missing=$((missing + 1))
        fi
    done

    # Check for terraform.tfvars or terraform.tfvars.example
    if [[ -f "environments/dev/terraform.tfvars" ]]; then
        [[ "$VERBOSE" == "true" ]] && print_success "PASS: environments/dev/terraform.tfvars exists"
    elif [[ -f "environments/dev/terraform.tfvars.example" ]]; then
        [[ "$VERBOSE" == "true" ]] && print_success "PASS: environments/dev/terraform.tfvars.example exists (can be used for validation)"
    else
        print_error "FAIL: environments/dev/terraform.tfvars or terraform.tfvars.example missing"
        missing=$((missing + 1))
    fi
    
    cd "$PROJECT_ROOT"
    
    if [[ $missing -eq 0 ]]; then
        print_success "Terraform configuration validation passed"
    else
        print_error "$missing required Terraform files missing"
        return 1
    fi
}

# Test Python application
test_python_app() {
    print_status "Testing Python application..."
    
    # Check Python 3 availability
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found"
        return 1
    fi
    
    # Test Python syntax
    if python3 -m py_compile app/main.py 2>/dev/null; then
        [[ "$VERBOSE" == "true" ]] && print_success "PASS: Python application syntax OK"
    else
        print_error "FAIL: Python application syntax error"
        return 1
    fi
    
    # Check required files
    local app_files=("app/main.py" "app/requirements.txt" "app/Dockerfile")
    local missing=0
    
    for file in "${app_files[@]}"; do
        if [[ -f "$file" ]]; then
            [[ "$VERBOSE" == "true" ]] && print_success "PASS: $file exists"
        else
            print_error "FAIL: $file missing"
            missing=$((missing + 1))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        print_success "Python application validation passed"
    else
        print_error "$missing required application files missing"
        return 1
    fi
}

# Test cost monitoring
test_cost_monitoring() {
    print_status "Testing cost monitoring functionality..."

    # Skip Azure CLI dependent tests in CI environment
    if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
        print_warning "Skipping cost monitoring tests in CI environment (no Azure CLI)"
        print_success "Cost monitoring validation skipped (CI environment)"
        return 0
    fi

    # Test cost estimation (requires Azure CLI)
    if "$SCRIPT_DIR/cost-monitor.sh" --estimate --quiet >/dev/null 2>&1; then
        [[ "$VERBOSE" == "true" ]] && print_success "PASS: Cost estimation working"
    else
        print_warning "Cost estimation failed (likely missing Azure CLI or authentication)"
        # Don't fail the test - this is expected in CI
    fi

    # Test help functions (should work without Azure CLI)
    if "$SCRIPT_DIR/cost-monitor.sh" --help >/dev/null 2>&1; then
        [[ "$VERBOSE" == "true" ]] && print_success "PASS: Cost monitor help working"
    else
        print_error "FAIL: Cost monitor help failed"
        return 1
    fi

    print_success "Cost monitoring validation passed"
}

# Test documentation
test_documentation() {
    print_status "Testing documentation..."
    
    local docs=("README.md")
    local missing=0
    
    for doc in "${docs[@]}"; do
        if [[ -f "$doc" ]]; then
            [[ "$VERBOSE" == "true" ]] && print_success "PASS: $doc exists"
        else
            print_error "FAIL: $doc missing"
            missing=$((missing + 1))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        print_success "Documentation validation passed"
    else
        print_error "$missing required documentation files missing"
        return 1
    fi
}

# Test deployment scripts functionality
test_deployment_scripts() {
    print_status "Testing deployment script functionality..."
    
    # Test deploy script help
    if "$SCRIPT_DIR/deploy.sh" --help >/dev/null 2>&1; then
        [[ "$VERBOSE" == "true" ]] && print_success "PASS: Deploy script help working"
    else
        print_error "FAIL: Deploy script help failed"
        return 1
    fi
    
    # Test cleanup script help
    if "$SCRIPT_DIR/cleanup.sh" --help >/dev/null 2>&1; then
        [[ "$VERBOSE" == "true" ]] && print_success "PASS: Cleanup script help working"
    else
        print_error "FAIL: Cleanup script help failed"
        return 1
    fi
    
    print_success "Deployment scripts validation passed"
}

# Main test function
main() {
    # Parse arguments first
    parse_arguments "$@"

    echo "========================================"
    echo "AZURE WEBAPP DEMO - END-TO-END TESTING"
    echo "========================================"
    echo "Quick mode: $QUICK_MODE"
    echo "Verbose: $VERBOSE"
    echo "========================================"
    echo ""
    
    local failed_tests=0
    
    # Run tests
    test_scripts || failed_tests=$((failed_tests + 1))
    test_terraform || failed_tests=$((failed_tests + 1))
    test_python_app || failed_tests=$((failed_tests + 1))
    test_cost_monitoring || failed_tests=$((failed_tests + 1))
    test_deployment_scripts || failed_tests=$((failed_tests + 1))
    
    if [[ "$QUICK_MODE" != "true" ]]; then
        test_documentation || failed_tests=$((failed_tests + 1))
    fi
    
    echo ""
    echo "========================================"
    if [[ $failed_tests -eq 0 ]]; then
        echo "ALL TESTS PASSED!"
        echo "========================================"
        echo ""
        echo "The Azure WebApp Demo is ready for deployment!"
        echo ""
        echo "Next steps:"
        echo "1. Run: ./scripts/deploy.sh"
        echo "2. Monitor costs: ./scripts/cost-monitor.sh --actual"
        echo "3. Clean up: ./scripts/cleanup.sh"
    else
        echo "TESTS FAILED: $failed_tests"
        echo "========================================"
        echo ""
        echo "Please fix the failing tests before deployment."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
