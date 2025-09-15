# Azure WebApp Demo - Simplified Deployment

A secure, highly available web application that displays random famous quotes from an Azure SQL Database.

**Project Requirement**: Treat all data as critical PII (Personally Identifiable Information).

**Repository**: [cmcconnell1/azure-webapp-demo](https://github.com/cmcconnell1/azure-webapp-demo)

## IMPORTANT: Testing Environment Disclaimer

**ALWAYS USE A DEDICATED TEST ENVIRONMENT**

This project creates and manages Azure resources that incur costs. To ensure safety and avoid any impact on existing systems:

- **Use a dedicated Azure tenant/subscription** for testing this demo
- **Never deploy to production Azure environments** without thorough testing
- **Validate all deployments in isolated test environments first**
- **Review all Terraform configurations** before applying to any environment
- **Monitor costs closely** during testing (budget alerts are configured)
- **Clean up resources promptly** after testing to minimize costs

**Recommended Setup:**
1. Create a separate Azure subscription specifically for testing
2. Use a dedicated resource group prefix (already configured as "webapp-demo")
3. Set up budget alerts (automatically configured at $10)
4. Test the complete deployment and cleanup cycle before any production use

**Resource Naming Patterns:**
- Resource Groups: `webapp-demo-{environment}-rg` (e.g., `webapp-demo-dev-rg`)
- Storage Accounts: `webappdemotf{env}{random}` (e.g., `webappdemotfdev0c3bfb`)
- Other Resources: `webapp-demo-{environment}-{type}` (e.g., `webapp-demo-dev-sql-abc123`)
- Terraform State: Stored in separate `webapp-demo-terraform-state-rg` resource group

**This demo project is designed for learning and testing purposes only.**

## Demo Project Overview

**DEMO PROJECT ONLY**: This project uses simplified deployment patterns for demonstration purposes.
Production projects should use comprehensive CI/CD pipelines and environment management.

### Requirements Met
- **Public web application** - Azure App Service (S1 Standard)
- **Azure SQL database** - S0 Standard tier with quotes
- **Random quote display** - Flask API with database queries
- **Treat data as critical PII** - Azure Key Vault for secrets
- **High availability** - Standard tiers with always_on enabled
- **Terraform provisioning** - Infrastructure as Code

### Architecture
- **Web App**: Python Flask on Azure App Service S1 (HA-compliant)
- **Database**: Azure SQL Database S0 (HA-compliant)
- **Security**: Azure Key Vault for PII data protection
- **Monitoring**: Application Insights for observability
- **Infrastructure**: Terraform with hardcoded HA values
- **Auto-Cleanup**: 2-hour deployment window with automatic cleanup

### Cost Management (FinOps)
- **Infrastructure Cost**: ~$50-70/month (HA-compliant tiers)
- **Actual Demo Cost**: ~$0.15 per 2-hour deployment
- **Auto-Cleanup**: Prevents cost overruns
- **Budget Monitoring**: Real-time cost tracking and alerts
- **FinOps Integration**: Cost estimation and reporting

## Architecture Overview

**[View Complete Architecture Diagrams](docs/architecture-overview.md)**

This project demonstrates a modern Azure cloud-native application with:
- **Compute**: App Service with container deployment
- **Data**: Azure SQL Database with automatic seeding
- **Security**: Key Vault and Managed Identity
- **Monitoring**: Application Insights and cost tracking
- **Automation**: Scheduled cleanup and cost management

## Quick Start (2-Hour Demo)

**SAFETY FIRST**: Ensure you're using a dedicated test Azure subscription before proceeding.

## Deployment and Management

### Preferred Method: GitHub Actions (Recommended)

**GitHub Actions is the preferred deployment and management method** for this project. It provides:
- **One-click deployment** from the GitHub web interface
- **No local setup required** (Azure CLI, Terraform, Docker)
- **Automated validation** and testing
- **Built-in cost monitoring** and reporting
- **Secure OIDC authentication** (no stored credentials)
- **Environment protection** for staging/prod
- **Audit trail** and deployment history

### Prerequisites (One-time Setup)

**Step 1: Install GitHub CLI and authenticate**
```bash
# Install GitHub CLI (if not already installed)
# macOS: brew install gh
# Windows: winget install GitHub.cli
# Linux: See https://cli.github.com/

# Authenticate with GitHub
gh auth login
```

**Step 2: Configure Azure authentication for GitHub Actions**
```bash
# Clone the repository
git clone https://github.com/cmcconnell1/azure-webapp-demo.git
cd azure-webapp-demo

# Run the one-time Azure credentials setup
./scripts/setup-github-actions-azure.sh
```

**What the setup script does:**
- Creates Azure AD App Registration with OIDC trust
- Assigns necessary Azure permissions (Contributor + User Access Administrator)
- **Automatically configures GitHub repository secrets** (if GitHub CLI is available)
- Sets up environment secrets for dev, staging, and prod
- Provides manual instructions if GitHub CLI is not available

### GitHub Actions Deployment (Preferred)

**For Deployment:**
1. **Go to**: [GitHub Actions](https://github.com/cmcconnell1/azure-webapp-demo/actions)
2. **Click**: "Azure WebApp Demo - Deploy" workflow
3. **Click**: "Run workflow" button
4. **Configure**: Environment, cleanup hours, budget, test options
5. **Click**: "Run workflow" to deploy
6. **Monitor**: Progress in GitHub Actions tab

**For Cleanup:**
1. **Go to**: [GitHub Actions](https://github.com/cmcconnell1/azure-webapp-demo/actions)
2. **Click**: "Azure WebApp Demo - Cleanup" workflow
3. **Click**: "Run workflow" button
4. **Select**: Target environment
5. **Type**: "DELETE" to confirm
6. **Click**: "Run workflow" to cleanup

### Alternative Methods

#### Command Line + GitHub Actions
```bash
# Trigger GitHub Actions deployment from command line
./scripts/deploy-github.sh

# Custom deployment options
./scripts/deploy-github.sh --env staging --cleanup-hours 4 --budget 50
```

**How `deploy-github.sh` Works:**
- **Same as clicking "Run workflow"** in GitHub Actions web UI
- **Triggers the deployment workflow** via GitHub CLI API
- **No difference in functionality** - just a command-line interface to the web UI

**Complete Deployment Flow:**
1. **Infrastructure Deployment** (Terraform)
   - Creates/updates Azure resources (App Service, SQL Database, Key Vault)
   - Configures environment variables (`DEMO_MODE=true`, `ENVIRONMENT=dev`)
2. **Container Build & Deploy**
   - Builds Docker container with latest code from repository
   - Pushes container to Azure Container Registry
   - Deploys container to Azure App Service
3. **Application Startup**
   - Container starts with environment constraint validations
   - Database seeding runs with proper PII compliance logic
   - Application becomes available at Azure App Service URL

#### Local Deployment (Advanced Users)
**Prerequisites**: Azure CLI, Terraform >= 1.5, Docker

```bash
# Authenticate with Azure
az login
az account set --subscription <your-subscription-id>

# Deploy locally
./scripts/deploy.sh

# Custom deployment options
./scripts/deploy.sh --cleanup-hours 4 --budget 50
```

### GitHub Actions Workflow Design

This project uses **two focused GitHub Actions workflows** for optimal user experience:

**Azure WebApp Demo - Deploy** (`main.yml`):
- **Validation**: Automatic on code changes (no deployment)
- **Deployment**: Manual trigger with deployment-specific parameters
- **Command Line**: API trigger via `./scripts/deploy-github.sh`
- **Cost Monitoring**: Automatic cost reporting and budget alerts
- **Auto-Cleanup**: Configurable automatic resource cleanup

**Azure WebApp Demo - Cleanup** (`cleanup.yml`):
- **Cleanup**: Manual trigger with confirmation requirement
- **Environment Protection**: Staging/prod require approval
- **Safety**: Must type "DELETE" to confirm resource deletion
- **Audit Trail**: Complete cleanup history and verification

**Clear separation** - deploy parameters vs cleanup parameters, no confusion.

### Monitoring and Testing

**GitHub Actions provides built-in monitoring**, but you can also use local scripts:

```bash
# Monitor costs in real-time (local)
./scripts/cost-monitor.sh --actual

# Generate cost dashboard (local)
./scripts/cost-dashboard.sh

# Validate deployment (local)
./scripts/validate-database-source.sh
```

### Cleanup Options

#### Preferred: GitHub Actions Cleanup
**Use the GitHub Actions cleanup workflow** (see deployment section above) for:
- **Audit trail** and approval workflows
- **Environment protection** for staging/prod
- **Confirmation requirements** (type "DELETE")
- **Complete cleanup verification**

#### Alternative: Local Cleanup
```bash
# Manual cleanup using Terraform destroy
./scripts/cleanup.sh

# Force cleanup without confirmation
./scripts/cleanup.sh --force
```

#### Automatic Cleanup (Optional)
```bash
# Set up Azure Automation for automatic cleanup after 2 hours
./scripts/setup-azure-automation.sh

# Resources will be automatically deleted after 2 hours
# Uses azure-automation-cleanup.py script in Azure Automation Account
```

## Project Structure

```
azure-webapp-demo/
├── app/                    # Flask web application
├── terraform/              # Infrastructure as Code (simplified)
├── database/              # SQL scripts and quote data
├── scripts/               # Deployment and utility scripts
│   ├── deploy.sh          # Local deployment (Terraform)
│   ├── deploy-github.sh   # GitHub Actions deployment trigger
│   ├── setup-github-actions-azure.sh # Azure credentials setup for GitHub Actions
│   ├── cleanup.sh         # Manual cleanup (Terraform destroy)
│   ├── azure-automation-cleanup.py  # Automatic cleanup (Azure Automation)
│   ├── setup-azure-automation.sh    # Set up automatic cleanup
│   ├── setup-auto-cleanup-current.sh # Auto-detect and setup cleanup for current deployment
│   ├── cost-monitor.sh    # FinOps cost tracking
│   └── cost-dashboard.sh  # Cost visualization
├── docs/                  # Essential documentation
│   ├── architecture-overview.md # System architecture and diagrams

│   ├── cost-monitoring.md # FinOps documentation
│   ├── cleanup-options.md # Resource cleanup guide
│   └── mock-pii-disclaimer.md # Demo PII data limitations
└── tests/                 # Application tests
```

## Scripts Reference

This project includes 17 scripts organized by functionality. All core scripts are fully functional and tested.

### Essential Scripts (10) - Core Functionality

#### GitHub Actions Deployment (Preferred Method)
- **`./scripts/setup-github-actions-azure.sh`** - **REQUIRED** One-time Azure credentials setup for GitHub Actions
- **`./scripts/deploy-github.sh`** - **PREFERRED** Trigger GitHub Actions deployment from command line

#### Local Deployment (Alternative Method)
- **`./scripts/deploy.sh`** - Local deployment with Terraform (requires Azure CLI, Terraform, Docker)
- **`./scripts/cleanup.sh`** - Manual cleanup using Terraform destroy (used by GitHub Actions and local)

#### Infrastructure Support Scripts
- **`./scripts/bootstrap-tf-backend.sh`** - Terraform backend setup (called by deploy.sh)
- **`./scripts/deploy-container.sh`** - Container deployment (called by deploy.sh)
- **`./scripts/discover-azure-resources.sh`** - Resource discovery (called by validation scripts)

#### Validation and Testing Scripts
- **`./scripts/validate-database-source.sh`** - Deployment validation (called by deploy.sh and GitHub Actions)
- **`./scripts/test-end-to-end.sh`** - Comprehensive testing (called by GitHub Actions validation)
- **`./scripts/troubleshoot-github-actions.sh`** - GitHub Actions diagnostics and troubleshooting

### Cost Monitoring Scripts (4) - FinOps Integration

- **`./scripts/cost-monitor.sh`** - Real-time cost tracking and estimation
- **`./scripts/cost-dashboard.sh`** - Cost visualization dashboard (HTML output)
- **`./scripts/setup-cost-monitoring.sh`** - Budget alerts setup
- **`./scripts/azure-cost-monitor.py`** - Advanced cost monitoring (requires Azure SDK dependencies)

**Note**: Cost monitoring scripts work out-of-the-box with simplified cost estimation. For advanced Azure Cost Management API integration, install: `pip install -r requirements-cost-monitoring.txt`

### Azure Automation Scripts (3) - Advanced Features

- **`./scripts/setup-azure-automation.sh`** - Set up Azure Automation for automatic cleanup (alternative to GitHub Actions)
- **`./scripts/azure-automation-cleanup.py`** - Python script for automated resource cleanup (used by Azure Automation)
- **`./scripts/setup-auto-cleanup-current.sh`** - Auto-detect current deployment and setup cleanup (alternative method)

**Note**: Azure Automation scripts are optional advanced features. Most users should use GitHub Actions cleanup workflow instead.

### Script Usage by User Type

#### GitHub Actions Users (Recommended)
```bash
# Required setup (one-time)
./scripts/setup-github-actions-azure.sh

# Deployment (use GitHub Actions web interface)
# OR trigger from command line:
./scripts/deploy-github.sh

# Optional monitoring
./scripts/cost-monitor.sh --actual
./scripts/cost-dashboard.sh
```

#### Local Development Users
```bash
# Full local deployment
./scripts/deploy.sh

# Validation and testing
./scripts/validate-database-source.sh
./scripts/test-end-to-end.sh

# Cost monitoring
./scripts/cost-monitor.sh --actual
./scripts/cost-dashboard.sh

# Cleanup
./scripts/cleanup.sh
```

#### Advanced Users
```bash
# Azure Automation cleanup (alternative to GitHub Actions)
./scripts/setup-azure-automation.sh

# Advanced cost monitoring (requires pip install)
pip install -r requirements-cost-monitoring.txt
python3 ./scripts/azure-cost-monitor.py --project-name webapp-demo
```

## Testing and Validation

### Automated Testing (GitHub Actions)
GitHub Actions automatically runs comprehensive validation on every code change:
- **Script syntax validation** - All shell and Python scripts
- **Terraform configuration validation** - Infrastructure as Code validation
- **Python application testing** - Flask application validation
- **Cost monitoring validation** - FinOps script testing

### Manual Testing and Validation

#### Run Application Tests
```bash
# Install test dependencies
pip install -r requirements-dev.txt

# Run all tests
python -m pytest tests/

# Run specific test types
python -m pytest tests/unit/      # Unit tests
python -m pytest tests/integration/  # Integration tests
```

#### Validate Deployment
```bash
# Comprehensive end-to-end testing
./scripts/test-end-to-end.sh

# Check infrastructure deployment
./scripts/validate-database-source.sh

# Test application endpoints
curl https://your-app.azurewebsites.net/           # Random quote (JSON)
curl https://your-app.azurewebsites.net/healthz    # Health check
curl https://your-app.azurewebsites.net/db-test    # Database connectivity
curl https://your-app.azurewebsites.net/db-validate # Database validation
```

#### Troubleshooting
```bash
# GitHub Actions troubleshooting
./scripts/troubleshoot-github-actions.sh

# Resource discovery and validation
./scripts/discover-azure-resources.sh dev
```

## Demo Notes

### Hardcoded Values (Demo Only)
This project uses hardcoded values for simplicity. **NOT recommended for production**:
- App Service Plan: S1 Standard (hardcoded for HA)
- SQL Database: S0 Standard (hardcoded for HA)
- Region: West US 2 (hardcoded)
- Auto-cleanup: 2 hours (hardcoded)

### Production Recommendations
For production deployments:
- Use proper environment management
- Implement comprehensive CI/CD pipelines
- Use dynamic resource sizing
- Implement proper secret rotation
- Use multiple environments (dev/staging/prod)

## FinOps and Cost Management

### Cost Breakdown (2-Hour Demo)
- **App Service S1**: ~$0.06 per 2 hours
- **SQL Database S0**: ~$0.08 per 2 hours
- **Other Services**: ~$0.01 per 2 hours
- **Total**: ~$0.15 per demo deployment

### Cost Monitoring Commands

#### Basic Cost Monitoring (Works Out-of-the-Box)
```bash
# Estimate costs before deployment
./scripts/cost-monitor.sh --estimate

# Monitor actual costs during deployment
./scripts/cost-monitor.sh --actual

# Set budget alerts
./scripts/cost-monitor.sh --budget 10

# Generate cost dashboard (HTML output)
./scripts/cost-dashboard.sh

# Serve dashboard with auto-refresh
./scripts/cost-dashboard.sh --serve --port 8080
```

#### Advanced Cost Monitoring (Requires Azure SDK)
```bash
# Install Azure Cost Management dependencies
pip install -r requirements-cost-monitoring.txt

# Detailed cost analysis with Azure Cost Management API
python3 ./scripts/azure-cost-monitor.py --project-name webapp-demo

# Export cost data to JSON
python3 ./scripts/azure-cost-monitor.py --export-json costs.json --detailed
```

### FinOps Best Practices Demonstrated
- **Cost Transparency**: Real-time cost visibility for all stakeholders
- **Budget Governance**: Automated budget alerts and threshold monitoring
- **Resource Optimization**: Automatic cleanup to prevent cost overruns
- **Cost Allocation**: Environment-specific cost tracking (dev, staging, prod)
- **Reporting and Analysis**: HTML dashboards and JSON export capabilities
- **Proactive Monitoring**: Continuous cost tracking during deployment lifecycle

## Security Features

- **PII Protection**: All data treated as critical PII
- **Azure Key Vault**: Secure secrets management
- **Managed Identity**: Passwordless authentication

### Mock-PII Data Disclaimer

**DEMO PROJECT ONLY**: This project includes mock-PII data (famous sports quotes) in source control for demonstration purposes. This violates PII best practices and should NOT be done in production.

**Production Requirements**:
- Store PII data in Azure Key Vault secrets
- Use secure data loading from external sources
- Never commit PII data to version control
- Implement proper data classification and handling

**Demo Limitation**: The "chicken and egg" problem with greenfield Terraform projects requires initial data to demonstrate the application. In production, use secure data migration processes and external PII sources.
- **TLS Encryption**: All communications encrypted
- **Input Validation**: SQL injection prevention

## Documentation

### Current Demo Documentation
- **README.md** - This file (simplified setup guide)

- **docs/cleanup-options.md** - Manual vs automatic cleanup explained
- **docs/finops-cost-analysis.md** - FinOps best practices
- **docs/cost-monitoring.md** - Cost monitoring tools
- **docs/database-seeding.md** - Database setup

### Future Scope and Production Planning
- **[Future Scope Overview](docs/future-scope/README.md)** - Production roadmap and considerations
- **[Architecture Decision Records](docs/future-scope/adr/)** - Technical decisions and future planning
  - [ADR-0001: App Service vs AKS](docs/future-scope/adr/0001-app-service-vs-aks.md)
  - [ADR-0002: Identity and Secrets](docs/future-scope/adr/0002-identity-and-secrets.md)
  - [ADR-0003: Networking and Data Protection](docs/future-scope/adr/0003-networking-and-data-protection.md)
  - [ADR-0004: Database Migrations](docs/future-scope/adr/0004-db-migrations-and-seeding.md)

### API Endpoints
- **`/`** - Random quote API (JSON)
- **`/healthz`** - Health check endpoint (JSON)
- **`/db-test`** - Database connectivity test (JSON)
- **`/db-validate`** - Database validation with schema info (JSON)
- **`/quote-with-source`** - Quote with database source validation (JSON)

### Validation Scripts
- **`./scripts/validate-database-source.sh`** - Verify deployment
- **`./scripts/cost-monitor.sh`** - Cost tracking
- **`./scripts/cost-dashboard.sh`** - Cost visualization

## Important Notes

### Demo Project Disclaimer
This is a **demonstration project** with simplified patterns. For production use:
- Implement proper CI/CD pipelines
- Use environment-specific configurations
- Add comprehensive monitoring and alerting
- Implement proper secret rotation
- Use blue-green or canary deployments

### Environment Isolation
The project supports multiple environments (dev, staging, prod) with complete resource isolation:
- **Separate Resource Groups**: Each environment gets its own resource group
- **Environment-Specific Cleanup**: Cleanup scripts only affect the specified environment
- **Isolated Terraform State**: Each environment has its own state file
- **Independent Deployments**: Environments can be deployed and managed independently

### Cleanup Options
**Two ways to clean up resources:**

#### Manual Cleanup (Default)
- Run `./scripts/cleanup.sh` when you're done with the demo
- Uses Terraform destroy for clean removal
- Interactive with confirmation prompts

#### Automatic Cleanup (Optional)
- Set up with `./scripts/setup-azure-automation.sh`
- Resources automatically deleted after 2 hours
- Uses Azure Automation Account with Python script
- No user interaction required

**For detailed comparison**: See [docs/cleanup-options.md](docs/cleanup-options.md)

### Cost Monitoring
- Budget alerts are set to $10 by default
- Monitor costs with `./scripts/cost-monitor.sh --actual`
- Final cost report generated during cleanup

## Troubleshooting

### GitHub Actions Authentication Issues

If GitHub Actions deployment fails with Azure login errors:

```bash
# Run comprehensive troubleshooting
./scripts/troubleshoot-github-actions.sh

# Or check manually:
# 1. Verify GitHub secrets exist
gh secret list --repo cmcconnell1/azure-webapp-demo
gh secret list --repo cmcconnell1/azure-webapp-demo --env dev

# 2. Check Azure App Registration
az ad app list --display-name "azure-webapp-demo-github-actions" --query "[].{appId:appId,displayName:displayName}" -o table

# 3. Verify OIDC federated credentials
APP_ID=$(az ad app list --display-name "azure-webapp-demo-github-actions" --query "[0].appId" -o tsv)
az ad app federated-credential list --id "$APP_ID" --query "[].{name:name,subject:subject,issuer:issuer}" -o table

# 4. Check Azure permissions
az role assignment list --assignee "$APP_ID" --query "[].{principalName:principalName,roleDefinitionName:roleDefinitionName,scope:scope}" -o table
```

### Common Issues

- **"auth-type is correct" error**: Fixed in latest workflow (requires `auth-type: IDENTITY`)
- **Missing secrets**: Run `./scripts/setup-github-actions-azure.sh` again
- **OIDC trust issues**: Federated credential subject must be `repo:cmcconnell1/azure-webapp-demo:ref:refs/heads/main`
- **Permission denied**: Service principal needs Contributor and User Access Administrator roles at subscription level

## Support

For other deployment issues:
1. Check Application Insights logs in Azure Portal
2. Review deployment logs: `./scripts/deploy.sh --verbose`
3. Validate deployment: `./scripts/validate-database-source.sh`

## License

## PII Compliance

**IMPORTANT**: This demo project contains documented PII exceptions for demonstration purposes.

### Demo Exception
- **File**: `database/seed/quotes.json` contains famous sports quotes (treated as PII per requirements)
- **Justification**: Greenfield demos require initial data to demonstrate functionality
- **Production**: Remove all PII from source control and use secure external loading methods

### Compliance Documentation
- **Complete Guide**: [docs/pii-compliance.md](docs/pii-compliance.md)
- **Demo Verification**: `./scripts/verify-demo-compliance.sh`
- **Production Verification**: `./scripts/verify-pii-compliance.sh`

### Production Requirements
For production deployment, you MUST:
1. Remove `database/seed/quotes.json`
2. Load PII data via Azure Key Vault using approved external methods
3. Follow organizational PII handling policies
4. Implement proper data governance procedures

### Environment Constraint Validations
The application includes built-in environment constraint validations for proper PII data handling:

**Environment Variables:**
- **`DEMO_MODE=true`** - Explicitly enables seed file usage (documented PII exception)
- **`ENVIRONMENT=dev|staging|prod`** - Controls data source selection logic
- **`KEY_VAULT_URL`** - Required for production environments
- **`QUOTES_DATA_BASE64`** - For local development with environment variables

**Constraint Logic:**
1. **Production environments MUST use Key Vault** - No fallback to seed files
2. **Demo mode explicitly enables seed file usage** - Documented PII exception
3. **Local development prefers environment variables** - Secure local testing
4. **Dev environments can fallback to seed files** - With proper warnings
5. **No production fallback** - Strict compliance enforcement

## Additional Resources

- **Architecture Overview**: [docs/architecture-overview.md](docs/architecture-overview.md)
- **PII Compliance Guide**: [docs/pii-compliance.md](docs/pii-compliance.md)
- **Troubleshooting Guide**: [docs/troubleshooting.md](docs/troubleshooting.md)
- **Cost Optimization**: [docs/cost-optimization.md](docs/cost-optimization.md)
- **Security Best Practices**: [docs/security.md](docs/security.md)

## Contributing

This is a demonstration project. For production use, review and adapt the configurations according to your organization's requirements and security policies.

**PII Compliance**: Ensure all PII handling follows your organization's data protection policies and regulatory requirements.

## License

MIT License - see LICENSE file for details.

---

**Repository**: [cmcconnell1/azure-webapp-demo](https://github.com/cmcconnell1/azure-webapp-demo)

**Preferred Workflow (GitHub Actions)**:
1. **Setup**: `./scripts/setup-github-actions-azure.sh` (one-time)
2. **Deploy**: Use [GitHub Actions](https://github.com/cmcconnell1/azure-webapp-demo/actions) → "Azure WebApp Demo - Deploy"
3. **Cleanup**: Use [GitHub Actions](https://github.com/cmcconnell1/azure-webapp-demo/actions) → "Azure WebApp Demo - Cleanup"

**Alternative Commands (Local)**:
```bash
./scripts/deploy-github.sh   # Trigger GitHub Actions from CLI
./scripts/deploy.sh          # Local deployment (requires setup)
./scripts/cost-monitor.sh    # Monitor costs
./scripts/cleanup.sh         # Clean up resources
```

