# Azure WebApp Demo - Simplified Configuration
#
# DEMO PROJECT ONLY: This configuration uses hardcoded values for simplicity.
# Production projects should parameterize these values and use proper variable management.
#
# Features:
# - High Availability: S1 App Service Plan, S0 SQL Database
# - PII Compliance: Azure Key Vault for secrets
# - Auto-Cleanup: Resources automatically deleted after 2 hours
# - Cost Estimate: ~$50-70/month (but only deployed for 2 hours)

project_prefix = "webapp-demo"
environment   = "dev"
location      = "westus2"

# Networking (simplified for demo)
vnet_cidr                      = "10.20.0.0/16"
subnet_app_integration_cidr    = "10.20.1.0/24"
subnet_private_endpoints_cidr  = "10.20.2.0/24"

# Default tags for all resources
default_tags = {
  Project     = "azure-webapp-demo"
  Environment = "dev"
  Purpose     = "demonstration"
  AutoCleanup = "2hours"
  Repository  = "cmcconnell1/azure-webapp-demo"
}

