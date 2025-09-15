#!/bin/bash

# Azure Credentials Setup for GitHub Actions - Azure WebApp Demo
#
# This script sets up Azure App Registration and OIDC trust for GitHub Actions
# to enable passwordless authentication from GitHub workflows to Azure.
#
# DEMO PROJECT ONLY: This creates broad permissions for simplicity.
# Production projects should use more restrictive permissions and proper governance.
#
# What this script does:
# 1. Creates Azure AD App Registration
# 2. Configures OIDC trust for GitHub repository
# 3. Assigns necessary Azure permissions (Contributor + User Access Administrator)
# 4. Outputs GitHub repository secrets to configure
#
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - Owner or User Access Administrator permissions on Azure subscription (to assign roles)
# - GitHub repository: https://github.com/cmcconnell1/azure-webapp-demo
#
# Usage:
#   ./scripts/setup-github-actions-azure.sh
#
# After running this script, you'll need to manually add the secrets
# to your GitHub repository settings.

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# GitHub repository information
GITHUB_REPO_OWNER="cmcconnell1"
GITHUB_REPO_NAME="azure-webapp-demo"
GITHUB_REPO_URL="https://github.com/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"

# Azure App Registration configuration
APP_NAME="azure-webapp-demo-github-actions"
APP_DESCRIPTION="GitHub Actions OIDC authentication for Azure WebApp Demo"

# Color output functions
print_status() { echo -e "\033[34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI."
        echo "Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
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
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    print_success "Prerequisites check passed"
    print_status "Subscription: $SUBSCRIPTION_NAME"
    print_status "Subscription ID: $SUBSCRIPTION_ID"
    print_status "Tenant ID: $TENANT_ID"
    print_status "GitHub Repository: $GITHUB_REPO_URL"
    echo ""
}

# Create Azure App Registration
create_app_registration() {
    print_status "Creating Azure App Registration..."
    
    # Check if app already exists
    EXISTING_APP=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$EXISTING_APP" && "$EXISTING_APP" != "null" ]]; then
        print_warning "App Registration already exists: $APP_NAME"
        CLIENT_ID="$EXISTING_APP"
        print_status "Using existing Client ID: $CLIENT_ID"
    else
        # Create new app registration
        print_status "Creating new App Registration: $APP_NAME"
        
        CLIENT_ID=$(az ad app create \
            --display-name "$APP_NAME" \
            --query appId -o tsv)
        
        print_success "App Registration created successfully"
        print_status "Client ID: $CLIENT_ID"
    fi
    
    # Get object ID for the app
    OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)
    print_status "Object ID: $OBJECT_ID"
}

# Configure OIDC trust for GitHub Actions
configure_oidc_trust() {
    print_status "Configuring OIDC trust for GitHub Actions..."
    
    # Create federated credential for main branch
    CREDENTIAL_NAME="github-actions-main"
    
    # Check if credential already exists
    EXISTING_CREDENTIAL=$(az ad app federated-credential list --id "$CLIENT_ID" \
        --query "[?name=='$CREDENTIAL_NAME'].name" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$EXISTING_CREDENTIAL" ]]; then
        print_warning "Federated credential already exists: $CREDENTIAL_NAME"
    else
        print_status "Creating federated credential: $CREDENTIAL_NAME"
        
        # Create the federated credential
        az ad app federated-credential create \
            --id "$CLIENT_ID" \
            --parameters '{
                "name": "'$CREDENTIAL_NAME'",
                "issuer": "https://token.actions.githubusercontent.com",
                "subject": "repo:'$GITHUB_REPO_OWNER'/'$GITHUB_REPO_NAME':ref:refs/heads/main",
                "description": "GitHub Actions OIDC trust for main branch",
                "audiences": ["api://AzureADTokenExchange"]
            }'
        
        print_success "Federated credential created successfully"
    fi
    
    # Create federated credential for pull requests (optional)
    PR_CREDENTIAL_NAME="github-actions-pr"

    EXISTING_PR_CREDENTIAL=$(az ad app federated-credential list --id "$CLIENT_ID" \
        --query "[?name=='$PR_CREDENTIAL_NAME'].name" -o tsv 2>/dev/null || echo "")

    if [[ -z "$EXISTING_PR_CREDENTIAL" ]]; then
        print_status "Creating federated credential for pull requests: $PR_CREDENTIAL_NAME"

        az ad app federated-credential create \
            --id "$CLIENT_ID" \
            --parameters '{
                "name": "'$PR_CREDENTIAL_NAME'",
                "issuer": "https://token.actions.githubusercontent.com",
                "subject": "repo:'$GITHUB_REPO_OWNER'/'$GITHUB_REPO_NAME':pull_request",
                "description": "GitHub Actions OIDC trust for pull requests",
                "audiences": ["api://AzureADTokenExchange"]
            }'

        print_success "Pull request federated credential created successfully"
    fi

    # Create federated credentials for environments (dev, staging, prod)
    for ENV in dev staging prod; do
        ENV_CREDENTIAL_NAME="github-actions-env-$ENV"

        EXISTING_ENV_CREDENTIAL=$(az ad app federated-credential list --id "$CLIENT_ID" \
            --query "[?name=='$ENV_CREDENTIAL_NAME'].name" -o tsv 2>/dev/null || echo "")

        if [[ -z "$EXISTING_ENV_CREDENTIAL" ]]; then
            print_status "Creating federated credential for environment: $ENV"

            az ad app federated-credential create \
                --id "$CLIENT_ID" \
                --parameters '{
                    "name": "'$ENV_CREDENTIAL_NAME'",
                    "issuer": "https://token.actions.githubusercontent.com",
                    "subject": "repo:'$GITHUB_REPO_OWNER'/'$GITHUB_REPO_NAME':environment:'$ENV'",
                    "description": "GitHub Actions OIDC trust for '$ENV' environment",
                    "audiences": ["api://AzureADTokenExchange"]
                }'

            print_success "Environment federated credential created for: $ENV"
        else
            print_status "Environment federated credential already exists for: $ENV"
        fi
    done
}

# Assign Azure permissions
assign_permissions() {
    print_status "Assigning Azure permissions..."
    
    # Create service principal if it doesn't exist
    SP_ID=$(az ad sp list --display-name "$APP_NAME" --query "[0].id" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$SP_ID" || "$SP_ID" == "null" ]]; then
        print_status "Creating service principal..."
        SP_ID=$(az ad sp create --id "$CLIENT_ID" --query id -o tsv)
        print_success "Service principal created: $SP_ID"
    else
        print_status "Service principal already exists: $SP_ID"
    fi
    
    # Assign Contributor role to subscription (for demo purposes)
    print_status "Assigning Contributor role to subscription..."

    ROLE_ASSIGNMENT=$(az role assignment list \
        --assignee "$CLIENT_ID" \
        --role "Contributor" \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --query "[0].id" -o tsv 2>/dev/null || echo "")

    if [[ -z "$ROLE_ASSIGNMENT" || "$ROLE_ASSIGNMENT" == "null" ]]; then
        az role assignment create \
            --assignee "$CLIENT_ID" \
            --role "Contributor" \
            --scope "/subscriptions/$SUBSCRIPTION_ID"

        print_success "Contributor role assigned successfully"
    else
        print_status "Contributor role already assigned"
    fi

    # Assign User Access Administrator role (needed for role assignments)
    print_status "Assigning User Access Administrator role to subscription..."

    UAA_ROLE_ASSIGNMENT=$(az role assignment list \
        --assignee "$CLIENT_ID" \
        --role "User Access Administrator" \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --query "[0].id" -o tsv 2>/dev/null || echo "")

    if [[ -z "$UAA_ROLE_ASSIGNMENT" || "$UAA_ROLE_ASSIGNMENT" == "null" ]]; then
        az role assignment create \
            --assignee "$CLIENT_ID" \
            --role "User Access Administrator" \
            --scope "/subscriptions/$SUBSCRIPTION_ID"

        print_success "User Access Administrator role assigned successfully"
    else
        print_status "User Access Administrator role already assigned"
    fi

    print_warning "Note: Contributor and User Access Administrator roles assigned for demo purposes."
    print_warning "Production deployments should use more restrictive permissions."
}

# Configure GitHub repository secrets automatically
configure_github_secrets() {
    print_status "Configuring GitHub repository secrets..."

    # Check if GitHub CLI is available and authenticated
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        print_status "Using GitHub CLI to automatically configure secrets..."

        # Check if repository exists
        if gh repo view "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" &> /dev/null; then
            print_status "Repository found: $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"

            # Set repository secrets
            print_status "Setting repository secrets..."

            echo -n "$CLIENT_ID" | gh secret set AZURE_CLIENT_ID --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
            echo -n "$TENANT_ID" | gh secret set AZURE_TENANT_ID --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
            echo -n "$SUBSCRIPTION_ID" | gh secret set AZURE_SUBSCRIPTION_ID --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"

            print_success "Repository secrets configured automatically!"

            # Also set up environment secrets for dev, staging, prod
            print_status "Setting up environment secrets..."

            for ENV in dev staging prod; do
                print_status "Configuring environment: $ENV"

                # Ensure environment exists
                gh api --method PUT "/repos/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME/environments/$ENV" --silent 2>/dev/null || true

                # Set environment secrets
                echo -n "$CLIENT_ID" | gh secret set AZURE_CLIENT_ID --env "$ENV" --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
                echo -n "$TENANT_ID" | gh secret set AZURE_TENANT_ID --env "$ENV" --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
                echo -n "$SUBSCRIPTION_ID" | gh secret set AZURE_SUBSCRIPTION_ID --env "$ENV" --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"

                print_success "Environment secrets configured for: $ENV"
            done

            print_success "All GitHub secrets configured automatically!"

        else
            print_error "Repository not found: $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
            print_error "Please create the repository first or check the repository name."
            return 1
        fi

    else
        print_warning "GitHub CLI not available or not authenticated."
        print_warning "Falling back to manual configuration instructions..."
        generate_manual_secrets_instructions
    fi
}

# Generate manual GitHub repository secrets instructions
generate_manual_secrets_instructions() {
    print_status "Generating manual GitHub repository secrets configuration..."

    echo ""
    echo "========================================"
    echo "GITHUB REPOSITORY SECRETS CONFIGURATION"
    echo "========================================"
    echo ""
    echo "Add these secrets to your GitHub repository:"
    echo "Repository: $GITHUB_REPO_URL"
    echo "Path: Settings > Secrets and variables > Actions > Repository secrets"
    echo ""
    echo "Required secrets:"
    echo ""
    echo "AZURE_CLIENT_ID"
    echo "$CLIENT_ID"
    echo ""
    echo "AZURE_TENANT_ID"
    echo "$TENANT_ID"
    echo ""
    echo "AZURE_SUBSCRIPTION_ID"
    echo "$SUBSCRIPTION_ID"
    echo ""
    echo "========================================"
    echo "MANUAL STEPS REQUIRED"
    echo "========================================"
    echo ""
    echo "1. Go to: $GITHUB_REPO_URL/settings/secrets/actions"
    echo "2. Click 'New repository secret' for each secret above"
    echo "3. Copy the exact values (including any dashes or special characters)"
    echo "4. Test the setup by running a GitHub Actions workflow"
    echo ""
    echo "After adding secrets, you can:"
    echo "- Use GitHub web UI: Go to Actions > Deploy Azure WebApp Demo > Run workflow"
    echo "- Use command line: ./scripts/deploy-github.sh"
    echo "- Use local deployment: ./scripts/deploy.sh"
    echo ""
}

# Main execution
main() {
    echo "========================================"
    echo "AZURE CREDENTIALS SETUP FOR GITHUB ACTIONS"
    echo "========================================"
    echo "Setting up passwordless authentication from GitHub Actions to Azure"
    echo "Repository: $GITHUB_REPO_URL"
    echo "App Registration: $APP_NAME"
    echo "========================================"
    echo ""
    
    check_prerequisites
    create_app_registration
    configure_oidc_trust
    assign_permissions
    configure_github_secrets
    
    echo ""
    echo "========================================"
    echo "SETUP COMPLETE"
    echo "========================================"
    echo ""
    print_success "Azure credentials and GitHub secrets setup completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Test deployment: Go to GitHub Actions > Run workflow"
    echo "2. Or use command line: ./scripts/deploy-github.sh"
    echo "3. Or use local deployment: ./scripts/deploy.sh"
    echo ""
}

# Execute main function
main "$@"
