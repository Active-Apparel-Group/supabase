-- =====================================================
-- Migration: 0008_create_folders_view
-- Description: Add tracking_folders view for folder listing endpoint
-- Author: System
-- Date: 2025-10-23
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: Folders List View
-- =====================================================

-- View: v_folders
-- Purpose: Folder list with plan counts for folder discovery UI
-- Endpoint: /rest/v1/tracking_folders
-- Usage: Primary endpoint for folder listing (BeProduct folderList analog)
-- Notes: Base table 'folders' already exists; this view adds computed counts

CREATE OR REPLACE VIEW tracking.v_folders AS
SELECT 
  f.id AS folder_id,
  f.name AS folder_name,
  f.brand,
  f.style_folder_id,
  f.style_folder_name,
  f.active,
  f.created_at,
  f.updated_at,
  -- Computed aggregates
  (SELECT COUNT(*) 
   FROM tracking.plans p 
   WHERE p.folder_id = f.id 
     AND p.active = true) AS active_plan_count,
  (SELECT COUNT(*) 
   FROM tracking.plans p 
   WHERE p.folder_id = f.id) AS total_plan_count,
  -- Latest plan date for sorting
  (SELECT MAX(p.start_date) 
   FROM tracking.plans p 
   WHERE p.folder_id = f.id 
     AND p.active = true) AS latest_plan_date,
  -- Season summary (comma-separated list of unique seasons from active plans)
  (SELECT string_agg(DISTINCT p.season, ', ' ORDER BY p.season) 
   FROM tracking.plans p 
   WHERE p.folder_id = f.id 
     AND p.active = true 
     AND p.season IS NOT NULL) AS active_seasons
FROM tracking.folders f
WHERE f.active = true
ORDER BY f.name;

COMMENT ON VIEW tracking.v_folders IS 
'Folder list with plan counts and season summary. BeProduct folderList analog. Filter by brand, style_folder_id. Use for folder discovery UI.';

-- =====================================================
-- SECTION 2: Indexes for Performance
-- =====================================================

-- Ensure we have index on brand for folder filtering
-- (Should already exist, but adding for completeness)
CREATE INDEX IF NOT EXISTS idx_folders_brand 
ON tracking.folders(brand) 
WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_folders_style_folder_id 
ON tracking.folders(style_folder_id) 
WHERE style_folder_id IS NOT NULL;

-- =====================================================
-- SECTION 3: PostgREST Endpoint Configuration
-- =====================================================

-- Note: PostgREST will auto-expose this view at /rest/v1/tracking_v_folders
-- To match the API plan endpoint name /rest/v1/tracking_folders, 
-- front-end should use the view name directly

-- Example queries:
-- GET /rest/v1/tracking_v_folders
-- GET /rest/v1/tracking_v_folders?brand=eq.GREYSON
-- GET /rest/v1/tracking_v_folders?select=folder_id,folder_name,active_plan_count
-- GET /rest/v1/tracking_v_folders?order=folder_name.asc

COMMIT;

-- =====================================================
-- Post-Migration Verification
-- =====================================================

-- Verify view was created successfully
DO $$
DECLARE
  v_folder_count integer;
BEGIN
  SELECT COUNT(*) INTO v_folder_count
  FROM tracking.v_folders;
  
  RAISE NOTICE 'v_folders created successfully. Total folders: %', v_folder_count;
  
  -- Show sample data
  RAISE NOTICE 'Sample folder data:';
  PERFORM folder_id, folder_name, brand, active_plan_count, active_seasons
  FROM tracking.v_folders
  LIMIT 3;
END $$;
