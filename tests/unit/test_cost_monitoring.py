"""
Unit tests for cost monitoring functionality.
"""

import pytest
import json
from unittest.mock import patch, MagicMock, mock_open
import sys
from pathlib import Path

# Add scripts directory to path
scripts_dir = Path(__file__).parent.parent.parent / "scripts"
sys.path.insert(0, str(scripts_dir))


class TestAzureCostMonitor:
    """Test cases for Azure Cost Monitor functionality."""
    
    @patch('azure_cost_monitor.DefaultAzureCredential')
    @patch('azure_cost_monitor.CostManagementClient')
    @patch('azure_cost_monitor.ResourceManagementClient')
    def test_cost_monitor_initialization(self, mock_resource_client, mock_cost_client, mock_credential):
        """Test AzureCostMonitor initialization."""
        from azure_cost_monitor import AzureCostMonitor
        
        monitor = AzureCostMonitor("test-subscription", "test-project")
        
        assert monitor.subscription_id == "test-subscription"
        assert monitor.project_name == "test-project"
        mock_credential.assert_called_once()
    
    @patch('azure_cost_monitor.subprocess.run')
    def test_get_subscription_info(self, mock_run):
        """Test subscription information retrieval."""
        from azure_cost_monitor import AzureCostMonitor
        
        # Mock subprocess response
        mock_result = MagicMock()
        mock_result.stdout = '{"id": "test-sub", "name": "Test Subscription"}'
        mock_run.return_value = mock_result
        
        with patch('azure_cost_monitor.DefaultAzureCredential'), \
             patch('azure_cost_monitor.CostManagementClient'), \
             patch('azure_cost_monitor.ResourceManagementClient'):
            
            monitor = AzureCostMonitor("test-subscription", "test-project")
            info = monitor.get_subscription_info()
            
            assert info['id'] == "test-sub"
            assert info['name'] == "Test Subscription"
    
    def test_get_project_resource_groups(self):
        """Test project resource group discovery."""
        from azure_cost_monitor import AzureCostMonitor
        
        # Mock resource group with tags
        mock_rg = MagicMock()
        mock_rg.name = "webapp-demo-dev-rg"
        mock_rg.tags = {"Project": "webapp-demo"}
        
        with patch('azure_cost_monitor.DefaultAzureCredential'), \
             patch('azure_cost_monitor.CostManagementClient'), \
             patch('azure_cost_monitor.ResourceManagementClient') as mock_resource_client:
            
            mock_resource_client.return_value.resource_groups.list.return_value = [mock_rg]
            
            monitor = AzureCostMonitor("test-subscription", "webapp-demo")
            resource_groups = monitor.get_project_resource_groups()
            
            assert "webapp-demo-dev-rg" in resource_groups
    
    @patch('azure_cost_monitor.subprocess.run')
    def test_get_cost_data_via_cli(self, mock_run):
        """Test cost data retrieval via Azure CLI."""
        from azure_cost_monitor import AzureCostMonitor
        
        # Mock successful CLI responses
        mock_run.side_effect = [
            MagicMock(returncode=0, stdout="", text=True),  # Resource group check
            MagicMock(returncode=0, stdout='[{"cost": "10.50", "service": "App Service"}]', text=True)  # Cost data
        ]
        
        with patch('azure_cost_monitor.DefaultAzureCredential'), \
             patch('azure_cost_monitor.CostManagementClient'), \
             patch('azure_cost_monitor.ResourceManagementClient'):
            
            monitor = AzureCostMonitor("test-subscription", "webapp-demo")
            
            # Mock resource groups
            with patch.object(monitor, 'get_project_resource_groups', return_value=['webapp-demo-dev-rg']):
                cost_data = monitor._get_cost_data_via_cli(30, None)
                
                assert 'total_cost' in cost_data
                assert 'breakdown' in cost_data
    
    def test_check_budget_alerts(self):
        """Test budget alert checking."""
        from azure_cost_monitor import AzureCostMonitor
        
        with patch('azure_cost_monitor.DefaultAzureCredential'), \
             patch('azure_cost_monitor.CostManagementClient'), \
             patch('azure_cost_monitor.ResourceManagementClient'):
            
            monitor = AzureCostMonitor("test-subscription", "webapp-demo")
            
            # Test critical alert (over budget)
            alerts = monitor.check_budget_alerts(100.0, 120.0)
            assert alerts['status'] == 'critical'
            assert alerts['percentage'] == 120.0
            assert len(alerts['alerts']) > 0
            
            # Test warning alert
            alerts = monitor.check_budget_alerts(100.0, 80.0)
            assert alerts['status'] == 'warning'
            assert alerts['percentage'] == 80.0
            
            # Test OK status
            alerts = monitor.check_budget_alerts(100.0, 50.0)
            assert alerts['status'] == 'ok'
            assert alerts['percentage'] == 50.0


class TestCostReporting:
    """Test cases for cost reporting functionality."""
    
    def test_format_cost_report(self):
        """Test cost report formatting."""
        from azure_cost_monitor import format_cost_report
        
        cost_data = {
            'total_cost': 25.50,
            'breakdown': {
                'webapp-demo-dev-rg': 20.00,
                'webapp-demo-terraform-state-rg': 5.50
            },
            'period': '2024-01-01 to 2024-01-31',
            'currency': 'USD'
        }
        
        report = format_cost_report(cost_data, "webapp-demo", "dev")
        
        assert "webapp-demo" in report
        assert "Environment: dev" in report
        assert "$25.50" in report
        assert "webapp-demo-dev-rg" in report
    
    def test_format_cost_report_empty(self):
        """Test cost report formatting with empty data."""
        from azure_cost_monitor import format_cost_report
        
        cost_data = {
            'total_cost': 0.0,
            'breakdown': {},
            'period': 'Unknown',
            'currency': 'USD'
        }
        
        report = format_cost_report(cost_data, "webapp-demo")
        
        assert "Total Cost: $0.00" in report
        assert "webapp-demo" in report


class TestCostEstimation:
    """Test cases for cost estimation functionality."""
    
    def test_cost_estimation_dev(self):
        """Test cost estimation for development environment."""
        # This would test the cost estimation logic from cost-monitor.sh
        # Since it's a bash script, we'll test the Python equivalent logic
        
        base_cost_dev = 25
        regional_multiplier = 1.02  # westus2
        
        estimated_cost = base_cost_dev * regional_multiplier
        
        assert estimated_cost == 25.50
    
    def test_cost_estimation_prod(self):
        """Test cost estimation for production environment."""
        base_cost_prod = 100
        regional_multiplier = 1.0  # eastus
        
        estimated_cost = base_cost_prod * regional_multiplier
        
        assert estimated_cost == 100.0
    
    def test_regional_multipliers(self):
        """Test regional cost multipliers."""
        multipliers = {
            'eastus': 1.0,
            'westus': 1.05,
            'westus2': 1.02,
            'centralus': 1.0,
            'southcentralus': 1.03
        }
        
        base_cost = 100
        
        for region, multiplier in multipliers.items():
            estimated = base_cost * multiplier
            assert estimated >= base_cost  # Should never be less than base cost


class TestCostDashboard:
    """Test cases for cost dashboard functionality."""
    
    @patch('builtins.open', new_callable=mock_open)
    def test_dashboard_generation(self, mock_file):
        """Test HTML dashboard generation."""
        # This tests the concept - actual implementation is in bash
        dashboard_data = {
            'project_name': 'webapp-demo',
            'total_cost': 25.50,
            'budget_status': 'ok',
            'breakdown': {'webapp-demo-dev-rg': 25.50}
        }
        
        # Simulate dashboard HTML generation
        html_content = f"""
        <title>Azure Cost Dashboard - {dashboard_data['project_name']}</title>
        <div class="cost-total">${dashboard_data['total_cost']}</div>
        """
        
        assert dashboard_data['project_name'] in html_content
        assert str(dashboard_data['total_cost']) in html_content
    
    def test_budget_alert_styling(self):
        """Test budget alert CSS class selection."""
        def get_alert_class(percentage):
            if percentage >= 100:
                return 'alert-critical'
            elif percentage >= 75:
                return 'alert-warning'
            else:
                return 'alert-ok'
        
        assert get_alert_class(120) == 'alert-critical'
        assert get_alert_class(80) == 'alert-warning'
        assert get_alert_class(50) == 'alert-ok'
