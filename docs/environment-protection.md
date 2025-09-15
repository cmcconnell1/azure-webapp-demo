# Environment Protection and Security Guards

This document explains the security protections and approval requirements for different environments in the Azure WebApp Demo project.

## Environment Security Model

### Dev Environment
- **Protection Level**: Minimal
- **Approval Required**: No
- **Branch Restrictions**: None
- **Use Case**: Development and testing

### Staging Environment  
- **Protection Level**: Medium
- **Approval Required**: Yes (manual approval)
- **Branch Restrictions**: None
- **Use Case**: Pre-production testing and validation

### Production Environment
- **Protection Level**: High
- **Approval Required**: Yes (manual approval)
- **Branch Restrictions**: Main branch only
- **Use Case**: Live production workloads

## GitHub Actions Workflow Protection

### Workflow Structure
The project uses two separate workflows for better user experience:

1. **Azure WebApp Demo - Deploy** (`main.yml`): Handles resource deployment
   - Shows only deployment-relevant parameters
   - Includes auto-cleanup, budget alerts, test options
   - Environment-specific deployment protections

2. **Azure WebApp Demo - Cleanup** (`cleanup.yml`): Handles resource cleanup
   - Shows only cleanup-relevant parameters
   - Requires typing "DELETE" to confirm
   - Environment-specific cleanup protections

### Deployment Protection

### Environment-Specific Guards

#### Production Environment Guards
- **Manual Approval Required**: GitHub environment protection rules
- **Branch Restriction**: Only main branch can deploy/cleanup production
- **Actor Verification**: Logs who initiated the action
- **Resource Inventory**: Shows what will be deleted before cleanup
- **Post-Cleanup Verification**: Confirms all resources are deleted

#### Staging Environment Guards
- **Manual Approval Required**: GitHub environment protection rules
- **Actor Verification**: Logs who initiated the action
- **Resource Inventory**: Shows what will be deleted before cleanup
- **Post-Cleanup Verification**: Confirms all resources are deleted

#### Dev Environment Guards
- **No Manual Approval**: Immediate execution
- **Resource Inventory**: Shows what will be deleted before cleanup
- **Post-Cleanup Verification**: Confirms all resources are deleted

## Setting Up Environment Protection

### 1. Configure GitHub Environment Protection Rules

Go to your repository - Settings - Environments

#### For Staging Environment:
1. Create environment named `staging`
2. Enable "Required reviewers"
3. Add trusted team members as reviewers
4. Set "Prevent administrators from bypassing configured protection rules" (optional)

#### For Production Environment:
1. Create environment named `prod`
2. Enable "Required reviewers"
3. Add senior team members/administrators as reviewers
4. Enable "Restrict pushes that create matching branches" - `main`
5. Set "Prevent administrators from bypassing configured protection rules"

### 2. Environment Secrets

Each environment should have its own secrets:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID` 
- `AZURE_SUBSCRIPTION_ID`

These are automatically configured by the setup script: `./scripts/setup-github-actions-azure.sh`

## Usage Examples

### Deploy to Different Environments

```bash
# Deploy to dev (no approval required)
# Go to Actions - "Azure WebApp Demo - Deploy" - Run workflow - Environment: "dev"

# Deploy to staging (requires approval)
# Go to Actions - "Azure WebApp Demo - Deploy" - Run workflow - Environment: "staging"
# Reviewer must approve the deployment

# Deploy to production (requires approval + main branch)
# Must be on main branch
# Go to Actions - "Azure WebApp Demo - Deploy" - Run workflow - Environment: "prod"
# Reviewer must approve the deployment
```

### Cleanup Different Environments

```bash
# Cleanup dev environment (no approval required)
# Go to Actions - "Azure WebApp Demo - Cleanup" - Run workflow
# Environment: "dev", Confirmation: "DELETE"

# Cleanup staging environment (requires approval)
# Go to Actions - "Azure WebApp Demo - Cleanup" - Run workflow
# Environment: "staging", Confirmation: "DELETE"
# Reviewer must approve the cleanup

# Cleanup production environment (requires approval + main branch)
# Must be on main branch
# Go to Actions - "Azure WebApp Demo - Cleanup" - Run workflow
# Environment: "prod", Confirmation: "DELETE"
# Reviewer must approve the cleanup
```

### Command Line Cleanup

```bash
# Cleanup specific environments
./scripts/cleanup.sh --env dev --force
./scripts/cleanup.sh --env staging --force
./scripts/cleanup.sh --env prod --force

# Interactive cleanup (with confirmation)
./scripts/cleanup.sh --env staging
./scripts/cleanup.sh --env prod
```

## Security Features

### Pre-Cleanup Resource Inventory
Before any cleanup, the workflow shows:
- Target environment and resource group
- List of all resources that will be deleted
- Current costs (if available)
- Who initiated the cleanup

### Post-Cleanup Verification
After cleanup, the workflow verifies:
- Resource group is completely deleted
- No resources remain in the environment
- Cleanup summary with timestamp and actor

### Audit Trail
All actions are logged with:
- Environment target
- Actor (who initiated)
- Timestamp
- Success/failure status
- Resource inventory before/after

## Best Practices

### For Development Teams
1. Use dev environment for daily development and testing
2. Use staging for integration testing and pre-production validation
3. Only deploy to production from main branch with proper approvals

### For Operations Teams
1. Set up appropriate reviewers for staging and production environments
2. Monitor cleanup actions through GitHub Actions logs
3. Regularly review environment protection settings
4. Ensure proper Azure RBAC permissions align with GitHub environment access

### For Security Teams
1. Audit environment protection rules regularly
2. Review who has approval rights for production deployments
3. Monitor resource cleanup activities
4. Ensure branch protection rules are enforced for production

## Troubleshooting

### Common Issues

**Approval Required but No Reviewers Set**
- Go to repository Settings - Environments - [environment] - Required reviewers
- Add appropriate team members

**Production Deployment Fails with Branch Error**
- Ensure you're on the main branch
- Check branch protection rules in environment settings

**Cleanup Fails to Delete Resources**
- Check Azure permissions for the service principal
- Verify resource group exists in the target environment
- Review Terraform state for any locks or dependencies

### Getting Help

For issues with environment protection:
1. Check GitHub Actions logs for specific error messages
2. Verify environment protection settings in repository settings
3. Run the troubleshooting script: `./scripts/troubleshoot-github-actions.sh`
4. Check Azure resource group and permissions

## Related Documentation

- [GitHub Actions Troubleshooting](../README.md#troubleshooting)
- [Setup Guide](../README.md#quick-start-2-hour-demo)
- [Cost Monitoring](../README.md#cost-monitoring)
