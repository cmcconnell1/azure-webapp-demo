output "vnet_id" { value = azurerm_virtual_network.vnet.id }
output "subnet_app_id" { value = azurerm_subnet.app_integration.id }
output "subnet_pe_id" { value = azurerm_subnet.private_endpoints.id }

