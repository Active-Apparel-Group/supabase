-- =====================================================
-- Migration: 0007_create_folder_plan_views
-- Description: Add folder/plan views for Phase 1 UI (read-only data surfaces)
-- Author: System
-- Date: 2025-10-23
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 0: Add Missing Columns to Tables
-- =====================================================

-- Add missing columns to plan_styles table
DO $$ 
BEGIN
  -- Add active flag if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'tracking' 
      AND table_name = 'plan_styles' 
      AND column_name = 'active'
  ) THEN
    ALTER TABLE tracking.plan_styles 
    ADD COLUMN active boolean DEFAULT true NOT NULL;
    
    RAISE NOTICE 'Added active column to plan_styles';
  END IF;
END $$;

-- Add missing columns to plan_materials table
DO $$ 
BEGIN
  -- Add active flag if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'tracking' 
      AND table_name = 'plan_materials' 
      AND column_name = 'active'
  ) THEN
    ALTER TABLE tracking.plan_materials 
    ADD COLUMN active boolean DEFAULT true NOT NULL;
    
    RAISE NOTICE 'Added active column to plan_materials';
  END IF;
  
  -- Add bom_references if missing (for BOM linkages)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'tracking' 
      AND table_name = 'plan_materials' 
      AND column_name = 'bom_references'
  ) THEN
    ALTER TABLE tracking.plan_materials 
    ADD COLUMN bom_references jsonb DEFAULT '[]'::jsonb;
    
    RAISE NOTICE 'Added bom_references column to plan_materials';
  END IF;
END $$;

-- Add missing columns to plan_views table for column configuration
DO $$ 
BEGIN
  -- Add description field
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'tracking' 
      AND table_name = 'plan_views' 
      AND column_name = 'description'
  ) THEN
    ALTER TABLE tracking.plan_views 
    ADD COLUMN description text;
    
    RAISE NOTICE 'Added description column to plan_views';
  END IF;
  
  -- Add column_config JSONB for storing column configuration
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'tracking' 
      AND table_name = 'plan_views' 
      AND column_name = 'column_config'
  ) THEN
    ALTER TABLE tracking.plan_views 
    ADD COLUMN column_config jsonb DEFAULT '[]'::jsonb;
    
    RAISE NOTICE 'Added column_config column to plan_views';
  END IF;
  
  -- Add updated_at for tracking changes
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'tracking' 
      AND table_name = 'plan_views' 
      AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE tracking.plan_views 
    ADD COLUMN updated_at timestamptz DEFAULT timezone('utc', now()) NOT NULL;
    
    RAISE NOTICE 'Added updated_at column to plan_views';
  END IF;
END $$;

-- Add comments
COMMENT ON COLUMN tracking.plan_views.description IS 
'Optional description of what this view displays or filters';

COMMENT ON COLUMN tracking.plan_views.column_config IS 
'JSONB array of column configurations. Each element contains: field_key, label, visible, pinned, width_px, sort_order, data_type, format_config';

COMMENT ON COLUMN tracking.plan_styles.active IS 
'Soft delete flag. Set to false to exclude from views without losing data';

COMMENT ON COLUMN tracking.plan_materials.active IS 
'Soft delete flag. Set to false to exclude from views without losing data';

COMMENT ON COLUMN tracking.plan_materials.bom_references IS 
'Array of BOM item references linking this material to production BOMs. Format: [{"bom_item_id": "uuid", "style_id": "uuid", "quantity": number}]';

-- =====================================================
-- SECTION 1: Folder + Plan Overview View
-- =====================================================

-- View: v_folder_plan
-- Purpose: Combined folder + plan list with counts and metadata
-- Endpoint: /rest/v1/tracking_v_folder_plan
-- Usage: Primary data source for folder grid and plan tile views
CREATE OR REPLACE VIEW tracking.v_folder_plan AS
SELECT 
  f.id AS folder_id,
  f.name AS folder_name,
  f.brand,
  f.style_folder_id,
  f.style_folder_name,
  f.active AS folder_active,
  f.created_at AS folder_created_at,
  f.updated_at AS folder_updated_at,
  -- Plan details
  p.id AS plan_id,
  p.name AS plan_name,
  p.season AS plan_season,
  p.brand AS plan_brand,
  p.description AS plan_description,
  p.start_date,
  p.end_date,
  p.active AS plan_active,
  p.template_id,
  p.default_view_id,
  p.suppliers AS plan_suppliers,
  p.timezone,
  p.color_theme,
  p.created_at AS plan_created_at,
  p.created_by AS plan_created_by,
  p.updated_at AS plan_updated_at,
  p.updated_by AS plan_updated_by,
  -- Template metadata
  t.id AS template_id_ref,
  t.name AS template_name,
  t.brand AS template_brand,
  t.season AS template_season,
  t.version AS template_version,
  t.is_active AS template_is_active,
  -- Default view metadata
  pv.id AS default_view_id_ref,
  pv.name AS default_view_name,
  pv.view_type AS default_view_type,
  pv.sort_order AS default_view_sort_order,
  -- Computed counts (subqueries for accuracy)
  (SELECT COUNT(*) FROM tracking.plan_styles ps WHERE ps.plan_id = p.id AND ps.active = true) AS style_count,
  (SELECT COUNT(*) FROM tracking.plan_materials pm WHERE pm.plan_id = p.id AND pm.active = true) AS material_count,
  -- Timeline milestone counts (optional, can be expensive)
  (SELECT COUNT(*) FROM tracking.plan_styles ps 
   JOIN tracking.plan_style_timelines pst ON pst.plan_style_id = ps.id 
   WHERE ps.plan_id = p.id AND ps.active = true) AS style_milestone_count,
  (SELECT COUNT(*) FROM tracking.plan_materials pm 
   JOIN tracking.plan_material_timelines pmt ON pmt.plan_material_id = pm.id 
   WHERE pm.plan_id = p.id AND pm.active = true) AS material_milestone_count
FROM tracking.folders f
LEFT JOIN tracking.plans p ON p.folder_id = f.id
LEFT JOIN tracking.timeline_templates t ON t.id = p.template_id
LEFT JOIN tracking.plan_views pv ON pv.id = p.default_view_id
WHERE f.active = true
ORDER BY f.name, p.start_date DESC NULLS LAST;

COMMENT ON VIEW tracking.v_folder_plan IS 
'Combined folder + plan overview with template metadata and counts. Primary data source for folder/plan landing UI. One row per plan. Filter by folder_id, brand, plan_active.';

-- =====================================================
-- SECTION 2: Plan View Column Configuration
-- =====================================================

-- View: v_folder_plan_columns
-- Purpose: Denormalized column configuration per plan view
-- Endpoint: /rest/v1/tracking_v_folder_plan_columns
-- Usage: Supplies column schema (field list, labels, pins, widths) for grid rendering
CREATE OR REPLACE VIEW tracking.v_folder_plan_columns AS
SELECT 
  pv.id AS view_id,
  pv.plan_id,
  pv.view_type,
  pv.name AS view_name,
  pv.description AS view_description,
  pv.active AS view_active,
  pv.sort_order AS view_sort_order,
  pv.template_id,
  pv.created_at AS view_created_at,
  pv.updated_at AS view_updated_at,
  -- Flattened column metadata from column_config JSONB
  col.field_key,
  col.label,
  col.visible,
  col.pinned,
  col.width_px,
  col.sort_order AS column_sort_order,
  col.data_type,
  col.format_config
FROM tracking.plan_views pv
LEFT JOIN LATERAL jsonb_to_recordset(pv.column_config) AS col(
  field_key text,
  label text,
  visible boolean,
  pinned boolean,
  width_px integer,
  sort_order integer,
  data_type text,
  format_config jsonb
) ON true
WHERE pv.active = true
ORDER BY pv.plan_id, pv.sort_order NULLS LAST, col.sort_order NULLS LAST;

COMMENT ON VIEW tracking.v_folder_plan_columns IS 
'Denormalized column configuration from plan_views.column_config. One row per column per view (or one row per view if column_config is empty). Used by front-end to render grid headers and apply formatting without parsing raw JSON.';

-- =====================================================
-- SECTION 3: Indexes for Performance
-- =====================================================

-- Ensure we have indexes on key join/filter columns
-- (Most should already exist from previous migrations, but adding for completeness)

CREATE INDEX IF NOT EXISTS idx_plans_folder_id_active 
ON tracking.plans(folder_id, active) 
WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_plan_styles_plan_id_active 
ON tracking.plan_styles(plan_id, active) 
WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_plan_materials_plan_id_active 
ON tracking.plan_materials(plan_id, active) 
WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_folders_brand_active 
ON tracking.folders(brand, active) 
WHERE active = true;

-- =====================================================
-- SECTION 4: Security (RLS Policies)
-- =====================================================

-- Note: RLS policies should already exist on base tables (folders, plans, plan_views)
-- Views inherit the security context of the invoker, so if base tables are secured,
-- views will respect those policies automatically.

-- For reference, typical RLS pattern (assuming JWT claims contain brand_ids array):
-- CREATE POLICY folder_brand_access ON tracking.folders
--   FOR SELECT
--   USING (brand = ANY(current_setting('request.jwt.claims', true)::jsonb->'brand_ids'));

-- Verify existing RLS policies are in place:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'tracking' 
      AND tablename = 'folders' 
      AND policyname LIKE '%brand%'
  ) THEN
    RAISE NOTICE 'WARNING: No brand-based RLS policy found on tracking.folders. Add RLS policies to restrict folder access by brand.';
  END IF;
END $$;

COMMIT;

-- =====================================================
-- Post-Migration Verification
-- =====================================================

-- Verify views were created successfully
DO $$
DECLARE
  v_folder_plan_count integer;
  v_folder_plan_columns_count integer;
BEGIN
  -- Check v_folder_plan
  SELECT COUNT(*) INTO v_folder_plan_count
  FROM tracking.v_folder_plan
  LIMIT 1;
  
  RAISE NOTICE 'v_folder_plan created successfully. Sample row count: %', v_folder_plan_count;
  
  -- Check v_folder_plan_columns
  SELECT COUNT(*) INTO v_folder_plan_columns_count
  FROM tracking.v_folder_plan_columns
  LIMIT 1;
  
  RAISE NOTICE 'v_folder_plan_columns created successfully. Sample row count: %', v_folder_plan_columns_count;
END $$;
