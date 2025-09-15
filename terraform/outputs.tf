output "webapp_name" { value = azurerm_linux_web_app.app.name }
output "webapp_url" { value = azurerm_linux_web_app.app.default_hostname }
output "resource_group" { value = azurerm_resource_group.rg.name }
output "sql_server" { value = azurerm_mssql_server.sql.name }
output "sql_database" { value = azurerm_mssql_database.db.name }
output "key_vault_name" { value = azurerm_key_vault.kv.name }
output "acr_name" { value = azurerm_container_registry.acr.name }
output "acr_login_server" { value = azurerm_container_registry.acr.login_server }
output "suffix" { value = random_string.suffix.result }

