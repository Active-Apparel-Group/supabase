-- 0001_create_tracking_schema.sql
-- Creates the tracking schema and enumerations.

BEGIN;

CREATE SCHEMA IF NOT EXISTS tracking;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'timeline_status_enum'
          AND n.nspname = 'tracking'
    ) THEN
        CREATE TYPE tracking.timeline_status_enum AS ENUM (
            'NOT_STARTED',
            'IN_PROGRESS',
            'APPROVED',
            'REJECTED',
            'COMPLETE',
            'BLOCKED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'timeline_type_enum'
          AND n.nspname = 'tracking'
    ) THEN
        CREATE TYPE tracking.timeline_type_enum AS ENUM ('MASTER', 'STYLE', 'MATERIAL');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'view_type_enum'
          AND n.nspname = 'tracking'
    ) THEN
        CREATE TYPE tracking.view_type_enum AS ENUM ('STYLE', 'MATERIAL');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'page_type_enum'
          AND n.nspname = 'tracking'
    ) THEN
        CREATE TYPE tracking.page_type_enum AS ENUM ('BOM', 'SAMPLE_REQUEST_MULTI', 'SAMPLE_REQUEST', 'FORM', 'TECHPACK', 'NONE');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'node_type_enum'
          AND n.nspname = 'tracking'
    ) THEN
        CREATE TYPE tracking.node_type_enum AS ENUM ('ANCHOR', 'TASK');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'offset_relation_enum'
          AND n.nspname = 'tracking'
    ) THEN
        CREATE TYPE tracking.offset_relation_enum AS ENUM ('AFTER', 'BEFORE');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'offset_unit_enum'
          AND n.nspname = 'tracking'
    ) THEN
        CREATE TYPE tracking.offset_unit_enum AS ENUM ('DAYS', 'BUSINESS_DAYS');
    END IF;
END;
$$;

COMMIT;
