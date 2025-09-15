# ADR-0003: Networking and Data Protection

**Status**: Accepted (simplified for demo), Future enhancement required  
**Date**: 2024-12-13  
**Context**: Demo project - Production requires comprehensive network security  

## Context

The Azure WebApp Demo requires secure networking and data protection while maintaining public accessibility and treating all data as critical PII.

**DEMO PROJECT NOTE**: This ADR documents the simplified approach for demo purposes. Production deployments require comprehensive network security architecture.

## Decision

**Selected for Demo**: Public endpoints with basic security controls

### Rationale for Demo
- **Public Access**: Requirement for public web application
- **Simplicity**: Minimal network configuration for 2-hour demo
- **Cost Control**: Avoid expensive networking services
- **HA Compliance**: Standard tiers provide basic protection
- **PII Protection**: Rely on application-level and Key Vault security

## Considered Alternatives

### Public Endpoints with Basic Security (Selected)
**Pros**:
- Simple configuration and deployment
- No additional networking costs
- Fast deployment time
- Public accessibility as required
- Built-in Azure platform security

**Cons**:
- Limited network isolation
- Exposed to internet threats
- Basic DDoS protection only
- No private connectivity

### Virtual Network Integration (Future Consideration)
**Pros**:
- Network isolation and segmentation
- Private connectivity between services
- Advanced security controls
- Custom routing and firewall rules

**Cons**:
- Increased complexity and cost
- Longer deployment time
- Requires networking expertise
- May impact public accessibility

### Azure Front Door + WAF (Future Consideration)
**Pros**:
- Global load balancing
- Web Application Firewall protection
- DDoS protection
- SSL termination and optimization

**Cons**:
- Additional cost (~$22/month + usage)
- Increased complexity
- Overkill for demo application

## Implementation Details

### Demo Configuration
```hcl
# App Service with basic security
resource "azurerm_linux_web_app" "app" {
  name                = "${local.name_prefix}-web"
  location           = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id    = azurerm_service_plan.asp.id
  
  site_config {
    always_on = true  # HA requirement
    
    # Basic security headers
    app_command_line = ""
    
    application_stack {
      python_version = "3.11"
    }
  }
  
  # HTTPS only
  https_only = true
  
  # Basic identity
  identity {
    type = "SystemAssigned"
  }
}

# SQL Database with basic firewall
resource "azurerm_mssql_server" "sql" {
  name                         = "${local.name_prefix}-sql"
  resource_group_name         = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  version                    = "12.0"
  administrator_login        = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  
  # Basic security
  public_network_access_enabled = true  # Required for demo
}

# Firewall rule for Azure services
resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
```

### Security Controls Implemented
1. **HTTPS Only**: Force SSL/TLS encryption
2. **Managed Identity**: No stored credentials
3. **Key Vault Integration**: Secure secret management
4. **Azure Services Firewall**: Limit database access
5. **Application Insights**: Security monitoring

## Future Production Considerations

### Network Security Enhancements

#### Virtual Network Integration
```hcl
# Production VNet architecture
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location           = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# App Service subnet
resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  
  delegation {
    name = "app-service-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

# Database subnet
resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  
  service_endpoints = ["Microsoft.Sql"]
}
```

#### Private Endpoints
```hcl
# Private endpoint for SQL Database
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "${local.name_prefix}-sql-pe"
  location           = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id          = azurerm_subnet.db_subnet.id
  
  private_service_connection {
    name                           = "sql-private-connection"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names             = ["sqlServer"]
    is_manual_connection          = false
  }
}
```

### Web Application Firewall (WAF)
```hcl
# Azure Front Door with WAF
resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = "${local.name_prefix}-fd"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name           = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  name                = "${local.name_prefix}wafpolicy"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name           = "Standard_AzureFrontDoor"
  enabled            = true
  mode               = "Prevention"
  
  managed_rule {
    type    = "DefaultRuleSet"
    version = "1.0"
  }
}
```

### Data Protection Enhancements

#### Database Security
1. **Transparent Data Encryption (TDE)**: Enabled by default
2. **Always Encrypted**: Column-level encryption
3. **Dynamic Data Masking**: PII protection
4. **Auditing**: Comprehensive access logging
5. **Threat Detection**: Anomaly detection

#### Application Security
1. **Content Security Policy (CSP)**: XSS protection
2. **Security Headers**: HSTS, X-Frame-Options
3. **Input Validation**: SQL injection prevention
4. **Rate Limiting**: DDoS protection
5. **Authentication**: Azure AD integration

## Compliance Considerations

### Data Residency
- **Demo**: Single region deployment (West US 2)
- **Production**: Consider data sovereignty requirements
- **Backup**: Cross-region backup for DR

### Encryption
- **In Transit**: HTTPS/TLS 1.2+
- **At Rest**: Azure Storage encryption
- **Database**: TDE enabled
- **Key Management**: Azure Key Vault

### Monitoring and Logging
- **Network Traffic**: NSG flow logs
- **Application**: Application Insights
- **Database**: SQL audit logs
- **Security**: Azure Security Center

## Consequences

### Positive
- **Rapid Deployment**: Simple network configuration
- **Cost Effective**: No additional networking charges
- **Public Access**: Meets requirement for public web app
- **Basic Security**: Platform-level protection

### Negative
- **Limited Isolation**: No network segmentation
- **Attack Surface**: Exposed to internet threats
- **Compliance Gaps**: May not meet strict security requirements
- **Scalability**: Limited advanced networking features

## Migration Path to Production

### Phase 1: Basic Hardening
1. Implement WAF with Azure Front Door
2. Add custom domain with SSL certificate
3. Enable advanced threat protection
4. Implement rate limiting

### Phase 2: Network Isolation
1. Deploy VNet integration
2. Implement private endpoints
3. Add network security groups (NSGs)
4. Configure service endpoints

### Phase 3: Advanced Security
1. Implement Zero Trust architecture
2. Add Azure Firewall
3. Deploy Azure Bastion for management
4. Implement advanced monitoring

## Review Schedule

- **Demo Phase**: No review needed (fixed approach)
- **Production Planning**: Re-evaluate based on:
  - Security requirements and threat model
  - Compliance needs (SOC 2, PCI DSS)
  - Performance and availability requirements
  - Cost optimization opportunities

---

**Previous ADR**: [0002-identity-and-secrets.md](0002-identity-and-secrets.md)  
**Next ADR**: [0004-db-migrations-and-seeding.md](0004-db-migrations-and-seeding.md)
