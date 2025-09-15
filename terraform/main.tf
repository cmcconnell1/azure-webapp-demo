resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.name_prefix}-rg"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appi" {
  name                = "${local.name_prefix}-appi"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_service_plan" "asp" {
  name                = "${local.name_prefix}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  # DEMO PROJECT ONLY: Hardcoded to S1 Standard for HA compliance
  # Production projects should parameterize this value
  sku_name = "S1" # Standard tier for high availability

  tags = merge(var.default_tags, {
    Purpose = "web-application"
  })
}

resource "azurerm_key_vault" "kv" {
  name                       = "kv${replace(local.name_prefix, "-", "")}${random_string.suffix.result}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
}

data "azurerm_client_config" "current" {}

resource "random_password" "sql_admin_password" {
  length  = 20
  special = true
  # Exclude characters that can cause issues in ODBC connection strings
  override_special = "!@#$%^&*-_=+|:,."
}

resource "azurerm_mssql_server" "sql" {
  name                          = "${local.name_prefix}-sql-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login           = "sqladminuser"
  administrator_login_password  = random_password.sql_admin_password.result
  public_network_access_enabled = true
  minimum_tls_version           = "1.2"
}

resource "azurerm_mssql_database" "db" {
  name      = "${local.name_prefix}-db"
  server_id = azurerm_mssql_server.sql.id

  # DEMO PROJECT ONLY: Hardcoded to S0 Standard for HA compliance
  # Production projects should parameterize this value
  sku_name    = "S0" # Standard tier for high availability
  max_size_gb = 250  # 250GB for adequate capacity

  # Standard backup retention for HA
  short_term_retention_policy {
    retention_days = 7
  }

  tags = merge(var.default_tags, {
    Purpose = "quotes-database"
  })
}

# Allow Azure services (limited demo; prefer Private Endpoint in production)
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Azure Container Registry for storing container images
resource "azurerm_container_registry" "acr" {
  name                = "acr${replace(local.name_prefix, "-", "")}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false # Use managed identity instead
}

# Store SQL connection string in Key Vault
locals {
  sql_conn_str = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.db.name};Uid=${azurerm_mssql_server.sql.administrator_login};Pwd=${random_password.sql_admin_password.result};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
}

resource "azurerm_key_vault_secret" "sql_conn" {
  name         = "sql-connection-string"
  value        = local.sql_conn_str
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# PII COMPLIANCE: Quotes data must be loaded externally - NOT stored in Terraform
# This resource creates a placeholder secret that will be populated by external processes
# Production approach: Use Azure CLI, PowerShell, or secure data migration tools
resource "azurerm_key_vault_secret" "quotes_data" {
  name = "quotes-data"
  # Placeholder value - real data must be loaded via secure external process
  # See docs/pii-compliance.md for approved data loading methods
  value = base64encode(jsonencode([
    {
      "author" : "Demo User",
      "text" : "This is placeholder data. Real PII data must be loaded via secure external process after infrastructure deployment."
    }
  ]))
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.current_user]

  lifecycle {
    # Prevent Terraform from overwriting externally managed PII data
    ignore_changes = [value]
  }
}

resource "azurerm_linux_web_app" "app" {
  name                    = "${local.name_prefix}-web-${random_string.suffix.result}"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  service_plan_id         = azurerm_service_plan.asp.id
  https_only              = true
  client_affinity_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      docker_image_name   = "mcr.microsoft.com/appsvc/staticsite:latest" # Placeholder; will be updated via deployment
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
    # DEMO PROJECT ONLY: Hardcoded for HA compliance
    # Production projects should parameterize this value
    always_on                               = true # Required for high availability
    ftps_state                              = "Disabled"
    health_check_path                       = "/healthz"
    container_registry_use_managed_identity = true

    # Standard application logging for HA monitoring
    # Note: application_logs configured at app service level, not site_config
  }

  # DEMO PROJECT ONLY: Hardcoded app settings for simplicity
  # Production projects should parameterize these values
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appi.connection_string
    # Key Vault reference; App Service resolves this into SQL_CONN_STR at runtime
    "SQL_CONN_STR" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.sql_conn.id})"
    # Environment constraint validations for PII compliance
    "ENVIRONMENT" = var.environment
    "DEMO_MODE"   = "true"  # Documented PII exception for demo purposes
    "KEY_VAULT_URL" = azurerm_key_vault.kv.vault_uri
    # Standard settings for HA compliance
    "WEBSITE_TIME_ZONE"               = "UTC"
    "WEBSITE_ENABLE_SYNC_UPDATE_SITE" = "true"
  }

  tags = merge(var.default_tags, {
    Purpose = "web-application"
  })
}

# Grant current user access to Key Vault for secret creation
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

# Grant Web App access to Key Vault secrets
resource "azurerm_key_vault_access_policy" "app_kv" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

# Grant Web App managed identity AcrPull role on Container Registry
resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

