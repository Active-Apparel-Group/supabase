-- Migration: Grant permissions on summary views
-- Date: 2025-01-24
-- Description: Grant SELECT permissions on 6 tracking schema summary views to expose them via PostgREST

-- Grant SELECT to anon and authenticated roles
GRANT SELECT ON tracking.tracking_folder_summary TO anon, authenticated;
GRANT SELECT ON tracking.tracking_plan_summary TO anon, authenticated;
GRANT SELECT ON tracking.tracking_plan_style_summary TO anon, authenticated;
GRANT SELECT ON tracking.tracking_plan_material_summary TO anon, authenticated;
GRANT SELECT ON tracking.tracking_plan_style_timeline_detail TO anon, authenticated;
GRANT SELECT ON tracking.tracking_timeline_template_detail TO anon, authenticated;

-- Verification
DO $$
DECLARE
  view_count int;
BEGIN
  SELECT COUNT(*) INTO view_count
  FROM information_schema.table_privileges
  WHERE table_schema = 'tracking'
    AND grantee IN ('anon', 'authenticated')
    AND privilege_type = 'SELECT'
    AND (table_name LIKE '%_summary' OR table_name LIKE '%_detail');
  
  IF view_count < 12 THEN -- 6 views × 2 roles = 12 grants
    RAISE WARNING 'Expected 12 SELECT grants (6 views × 2 roles), found %', view_count;
  END IF;
  
  RAISE NOTICE 'Migration 0104 successful: Summary views now accessible via PostgREST';
  RAISE NOTICE 'Test endpoints: /rest/v1/tracking_folder_summary, /rest/v1/tracking_plan_style_summary';
END $$;
