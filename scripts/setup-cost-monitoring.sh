#!/bin/bash

# Setup script for Azure Cost Monitoring
# This script installs all required dependencies for cost monitoring functionality

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    echo "Azure Cost Monitoring Setup Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --venv              Create and use virtual environment"
    echo "  --system            Install system-wide (default)"
    echo "  --check             Check current installation status"
    echo "  --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                  # Install system-wide"
    echo "  $0 --venv          # Install in virtual environment"
    echo "  $0 --check         # Check installation status"
}

check_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 is not installed"
        print_status "Install Python 3 first: https://www.python.org/downloads/"
        exit 1
    fi
    
    local python_version=$(python3 --version | cut -d' ' -f2)
    print_status "Python version: $python_version"
}

check_pip() {
    if ! command -v pip3 >/dev/null 2>&1 && ! python3 -m pip --version >/dev/null 2>&1; then
        print_error "pip is not installed"
        print_status "Install pip first: python3 -m ensurepip --upgrade"
        exit 1
    fi
    
    print_status "pip is available"
}

check_azure_cli() {
    if ! command -v az >/dev/null 2>&1; then
        print_warning "Azure CLI is not installed"
        print_status "Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        print_status "Cost monitoring will not work without Azure CLI"
        return 1
    fi
    
    print_status "Azure CLI is installed"
    
    # Check if logged in
    if ! az account show >/dev/null 2>&1; then
        print_warning "Not logged in to Azure CLI"
        print_status "Run 'az login' to authenticate"
        return 1
    fi
    
    print_success "Azure CLI is authenticated"
    return 0
}

check_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq is not installed (optional for dashboard)"
        print_status "Install jq for better JSON processing:"
        print_status "  macOS: brew install jq"
        print_status "  Ubuntu/Debian: sudo apt-get install jq"
        print_status "  CentOS/RHEL: sudo yum install jq"
        return 1
    fi
    
    print_status "jq is available"
    return 0
}

check_installation() {
    print_status "Checking Azure Cost Monitoring installation..."
    echo
    
    check_python
    check_pip
    check_azure_cli
    check_jq
    
    echo
    print_status "Checking Python packages..."
    
    local missing_packages=()
    
    # Check each required package
    if ! python3 -c "import azure.identity" >/dev/null 2>&1; then
        missing_packages+=("azure-identity")
    fi
    
    if ! python3 -c "import azure.mgmt.costmanagement" >/dev/null 2>&1; then
        missing_packages+=("azure-mgmt-costmanagement")
    fi
    
    if ! python3 -c "import azure.mgmt.resource" >/dev/null 2>&1; then
        missing_packages+=("azure-mgmt-resource")
    fi
    
    if ! python3 -c "import requests" >/dev/null 2>&1; then
        missing_packages+=("requests")
    fi
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        print_success "All required Python packages are installed"
        echo
        print_success "Cost monitoring is ready to use!"
        print_status "Try: ./scripts/cost-monitor.sh --estimate --env dev"
    else
        print_warning "Missing Python packages: ${missing_packages[*]}"
        print_status "Run this script without --check to install them"
    fi
}

setup_venv() {
    print_status "Setting up virtual environment..."
    
    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
        print_success "Virtual environment created"
    else
        print_status "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    print_status "Virtual environment activated"
    
    # Upgrade pip
    python -m pip install --upgrade pip
}

install_dependencies() {
    print_status "Installing Azure Cost Monitoring dependencies..."
    
    if [[ -f "requirements-cost-monitoring.txt" ]]; then
        print_status "Installing from requirements-cost-monitoring.txt..."
        pip install -r requirements-cost-monitoring.txt
    else
        print_status "Installing individual packages..."
        pip install azure-mgmt-costmanagement azure-identity azure-mgmt-resource requests
    fi
    
    print_success "Dependencies installed successfully"
}

main() {
    local use_venv=false
    local check_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --venv)
                use_venv=true
                shift
                ;;
            --system)
                use_venv=false
                shift
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
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
    
    echo "Azure Cost Monitoring Setup"
    echo "============================"
    echo
    
    if [[ "$check_only" == "true" ]]; then
        check_installation
        exit 0
    fi
    
    # Check prerequisites
    check_python
    check_pip
    
    # Setup virtual environment if requested
    if [[ "$use_venv" == "true" ]]; then
        setup_venv
    fi
    
    # Install dependencies
    install_dependencies
    
    echo
    print_success "Setup completed successfully!"
    echo
    print_status "Next steps:"
    print_status "  1. Ensure Azure CLI is authenticated: az login"
    print_status "  2. Test cost monitoring: ./scripts/cost-monitor.sh --estimate --env dev"
    print_status "  3. Generate cost dashboard: ./scripts/cost-dashboard.sh --serve --port 8080"
    
    if [[ "$use_venv" == "true" ]]; then
        echo
        print_status "Virtual environment is activated. To reactivate later:"
        print_status "  source venv/bin/activate"
    fi
}

main "$@"
