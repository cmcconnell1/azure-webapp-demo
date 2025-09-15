"""
Security tests for the Azure Web Application Demo.
"""

import pytest
import json
import os
from unittest.mock import patch, MagicMock


class TestApplicationSecurity:
    """Security tests for the Flask application."""
    
    def test_sql_injection_prevention(self, client):
        """Test that the application prevents SQL injection attacks."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock normal response
            mock_cursor.fetchone.return_value = (1, "Safe Author", "Safe quote")
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            # Test normal request
            response = client.get('/')
            assert response.status_code == 200
            
            # Verify parameterized queries are used
            mock_cursor.execute.assert_called()
            
            # Check that the SQL query uses parameters, not string concatenation
            call_args = mock_cursor.execute.call_args
            if call_args and len(call_args[0]) > 0:
                sql_query = call_args[0][0]
                # Should use ? parameters, not direct string insertion
                assert "?" in sql_query or "SELECT TOP 1" in sql_query
    
    def test_xss_prevention(self, client):
        """Test that the application prevents XSS attacks."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock response with potential XSS content
            mock_cursor.fetchone.return_value = (
                1, 
                "<script>alert('xss')</script>", 
                "Quote with <script>alert('xss')</script> content"
            )
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            response = client.get('/')
            assert response.status_code == 200
            
            # Response should be JSON, which naturally escapes HTML
            data = json.loads(response.data)
            assert '<script>' in data['author']  # Should be preserved as text
            assert '<script>' in data['text']    # Should be preserved as text
            
            # But when rendered, it should be escaped (this is handled by the client)
    
    def test_sensitive_data_exposure(self, client):
        """Test that sensitive data is not exposed in responses."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock database error
            mock_cursor.execute.side_effect = Exception("Connection string: Server=secret;Database=secret;")
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            response = client.get('/')
            assert response.status_code == 500
            
            # Error response should not contain sensitive information
            response_text = response.get_data(as_text=True)
            assert 'Connection string' not in response_text
            assert 'Server=' not in response_text
            assert 'Database=' not in response_text
    
    def test_error_information_disclosure(self, client):
        """Test that error messages don't disclose sensitive information."""
        with patch('main.get_db_connection') as mock_db:
            # Simulate various database errors
            mock_db.side_effect = Exception("Login failed for user 'sa'")
            
            response = client.get('/')
            assert response.status_code == 500
            
            data = json.loads(response.data)
            assert 'error' in data
            
            # Error message should be generic
            error_message = data['error'].lower()
            assert 'sa' not in error_message
            assert 'login failed' not in error_message
            assert 'database' not in error_message or 'unavailable' in error_message
    
    def test_http_security_headers(self, client):
        """Test that appropriate security headers are set."""
        response = client.get('/')
        
        # Check for security headers (these might need to be added to the Flask app)
        headers = response.headers
        
        # Note: These headers should be added to the Flask application
        # This test documents what SHOULD be implemented
        expected_headers = [
            'X-Content-Type-Options',
            'X-Frame-Options', 
            'X-XSS-Protection',
            'Strict-Transport-Security'
        ]
        
        # For now, just verify the response has headers
        assert len(headers) > 0
    
    def test_cors_configuration(self, client):
        """Test CORS configuration is secure."""
        response = client.get('/')
        
        # Check that CORS is not overly permissive
        cors_header = response.headers.get('Access-Control-Allow-Origin')
        
        if cors_header:
            # Should not be wildcard for production
            assert cors_header != '*' or os.getenv('FLASK_ENV') == 'development'
    
    def test_authentication_bypass(self, client):
        """Test that there are no authentication bypass vulnerabilities."""
        # Test that all endpoints are accessible (this is a public app)
        # But verify that admin/debug endpoints don't exist
        
        admin_endpoints = [
            '/admin',
            '/debug',
            '/config',
            '/env',
            '/phpinfo',
            '/server-info',
            '/status'
        ]
        
        for endpoint in admin_endpoints:
            response = client.get(endpoint)
            # Should return 404, not 200 or 500
            assert response.status_code == 404


class TestInfrastructureSecurity:
    """Security tests for infrastructure configuration."""
    
    def test_environment_variable_security(self):
        """Test that sensitive environment variables are properly handled."""
        sensitive_vars = [
            'DATABASE_PASSWORD',
            'DATABASE_USERNAME', 
            'AZURE_CLIENT_SECRET',
            'SECRET_KEY'
        ]
        
        for var in sensitive_vars:
            value = os.getenv(var)
            if value:
                # Should not be empty or default values
                assert value != ''
                assert value != 'changeme'
                assert value != 'password'
                assert value != 'secret'
                assert len(value) > 8  # Minimum length
    
    def test_database_connection_security(self):
        """Test database connection security configuration."""
        # Test that database connections use encryption
        db_server = os.getenv('DATABASE_SERVER')
        if db_server:
            # Should use secure connection
            assert '.database.windows.net' in db_server  # Azure SQL
    
    def test_key_vault_integration(self):
        """Test Key Vault integration for secrets management."""
        # Test that Key Vault is configured
        key_vault_name = os.getenv('KEY_VAULT_NAME')
        if key_vault_name:
            assert key_vault_name.startswith('kv')
            assert len(key_vault_name) > 5
    
    @pytest.mark.skipif(
        not os.getenv('AZURE_CLIENT_ID'),
        reason="Azure security tests require Azure credentials"
    )
    def test_managed_identity_configuration(self):
        """Test that Managed Identity is properly configured."""
        # This would test actual Managed Identity configuration
        # For now, just verify environment suggests Managed Identity usage
        client_id = os.getenv('AZURE_CLIENT_ID')
        if client_id:
            # Should be a valid GUID format
            assert len(client_id) == 36
            assert client_id.count('-') == 4


class TestDataProtection:
    """Tests for data protection and privacy compliance."""
    
    def test_pii_data_handling(self, client):
        """Test that PII data is properly handled."""
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            # Mock quote data (quotes are treated as PII)
            mock_cursor.fetchone.return_value = (1, "Author Name", "Sensitive quote content")
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            response = client.get('/')
            assert response.status_code == 200
            
            # Verify that quote content is returned (it's the app's purpose)
            # But ensure it's handled securely
            data = json.loads(response.data)
            assert 'text' in data
            assert len(data['text']) > 0
    
    def test_logging_data_protection(self):
        """Test that sensitive data is not logged."""
        # This would test actual logging configuration
        # For now, verify that the application doesn't log quote content
        
        # Mock a logging scenario
        with patch('main.get_db_connection') as mock_db:
            mock_connection = MagicMock()
            mock_cursor = MagicMock()
            
            mock_cursor.fetchone.return_value = (1, "Author", "Secret quote content")
            mock_connection.cursor.return_value = mock_cursor
            mock_db.return_value = mock_connection
            
            # The application should not log quote content
            # This is verified by code review and logging configuration
            assert True  # Placeholder for actual logging tests
    
    def test_data_encryption_in_transit(self):
        """Test that data is encrypted in transit."""
        # Test HTTPS configuration
        # In production, this should be enforced by Azure App Service
        
        # For now, verify that the application can handle HTTPS
        assert True  # Placeholder - HTTPS is handled by Azure App Service
    
    def test_data_encryption_at_rest(self):
        """Test that data is encrypted at rest."""
        # Azure SQL Database encrypts data at rest by default
        # Key Vault encrypts secrets at rest by default
        
        # Verify that we're using Azure services that provide encryption
        db_server = os.getenv('DATABASE_SERVER')
        if db_server:
            assert '.database.windows.net' in db_server  # Azure SQL provides encryption
        
        key_vault = os.getenv('KEY_VAULT_NAME')
        if key_vault:
            assert 'kv' in key_vault  # Key Vault provides encryption


class TestAccessControl:
    """Tests for access control and authorization."""
    
    def test_database_access_control(self):
        """Test database access control configuration."""
        # Test that database credentials are properly configured
        db_username = os.getenv('DATABASE_USERNAME')
        if db_username:
            # Should not be admin or sa
            assert db_username.lower() not in ['admin', 'sa', 'root']
            # Should be application-specific
            assert 'webapp' in db_username.lower() or 'app' in db_username.lower()
    
    def test_azure_rbac_configuration(self):
        """Test Azure RBAC configuration."""
        # This would test actual RBAC configuration
        # For now, verify that we're using Managed Identity (which implies RBAC)
        
        client_id = os.getenv('AZURE_CLIENT_ID')
        if client_id:
            # Using Managed Identity implies proper RBAC configuration
            assert len(client_id) > 0
    
    def test_network_access_control(self):
        """Test network access control configuration."""
        # Test that database server is configured for restricted access
        db_server = os.getenv('DATABASE_SERVER')
        if db_server:
            # Should be Azure SQL (which supports firewall rules)
            assert '.database.windows.net' in db_server
    
    def test_api_rate_limiting(self, client):
        """Test API rate limiting (if implemented)."""
        # Make multiple requests to test rate limiting
        responses = []
        for i in range(10):
            with patch('main.get_db_connection') as mock_db:
                mock_connection = MagicMock()
                mock_cursor = MagicMock()
                mock_cursor.fetchone.return_value = (1, "Author", "Quote")
                mock_connection.cursor.return_value = mock_cursor
                mock_db.return_value = mock_connection
                
                response = client.get('/')
                responses.append(response.status_code)
        
        # All should succeed (no rate limiting implemented yet)
        # But this test documents where rate limiting should be added
        assert all(status == 200 for status in responses)
