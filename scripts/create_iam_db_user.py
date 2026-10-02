"""Create the limited PostgreSQL login used by EKS Pod Identity."""

import os

from sqlalchemy import create_engine, text

engine = create_engine(os.environ["DATABASE_URL"])

# Run through the application's existing admin connection inside EKS.
# Re-running this script keeps the same role and grants.
with engine.begin() as connection:
    database = connection.scalar(text("SELECT current_database()"))
    owner = connection.scalar(text("SELECT current_user"))
    if database != "boundarypass" or owner != "boundarypassadmin":
        raise RuntimeError("Unexpected database or administrator; no changes made")

    connection.execute(text("""
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_roles WHERE rolname = 'boundarypass_app'
          ) THEN
            CREATE ROLE boundarypass_app LOGIN;
          END IF;
        END
        $$;
    """))

    # rds_iam makes this role authenticate with an AWS IAM token.
    connection.execute(text("GRANT rds_iam TO boundarypass_app"))

    # Allow application queries without giving ownership or admin rights.
    connection.execute(text("GRANT CONNECT ON DATABASE boundarypass TO boundarypass_app"))
    connection.execute(text("GRANT USAGE ON SCHEMA public TO boundarypass_app"))
    connection.execute(text("""
        GRANT SELECT, INSERT, UPDATE, DELETE
        ON ALL TABLES IN SCHEMA public TO boundarypass_app
    """))
    connection.execute(text("""
        GRANT USAGE, SELECT
        ON ALL SEQUENCES IN SCHEMA public TO boundarypass_app
    """))

    # Tables and sequences added later by boundarypassadmin get the same grants.
    connection.execute(text("""
        ALTER DEFAULT PRIVILEGES FOR ROLE boundarypassadmin IN SCHEMA public
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO boundarypass_app
    """))
    connection.execute(text("""
        ALTER DEFAULT PRIVILEGES FOR ROLE boundarypassadmin IN SCHEMA public
        GRANT USAGE, SELECT ON SEQUENCES TO boundarypass_app
    """))

print("Created or updated IAM database user boundarypass_app")
