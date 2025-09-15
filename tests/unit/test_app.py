"""
Unit tests for the Flask application core functionality.
"""

import pytest
import json
from unittest.mock import patch, MagicMock


class TestFlaskApp:
    """Test cases for Flask application routes and functionality."""
    
    def test_app_creation(self, app):
        """Test that the Flask app is created successfully."""
        assert app is not None
        assert app.config['TESTING'] is True
    
    def test_health_check(self, client):
        """Test the basic health check endpoint."""
        with patch('main.get_db_connection') as mock_db:
            mock_db.return_value = None
            response = client.get('/health')
            assert response.status_code == 200
    
    @patch('main.get_db_connection')
    def test_home_route_success(self, mock_db, client, mock_database_connection):
        """Test successful quote retrieval from home route."""
        mock_db.return_value = mock_database_connection
        
        response = client.get('/')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'id' in data
        assert 'author' in data
        assert 'text' in data
    
    @patch('main.get_db_connection')
    def test_home_route_db_error(self, mock_db, client):
        """Test home route when database connection fails."""
        mock_db.side_effect = Exception("Database connection failed")
        
        response = client.get('/')
        assert response.status_code == 500
        
        data = json.loads(response.data)
        assert 'error' in data
    
    @patch('main.get_db_connection')
    def test_db_test_route(self, mock_db, client, mock_database_connection):
        """Test the database test endpoint."""
        mock_db.return_value = mock_database_connection
        
        response = client.get('/db-test')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'status' in data
        assert 'quote_count' in data
    
    @patch('main.get_db_connection')
    def test_db_validate_route(self, mock_db, client, mock_database_connection):
        """Test the database validation endpoint."""
        mock_db.return_value = mock_database_connection
        
        response = client.get('/db-validate')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'database_status' in data
        assert 'quote_count' in data
    
    @patch('main.get_db_connection')
    def test_quote_with_source_route(self, mock_db, client, mock_database_connection):
        """Test the quote with source endpoint."""
        mock_db.return_value = mock_database_connection
        
        response = client.get('/quote-with-source')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'quote' in data
        assert 'source_info' in data


class TestDatabaseFunctions:
    """Test cases for database-related functions."""
    
    @patch('main.pyodbc.connect')
    def test_get_db_connection_success(self, mock_connect):
        """Test successful database connection."""
        from main import get_db_connection
        
        mock_connection = MagicMock()
        mock_connect.return_value = mock_connection
        
        # Mock environment variables
        with patch.dict('os.environ', {
            'DATABASE_SERVER': 'test-server',
            'DATABASE_NAME': 'test-db',
            'DATABASE_USERNAME': 'test-user',
            'DATABASE_PASSWORD': 'test-pass'
        }):
            connection = get_db_connection()
            assert connection == mock_connection
    
    @patch('main.pyodbc.connect')
    def test_get_db_connection_failure(self, mock_connect):
        """Test database connection failure."""
        from main import get_db_connection
        
        mock_connect.side_effect = Exception("Connection failed")
        
        with patch.dict('os.environ', {
            'DATABASE_SERVER': 'test-server',
            'DATABASE_NAME': 'test-db',
            'DATABASE_USERNAME': 'test-user',
            'DATABASE_PASSWORD': 'test-pass'
        }):
            connection = get_db_connection()
            assert connection is None
    
    def test_get_random_quote_success(self, mock_database_connection):
        """Test successful quote retrieval."""
        from main import get_random_quote
        
        quote = get_random_quote(mock_database_connection)
        assert quote is not None
        assert 'id' in quote
        assert 'author' in quote
        assert 'text' in quote
    
    def test_get_random_quote_failure(self):
        """Test quote retrieval with database error."""
        from main import get_random_quote
        
        mock_connection = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.execute.side_effect = Exception("Query failed")
        mock_connection.cursor.return_value = mock_cursor
        
        quote = get_random_quote(mock_connection)
        assert quote is None


class TestUtilityFunctions:
    """Test cases for utility functions."""
    
    def test_format_quote_response(self):
        """Test quote response formatting."""
        from main import format_quote_response
        
        quote_data = (1, "Test Author", "Test quote text")
        formatted = format_quote_response(quote_data)
        
        assert formatted['id'] == 1
        assert formatted['author'] == "Test Author"
        assert formatted['text'] == "Test quote text"
    
    def test_format_quote_response_none(self):
        """Test quote response formatting with None input."""
        from main import format_quote_response
        
        formatted = format_quote_response(None)
        assert formatted is None
    
    def test_error_response_format(self):
        """Test error response formatting."""
        from main import create_error_response
        
        error_response = create_error_response("Test error message", 500)
        
        assert error_response[1] == 500  # Status code
        data = json.loads(error_response[0].data)
        assert data['error'] == "Test error message"
        assert data['status'] == 'error'
