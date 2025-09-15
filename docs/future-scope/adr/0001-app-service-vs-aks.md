# ADR-0001: App Service vs Azure Kubernetes Service (AKS)

**Status**: Accepted (for demo), Future consideration for production  
**Date**: 2024-12-13  
**Context**: Demo project - Production should re-evaluate  

## Context

For the Azure WebApp Demo, we need to choose between Azure App Service and Azure Kubernetes Service (AKS) for hosting our Python Flask application.

**DEMO PROJECT NOTE**: This ADR documents the simplified decision for demo purposes. Production deployments should conduct comprehensive evaluation.

## Decision

**Selected for Demo**: Azure App Service S1 Standard tier

### Rationale for Demo
- **Simplicity**: Minimal configuration required
- **HA Compliance**: S1 tier meets high availability requirements
- **Cost Control**: Fixed pricing, predictable costs
- **Time Constraints**: 2-hour deployment window
- **Team Familiarity**: Easier for demo purposes

## Considered Alternatives

### Azure App Service (Selected)
**Pros**:
- Fully managed platform (PaaS)
- Built-in SSL, custom domains, auto-scaling
- Integrated with Azure Key Vault
- Simple deployment model
- Built-in monitoring and logging
- Cost-effective for single application

**Cons**:
- Less flexibility than containers
- Vendor lock-in to Azure
- Limited customization of runtime environment

### Azure Kubernetes Service (AKS)
**Pros**:
- Full container orchestration
- Multi-application deployment
- Portable across cloud providers
- Advanced networking and security options
- Microservices architecture support

**Cons**:
- Higher complexity and operational overhead
- Requires Kubernetes expertise
- More expensive for single application
- Longer setup time (incompatible with 2-hour demo)

### Azure Container Instances (ACI)
**Pros**:
- Serverless containers
- Pay-per-second billing
- Quick startup times

**Cons**:
- No built-in load balancing
- Limited networking options
- Not suitable for production workloads

## Future Production Considerations

### When to Reconsider AKS
- **Multi-application architecture**: Multiple microservices
- **Advanced networking**: Service mesh, complex routing
- **Hybrid/multi-cloud**: Portability requirements
- **DevOps maturity**: Team has Kubernetes expertise
- **Compliance**: Advanced security and isolation needs

### Migration Path
1. **Phase 1**: Continue with App Service for MVP
2. **Phase 2**: Evaluate containerization benefits
3. **Phase 3**: Consider AKS for microservices architecture

### Cost Comparison (Production)
- **App Service P1V3**: ~$146/month
- **AKS (2-node cluster)**: ~$200-300/month
- **Break-even point**: 3+ applications

## Implementation Notes

### Demo Configuration
```hcl
resource "azurerm_service_plan" "asp" {
  name                = "${local.name_prefix}-asp"
  resource_group_name = azurerm_resource_group.rg.name
  location           = azurerm_resource_group.rg.location
  os_type            = "Linux"
  sku_name           = "S1"  # Hardcoded for demo
}
```

### Production Recommendations
- Use variables for SKU sizing
- Implement auto-scaling rules
- Add deployment slots for blue-green deployments
- Consider App Service Environment for isolation

## Consequences

### Positive
- Rapid deployment and demo readiness
- Lower operational complexity
- Cost-effective for single application
- Built-in HA and monitoring

### Negative
- Limited to single application architecture
- Vendor lock-in to Azure App Service
- Less flexibility for future microservices

## Review Schedule

- **Demo Phase**: No review needed (fixed approach)
- **Production Planning**: Re-evaluate based on:
  - Application architecture evolution
  - Team Kubernetes expertise
  - Multi-application requirements
  - Cost optimization needs

---

**Next ADR**: [0002-identity-and-secrets.md](0002-identity-and-secrets.md)
