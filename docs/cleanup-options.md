# Cleanup Options - Azure WebApp Demo

This document explains the two different cleanup approaches available in the Azure WebApp Demo project.

## Overview

The project provides **three distinct cleanup methods** to accommodate different use cases:

1. **GitHub Actions Cleanup** - Web-based cleanup with environment protection
2. **Manual Cleanup** - Interactive, immediate cleanup using Terraform
3. **Automatic Cleanup** - Scheduled, unattended cleanup using Azure Automation

## GitHub Actions Cleanup (Recommended Approach)

### Workflow: `Azure WebApp Demo - Cleanup`

**Purpose**: Web-based cleanup with environment protection and confirmation requirements.

**How it works**:
- Uses GitHub Actions web interface for easy access
- Requires typing "DELETE" to confirm resource deletion
- Environment-specific protections (staging/prod require approval)
- Pre-cleanup resource inventory and post-cleanup verification
- Complete audit trail in GitHub Actions

**Usage**:
1. Go to [GitHub Actions](https://github.com/cmcconnell1/azure-webapp-demo/actions)
2. Click "Azure WebApp Demo - Cleanup" workflow
3. Click "Run workflow" button
4. Select target environment (dev/staging/prod)
5. Type "DELETE" in confirmation field
6. Click "Run workflow"

**Benefits**:
- **No local setup required** - Works from any browser
- **Environment protection** - Staging/prod require manual approval
- **Confirmation required** - Must type "DELETE" to proceed
- **Audit trail** - Complete history in GitHub Actions
- **Real-time monitoring** - Watch cleanup progress live

**Perfect for**:
- Team members without local development setup
- Demos and presentations
- Environments requiring approval workflows
- Audit and compliance requirements

## Manual Cleanup (Local Development)

### Script: `./scripts/cleanup.sh`

**Purpose**: Interactive cleanup for developers working with the demo locally.

**How it works**:
- Uses `terraform destroy` to remove infrastructure
- Provides interactive confirmation prompts
- Generates final cost report
- Manages Terraform state properly

**Usage**:
```bash
# Interactive cleanup with confirmation
./scripts/cleanup.sh

# Force cleanup without confirmation
./scripts/cleanup.sh --force

# Generate cost report only
./scripts/cleanup.sh --cost-report
```

**When to use**:
- Normal demo workflow
- Development and testing
- When you want immediate cleanup
- When you want to see what's being deleted

## Automatic Cleanup (Optional Approach)

### Scripts: `./scripts/setup-azure-automation.sh` + `./scripts/azure-automation-cleanup.py`

**Purpose**: Hands-off automatic cleanup for unattended demos or cost protection.

**How it works**:
1. `setup-azure-automation.sh` creates Azure Automation Account
2. Uploads `azure-automation-cleanup.py` as a Python runbook
3. Schedules the runbook to run after specified time (default: 2 hours)
4. Runbook uses Azure SDK to delete resource groups directly
5. Optional webhook notifications

**Setup**:
```bash
# One-time setup for automatic cleanup
./scripts/setup-azure-automation.sh

# Custom configuration
./scripts/setup-azure-automation.sh \
  --resource-group rg-automation \
  --cleanup-hours 4 \
  --webhook-url https://hooks.slack.com/services/...
```

**When to use**:
- Hands-off demos or presentations
- Cost protection (prevent forgotten resources)
- Automated demo environments
- When you might forget to clean up manually

## Key Differences

| Aspect | GitHub Actions Cleanup | Manual Cleanup | Automatic Cleanup |
|--------|----------------------|----------------|-------------------|
| **Interface** | GitHub web UI | Command line | Scheduled |
| **Method** | Terraform destroy via GitHub Actions | Terraform destroy | Azure SDK resource deletion |
| **Timing** | On-demand (web trigger) | Immediate (when you run it) | Scheduled (after X hours) |
| **Interaction** | Web form + confirmation | Interactive prompts | Unattended |
| **Setup** | GitHub Actions configured | None required | One-time Azure Automation setup |
| **Dependencies** | GitHub repository access | Terraform, local state | Azure Automation Account |
| **Environment Protection** | Staging/prod require approval | None | None |
| **Confirmation** | Must type "DELETE" | Interactive prompts | None |
| **Audit Trail** | GitHub Actions history | Local console | Azure Automation logs |
| **Cost** | Free (GitHub Actions) | Free (uses local tools) | Small cost for Automation Account |

## When to Use Each Method

### Use GitHub Actions Cleanup When:
- **Team collaboration** - Multiple people need cleanup access
- **Demos and presentations** - No local setup required
- **Environment protection needed** - Staging/prod require approval
- **Audit requirements** - Need complete cleanup history
- **Remote access** - Working from different machines
- **Safety first** - Want confirmation requirements

### Use Manual Cleanup When:
- **Local development** - Working on your own machine
- **Immediate cleanup needed** - Want instant results
- **Terraform state management** - Need to preserve state consistency
- **Debugging** - Want to see detailed Terraform output
- **Offline work** - No internet access to GitHub

### Use Automatic Cleanup When:
- **Demo environments** - Want hands-off cleanup
- **Cost protection** - Prevent forgotten resources
- **Scheduled cleanup** - Want cleanup at specific times
- **Unattended operation** - No human intervention needed

## Recommendations

### For Normal Demo Use
**Use Manual Cleanup**: `./scripts/cleanup.sh`
- Simple, immediate, no additional setup required
- Good for development and testing workflows

### For Hands-Off Demos
**Use Automatic Cleanup**: Set up once with `./scripts/setup-azure-automation.sh`
- Prevents forgotten resources from accumulating costs
- Good for presentations or shared demo environments

### For Production
**Neither approach is suitable for production**
- Implement proper CI/CD pipelines
- Use environment-specific lifecycle management
- Implement proper governance and approval workflows

## Troubleshooting

### Manual Cleanup Issues
```bash
# If Terraform state is corrupted
terraform refresh
terraform destroy

# If resources are stuck
./scripts/cleanup.sh --force
```

### Automatic Cleanup Issues
```bash
# Check Azure Automation Account logs in Azure Portal
# Verify Managed Identity permissions
# Check runbook execution history
```

## Cost Implications

### Manual Cleanup
- **Cost**: Free (uses local Terraform)
- **Risk**: If you forget to run it, resources continue to cost money

### Automatic Cleanup
- **Setup Cost**: ~$0.002/hour for Automation Account
- **Benefit**: Guaranteed cleanup prevents larger costs from forgotten resources
- **ROI**: Pays for itself if it prevents even one forgotten deployment

## Security Considerations

### Manual Cleanup
- Uses your local Azure CLI credentials
- Requires Contributor access to resource group
- Terraform state contains sensitive information

### Automatic Cleanup
- Uses Managed Identity (more secure)
- Scoped permissions to specific resource groups
- No local credential storage required
- Audit trail in Azure Activity Log

## Summary

Both cleanup methods achieve the same goal but serve different use cases:

- **Manual cleanup** is perfect for normal development workflows
- **Automatic cleanup** provides insurance against forgotten resources and enables hands-off demos

Choose the approach that best fits your specific use case and workflow requirements.
