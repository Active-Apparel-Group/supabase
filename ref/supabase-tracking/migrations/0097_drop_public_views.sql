-- Migration: 0097_drop_and_recreate_functions
-- Description: Drop/recreate functions with updated tracking_ table names
-- Date: 2025-10-24
-- Purpose: Functions have hardcoded table references that won't follow renames
-- Breaking: Trigger will temporarily stop working (recreated in 0098)

BEGIN;

-- Drop existing functions (CASCADE drops dependent trigger)
DROP FUNCTION IF EXISTS tracking.instantiate_timeline_from_template() CASCADE;
DROP FUNCTION IF EXISTS tracking.calculate_timeline_dates(uuid) CASCADE;

-- Note: Trigger trg_instantiate_style_timeline on plan_styles will be dropped by CASCADE
-- It will be recreated in migration 0098 after table rename

DO $$
BEGIN
  RAISE NOTICE 'Migration 0097 successful: 2 functions dropped (trigger cascade dropped)';
END $$;

COMMIT;
