"""
Pytest configuration and shared fixtures for Azure Web Application Demo tests.
"""

import pytest
import os
import sys
from pathlib import Path

# Add the app directory to the Python path
app_dir = Path(__file__).parent.parent / "app"
sys.path.insert(0, str(app_dir))

@pytest.fixture
def app():
    """Create and configure a test instance of the Flask app."""
    from main import create_app
    
    # Create app with test configuration
    app = create_app({
        'TESTING': True,
        'DATABASE_URL': 'sqlite:///:memory:',  # Use in-memory SQLite for tests
        'SECRET_KEY': 'test-secret-key'
    })
    
    return app

@pytest.fixture
def client(app):
    """Create a test client for the Flask app."""
    return app.test_client()

@pytest.fixture
def runner(app):
    """Create a test runner for the Flask app."""
    return app.test_cli_runner()

@pytest.fixture
def mock_azure_credentials():
    """Mock Azure credentials for testing."""
    return {
        'subscription_id': 'test-subscription-id',
        'resource_group': 'test-resource-group',
        'tenant_id': 'test-tenant-id'
    }

@pytest.fixture
def sample_quotes():
    """Sample quotes data for testing."""
    return [
        {
            "id": 1,
            "author": "Test Author 1",
            "text": "This is a test quote about music."
        },
        {
            "id": 2,
            "author": "Test Author 2", 
            "text": "This is a test quote about sports."
        }
    ]

@pytest.fixture
def mock_database_connection():
    """Mock database connection for testing."""
    class MockConnection:
        def __init__(self):
            self.closed = False
            
        def cursor(self):
            return MockCursor()
            
        def close(self):
            self.closed = True
            
        def commit(self):
            pass
    
    class MockCursor:
        def __init__(self):
            self.results = []
            
        def execute(self, query, params=None):
            # Mock different query responses
            if "SELECT COUNT(1)" in query:
                self.results = [(5,)]  # Mock count
            elif "SELECT TOP 1" in query:
                self.results = [(1, "Test Author", "Test quote text")]
            else:
                self.results = []
                
        def fetchone(self):
            return self.results[0] if self.results else None
            
        def fetchall(self):
            return self.results
            
        def close(self):
            pass
    
    return MockConnection()
