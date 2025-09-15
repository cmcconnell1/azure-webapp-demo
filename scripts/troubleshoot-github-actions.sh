#!/bin/bash

# ============================================================================
# GitHub Actions Troubleshooting Script
# ============================================================================
# This script diagnoses common GitHub Actions authentication and deployment issues
# for the Azure WebApp Demo project.
#
# Usage:
#   ./scripts/troubleshoot-github-actions.sh
#   ./scripts/troubleshoot-github-actions.sh --verbose
#   ./scripts/troubleshoot-github-actions.sh --fix-workflow
#
# Requirements:
#   - Azure CLI (az)
#   - GitHub CLI (gh)
#   - Authenticated with both Azure and GitHub
# ============================================================================

set -euo pipefail

# Configuration
GITHUB_REPO_OWNER="cmcconnell1"
GITHUB_REPO_NAME="azure-webapp-demo"
APP_DISPLAY_NAME="azure-webapp-demo-github-actions"
VERBOSE=false
FIX_WORKFLOW=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
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

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --fix-workflow)
                FIX_WORKFLOW=true
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
}

show_help() {
    echo "GitHub Actions Troubleshooting Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --verbose        Show detailed output"
    echo "  --fix-workflow   Attempt to fix common workflow issues"
    echo "  --help          Show this help message"
    echo ""
    echo "This script checks:"
    echo "  1. GitHub CLI authentication and repository access"
    echo "  2. GitHub repository and environment secrets"
    echo "  3. Azure CLI authentication"
    echo "  4. Azure App Registration and federated credentials"
    echo "  5. Azure service principal permissions"
    echo "  6. GitHub Actions workflow configuration"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local issues=0
    
    # Check GitHub CLI
    if command -v gh &> /dev/null; then
        print_success "GitHub CLI is installed"
        
        if gh auth status &> /dev/null; then
            print_success "GitHub CLI is authenticated"
        else
            print_error "GitHub CLI is not authenticated. Run: gh auth login"
            ((issues++))
        fi
    else
        print_error "GitHub CLI is not installed. Install from: https://cli.github.com/"
        ((issues++))
    fi
    
    # Check Azure CLI
    if command -v az &> /dev/null; then
        print_success "Azure CLI is installed"
        
        if az account show &> /dev/null; then
            print_success "Azure CLI is authenticated"
        else
            print_error "Azure CLI is not authenticated. Run: az login"
            ((issues++))
        fi
    else
        print_error "Azure CLI is not installed. Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        ((issues++))
    fi
    
    if [[ $issues -gt 0 ]]; then
        print_error "Prerequisites check failed. Please fix the above issues and try again."
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Check GitHub repository access
check_github_repository() {
    print_header "Checking GitHub Repository Access"
    
    if gh repo view "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" &> /dev/null; then
        print_success "Repository access confirmed: $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
    else
        print_error "Cannot access repository: $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
        print_error "Check repository name and GitHub CLI permissions"
        exit 1
    fi
}

# Check GitHub secrets
check_github_secrets() {
    print_header "Checking GitHub Secrets"
    
    local required_secrets=("AZURE_CLIENT_ID" "AZURE_TENANT_ID" "AZURE_SUBSCRIPTION_ID")
    local missing_repo_secrets=()
    local missing_env_secrets=()
    
    print_status "Checking repository secrets..."
    
    # Check repository secrets
    local repo_secrets
    repo_secrets=$(gh secret list --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" --json name --jq '.[].name')
    
    for secret in "${required_secrets[@]}"; do
        if echo "$repo_secrets" | grep -q "^$secret$"; then
            [[ "$VERBOSE" == "true" ]] && print_success "Repository secret exists: $secret"
        else
            missing_repo_secrets+=("$secret")
        fi
    done
    
    # Check environment secrets (dev)
    print_status "Checking dev environment secrets..."
    
    local env_secrets
    env_secrets=$(gh secret list --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" --env dev --json name --jq '.[].name' 2>/dev/null || echo "")
    
    for secret in "${required_secrets[@]}"; do
        if echo "$env_secrets" | grep -q "^$secret$"; then
            [[ "$VERBOSE" == "true" ]] && print_success "Environment secret exists: $secret"
        else
            missing_env_secrets+=("$secret")
        fi
    done
    
    # Report results
    if [[ ${#missing_repo_secrets[@]} -eq 0 ]]; then
        print_success "All repository secrets are configured"
    else
        print_error "Missing repository secrets: ${missing_repo_secrets[*]}"
    fi
    
    if [[ ${#missing_env_secrets[@]} -eq 0 ]]; then
        print_success "All dev environment secrets are configured"
    else
        print_error "Missing dev environment secrets: ${missing_env_secrets[*]}"
    fi
    
    if [[ ${#missing_repo_secrets[@]} -gt 0 ]] || [[ ${#missing_env_secrets[@]} -gt 0 ]]; then
        print_warning "Run this command to configure secrets: ./scripts/setup-github-actions-azure.sh"
        return 1
    fi
    
    return 0
}

# Check Azure App Registration
check_azure_app_registration() {
    print_header "Checking Azure App Registration"
    
    local app_info
    app_info=$(az ad app list --display-name "$APP_DISPLAY_NAME" --query "[].{appId:appId,displayName:displayName}" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$app_info" ]]; then
        print_error "Azure App Registration not found: $APP_DISPLAY_NAME"
        print_warning "Run this command to create it: ./scripts/setup-github-actions-azure.sh"
        return 1
    fi
    
    local app_id
    app_id=$(echo "$app_info" | cut -f1)
    
    print_success "Azure App Registration found: $APP_DISPLAY_NAME"
    [[ "$VERBOSE" == "true" ]] && print_status "App ID: $app_id"
    
    # Store app ID for other checks
    export AZURE_APP_ID="$app_id"
    
    return 0
}

# Check federated credentials
check_federated_credentials() {
    print_header "Checking OIDC Federated Credentials"
    
    if [[ -z "${AZURE_APP_ID:-}" ]]; then
        print_error "Azure App ID not available. Skipping federated credential check."
        return 1
    fi
    
    local credentials
    credentials=$(az ad app federated-credential list --id "$AZURE_APP_ID" --query "[].{name:name,subject:subject,issuer:issuer}" -o json 2>/dev/null || echo "[]")
    
    local main_cred_found=false
    local pr_cred_found=false
    local expected_main_subject="repo:$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME:ref:refs/heads/main"
    local expected_pr_subject="repo:$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME:pull_request"
    local expected_issuer="https://token.actions.githubusercontent.com"
    
    # Check each credential
    local cred_count
    cred_count=$(echo "$credentials" | jq length)
    
    if [[ "$cred_count" -eq 0 ]]; then
        print_error "No federated credentials found"
        print_warning "Run this command to create them: ./scripts/setup-github-actions-azure.sh"
        return 1
    fi
    
    for ((i=0; i<cred_count; i++)); do
        local name subject issuer
        name=$(echo "$credentials" | jq -r ".[$i].name")
        subject=$(echo "$credentials" | jq -r ".[$i].subject")
        issuer=$(echo "$credentials" | jq -r ".[$i].issuer")
        
        [[ "$VERBOSE" == "true" ]] && print_status "Found credential: $name"
        [[ "$VERBOSE" == "true" ]] && print_status "  Subject: $subject"
        [[ "$VERBOSE" == "true" ]] && print_status "  Issuer: $issuer"
        
        # Check main branch credential
        if [[ "$subject" == "$expected_main_subject" ]] && [[ "$issuer" == "$expected_issuer" ]]; then
            main_cred_found=true
            print_success "Main branch federated credential is correctly configured"
        fi
        
        # Check pull request credential
        if [[ "$subject" == "$expected_pr_subject" ]] && [[ "$issuer" == "$expected_issuer" ]]; then
            pr_cred_found=true
            [[ "$VERBOSE" == "true" ]] && print_success "Pull request federated credential is correctly configured"
        fi
    done
    
    local issues=0
    
    if [[ "$main_cred_found" == "false" ]]; then
        print_error "Main branch federated credential not found or incorrect"
        print_error "Expected subject: $expected_main_subject"
        ((issues++))
    fi
    
    if [[ "$pr_cred_found" == "false" ]]; then
        print_warning "Pull request federated credential not found (optional)"
    fi
    
    if [[ $issues -gt 0 ]]; then
        print_warning "Run this command to fix federated credentials: ./scripts/setup-github-actions-azure.sh"
        return 1
    fi
    
    return 0
}

# Check Azure permissions
check_azure_permissions() {
    print_header "Checking Azure Service Principal Permissions"
    
    if [[ -z "${AZURE_APP_ID:-}" ]]; then
        print_error "Azure App ID not available. Skipping permissions check."
        return 1
    fi
    
    local role_assignments
    role_assignments=$(az role assignment list --assignee "$AZURE_APP_ID" --query "[].{principalName:principalName,roleDefinitionName:roleDefinitionName,scope:scope}" -o json 2>/dev/null || echo "[]")
    
    local assignment_count
    assignment_count=$(echo "$role_assignments" | jq length)
    
    if [[ "$assignment_count" -eq 0 ]]; then
        print_error "No role assignments found for service principal"
        print_warning "Run this command to assign permissions: ./scripts/setup-github-actions-azure.sh"
        return 1
    fi
    
    local contributor_found=false
    local uaa_found=false
    local subscription_scope_found=false

    for ((i=0; i<assignment_count; i++)); do
        local role scope
        role=$(echo "$role_assignments" | jq -r ".[$i].roleDefinitionName")
        scope=$(echo "$role_assignments" | jq -r ".[$i].scope")

        [[ "$VERBOSE" == "true" ]] && print_status "Found role assignment: $role at $scope"

        if [[ "$role" == "Contributor" ]]; then
            contributor_found=true
        fi

        if [[ "$role" == "User Access Administrator" ]]; then
            uaa_found=true
        fi

        if [[ "$scope" =~ ^/subscriptions/[^/]+$ ]]; then
            subscription_scope_found=true
        fi
    done

    if [[ "$contributor_found" == "true" ]] && [[ "$uaa_found" == "true" ]] && [[ "$subscription_scope_found" == "true" ]]; then
        print_success "Service principal has required roles (Contributor + User Access Administrator) at subscription level"
        return 0
    else
        print_error "Service principal missing required permissions"
        if [[ "$contributor_found" == "false" ]]; then
            print_error "Missing Contributor role"
        fi
        if [[ "$uaa_found" == "false" ]]; then
            print_error "Missing User Access Administrator role"
        fi
        if [[ "$subscription_scope_found" == "false" ]]; then
            print_error "Missing subscription-level scope"
        fi
        print_warning "Run this command to fix permissions: ./scripts/setup-github-actions-azure.sh"
        return 1
    fi
}

# Check workflow configuration
check_workflow_configuration() {
    print_header "Checking GitHub Actions Workflow Configuration"
    
    local workflow_file=".github/workflows/main.yml"
    
    if [[ ! -f "$workflow_file" ]]; then
        print_error "Workflow file not found: $workflow_file"
        return 1
    fi
    
    print_success "Workflow file exists: $workflow_file"
    
    # Check for auth-type parameter
    if grep -q "auth-type: IDENTITY" "$workflow_file"; then
        print_success "Workflow has correct auth-type configuration"
    else
        print_warning "Workflow missing 'auth-type: IDENTITY' parameter"
        
        if [[ "$FIX_WORKFLOW" == "true" ]]; then
            print_status "Attempting to fix workflow configuration..."
            # This would require more complex sed/awk manipulation
            print_warning "Automatic workflow fix not implemented yet"
            print_warning "Please add 'auth-type: IDENTITY' to the Azure login step manually"
        fi
    fi
    
    # Check for required permissions
    if grep -q "id-token: write" "$workflow_file"; then
        print_success "Workflow has required OIDC permissions"
    else
        print_error "Workflow missing 'id-token: write' permission"
    fi
    
    return 0
}

# Generate summary report
generate_summary() {
    print_header "Troubleshooting Summary"
    
    print_status "If issues were found, try these solutions:"
    echo ""
    echo "1. Missing or incorrect secrets:"
    echo "   ./scripts/setup-github-actions-azure.sh"
    echo ""
    echo "2. Workflow authentication errors:"
    echo "   - Ensure workflow has 'auth-type: IDENTITY'"
    echo "   - Verify 'id-token: write' permission is set"
    echo ""
    echo "3. OIDC trust issues:"
    echo "   - Check federated credential subject matches exactly"
    echo "   - Wait a few minutes for Azure AD propagation"
    echo ""
    echo "4. Permission denied errors:"
    echo "   - Verify service principal has Contributor and User Access Administrator roles"
    echo "   - Check roles are assigned at subscription level"
    echo ""
    echo "5. Still having issues?"
    echo "   - Check GitHub Actions logs for specific error messages"
    echo "   - Verify Azure subscription is active and accessible"
    echo "   - Try re-running the setup script: ./scripts/setup-github-actions-azure.sh"
}

# Main execution
main() {
    parse_arguments "$@"
    
    print_header "GitHub Actions Troubleshooting"
    print_status "Diagnosing Azure WebApp Demo GitHub Actions setup..."
    
    local overall_status=0
    
    # Run all checks
    check_prerequisites || ((overall_status++))
    check_github_repository || ((overall_status++))
    check_github_secrets || ((overall_status++))
    check_azure_app_registration || ((overall_status++))
    check_federated_credentials || ((overall_status++))
    check_azure_permissions || ((overall_status++))
    check_workflow_configuration || ((overall_status++))
    
    # Generate summary
    generate_summary
    
    if [[ $overall_status -eq 0 ]]; then
        print_success "All checks passed! GitHub Actions should work correctly."
        exit 0
    else
        print_warning "Some issues were found. Please review the output above."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
