# GitHub Actions Deployment - Azure WebApp Demo

This document explains how to use GitHub Actions for simplified deployment of the Azure WebApp Demo.

## Overview

GitHub Actions deployment provides the **simplest demo experience** by eliminating local setup requirements. Users can deploy the demo with just a few clicks in the GitHub web interface or a single command line.

## Benefits of GitHub Actions Deployment

### For Demos and Presentations
- **No local setup required** - No need to install Azure CLI, Terraform, or Docker
- **One-click deployment** - Deploy from GitHub web interface
- **Consistent environment** - Same deployment environment every time
- **Real-time monitoring** - Watch deployment progress in GitHub Actions
- **Automatic cleanup** - Built-in resource cleanup scheduling

### For Development Teams
- **Standardized deployment** - Same process for all team members
- **Audit trail** - Complete deployment history in GitHub
- **Cost control** - Centralized budget and cleanup management
- **Easy sharing** - Share deployment links with stakeholders

## Deployment Methods

### Method 1: GitHub Web Interface (Simplest)

#### Deployment Steps:
1. **Navigate to Actions**: Go to [GitHub Actions](https://github.com/cmcconnell1/azure-webapp-demo/actions)
2. **Select Workflow**: Click "Azure WebApp Demo - Deploy"
3. **Run Workflow**: Click "Run workflow" button
4. **Configure Parameters**:
   - **Environment**: dev, staging, or prod
   - **Cleanup Hours**: Auto-cleanup after X hours (0 = no cleanup)
   - **Budget Alert**: Budget alert amount in USD
   - **Skip Tests**: Skip validation tests for faster deployment
   - **Force Deploy**: Skip confirmations for demo purposes
5. **Start Deployment**: Click "Run workflow"
6. **Monitor Progress**: Watch real-time deployment in Actions tab

#### Cleanup Steps:
1. **Navigate to Actions**: Go to [GitHub Actions](https://github.com/cmcconnell1/azure-webapp-demo/actions)
2. **Select Workflow**: Click "Azure WebApp Demo - Cleanup"
3. **Run Workflow**: Click "Run workflow" button
4. **Configure Parameters**:
   - **Environment**: dev, staging, or prod
   - **Confirmation**: Type "DELETE" exactly to confirm
5. **Start Cleanup**: Click "Run workflow"
6. **Monitor Progress**: Watch real-time cleanup in Actions tab

#### Perfect For:
- Live demos and presentations
- Non-technical stakeholders
- Quick testing and validation
- Team members without local development setup
- Safe resource cleanup with confirmation

### Method 2: Command Line Trigger

#### Prerequisites:
- GitHub CLI installed (`gh auth login`) OR
- GitHub personal access token with repo/workflow permissions

#### Usage:
```bash
# Clone repository
git clone https://github.com/cmcconnell1/azure-webapp-demo.git
cd azure-webapp-demo

# Deploy with defaults (dev environment, 2-hour cleanup)
./scripts/deploy-github.sh

# Custom deployment
./scripts/deploy-github.sh --env staging --cleanup-hours 4 --budget 50

# Deploy without cleanup
./scripts/deploy-github.sh --no-cleanup --skip-tests
```

#### Perfect For:
- Developers who prefer command line
- Automated testing scenarios
- Integration with other scripts
- Batch deployments

### Method 3: Local Deployment (Traditional)

#### Prerequisites:
- Azure CLI authenticated
- Terraform >= 1.5 installed
- Docker installed

#### Usage:
```bash
# Traditional local deployment
./scripts/deploy.sh

# Custom local deployment
./scripts/deploy.sh --cleanup-hours 4 --budget 50
```

#### Perfect For:
- Development and testing
- Customization and experimentation
- Offline development
- Learning Terraform and Azure CLI

## GitHub Actions Workflow Features

### Automated Infrastructure Deployment
- **Terraform execution** in GitHub-hosted runners
- **Azure authentication** via OIDC (no stored credentials)
- **Environment-specific** configurations
- **State management** with remote backend

### Application Deployment
- **Container building** and deployment
- **Database seeding** with sample quotes
- **Health checks** and validation
- **Endpoint testing** after deployment

### Cost Management Integration
- **Pre-deployment cost estimation**
- **Real-time cost monitoring**
- **Budget alerts** and notifications
- **Cost reporting** as workflow artifacts

### Automatic Cleanup
- **Scheduled cleanup** via Azure Automation
- **Configurable cleanup time** (1-24 hours)
- **Manual cleanup option** available
- **Cleanup failure handling** and notifications

### Monitoring and Reporting
- **Real-time deployment logs**
- **Deployment summary** with URLs and costs
- **Artifact uploads** (cost reports, logs)
- **Failure notifications** and cleanup

## Configuration Requirements

### Azure Setup (One-time)
1. **Create Azure AD App Registration**
2. **Configure OIDC trust** for GitHub Actions
3. **Assign Azure permissions** (Contributor + User Access Administrator roles)
4. **Set repository secrets**:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`

### GitHub Repository Secrets
```bash
# Required secrets for GitHub Actions
AZURE_CLIENT_ID=<app-registration-client-id>
AZURE_TENANT_ID=<azure-tenant-id>
AZURE_SUBSCRIPTION_ID=<azure-subscription-id>
```

### Environment Configuration
- **dev**: Development environment (default)
- **staging**: Staging environment
- **prod**: Production environment (requires approval)

## Workflow Parameters

### Environment Settings
- **environment**: Target Azure environment (dev/staging/prod)
- **cleanup_hours**: Auto-cleanup timer (0-24 hours, 0 = disabled)
- **budget_alert**: Budget alert threshold in USD
- **skip_tests**: Skip validation tests for faster deployment
- **force_deploy**: Skip confirmations for demo purposes

### Example Configurations
```yaml
# Quick demo (2 hours, $10 budget)
environment: dev
cleanup_hours: 2
budget_alert: 10
skip_tests: false
force_deploy: true

# Extended demo (4 hours, $25 budget)
environment: staging
cleanup_hours: 4
budget_alert: 25
skip_tests: false
force_deploy: true

# Development (no cleanup, $50 budget)
environment: dev
cleanup_hours: 0
budget_alert: 50
skip_tests: true
force_deploy: true
```

## Monitoring Deployment

### GitHub Actions Interface
- **Real-time logs** for each deployment step
- **Progress indicators** and status updates
- **Deployment summary** with application URLs
- **Cost reports** and resource information

### Command Line Monitoring
```bash
# List recent workflow runs
gh run list --repo cmcconnell1/azure-webapp-demo

# Watch current deployment
gh run watch --repo cmcconnell1/azure-webapp-demo

# View specific run logs
gh run view <run-id> --repo cmcconnell1/azure-webapp-demo
```

### Deployment Outputs
- **Application URL**: Direct link to deployed web application
- **Resource Group**: Azure resource group name
- **Cost Report**: Deployment cost breakdown
- **Cleanup Schedule**: Automatic cleanup timing

## Troubleshooting

### Common Issues
1. **Authentication failures**: Check Azure OIDC configuration
2. **Quota errors**: Verify Azure subscription quotas
3. **Terraform state conflicts**: Check backend configuration
4. **Cost overruns**: Monitor budget alerts and cleanup

### Debug Steps
1. **Check workflow logs** in GitHub Actions
2. **Verify Azure permissions** for service principal (Contributor + User Access Administrator)
3. **Review Terraform state** in remote backend
4. **Monitor Azure costs** in cost management

## Comparison with Local Deployment

| Aspect | GitHub Actions | Local Deployment |
|--------|----------------|------------------|
| **Setup** | No local setup required | Azure CLI, Terraform, Docker |
| **Consistency** | Same environment every time | Varies by local setup |
| **Monitoring** | GitHub Actions interface | Terminal output |
| **Sharing** | Easy to share with team | Requires local access |
| **Customization** | Workflow parameters | Full script access |
| **Offline** | Requires internet | Works offline |
| **Learning** | Focus on Azure concepts | Learn tooling |

## Best Practices

### For Demos
- Use **GitHub web interface** for live presentations
- Set **2-4 hour cleanup** to prevent cost overruns
- Enable **budget alerts** at $10-25 for safety
- Use **force deploy** to skip confirmations

### For Development
- Use **command line trigger** for automation
- Disable **auto-cleanup** for extended testing
- Enable **detailed logging** for troubleshooting
- Set **higher budgets** for development work

### For Production Planning
- Use **staging environment** for production testing
- Implement **approval workflows** for production
- Add **comprehensive testing** and validation
- Configure **proper monitoring** and alerting

## Summary

GitHub Actions deployment **dramatically simplifies** the demo experience by:

1. **Eliminating local setup** requirements
2. **Providing one-click deployment** from web interface
3. **Offering command-line automation** for developers
4. **Including built-in cost management** and cleanup
5. **Maintaining audit trails** and deployment history

This approach makes the Azure WebApp Demo **accessible to anyone** with a GitHub account, regardless of their local development environment or Azure expertise.
