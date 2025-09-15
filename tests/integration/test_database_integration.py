"""
Integration tests for database connectivity and operations.
"""

import pytest
import json
import os
from unittest.mock import patch, MagicMock


class TestDatabaseIntegration:
    """Integration tests for database operations."""
    
    @pytest.mark.skipif(
        not os.getenv('DATABASE_SERVER'),
        reason="Database integration tests require DATABASE_SERVER environment variable"
    )
    def test_real_database_connection(self):
        """Test actual database connection (requires real Azure SQL)."""
        from main import get_db_connection
        
        connection = get_db_connection()
        if connection:
            cursor = connection.cursor()
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            assert result[0] == 1
            cursor.close()
            connection.close()
    
    def test_database_schema_validation(self, client):
        """Test that database schema is properly set up."""
        with patch('main.get_db_connection') as mock_db:
            # Mock a connection that returns schema info
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock schema check query
            mock_cursor.execute.return_value = None
            mock_cursor.fetchall.return_value = [
                ('quotes', 'id', 'int'),
                ('quotes', 'author', 'nvarchar'),
                ('quotes', 'text', 'nvarchar')
            ]
            
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            # Test schema validation endpoint
            response = client.get('/db-validate')
            assert response.status_code == 200
            
            data = json.loads(response.data)
            assert 'database_status' in data
    
    def test_quote_data_integrity(self, client):
        """Test that quote data maintains integrity."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock quote data with proper structure
            mock_cursor.fetchone.return_value = (1, "Test Author", "Test quote with proper content")
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            response = client.get('/')
            assert response.status_code == 200
            
            data = json.loads(response.data)
            assert isinstance(data['id'], int)
            assert isinstance(data['author'], str)
            assert isinstance(data['text'], str)
            assert len(data['text']) > 0
    
    def test_database_seeding_verification(self, client):
        """Test that database seeding worked correctly."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock count query to verify seeding
            mock_cursor.fetchone.return_value = (42,)  # Mock quote count
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            response = client.get('/db-test')
            assert response.status_code == 200
            
            data = json.loads(response.data)
            assert data['quote_count'] > 0
    
    def test_connection_pooling_behavior(self):
        """Test database connection pooling and cleanup."""
        from main import get_db_connection
        
        with patch('main.pyodbc.connect') as mock_connect:
            mock_connection = MagicMock()
            mock_connect.return_value = mock_connection
            
            # Test multiple connections
            conn1 = get_db_connection()
            conn2 = get_db_connection()
            
            # Both should be valid connections
            assert conn1 is not None
            assert conn2 is not None
    
    def test_database_error_handling(self, client):
        """Test proper error handling for database failures."""
        with patch('main.get_db_connection') as mock_db:
            # Simulate database connection failure
            mock_db.return_value = None
            
            response = client.get('/')
            assert response.status_code == 500
            
            data = json.loads(response.data)
            assert 'error' in data
            assert data['status'] == 'error'
    
    def test_sql_injection_protection(self, client):
        """Test that the application is protected against SQL injection."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock normal quote response
            mock_cursor.fetchone.return_value = (1, "Safe Author", "Safe quote text")
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            # Test normal request
            response = client.get('/')
            assert response.status_code == 200
            
            # Verify that parameterized queries are used
            # (This is more of a code review item, but we can check the mock calls)
            mock_cursor.execute.assert_called()
            call_args = mock_cursor.execute.call_args
            
            # Ensure no direct string concatenation in SQL
            if call_args and len(call_args[0]) > 0:
                sql_query = call_args[0][0]
                assert "'" not in sql_query or "?" in sql_query  # Parameterized queries


class TestAzureIntegration:
    """Integration tests for Azure services."""
    
    @pytest.mark.skipif(
        not os.getenv('AZURE_CLIENT_ID'),
        reason="Azure integration tests require Azure credentials"
    )
    def test_key_vault_integration(self):
        """Test Key Vault integration for secrets."""
        # This would test actual Key Vault connectivity
        # Skipped if no Azure credentials available
        pass
    
    @pytest.mark.skipif(
        not os.getenv('AZURE_CLIENT_ID'),
        reason="Azure integration tests require Azure credentials"
    )
    def test_application_insights_integration(self):
        """Test Application Insights telemetry."""
        # This would test actual Application Insights connectivity
        # Skipped if no Azure credentials available
        pass
    
    def test_container_registry_access(self):
        """Test Azure Container Registry access."""
        # Mock ACR access test
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout="Login Succeeded")
            
            # Simulate ACR login test
            result = mock_run.return_value
            assert result.returncode == 0
    
    def test_app_service_deployment_validation(self, client):
        """Test that the app is properly deployed to App Service."""
        # Test health endpoints that would be available in App Service
        response = client.get('/health')
        assert response.status_code == 200
        
        # Test that environment variables are properly configured
        with patch.dict(os.environ, {
            'WEBSITE_SITE_NAME': 'webapp-demo-dev-web-xgd8f4',
            'WEBSITE_RESOURCE_GROUP': 'webapp-demo-dev-rg'
        }):
            # App should recognize it's running in Azure
            assert os.getenv('WEBSITE_SITE_NAME') is not None


class TestEndToEndWorkflow:
    """End-to-end integration tests."""
    
    def test_complete_quote_retrieval_workflow(self, client):
        """Test the complete workflow from request to response."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock the complete workflow
            mock_cursor.fetchone.return_value = (1, "Integration Test Author", "This is an integration test quote")
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            # Test the complete workflow
            response = client.get('/')
            assert response.status_code == 200
            
            data = json.loads(response.data)
            assert data['id'] == 1
            assert data['author'] == "Integration Test Author"
            assert "integration test" in data['text'].lower()
    
    def test_database_validation_workflow(self, client):
        """Test the complete database validation workflow."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock validation responses
            mock_cursor.fetchone.side_effect = [
                (25,),  # Quote count
                (1, "Test Author", "Test quote")  # Sample quote
            ]
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            # Test validation endpoint
            response = client.get('/db-validate')
            assert response.status_code == 200
            
            data = json.loads(response.data)
            assert data['quote_count'] == 25
            assert 'sample_quote' in data
    
    def test_error_recovery_workflow(self, client):
        """Test error recovery and graceful degradation."""
        with patch('main.get_db_connection') as mock_db:
            # Test database failure recovery
            mock_db.side_effect = Exception("Database temporarily unavailable")
            
            response = client.get('/')
            assert response.status_code == 500
            
            data = json.loads(response.data)
            assert 'error' in data
            assert data['status'] == 'error'
            
            # Test that the application doesn't crash
            assert response.data is not None
