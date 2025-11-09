-- Migration: 0096_drop_all_views_first
-- Description: Drop all public and tracking schema views before table rename
-- Date: 2025-10-24
-- Purpose: Prevent cascade failures when renaming tables (views can't follow renames)
-- Breaking: Removes public.timeline_templates, all v_* endpoints

BEGIN;

-- Drop public views (10 views total - includes forgotten timeline_templates)
DROP VIEW IF EXISTS public.v_folder CASCADE;
DROP VIEW IF EXISTS public.v_folder_plan CASCADE;
DROP VIEW IF EXISTS public.v_plan_styles CASCADE;
DROP VIEW IF EXISTS public.v_plan_style_timelines_enriched CASCADE;
DROP VIEW IF EXISTS public.v_plan_materials CASCADE;
DROP VIEW IF EXISTS public.v_plan_material_timelines_enriched CASCADE;
DROP VIEW IF EXISTS public.v_timeline_templates CASCADE;
DROP VIEW IF EXISTS public.v_timeline_template_items CASCADE;
DROP VIEW IF EXISTS public.v_plan_views CASCADE;
DROP VIEW IF EXISTS public.timeline_templates CASCADE;  -- Not prefixed with v_!

-- Drop tracking schema internal views (9 views - will recreate later if needed)
DROP VIEW IF EXISTS tracking.v_folder CASCADE;
DROP VIEW IF EXISTS tracking.v_folder_plan CASCADE;
DROP VIEW IF EXISTS tracking.v_folder_plan_columns CASCADE;
DROP VIEW IF EXISTS tracking.v_plan_styles CASCADE;
DROP VIEW IF EXISTS tracking.v_plan_style_timelines_enriched CASCADE;
DROP VIEW IF EXISTS tracking.v_plan_materials CASCADE;
DROP VIEW IF EXISTS tracking.v_plan_material_timelines_enriched CASCADE;
DROP VIEW IF EXISTS tracking.v_timeline_template CASCADE;
DROP VIEW IF EXISTS tracking.v_timeline_template_item CASCADE;

-- Verify all tracking-related public views are gone
DO $$
DECLARE
  remaining_public_views int;
  remaining_tracking_views int;
BEGIN
  SELECT COUNT(*) INTO remaining_public_views
  FROM information_schema.views
  WHERE table_schema = 'public' 
    AND (table_name LIKE 'v_%' OR table_name = 'timeline_templates');
  
  SELECT COUNT(*) INTO remaining_tracking_views
  FROM information_schema.views
  WHERE table_schema = 'tracking'
    AND table_name LIKE 'v_%';
  
  IF remaining_public_views > 0 OR remaining_tracking_views > 0 THEN
    RAISE EXCEPTION 'Migration verification failed: % public views, % tracking views still exist', 
      remaining_public_views, remaining_tracking_views;
  END IF;
  
  RAISE NOTICE 'Migration 0096 successful: 19 views dropped (10 public + 9 tracking)';
END $$;

COMMIT;
