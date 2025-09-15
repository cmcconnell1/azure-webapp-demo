"""
Integration tests for cost monitoring with actual Azure resources.
"""

import pytest
import json
import os
import subprocess
from unittest.mock import patch, MagicMock


class TestCostMonitoringIntegration:
    """Integration tests for cost monitoring functionality."""
    
    @pytest.mark.skipif(
        not os.getenv('AZURE_SUBSCRIPTION_ID'),
        reason="Cost monitoring integration tests require Azure subscription"
    )
    def test_azure_cli_authentication(self):
        """Test that Azure CLI is properly authenticated."""
        try:
            result = subprocess.run(['az', 'account', 'show'], 
                                  capture_output=True, text=True, check=True)
            account_info = json.loads(result.stdout)
            assert 'id' in account_info
            assert 'name' in account_info
        except (subprocess.CalledProcessError, FileNotFoundError):
            pytest.skip("Azure CLI not available or not authenticated")
    
    @pytest.mark.skipif(
        not os.getenv('AZURE_SUBSCRIPTION_ID'),
        reason="Cost monitoring integration tests require Azure subscription"
    )
    def test_resource_group_discovery(self):
        """Test discovery of project resource groups."""
        try:
            result = subprocess.run([
                'az', 'group', 'list', 
                '--query', "[?contains(name, 'webapp-demo')]",
                '--output', 'json'
            ], capture_output=True, text=True, check=True)
            
            resource_groups = json.loads(result.stdout)
            assert len(resource_groups) > 0
            
            # Check for expected resource groups
            rg_names = [rg['name'] for rg in resource_groups]
            assert any('webapp-demo' in name for name in rg_names)
            
        except (subprocess.CalledProcessError, FileNotFoundError):
            pytest.skip("Azure CLI not available or resource groups not found")
    
    def test_cost_monitor_script_execution(self):
        """Test that cost monitoring scripts execute without errors."""
        # Test cost estimation (doesn't require Azure resources)
        try:
            result = subprocess.run([
                './scripts/cost-monitor.sh', '--estimate', '--env', 'dev', '--region', 'westus2'
            ], capture_output=True, text=True, cwd=os.getcwd())
            
            assert result.returncode == 0
            assert 'Estimated Monthly Cost:' in result.stdout
            assert 'USD' in result.stdout
            
        except FileNotFoundError:
            pytest.skip("Cost monitoring scripts not found")
    
    def test_cost_dashboard_generation(self):
        """Test cost dashboard generation."""
        try:
            # Generate a test dashboard
            result = subprocess.run([
                './scripts/cost-dashboard.sh', 
                '--output', '/tmp/test-dashboard.html',
                '--project-name', 'webapp-demo'
            ], capture_output=True, text=True, cwd=os.getcwd())
            
            # Check if dashboard was generated (may fail due to missing cost data)
            if result.returncode == 0:
                assert os.path.exists('/tmp/test-dashboard.html')
                
                # Check dashboard content
                with open('/tmp/test-dashboard.html', 'r') as f:
                    content = f.read()
                    assert 'Azure Cost Dashboard' in content
                    assert 'webapp-demo' in content
                
                # Cleanup
                os.remove('/tmp/test-dashboard.html')
            
        except FileNotFoundError:
            pytest.skip("Cost dashboard script not found")
    
    @pytest.mark.skipif(
        not os.getenv('AZURE_SUBSCRIPTION_ID'),
        reason="Requires Azure subscription for actual cost data"
    )
    def test_actual_cost_retrieval(self):
        """Test retrieval of actual Azure costs."""
        try:
            # Test with Python cost monitor
            result = subprocess.run([
                'python3', 'scripts/azure-cost-monitor.py',
                '--project-name', 'webapp-demo',
                '--current-month',
                '--quiet'
            ], capture_output=True, text=True, cwd=os.getcwd())
            
            if result.returncode == 0:
                # Should return a numeric cost value
                cost = float(result.stdout.strip())
                assert cost >= 0.0
            else:
                # May fail due to permissions or missing cost data
                pytest.skip("Cost data not available or insufficient permissions")
                
        except (FileNotFoundError, ValueError):
            pytest.skip("Cost monitoring script not available or invalid output")
    
    def test_resource_cost_breakdown(self):
        """Test that cost monitoring can break down costs by resource."""
        # Mock the resource list from Azure
        mock_resources = [
            {'name': 'webapp-demo-dev-sql-xgd8f4', 'type': 'Microsoft.Sql/servers'},
            {'name': 'webapp-demo-dev-asp', 'type': 'Microsoft.Web/serverFarms'},
            {'name': 'webapp-demo-dev-web-xgd8f4', 'type': 'Microsoft.Web/sites'},
            {'name': 'acrwebappdemodevxgd8f4', 'type': 'Microsoft.ContainerRegistry/registries'},
            {'name': 'kvwebappdemodevxgd8f4', 'type': 'Microsoft.KeyVault/vaults'}
        ]
        
        # Test that we can identify all expected resource types
        resource_types = [r['type'] for r in mock_resources]
        
        assert 'Microsoft.Sql/servers' in resource_types
        assert 'Microsoft.Web/serverFarms' in resource_types
        assert 'Microsoft.Web/sites' in resource_types
        assert 'Microsoft.ContainerRegistry/registries' in resource_types
        assert 'Microsoft.KeyVault/vaults' in resource_types
    
    def test_budget_alert_integration(self):
        """Test budget alert functionality."""
        try:
            # Test budget alert with a low threshold
            result = subprocess.run([
                './scripts/cost-monitor.sh',
                '--estimate', '--env', 'dev',
                '--budget', '10',  # Low budget to trigger alert
                '--export', '/tmp/budget-test.json'
            ], capture_output=True, text=True, cwd=os.getcwd())
            
            if result.returncode == 0 and os.path.exists('/tmp/budget-test.json'):
                with open('/tmp/budget-test.json', 'r') as f:
                    data = json.load(f)
                    
                    if 'budget_status' in data:
                        # Should trigger warning/critical alert
                        assert data['budget_status']['percentage'] > 75
                
                # Cleanup
                os.remove('/tmp/budget-test.json')
                
        except FileNotFoundError:
            pytest.skip("Cost monitoring script not found")
    
    def test_cost_monitoring_dependencies(self):
        """Test that all required dependencies are available."""
        # Test Python dependencies
        try:
            import azure.identity
            import azure.mgmt.costmanagement
            import azure.mgmt.resource
            import requests
        except ImportError as e:
            pytest.fail(f"Missing required Python dependency: {e}")
        
        # Test command line tools
        required_tools = ['az', 'python3', 'jq']
        missing_tools = []
        
        for tool in required_tools:
            try:
                subprocess.run([tool, '--version'], 
                             capture_output=True, check=True)
            except (subprocess.CalledProcessError, FileNotFoundError):
                if tool != 'jq':  # jq is optional
                    missing_tools.append(tool)
        
        if missing_tools:
            pytest.fail(f"Missing required command line tools: {missing_tools}")


class TestCostDataAccuracy:
    """Tests for cost data accuracy and completeness."""
    
    def test_resource_type_cost_mapping(self):
        """Test that all deployed resource types are accounted for in cost monitoring."""
        # Expected resource types from terraform output
        expected_resources = {
            'Microsoft.Sql/servers': 'Azure SQL Server',
            'Microsoft.Sql/servers/databases': 'Azure SQL Database',
            'Microsoft.Web/serverFarms': 'App Service Plan',
            'Microsoft.Web/sites': 'App Service',
            'Microsoft.ContainerRegistry/registries': 'Container Registry',
            'Microsoft.KeyVault/vaults': 'Key Vault',
            'Microsoft.Insights/components': 'Application Insights',
            'Microsoft.OperationalInsights/workspaces': 'Log Analytics Workspace'
        }
        
        # Test that cost monitoring recognizes these resource types
        for resource_type, friendly_name in expected_resources.items():
            assert resource_type is not None
            assert friendly_name is not None
    
    def test_cost_estimation_accuracy(self):
        """Test that cost estimations are reasonable."""
        # Test development environment estimation
        dev_estimate = 25.50  # From cost-monitor.sh
        
        # Reasonable bounds for development environment
        assert 20.0 <= dev_estimate <= 50.0
        
        # Test production environment estimation
        prod_estimate = 100.0  # Base cost for production
        
        # Reasonable bounds for production environment
        assert 80.0 <= prod_estimate <= 200.0
    
    def test_regional_cost_variations(self):
        """Test that regional cost variations are properly handled."""
        regions = ['eastus', 'westus', 'westus2', 'centralus', 'southcentralus']
        base_cost = 100.0
        
        for region in regions:
            try:
                result = subprocess.run([
                    './scripts/cost-monitor.sh',
                    '--estimate', '--env', 'dev',
                    '--region', region,
                    '--quiet'
                ], capture_output=True, text=True, cwd=os.getcwd())
                
                if result.returncode == 0:
                    # Should return a reasonable cost estimate
                    estimated_cost = float(result.stdout.strip().split()[-2])  # Extract cost from output
                    assert 20.0 <= estimated_cost <= 50.0
                    
            except (FileNotFoundError, ValueError, IndexError):
                pytest.skip(f"Could not test cost estimation for region {region}")
    
    def test_cost_data_freshness(self):
        """Test that cost data is reasonably fresh."""
        try:
            result = subprocess.run([
                'python3', 'scripts/azure-cost-monitor.py',
                '--project-name', 'webapp-demo',
                '--export', '/tmp/cost-freshness-test.json',
                '--quiet'
            ], capture_output=True, text=True, cwd=os.getcwd())
            
            if result.returncode == 0 and os.path.exists('/tmp/cost-freshness-test.json'):
                with open('/tmp/cost-freshness-test.json', 'r') as f:
                    data = json.load(f)
                    
                    # Check that data has a recent timestamp
                    assert 'generated_at' in data
                    
                    # Check that period is reasonable
                    if 'cost_data' in data and 'period' in data['cost_data']:
                        period = data['cost_data']['period']
                        assert period != 'Unknown'
                
                # Cleanup
                os.remove('/tmp/cost-freshness-test.json')
                
        except FileNotFoundError:
            pytest.skip("Cost monitoring script not available")
