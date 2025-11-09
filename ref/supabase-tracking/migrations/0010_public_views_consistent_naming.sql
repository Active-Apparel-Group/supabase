-- =====================================================
-- Migration: 0010_public_views_consistent_naming
-- Description: Create public views with consistent naming for PostgREST endpoints
-- Author: System
-- Date: 2025-10-23
-- =====================================================

BEGIN;

-- Remove old public views if they exist
DROP VIEW IF EXISTS public.folders;
DROP VIEW IF EXISTS public.folder_plans;
DROP VIEW IF EXISTS public.folder_plan_columns;

-- Create public views with consistent naming
CREATE OR REPLACE VIEW public.v_folders AS
SELECT * FROM tracking.v_folders;

CREATE OR REPLACE VIEW public.v_folder_plan AS
SELECT * FROM tracking.v_folder_plan;

CREATE OR REPLACE VIEW public.v_folder_plan_columns AS
SELECT * FROM tracking.v_folder_plan_columns;

-- Grant SELECT permissions
GRANT SELECT ON public.v_folders TO anon, authenticated;
GRANT SELECT ON public.v_folder_plan TO anon, authenticated;
GRANT SELECT ON public.v_folder_plan_columns TO anon, authenticated;

COMMIT;
