# ADR-0004: Database Migrations and Seeding

**Status**: Accepted (simplified for demo), Future enhancement needed  
**Date**: 2024-12-13  
**Context**: Demo project - Production requires comprehensive database lifecycle management  

## Context

The Azure WebApp Demo requires database schema management and initial data seeding with famous quotes, treating all data as critical PII.

**DEMO PROJECT NOTE**: This ADR documents the simplified approach for demo purposes. Production deployments require comprehensive database lifecycle management and migration strategies.

## Decision

**Selected for Demo**: Application-level schema creation and seeding

### Rationale for Demo
- **Simplicity**: No external migration tools required
- **Self-contained**: Application manages its own schema
- **Fast Deployment**: Immediate database readiness
- **PII Compliance**: Secure handling of quote data
- **Demo Appropriate**: Suitable for 2-hour deployment window

## Considered Alternatives

### Application-Level Management (Selected)
**Pros**:
- Simple implementation in Flask application
- No additional tools or services required
- Immediate schema creation on startup
- Self-contained deployment
- Easy to understand and debug

**Cons**:
- Limited migration capabilities
- No rollback mechanisms
- Potential race conditions in multi-instance deployments
- Not suitable for complex schema changes

### Database Migration Tools (Future Consideration)
**Options**: Alembic, Flyway, Liquibase

**Pros**:
- Versioned schema changes
- Rollback capabilities
- Production-ready migration management
- Team collaboration support
- Audit trail of changes

**Cons**:
- Additional complexity and dependencies
- Requires migration strategy planning
- Longer deployment time
- Learning curve for team

### Azure Database Migration Service (Future Consideration)
**Pros**:
- Managed migration service
- Minimal downtime migrations
- Assessment and compatibility tools
- Support for various source databases

**Cons**:
- Overkill for new application
- Additional cost and complexity
- Designed for existing database migrations

## Implementation Details

### Demo Implementation
```python
# app/db.py - Simplified database management
import pyodbc
import json
import os
from typing import List, Dict, Optional

class DatabaseManager:
    def __init__(self, connection_string: str):
        self.connection_string = connection_string
    
    def initialize_database(self):
        """Create schema and seed data if needed"""
        try:
            with pyodbc.connect(self.connection_string) as conn:
                cursor = conn.cursor()
                
                # Create quotes table if not exists
                cursor.execute("""
                    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='quotes' AND xtype='U')
                    CREATE TABLE quotes (
                        id INT IDENTITY(1,1) PRIMARY KEY,
                        quote NVARCHAR(MAX) NOT NULL,
                        author NVARCHAR(255) NOT NULL,
                        category NVARCHAR(100),
                        created_at DATETIME2 DEFAULT GETDATE(),
                        updated_at DATETIME2 DEFAULT GETDATE()
                    )
                """)
                
                # Check if data exists
                cursor.execute("SELECT COUNT(*) FROM quotes")
                count = cursor.fetchone()[0]
                
                if count == 0:
                    self._seed_quotes(cursor)
                
                conn.commit()
                
        except Exception as e:
            print(f"Database initialization error: {e}")
            raise
    
    def _seed_quotes(self, cursor):
        """Seed initial quote data"""
        quotes_file = os.path.join(os.path.dirname(__file__), '..', 'database', 'seed', 'quotes.json')
        
        with open(quotes_file, 'r', encoding='utf-8') as f:
            quotes_data = json.load(f)
        
        for quote_data in quotes_data.get('quotes', []):
            cursor.execute("""
                INSERT INTO quotes (quote, author, category)
                VALUES (?, ?, ?)
            """, (
                quote_data['quote'],
                quote_data['author'],
                quote_data.get('category', 'General')
            ))
```

### Quote Data Structure
```json
{
  "quotes": [
    {
      "quote": "The only way to do great work is to love what you do.",
      "author": "Steve Jobs",
      "category": "Motivation"
    },
    {
      "quote": "Innovation distinguishes between a leader and a follower.",
      "author": "Steve Jobs",
      "category": "Innovation"
    }
  ]
}
```

### Application Integration
```python
# app/main.py - Flask application
from flask import Flask, jsonify, render_template
from .db import DatabaseManager
import os

app = Flask(__name__)

# Initialize database on startup
@app.before_first_request
def initialize_database():
    db_connection = os.environ.get('DATABASE_URL')
    if db_connection:
        db_manager = DatabaseManager(db_connection)
        db_manager.initialize_database()

@app.route('/api/quote')
def get_random_quote():
    """Get a random quote from database"""
    try:
        db_connection = os.environ.get('DATABASE_URL')
        db_manager = DatabaseManager(db_connection)
        quote = db_manager.get_random_quote()
        return jsonify(quote)
    except Exception as e:
        return jsonify({'error': 'Failed to fetch quote'}), 500
```

## Future Production Considerations

### Database Migration Strategy

#### Alembic Integration (Recommended)
```python
# Production migration setup
from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory

class ProductionDatabaseManager:
    def __init__(self, connection_string: str):
        self.connection_string = connection_string
        self.alembic_cfg = Config("alembic.ini")
    
    def migrate_to_latest(self):
        """Run all pending migrations"""
        command.upgrade(self.alembic_cfg, "head")
    
    def create_migration(self, message: str):
        """Create new migration"""
        command.revision(self.alembic_cfg, message=message, autogenerate=True)
    
    def rollback_migration(self, revision: str):
        """Rollback to specific revision"""
        command.downgrade(self.alembic_cfg, revision)
```

#### Migration File Structure
```
migrations/
+-- versions/
|   +-- 001_initial_schema.py
|   +-- 002_add_quote_categories.py
|   +-- 003_add_user_favorites.py
+-- alembic.ini
+-- env.py
```

### Data Seeding Strategy

#### Environment-Specific Seeding
```python
class ProductionSeeder:
    def __init__(self, environment: str):
        self.environment = environment
    
    def seed_data(self):
        if self.environment == "development":
            self._seed_development_data()
        elif self.environment == "staging":
            self._seed_staging_data()
        elif self.environment == "production":
            self._seed_production_data()
    
    def _seed_production_data(self):
        """Minimal production data"""
        # Only essential quotes for production
        pass
    
    def _seed_development_data(self):
        """Full development dataset"""
        # Comprehensive quote collection for testing
        pass
```

### Schema Versioning
```sql
-- Migration tracking table
CREATE TABLE schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    applied_at DATETIME2 DEFAULT GETDATE(),
    applied_by VARCHAR(255),
    execution_time_ms INT
);

-- Audit trail for data changes
CREATE TABLE quote_audit (
    id INT IDENTITY(1,1) PRIMARY KEY,
    quote_id INT,
    operation VARCHAR(10), -- INSERT, UPDATE, DELETE
    old_values NVARCHAR(MAX),
    new_values NVARCHAR(MAX),
    changed_by VARCHAR(255),
    changed_at DATETIME2 DEFAULT GETDATE()
);
```

### Backup and Recovery Strategy

#### Automated Backups
```hcl
# Terraform configuration for automated backups
resource "azurerm_mssql_database" "db" {
  name           = "${local.name_prefix}-db"
  server_id      = azurerm_mssql_server.sql.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S0"
  
  # Backup configuration
  short_term_retention_policy {
    retention_days = 7
  }
  
  long_term_retention_policy {
    weekly_retention  = "P1M"   # 1 month
    monthly_retention = "P3M"   # 3 months
    yearly_retention  = "P1Y"   # 1 year
    week_of_year     = 1
  }
}
```

#### Point-in-Time Recovery
```bash
# Azure CLI backup commands
az sql db restore \
  --dest-name mydb-restored \
  --edition Standard \
  --name mydb \
  --resource-group mygroup \
  --server myserver \
  --time "2024-12-13T10:30:00"
```

## Data Protection and Compliance

### PII Handling
1. **Data Classification**: Identify PII columns
2. **Encryption**: Column-level encryption for sensitive data
3. **Masking**: Dynamic data masking for non-production
4. **Access Control**: Row-level security
5. **Audit**: Comprehensive access logging

### GDPR Compliance
```sql
-- Data retention policy
CREATE PROCEDURE CleanupOldData
AS
BEGIN
    -- Remove data older than retention period
    DELETE FROM quotes 
    WHERE created_at < DATEADD(year, -7, GETDATE())
    
    -- Log cleanup activity
    INSERT INTO audit_log (action, details, timestamp)
    VALUES ('DATA_CLEANUP', 'Removed quotes older than 7 years', GETDATE())
END
```

## Consequences

### Positive
- **Simple Implementation**: Easy to understand and maintain
- **Fast Deployment**: Immediate database readiness
- **Self-Contained**: No external dependencies
- **Demo Appropriate**: Suitable for demonstration purposes

### Negative
- **Limited Scalability**: Not suitable for complex schema changes
- **No Rollback**: Cannot easily undo schema changes
- **Race Conditions**: Potential issues with multiple instances
- **Production Gaps**: Missing enterprise database management features

## Migration Path to Production

### Phase 1: Add Migration Framework
1. Implement Alembic for schema versioning
2. Create initial migration from current schema
3. Add migration execution to deployment pipeline

### Phase 2: Enhanced Data Management
1. Implement environment-specific seeding
2. Add data validation and integrity checks
3. Create backup and recovery procedures

### Phase 3: Enterprise Features
1. Implement audit trails and compliance logging
2. Add data retention and cleanup policies
3. Implement advanced security features

## Review Schedule

- **Demo Phase**: No review needed (fixed approach)
- **Production Planning**: Re-evaluate based on:
  - Schema complexity growth
  - Data volume and performance requirements
  - Compliance and audit requirements
  - Team database management expertise

---

**Previous ADR**: [0003-networking-and-data-protection.md](0003-networking-and-data-protection.md)
