-- Migration: 0099_grant_crud_permissions
-- Description: Grant full CRUD permissions on tracking tables
-- Date: 2025-10-24
-- Purpose: Enable authenticated users to perform INSERT/UPDATE/DELETE operations
-- Security: No RLS yet - all authenticated users see all data (Phase 4 adds RLS)

BEGIN;

-- Grant CRUD on all tracking tables to authenticated role
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_folder TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_view TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style_timeline TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_material TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_material_timeline TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_template TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_template_item TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_template_visibility TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style_dependency TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_material_dependency TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_folder_style_link TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_assignment TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_status_history TO authenticated;

-- Grant usage on sequences (for INSERT operations)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA tracking TO authenticated;

-- Grant read-only access to internal tables for authenticated users
GRANT SELECT ON tracking.import_batches TO authenticated;
GRANT SELECT ON tracking.import_errors TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'Migration 0099 successful: CRUD permissions granted on 15 tables + sequences';
END $$;

COMMIT;
