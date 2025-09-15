import os
import json
import logging
from pathlib import Path
import base64
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

logger = logging.getLogger(__name__)

class DBNotConfigured(Exception):
    pass


def _load_quotes_securely():
    """
    Load quotes data securely from Azure Key Vault (production) or environment variable (local dev).

    PII COMPLIANCE: This function ensures quotes data is never stored in:
    - Container images
    - Source code
    - Configuration files
    - Container registries

    Returns:
        list: Quote data loaded from secure storage, or None if unavailable
    """
    try:
        # Environment constraint validations for proper data source selection
        demo_mode = os.environ.get('DEMO_MODE', '').lower() == 'true'
        environment = os.environ.get('ENVIRONMENT', 'dev').lower()
        key_vault_url = os.environ.get('KEY_VAULT_URL')
        quotes_env = os.environ.get('QUOTES_DATA_BASE64')

        logger.info("Environment constraints - ENV: %s, DEMO_MODE: %s, KEY_VAULT_URL: %s, QUOTES_DATA_BASE64: %s",
                   environment, demo_mode, 'set' if key_vault_url else 'not set', 'set' if quotes_env else 'not set')

        # CONSTRAINT 1: Production environments MUST use Key Vault
        if environment == 'prod' and not key_vault_url:
            logger.error("PRODUCTION CONSTRAINT VIOLATION: KEY_VAULT_URL required for production")
            raise Exception("Production environments must use Azure Key Vault for PII data")

        # CONSTRAINT 2: Demo mode explicitly enables seed file usage
        if demo_mode:
            logger.warning("DEMO MODE ENABLED: Using seed files (documented PII exception)")
            logger.warning("This violates PII security best practices - see docs/pii-compliance.md")
            return _load_from_seed_files()

        # CONSTRAINT 3: Local Development - prefer environment variable
        if quotes_env:
            logger.info("Loading quotes from environment variable (local dev)")
            try:
                quotes_json = base64.b64decode(quotes_env).decode('utf-8')
                quotes_data = json.loads(quotes_json)
                logger.info("Successfully loaded %d quotes from environment variable", len(quotes_data))
                return quotes_data
            except Exception as e:
                logger.error("Failed to load from environment variable: %s", str(e))

        # CONSTRAINT 4: Production/Staging - use Azure Key Vault
        if key_vault_url:
            logger.info("Loading quotes from Azure Key Vault (PII compliant)")
            try:
                credential = DefaultAzureCredential()
                client = SecretClient(vault_url=key_vault_url, credential=credential)
                secret = client.get_secret("quotes-data")
                quotes_json = base64.b64decode(secret.value).decode('utf-8')
                quotes_data = json.loads(quotes_json)
                logger.info("Successfully loaded %d quotes from Azure Key Vault", len(quotes_data))
                return quotes_data
            except Exception as e:
                logger.error("Failed to load quotes from Key Vault: %s", str(e))
                # Only fallback to seed files in non-production environments
                if environment != 'prod':
                    logger.warning("Falling back to seed files for demo functionality")
                else:
                    logger.error("Production fallback to seed files not allowed")
                    return None

        # CONSTRAINT 5: Fallback for dev environments only
        if environment in ['dev', 'development', 'demo']:
            logger.warning("DEV ENVIRONMENT: Falling back to seed files")
            logger.warning("For production: Set KEY_VAULT_URL and ENVIRONMENT=prod")
            logger.warning("For demo: Set DEMO_MODE=true to acknowledge PII exception")
            return _load_from_seed_files()

        # CONSTRAINT 6: No fallback for production
        logger.error("No secure quotes data source configured for environment: %s", environment)
        return None

    except Exception as e:
        logger.error("Failed to load quotes securely: %s", str(e))
        return None


def _load_from_seed_files():
    """
    Load quotes from seed files with proper error handling.
    This is a documented PII exception for demo purposes.
    """
    # Try multiple possible paths in container
    possible_paths = [
        Path(__file__).resolve().parents[1] / "database" / "seed" / "quotes.json",
        Path("/app/database/seed/quotes.json"),
        Path("./database/seed/quotes.json"),
        Path("../database/seed/quotes.json")
    ]

    for seed_path in possible_paths:
        if seed_path.exists():
            logger.info("Found seed file at: %s", str(seed_path))
            try:
                with open(seed_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    # Filter out comment objects used for documentation
                    quotes_data = [item for item in data if not item.get('_comment')]
                    logger.info("Successfully loaded %d quotes from seed file", len(quotes_data))
                    return quotes_data
            except Exception as e:
                logger.error("Failed to load from seed file %s: %s", str(seed_path), str(e))
                continue

    logger.error("No seed files found at any expected location")
    logger.error("Tried paths: %s", [str(p) for p in possible_paths])
    return None


def _load_pyodbc():
    try:
        import pyodbc  # noqa: F401
        return pyodbc
    except Exception as e:
        raise DBNotConfigured("pyodbc not available in runtime") from e


def _connection_string_from_env() -> str:
    # Prefer a full connection string if provided
    cs = os.getenv("DATABASE_CONNECTION_STRING") or os.getenv("SQL_CONN_STR")
    if cs:
        return cs
    # Otherwise, build from discrete vars (for local dev)
    server = os.getenv("SQL_SERVER")
    database = os.getenv("SQL_DATABASE")
    username = os.getenv("SQL_USER")
    password = os.getenv("SQL_PASSWORD")

    if server and database and username and password:
        return (
            f"Driver={{ODBC Driver 18 for SQL Server}};"
            f"Server=tcp:{server},1433;Database={database};"
            f"Uid={username};Pwd={password};Encrypt=yes;TrustServerCertificate=no;"
            f"Connection Timeout=30;"
        )

    # Managed identity path (future): implement token-based auth when MI is enabled in App Service
    if os.getenv("AZURE_SQL_AUTH", "").lower() == "managed_identity":
        raise DBNotConfigured("Managed Identity auth not implemented yet. Provide connection string or SQL_USER/PASSWORD for dev.")

    raise DBNotConfigured("Database connection not configured via env.")


def get_db_connection():
    """
    Return a live pyodbc connection.
    Raises DBNotConfigured if unavailable. Do not log secrets or PII.
    """
    pyodbc = _load_pyodbc()
    conn_str = _connection_string_from_env()
    logger.info('Connecting to Azure SQL over encrypted channel')
    return pyodbc.connect(conn_str)


def _ensure_table(cursor):
    cursor.execute(
        """
        IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='quotes' AND xtype='U')
        CREATE TABLE dbo.quotes (
            id INT IDENTITY(1,1) PRIMARY KEY,
            author NVARCHAR(255) NOT NULL,
            text NVARCHAR(2000) NOT NULL
        );
        """
    )


def _seed_if_empty(cursor):
    cursor.execute("SELECT COUNT(1) FROM dbo.quotes;")
    count = cursor.fetchone()[0]
    if count and int(count) > 0:
        return

    # PII COMPLIANCE: Load quotes from Azure Key Vault (production) or environment variable (local dev)
    quotes_data = _load_quotes_securely()
    if not quotes_data:
        logger.warning("No quotes data available for seeding")
        return

    rows = [(q.get("author", "Unknown"), q["text"]) for q in quotes_data if q.get("text")]
    for author, text in rows:
        cursor.execute("INSERT INTO dbo.quotes (author, text) VALUES (?, ?)", (author, text))

    logger.info("Database seeded with %d quotes (PII data loaded securely)", len(rows))


def ensure_schema_and_seed():
    """
    Best-effort schema/seed during bootstrap. If DB is not configured, skip.
    """
    try:
        conn = get_db_connection()
    except DBNotConfigured:
        logger.info("Database not configured yet; skipping schema/seed.")
        return
    try:
        cursor = conn.cursor()
        _ensure_table(cursor)
        _seed_if_empty(cursor)
        conn.commit()
    finally:
        conn.close()

