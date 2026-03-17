-- Create the additional databases required by the Rails multi-database setup.
-- The primary database (ei_point_of_sale_production) is created by the POSTGRES_DB env var.
SELECT 'CREATE DATABASE cache' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cache')\gexec
SELECT 'CREATE DATABASE queue' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'queue')\gexec
SELECT 'CREATE DATABASE cable' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cable')\gexec
