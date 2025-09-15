import os
import logging
from flask import Flask, jsonify
from .db import get_db_connection, ensure_schema_and_seed

# Configure logging with minimal data exposure
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
logger = logging.getLogger(__name__)


def create_app():
    app = Flask(__name__)

    # Health check
    @app.route('/healthz')
    def healthz():
        return jsonify(status='ok')

    @app.route('/db-test')
    def test_database():
        """Test database connectivity"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT @@VERSION")
            version = cursor.fetchone()[0]
            conn.close()
            return jsonify(status="success", database="connected", version=version[:100])
        except Exception as e:
            logger.error(f"Database test failed: {str(e)}")
            return jsonify(status="error", database="failed", error=str(e)), 500

    @app.route('/db-validate')
    def validate_database():
        """Validate quotes are coming from Azure SQL database"""
        try:
            conn = get_db_connection()
            cursor = conn.cursor()

            # Get database info
            cursor.execute("SELECT @@SERVERNAME, DB_NAME(), @@VERSION")
            server_info = cursor.fetchone()

            # Get quote statistics
            cursor.execute("SELECT COUNT(*) as total_quotes FROM dbo.quotes")
            total_quotes = cursor.fetchone()[0]

            # Get sample of quote IDs and authors
            cursor.execute("SELECT TOP 5 id, author FROM dbo.quotes ORDER BY id")
            sample_quotes = [{"id": row[0], "author": row[1]} for row in cursor.fetchall()]

            # Get table schema info
            cursor.execute("""
                SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_NAME = 'quotes'
                ORDER BY ORDINAL_POSITION
            """)
            schema = [{"column": row[0], "type": row[1], "max_length": row[2]} for row in cursor.fetchall()]

            conn.close()

            return jsonify(
                status="success",
                database_validation={
                    "server_name": server_info[0],
                    "database_name": server_info[1],
                    "sql_version": server_info[2][:100],
                    "total_quotes": total_quotes,
                    "sample_quotes": sample_quotes,
                    "table_schema": schema
                }
            )
        except Exception as e:
            logger.error(f"Database validation failed: {str(e)}")
            return jsonify(status="error", database="failed", error=str(e)), 500

    @app.route('/')
    def random_quote():
        # Treat all data as PII: do not log quote contents
        try:
            conn = get_db_connection()
        except Exception as e:
            logger.error(f"Database connection failed: {str(e)}")
            # Do not leak internals; indicate service unavailable until DB is ready
            return jsonify(error='database_unavailable'), 503
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT TOP 1 id, author, text FROM dbo.quotes ORDER BY NEWID();")
            row = cursor.fetchone()
            if not row:
                return jsonify(message='No quotes available'), 404
            return jsonify(id=row[0], author=row[1], text=row[2])
        finally:
            conn.close()

    @app.route('/quote-with-source')
    def quote_with_source():
        """Get a random quote with database source validation"""
        try:
            conn = get_db_connection()
        except Exception as e:
            logger.error(f"Database connection failed: {str(e)}")
            return jsonify(error='database_unavailable'), 503
        try:
            cursor = conn.cursor()
            # Get quote with database metadata
            cursor.execute("""
                SELECT TOP 1
                    q.id, q.author, q.text,
                    @@SERVERNAME as server_name,
                    DB_NAME() as database_name,
                    GETDATE() as query_time
                FROM dbo.quotes q
                ORDER BY NEWID();
            """)
            row = cursor.fetchone()
            if not row:
                return jsonify(message='No quotes available'), 404

            return jsonify(
                quote={
                    "id": row[0],
                    "author": row[1],
                    "text": row[2]
                },
                source_validation={
                    "server_name": row[3],
                    "database_name": row[4],
                    "query_time": row[5].isoformat(),
                    "source": "Azure SQL Database"
                }
            )
        finally:
            conn.close()

    @app.route('/debug-seed')
    def debug_seed():
        """Debug endpoint to check seed file accessibility and data loading"""
        from pathlib import Path
        import json

        debug_info = {
            "container_info": {
                "working_directory": os.getcwd(),
                "app_directory": "/app" if os.path.exists("/app") else "not_found"
            },
            "seed_file_check": {},
            "data_loading_test": {}
        }

        # Check multiple possible seed file locations
        possible_paths = [
            Path(__file__).resolve().parents[1] / "database" / "seed" / "quotes.json",
            Path("/app/database/seed/quotes.json"),
            Path("./database/seed/quotes.json"),
            Path("../database/seed/quotes.json")
        ]

        for i, path in enumerate(possible_paths):
            debug_info["seed_file_check"][f"path_{i+1}"] = {
                "path": str(path),
                "exists": path.exists(),
                "is_file": path.is_file() if path.exists() else False,
                "parent_exists": path.parent.exists() if path.parent else False
            }

            if path.exists() and path.is_file():
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        debug_info["data_loading_test"]["success"] = True
                        debug_info["data_loading_test"]["total_items"] = len(data)
                        debug_info["data_loading_test"]["quote_items"] = len([item for item in data if not item.get('_comment')])
                        debug_info["data_loading_test"]["first_quote"] = next((item for item in data if not item.get('_comment')), None)
                        break
                except Exception as e:
                    debug_info["data_loading_test"]["error"] = str(e)

        # Test the actual _load_quotes_securely function
        try:
            from .db import _load_quotes_securely
            quotes_data = _load_quotes_securely()
            debug_info["load_quotes_securely"] = {
                "success": quotes_data is not None,
                "quote_count": len(quotes_data) if quotes_data else 0,
                "sample_quote": quotes_data[0] if quotes_data else None
            }
        except Exception as e:
            debug_info["load_quotes_securely"] = {"error": str(e)}

        return jsonify(debug_info)

    return app


# Initialize app and ensure DB schema/seed once at startup
app = create_app()

# Debug: Log environment variables (without exposing secrets)
logger.info("Environment check:")
logger.info("PORT: %s", os.environ.get('PORT', 'not set'))
logger.info("KEY_VAULT_URL: %s", 'set' if os.environ.get('KEY_VAULT_URL') else 'not set')
logger.info("SQL_CONN_STR: %s", 'set' if os.environ.get('SQL_CONN_STR') else 'not set')
logger.info("DATABASE_CONNECTION_STRING: %s", 'set' if os.environ.get('DATABASE_CONNECTION_STRING') else 'not set')

# Make database initialization more resilient
def initialize_database():
    """Initialize database with better error handling"""
    try:
        logger.info("Starting database initialization...")
        ensure_schema_and_seed()
        logger.info("Database initialization completed successfully")
        return True
    except Exception as e:
        # Log the error but don't fail startup - allow app to run without DB
        logger.warning("Database initialization failed, app will run without DB: %s", str(e))
        return False

# Try to initialize database, but don't block startup
try:
    initialize_database()
except Exception as e:
    logger.error("Critical error during database initialization: %s", str(e))





if __name__ == '__main__':
    port = int(os.environ.get('PORT', '8080'))
    app.run(host='0.0.0.0', port=port)

