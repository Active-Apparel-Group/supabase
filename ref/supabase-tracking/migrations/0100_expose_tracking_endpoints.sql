-- Migration: 0100_expose_tracking_endpoints
-- Description: Enable PostgREST to discover and expose tracking tables as REST endpoints
-- Date: 2025-10-24
-- Purpose: Allow anon and authenticated roles to access tracking schema via /rest/v1/tracking_*
-- Result: Endpoints like /rest/v1/tracking_folder, /rest/v1/tracking_plan_style, etc.

BEGIN;

-- Grant USAGE on tracking schema to allow PostgREST discovery
GRANT USAGE ON SCHEMA tracking TO anon, authenticated;

-- Verify schema grants
DO $$
DECLARE
  anon_usage boolean;
  auth_usage boolean;
BEGIN
  SELECT has_schema_privilege('anon', 'tracking', 'USAGE') INTO anon_usage;
  SELECT has_schema_privilege('authenticated', 'tracking', 'USAGE') INTO auth_usage;
  
  IF NOT anon_usage OR NOT auth_usage THEN
    RAISE EXCEPTION 'Schema grant verification failed: anon=%, authenticated=%', anon_usage, auth_usage;
  END IF;
  
  RAISE NOTICE 'Migration 0100 successful: tracking schema exposed to PostgREST';
  RAISE NOTICE 'Endpoints available: /rest/v1/tracking_folder, /rest/v1/tracking_plan, etc.';
END $$;

COMMIT;
