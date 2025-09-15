# Database Seeding Implementation

## Overview

The Azure SQL database is automatically seeded with quote data when the Flask application starts up. This document explains how the seeding process works and how to manage the seed data.

## How Database Seeding Works

### 1. Automatic Seeding on App Startup

When the Flask application starts, it automatically:
- Creates the database schema if it doesn't exist
- Seeds the database with quotes if the table is empty
- Logs the initialization status

```python
# In app/main.py
app = create_app()
try:
    ensure_schema_and_seed()
    logger.info("Database initialization completed successfully")
except Exception as e:
    logger.warning("Database initialization failed, app will run without DB: %s", str(e))
```

### 2. Idempotent Seeding Process

The seeding process is idempotent - it only inserts data if the table is empty:

```python
# In app/db.py
def _seed_if_empty(cursor):
    cursor.execute("SELECT COUNT(1) FROM dbo.quotes;")
    count = cursor.fetchone()[0]
    if count and int(count) > 0:
        return  # Skip seeding if data already exists
    
    # Load and insert seed data...
```

### 3. Seed Data Source

The seed data is securely stored and loaded:
- Contains quotes from sports and music figures (treated as PII)
- Stored securely in Azure Key Vault for production environments
- Local development uses environment variables for secure access
- No plain text PII data is stored in version control

### 4. Database Schema

The application creates this table structure:

```sql
CREATE TABLE dbo.quotes (
    id INT IDENTITY(1,1) PRIMARY KEY,
    author NVARCHAR(255) NOT NULL,
    text NVARCHAR(2000) NOT NULL
);
```

## File Structure

```
database/
+-- seed/
    +-- quotes.json    # Seed data (10 quotes)

app/
+-- db.py             # Database connection and seeding logic
+-- main.py           # App initialization and seeding trigger
+-- Dockerfile        # Copies seed data into container
```

## Container Integration

The Docker container includes the seed data:

```dockerfile
# In app/Dockerfile
COPY app /app/app
COPY database/seed /app/database/seed  # Seed data copied into container
```

## Validation

You can validate that quotes are coming from the Azure SQL database using:

1. **Validation Script**: `./scripts/validate-database-source.sh`
2. **API Endpoints**:
   - `/db-test` - Tests database connectivity
   - `/db-validate` - Shows database metadata and sample quotes
   - `/quote-with-source` - Returns quotes with source validation

## Security Considerations

- **PII Compliance**: Quote text is not logged to respect PII posture
- **Parameterized Queries**: All database operations use parameterized queries
- **Encrypted Connections**: Database connections use TLS encryption
- **No Secrets in Code**: Connection strings come from Azure Key Vault

## Troubleshooting

### Common Issues

1. **Seeding Fails**: Check database connectivity and permissions
2. **Duplicate Data**: The process is idempotent - won't create duplicates
3. **Missing Seed File**: Check that `database/seed/quotes.json` exists in container

### Debugging Commands

```bash
# Check if quotes exist in database
curl -s https://your-app.azurewebsites.net/db-validate | jq '.database_validation.total_quotes'

# Test database connectivity
curl -s https://your-app.azurewebsites.net/db-test

# Validate seed data source
./scripts/validate-database-source.sh
```

## Future Enhancements

For more sophisticated database management, consider:

1. **Standalone Scripts**: Create `scripts/db-migrate.sh` and `scripts/db-seed.sh`
2. **Migration Versioning**: Implement proper schema versioning for complex changes
3. **Separate Initialization**: Decouple database setup from application startup
4. **Rollback Capability**: Add ability to rollback schema or data changes

## Seed Data Format

The quote data follows this structure when loaded from secure storage:

```json
[
  {
    "author": "[AUTHOR_NAME]",
    "text": "[QUOTE_TEXT]"
  },
  {
    "author": "[AUTHOR_NAME]",
    "text": "[QUOTE_TEXT]"
  }
]
```

**Note**: Actual quote content is treated as PII and stored securely in Azure Key Vault. The above shows the data structure only.

Each quote object requires:
- `author`: String (required) - The quote author's name
- `text`: String (required) - The quote text content
