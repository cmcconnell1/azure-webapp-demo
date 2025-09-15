#!/bin/bash

# GitHub Actions Deployment Trigger for Azure WebApp Demo
#
# This script allows triggering the GitHub Actions deployment workflow
# from the command line, providing the same functionality as clicking
# the "Run workflow" button in the GitHub web interface.
#
# DEMO PROJECT ONLY: This is a simplified GitHub Actions integration.
# Production projects should use proper CI/CD governance and approvals.
#
# Features:
# - Command-line trigger for GitHub Actions deployment
# - Same parameters as web UI workflow dispatch
# - Real-time workflow status monitoring
# - Deployment URL and status reporting
#
# Usage:
#   ./scripts/deploy-github.sh [OPTIONS]
#
# Examples:
#   ./scripts/deploy-github.sh                                    # Deploy to dev with defaults
#   ./scripts/deploy-github.sh --env staging --cleanup-hours 4
#   ./scripts/deploy-github.sh --no-cleanup --budget 50 --skip-tests

# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# ============================================================================
# SCRIPT CONFIGURATION AND GLOBAL VARIABLES
# ============================================================================

# Get absolute paths for script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default GitHub Actions workflow parameters
ENVIRONMENT="dev"           # Target environment for deployment
CLEANUP_HOURS="2"          # Hours after which resources are automatically cleaned up
BUDGET_ALERT="10"          # Budget alert threshold in USD
SKIP_TESTS="false"         # Whether to skip validation tests
FORCE_DEPLOY="true"        # Whether to force deployment without confirmation
GITHUB_TOKEN=""            # GitHub personal access token (auto-detected)
REPO_OWNER=""              # Repository owner (auto-detected from git remote)
REPO_NAME=""               # Repository name (auto-detected from git remote)

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
            --env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --cleanup-hours)
                CLEANUP_HOURS="$2"
                shift 2
                ;;
            --no-cleanup)
                CLEANUP_HOURS="0"
                shift
                ;;
            --budget)
                BUDGET_ALERT="$2"
                shift 2
                ;;
            --skip-tests)
                SKIP_TESTS="true"
                shift
                ;;
            --no-force)
                FORCE_DEPLOY="false"
                shift
                ;;
            --github-token)
                GITHUB_TOKEN="$2"
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
GitHub Actions Deployment Trigger for Azure WebApp Demo

USAGE:
    ./scripts/deploy-github.sh [OPTIONS]

OPTIONS:
    --env ENV              Target environment (dev|staging|prod) (default: dev)
    --cleanup-hours HOURS  Auto-cleanup after X hours, 0 = no cleanup (default: 2)
    --no-cleanup          Disable automatic cleanup
    --budget AMOUNT       Budget alert amount in USD (default: 10)
    --skip-tests          Skip validation tests for faster deployment
    --no-force            Don't force deployment (require confirmations)
    --github-token TOKEN  GitHub personal access token (or set GITHUB_TOKEN env var)
    --help, -h           Show this help message

EXAMPLES:
    ./scripts/deploy-github.sh                                    # Deploy to dev with defaults
    ./scripts/deploy-github.sh --env staging --cleanup-hours 4
    ./scripts/deploy-github.sh --no-cleanup --budget 50 --skip-tests

REQUIREMENTS:
    - GitHub CLI (gh) installed and authenticated, OR
    - GitHub personal access token with repo and actions permissions
    - Repository must be: https://github.com/cmcconnell1/azure-webapp-demo

GITHUB WEB UI ALTERNATIVE:
    You can also trigger deployment by:
    1. Go to: https://github.com/cmcconnell1/azure-webapp-demo/actions
    2. Click "Azure WebApp Demo - Deploy" workflow
    3. Click "Run workflow" button
    4. Fill in parameters and click "Run workflow"

EOF
}

# Detect repository information
detect_repo_info() {
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        print_status "Using GitHub CLI for authentication..."
        REPO_INFO=$(gh repo view --json owner,name 2>/dev/null || echo "")
        if [[ -n "$REPO_INFO" ]]; then
            REPO_OWNER=$(echo "$REPO_INFO" | jq -r '.owner.login')
            REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
        fi
    fi
    
    # Fallback to git remote
    if [[ -z "$REPO_OWNER" || -z "$REPO_NAME" ]]; then
        REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
            REPO_OWNER="${BASH_REMATCH[1]}"
            REPO_NAME="${BASH_REMATCH[2]}"
            REPO_NAME="${REPO_NAME%.git}"
        fi
    fi
    
    # Default fallback
    if [[ -z "$REPO_OWNER" || -z "$REPO_NAME" ]]; then
        REPO_OWNER="cmcconnell1"
        REPO_NAME="azure-webapp-demo"
        print_warning "Could not detect repository info, using default: $REPO_OWNER/$REPO_NAME"
    fi
    
    print_status "Repository: $REPO_OWNER/$REPO_NAME"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for GitHub CLI or token
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        print_success "GitHub CLI authenticated"
        return 0
    elif [[ -n "$GITHUB_TOKEN" ]]; then
        print_success "GitHub token provided"
        return 0
    elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
        GITHUB_TOKEN="$GITHUB_TOKEN"
        print_success "GitHub token from environment"
        return 0
    else
        print_error "GitHub authentication required!"
        echo ""
        echo "Options:"
        echo "1. Install and authenticate GitHub CLI: gh auth login"
        echo "2. Set GITHUB_TOKEN environment variable"
        echo "3. Use --github-token parameter"
        echo ""
        echo "To create a token: https://github.com/settings/tokens"
        echo "Required scopes: repo, workflow"
        exit 1
    fi
}

# Trigger GitHub Actions workflow
trigger_workflow() {
    print_status "Triggering GitHub Actions deployment workflow..."
    
    # Prepare workflow inputs
    WORKFLOW_INPUTS=$(cat << EOF
{
  "environment": "$ENVIRONMENT",
  "cleanup_hours": "$CLEANUP_HOURS",
  "budget_alert": "$BUDGET_ALERT",
  "skip_tests": $SKIP_TESTS,
  "force_deploy": $FORCE_DEPLOY
}
EOF
)
    
    print_status "Deployment parameters:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Cleanup hours: $CLEANUP_HOURS"
    echo "  Budget alert: \$$BUDGET_ALERT"
    echo "  Skip tests: $SKIP_TESTS"
    echo "  Force deploy: $FORCE_DEPLOY"
    echo ""
    
    # Trigger workflow using GitHub CLI or API
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        print_status "Triggering workflow via GitHub CLI..."
        gh workflow run "main.yml" \
            --repo "$REPO_OWNER/$REPO_NAME" \
            --field environment="$ENVIRONMENT" \
            --field cleanup_hours="$CLEANUP_HOURS" \
            --field budget_alert="$BUDGET_ALERT" \
            --field skip_tests="$SKIP_TESTS" \
            --field force_deploy="$FORCE_DEPLOY"
    else
        print_status "Triggering workflow via GitHub API..."
        curl -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/workflows/main.yml/dispatches" \
            -d "{\"ref\":\"main\",\"inputs\":$WORKFLOW_INPUTS}"
    fi
    
    print_success "Workflow triggered successfully!"
    
    # Provide links and next steps
    echo ""
    echo "========================================"
    echo "GITHUB ACTIONS DEPLOYMENT TRIGGERED"
    echo "========================================"
    echo ""
    echo "Monitor deployment progress:"
    echo "  Web UI: https://github.com/$REPO_OWNER/$REPO_NAME/actions"
    echo ""
    if command -v gh &> /dev/null; then
        echo "Command line: gh run list --repo $REPO_OWNER/$REPO_NAME"
        echo "Watch logs:   gh run watch --repo $REPO_OWNER/$REPO_NAME"
    fi
    echo ""
    echo "Expected deployment time: 5-10 minutes"
    echo "Auto-cleanup: $CLEANUP_HOURS hours (if enabled)"
    echo ""
}

# Main execution
main() {
    parse_arguments "$@"
    
    echo "========================================"
    echo "GITHUB ACTIONS DEPLOYMENT TRIGGER"
    echo "========================================"
    echo ""
    
    detect_repo_info
    check_prerequisites
    trigger_workflow
}

# Execute main function
main "$@"
