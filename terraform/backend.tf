terraform {
  # Remote state in Azure Storage. Values are provided via -backend-config file
  # e.g., terraform -chdir=terraform init -backend-config=environments/dev/backend.conf
  backend "azurerm" {}
}

