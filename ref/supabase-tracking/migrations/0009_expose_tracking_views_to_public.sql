-- =====================================================
-- Migration: 0009_expose_tracking_views_to_public
-- Description: Create public views that reference tracking schema views to expose them via PostgREST
-- Author: System
-- Date: 2025-10-23
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: Remove old public views
-- =====================================================
DROP VIEW IF EXISTS public.folders;
DROP VIEW IF EXISTS public.folder_plans;
DROP VIEW IF EXISTS public.folder_plan_columns;

-- =====================================================
-- SECTION 2: Create public views with consistent naming
-- =====================================================
CREATE OR REPLACE VIEW public.v_folders AS
SELECT * FROM tracking.v_folders;

COMMENT ON VIEW public.v_folders IS 
'Public view exposing tracking.v_folders for PostgREST API access. Endpoint: /rest/v1/v_folders';

CREATE OR REPLACE VIEW public.v_folder_plan AS
SELECT * FROM tracking.v_folder_plan;

COMMENT ON VIEW public.v_folder_plan IS 
'Public view exposing tracking.v_folder_plan for PostgREST API access. Endpoint: /rest/v1/v_folder_plan';

CREATE OR REPLACE VIEW public.v_folder_plan_columns AS
SELECT * FROM tracking.v_folder_plan_columns;

COMMENT ON VIEW public.v_folder_plan_columns IS 
'Public view exposing tracking.v_folder_plan_columns for PostgREST API access. Endpoint: /rest/v1/v_folder_plan_columns';

-- =====================================================
-- SECTION 3: Grant permissions to anon and authenticated roles
-- =====================================================
GRANT SELECT ON public.v_folders TO anon;
GRANT SELECT ON public.v_folder_plan TO anon;
GRANT SELECT ON public.v_folder_plan_columns TO anon;

GRANT SELECT ON public.v_folders TO authenticated;
GRANT SELECT ON public.v_folder_plan TO authenticated;
GRANT SELECT ON public.v_folder_plan_columns TO authenticated;

-- =====================================================
-- SECTION 4: Create RLS policies for public views
-- =====================================================
ALTER TABLE public.v_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v_folder_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v_folder_plan_columns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access to v_folders" ON public.v_folders
  FOR SELECT USING (true);

CREATE POLICY "Allow read access to v_folder_plan" ON public.v_folder_plan
  FOR SELECT USING (true);

CREATE POLICY "Allow read access to v_folder_plan_columns" ON public.v_folder_plan_columns
  FOR SELECT USING (true);

COMMIT;

-- =====================================================
-- Post-Migration Verification
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE 'Testing public views...';
  PERFORM COUNT(*) FROM public.v_folders;
  RAISE NOTICE 'public.v_folders accessible';
  PERFORM COUNT(*) FROM public.v_folder_plan;
  RAISE NOTICE 'public.v_folder_plan accessible';
  PERFORM COUNT(*) FROM public.v_folder_plan_columns;
  RAISE NOTICE 'public.v_folder_plan_columns accessible';
  RAISE NOTICE 'All public views created successfully!';
END $$;