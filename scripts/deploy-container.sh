#!/bin/bash

# ============================================================================
# AZURE WEBAPP DEMO - CONTAINER DEPLOYMENT SCRIPT
# ============================================================================
#
# Purpose: Builds Docker container, pushes to Azure Container Registry (ACR),
#          and deploys to Azure App Service for the Flask web application
#
# Features:
# - Docker container build and optimization
# - Azure Container Registry integration
# - Azure App Service deployment
# - Flexible deployment modes (build-only, deploy-only, full)
# - Environment-specific configuration
#
# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# ============================================================================
# SCRIPT CONFIGURATION AND GLOBAL VARIABLES
# ============================================================================

# Default deployment configuration
PROJECT_PREFIX="webapp-demo"   # Project identifier for resource naming
ENVIRONMENT="dev"             # Target environment for deployment
IMAGE_TAG="latest"            # Docker image tag for container versioning

# ANSI color codes for enhanced output formatting
RED='\033[0;31m'      # Red for errors
GREEN='\033[0;32m'    # Green for success messages
YELLOW='\033[1;33m'   # Yellow for warnings
BLUE='\033[0;34m'     # Blue for informational messages
NC='\033[0m'          # No color (reset)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Color-coded output functions for better user experience
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }      # Informational messages
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }  # Success confirmations
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; } # Warning messages
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }       # Error messages

show_usage() {
    cat << EOF
Container Application Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -p, --project-prefix    Project prefix (default: webapp-demo)
    -e, --env ENVIRONMENT   Environment (default: dev)
    -t, --tag TAG          Image tag (default: latest)
    --build-only           Build and push container only (skip deployment)
    --deploy-only          Deploy existing container only (skip build)
    
EXAMPLES:
    # Full deployment (build + push + deploy)
    $0
    
    # Build and push only
    $0 --build-only
    
    # Deploy existing container
    $0 --deploy-only --tag v1.2.3
    
    # Deploy to specific environment
    $0 --env stage --tag v1.2.3

PREREQUISITES:
    - Docker installed and running
    - Azure CLI installed and authenticated (az login)
    - Infrastructure deployed (ACR and App Service must exist)
    - Terraform outputs available
EOF
}

parse_arguments() {
    BUILD_ONLY=false
    DEPLOY_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -p|--project-prefix)
                PROJECT_PREFIX="$2"
                shift 2
                ;;
            -e|--env|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            --deploy-only)
                DEPLOY_ONLY=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [[ "$BUILD_ONLY" == true && "$DEPLOY_ONLY" == true ]]; then
        print_error "Cannot specify both --build-only and --deploy-only"
        exit 1
    fi
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if [[ "$DEPLOY_ONLY" != true ]]; then
        if ! command -v docker &> /dev/null; then
            print_error "Docker is not installed"
            exit 1
        fi
        
        if ! docker info &> /dev/null; then
            print_error "Docker is not running"
            exit 1
        fi
    fi
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Azure CLI is not authenticated. Run: az login"
        exit 1
    fi
    
    if [[ ! -f "app/Dockerfile" ]]; then
        print_error "Dockerfile not found in app directory"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

get_terraform_outputs() {
    print_status "Getting infrastructure details from Terraform..."
    
    if [[ ! -d "terraform" ]]; then
        print_error "Terraform directory not found"
        exit 1
    fi
    
    cd terraform
    
    ACR_NAME=$(terraform output -raw acr_name 2>/dev/null || echo "")
    ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server 2>/dev/null || echo "")
    WEBAPP_NAME=$(terraform output -raw webapp_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group 2>/dev/null || echo "")
    
    cd ..
    
    if [[ -z "$ACR_NAME" || -z "$ACR_LOGIN_SERVER" || -z "$WEBAPP_NAME" || -z "$RESOURCE_GROUP" ]]; then
        print_error "Could not get required infrastructure details from Terraform outputs"
        print_error "Make sure infrastructure is deployed first"
        exit 1
    fi
    
    print_success "Infrastructure details retrieved:"
    print_status "  ACR: $ACR_NAME ($ACR_LOGIN_SERVER)"
    print_status "  Web App: $WEBAPP_NAME"
    print_status "  Resource Group: $RESOURCE_GROUP"
}

build_and_push_container() {
    print_status "Building and pushing container image..."
    
    local image_name="${PROJECT_PREFIX}-app"
    local full_image_name="${ACR_LOGIN_SERVER}/${image_name}:${IMAGE_TAG}"
    
    print_status "Building Docker image: $full_image_name"
    
    # Build the container image
    docker build -t "$full_image_name" -f app/Dockerfile .
    
    print_status "Logging into Azure Container Registry..."
    az acr login --name "$ACR_NAME"
    
    print_status "Pushing image to ACR..."
    docker push "$full_image_name"
    
    print_success "Container image built and pushed: $full_image_name"
    
    # Store the full image name for deployment
    CONTAINER_IMAGE="$full_image_name"
}

deploy_container() {
    print_status "Deploying container to App Service..."
    
    if [[ -z "${CONTAINER_IMAGE:-}" ]]; then
        # If not set from build step, construct it
        local image_name="${PROJECT_PREFIX}-app"
        CONTAINER_IMAGE="${ACR_LOGIN_SERVER}/${image_name}:${IMAGE_TAG}"
    fi
    
    print_status "Updating App Service to use container: $CONTAINER_IMAGE"
    
    # Update the App Service to use the new container image
    az webapp config container set \
        --resource-group "$RESOURCE_GROUP" \
        --name "$WEBAPP_NAME" \
        --docker-custom-image-name "$CONTAINER_IMAGE" \
        --docker-registry-server-url "https://$ACR_LOGIN_SERVER"
    
    print_status "Restarting App Service..."
    az webapp restart \
        --resource-group "$RESOURCE_GROUP" \
        --name "$WEBAPP_NAME"
    
    print_success "Container deployment completed"
    
    # Get the URL and test
    local webapp_url
    webapp_url=$(cd terraform && terraform output -raw webapp_url 2>/dev/null || echo "")
    
    if [[ -n "$webapp_url" ]]; then
        print_success "Application URL: https://$webapp_url"
        print_status "Waiting for container to start..."
        
        # Wait a bit for the container to start
        sleep 30
        
        # Test health endpoint
        print_status "Testing health endpoint..."
        local health_status
        health_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$webapp_url/healthz" || echo "000")
        
        if [[ "$health_status" == "200" ]]; then
            print_success "Health check passed (HTTP $health_status)"
            print_success "Application is ready!"
        else
            print_warning "Health check returned HTTP $health_status"
            print_status "Container may still be starting. Check logs with:"
            print_status "  az webapp log tail --resource-group $RESOURCE_GROUP --name $WEBAPP_NAME"
        fi
    fi
}

main() {
    parse_arguments "$@"
    
    echo "========================================"
    echo "CONTAINER DEPLOYMENT"
    echo "========================================"
    echo "Project: $PROJECT_PREFIX"
    echo "Environment: $ENVIRONMENT"
    echo "Image Tag: $IMAGE_TAG"
    if [[ "$BUILD_ONLY" == true ]]; then
        echo "Mode: Build and push only"
    elif [[ "$DEPLOY_ONLY" == true ]]; then
        echo "Mode: Deploy only"
    else
        echo "Mode: Full deployment (build + push + deploy)"
    fi
    echo
    
    check_prerequisites
    echo
    
    get_terraform_outputs
    echo
    
    if [[ "$DEPLOY_ONLY" != true ]]; then
        build_and_push_container
        echo
    fi
    
    if [[ "$BUILD_ONLY" != true ]]; then
        deploy_container
        echo
    fi
    
    print_success "Container deployment completed!"
}

main "$@"
