# Azure Cost Monitoring for Web Application Demo

## Overview

This project includes comprehensive Azure cost monitoring tools to track infrastructure spending and ensure budget compliance. The cost monitoring system provides real-time cost analysis, budget alerts, and visual dashboards.

## Cost Monitoring Tools

### 1. Azure Cost Monitor (`scripts/azure-cost-monitor.py`)

Python script that provides detailed cost analysis using Azure Cost Management APIs.

**Features:**
- Real-time cost analysis using Azure Cost Management API
- Project-specific cost filtering using resource groups
- Environment-based cost breakdown (dev, staging, prod)
- Budget alerts and threshold monitoring
- Export capabilities for reporting and analysis

**Usage:**
```bash
# Current month costs
python3 scripts/azure-cost-monitor.py --project-name webapp-demo

# Specific environment
python3 scripts/azure-cost-monitor.py --environment dev --days 30

# With budget alerts
python3 scripts/azure-cost-monitor.py --budget-alert 100 --current-month

# Export to JSON
python3 scripts/azure-cost-monitor.py --export cost-report.json --quiet
```

### 2. Cost Dashboard (`scripts/cost-dashboard.sh`)

Generates an HTML dashboard for visual cost monitoring with auto-refresh capabilities.

**Features:**
- Real-time cost monitoring dashboard
- Auto-refresh capabilities (configurable interval)
- Budget alert visualization
- Cost breakdown charts by resource group
- Quick actions and Azure Portal integration

**Usage:**
```bash
# Generate static dashboard
./scripts/cost-dashboard.sh --project-name webapp-demo --output dashboard.html

# Serve live dashboard
./scripts/cost-dashboard.sh --serve --port 8080 --budget 100

# With custom refresh interval
./scripts/cost-dashboard.sh --serve --refresh 180 --budget 50
```

### 3. Unified Cost Monitor (`scripts/cost-monitor.sh`)

Comprehensive cost monitoring script that combines estimation, actual costs, and dashboard generation.

**Features:**
- Cost estimation using Azure pricing data
- Actual billing cost monitoring
- Budget alerts and threshold monitoring
- Automated scheduling with cron jobs
- Webhook notifications (Slack, Teams, etc.)
- Dashboard generation and serving

**Usage:**
```bash
# Current month actual costs
./scripts/cost-monitor.sh

# Cost estimation
./scripts/cost-monitor.sh --estimate --env dev --region westus2

# Generate dashboard
./scripts/cost-monitor.sh --dashboard --serve --port 8080

# Set up daily monitoring with alerts
./scripts/cost-monitor.sh --schedule daily --budget 50

# With webhook notifications
./scripts/cost-monitor.sh --budget 100 --webhook https://hooks.slack.com/...
```

## Cost Estimates

### Monthly Cost Estimates by Environment

| Environment | Estimated Monthly Cost (USD) | Components |
|-------------|------------------------------|------------|
| **Development** | $25-30 | App Service (B1), SQL Basic, Key Vault, ACR |
| **Staging** | $50-60 | App Service (S1), SQL Standard, enhanced monitoring |
| **Production** | $100-150 | App Service (P1), SQL Standard, geo-redundancy |

### Cost Breakdown by Service

**Development Environment (~$25/month):**
- App Service (B1): $12.50 (50%)
- Azure SQL Database (Basic): $7.50 (30%)
- Application Insights: $2.50 (10%)
- Key Vault: $1.25 (5%)
- Container Registry: $1.25 (5%)

**Production Environment (~$100/month):**
- App Service (P1): $50.00 (50%)
- Azure SQL Database (Standard): $30.00 (30%)
- Application Insights: $10.00 (10%)
- Key Vault: $2.50 (2.5%)
- Container Registry: $2.50 (2.5%)
- Additional monitoring/backup: $5.00 (5%)

## Budget Management

### Recommended Budget Thresholds

- **Development**: $30/month budget with 75% warning threshold
- **Staging**: $60/month budget with 80% warning threshold  
- **Production**: $150/month budget with 85% warning threshold

### Budget Alert Configuration

```bash
# Set up budget monitoring for development
./scripts/cost-monitor.sh --env dev --budget 30 --schedule daily

# Production with Slack notifications
./scripts/cost-monitor.sh --env prod --budget 150 --webhook $SLACK_WEBHOOK --schedule weekly
```

## Automated Monitoring

### Cron Job Setup

The cost monitor can automatically set up scheduled monitoring:

```bash
# Daily cost monitoring at 9 AM
./scripts/cost-monitor.sh --schedule daily --budget 100

# Weekly reports every Monday
./scripts/cost-monitor.sh --schedule weekly --budget 300 --webhook $WEBHOOK_URL

# Monthly summary on 1st of each month
./scripts/cost-monitor.sh --schedule monthly --budget 500
```

### Webhook Notifications

Supports webhook notifications for budget alerts:

```bash
# Slack webhook
export SLACK_WEBHOOK="https://hooks.slack.com/services/..."
./scripts/cost-monitor.sh --webhook $SLACK_WEBHOOK --budget 100

# Microsoft Teams webhook
export TEAMS_WEBHOOK="https://outlook.office.com/webhook/..."
./scripts/cost-monitor.sh --webhook $TEAMS_WEBHOOK --budget 100
```

## Prerequisites

### Quick Setup

```bash
# Automated setup (recommended)
./scripts/setup-cost-monitoring.sh

# Or with virtual environment
./scripts/setup-cost-monitoring.sh --venv

# Check installation status
./scripts/setup-cost-monitoring.sh --check
```

### Manual Installation

```bash
# Install Python dependencies
pip install -r requirements-cost-monitoring.txt

# Or install individual packages
pip install azure-mgmt-costmanagement azure-identity azure-mgmt-resource requests

# Or use the cost monitor installer
./scripts/cost-monitor.sh --install-deps
```

### Azure CLI Authentication

```bash
# Login to Azure
az login

# Verify subscription access
az account show
```

### Required Permissions

The Azure account needs the following permissions:
- **Cost Management Reader** role on the subscription
- **Reader** role on resource groups
- Access to Azure Cost Management APIs

## Integration with CI/CD

### GitHub Actions Integration

Add cost monitoring to your GitHub Actions workflows:

```yaml
- name: Monitor Azure Costs
  run: |
    ./scripts/cost-monitor.sh --quiet --budget 100 --export cost-report.json
    
- name: Upload Cost Report
  uses: actions/upload-artifact@v3
  with:
    name: cost-report
    path: cost-report.json
```

### Cost Alerts in Pull Requests

```yaml
- name: Cost Impact Analysis
  run: |
    # Get current costs
    CURRENT_COST=$(./scripts/cost-monitor.sh --quiet)
    echo "Current monthly cost: $CURRENT_COST USD" >> $GITHUB_STEP_SUMMARY
    
    # Check budget compliance
    if (( $(echo "$CURRENT_COST > 100" | bc -l) )); then
      echo "WARNING: Costs exceed budget threshold" >> $GITHUB_STEP_SUMMARY
    fi
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Ensure `az login` is completed and subscription access is available
2. **Missing Permissions**: Verify Cost Management Reader role is assigned
3. **No Cost Data**: Check that resources exist and have generated billing data
4. **Dashboard Not Loading**: Verify Python 3 is available and jq is installed for JSON parsing

### Debug Commands

```bash
# Test Azure CLI access
az account show

# Check resource groups
az group list --query "[?contains(name, 'webapp-demo')]"

# Verify cost data availability
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31 --top 5

# Test cost monitor in debug mode
python3 scripts/azure-cost-monitor.py --project-name webapp-demo --current-month
```

## Cost Optimization Tips

1. **Right-size Resources**: Use B1 App Service for development, scale up only when needed
2. **SQL Database Tiers**: Use Basic tier for development, Standard for production
3. **Monitor Data Transfer**: Keep resources in the same region to minimize egress costs
4. **Clean Up Resources**: Use `./scripts/dev-down.sh --force` to remove unused environments
5. **Reserved Instances**: Consider reserved capacity for long-running production workloads

## Reporting and Analytics

### Export Options

```bash
# JSON export for analysis
./scripts/cost-monitor.sh --export monthly-costs.json --current-month

# CSV format (via jq)
./scripts/cost-monitor.py --export costs.json --quiet
cat costs.json | jq -r '.cost_data.breakdown | to_entries[] | [.key, .value] | @csv'

# Dashboard for stakeholders
./scripts/cost-dashboard.sh --output stakeholder-dashboard.html --budget 200
```

### Integration with BI Tools

The JSON export format is compatible with:
- Power BI (via JSON connector)
- Tableau (via JSON import)
- Excel (via Power Query)
- Custom analytics tools
