-- 0106_fix_timeline_detail_views_add_missing_columns.sql
-- Add missing columns to timeline detail views that were accidentally omitted in migration 0105
--
-- PROBLEM:
-- Migration 0105 recreated the timeline detail views but omitted several columns from the base tables:
-- - start_date_plan
-- - start_date_due
-- - duration_value
-- - duration_unit
-- - page_id
-- - request_id
-- - request_code
-- - request_status
-- - shared_with
--
-- SOLUTION:
-- Recreate both views with ALL columns from the base tables

BEGIN;

-- ============================================================================
-- Drop existing views
-- ============================================================================

DROP VIEW IF EXISTS tracking.tracking_plan_style_timeline_detail;
DROP VIEW IF EXISTS tracking.tracking_plan_material_timeline_detail;

-- ============================================================================
-- Recreate tracking_plan_style_timeline_detail with ALL columns
-- ============================================================================

CREATE OR REPLACE VIEW tracking.tracking_plan_style_timeline_detail AS
SELECT 
  pst.id,
  pst.plan_style_id,
  pst.template_item_id,
  pst.status,
  pst.plan_date,
  pst.rev_date,
  pst.final_date,
  pst.due_date,
  pst.completed_date,
  pst.start_date_plan,
  pst.start_date_due,
  pst.duration_value,
  pst.duration_unit,
  pst.late,
  pst.notes,
  pst.page_id,
  pst.page_type,
  pst.page_name,
  pst.request_id,
  pst.request_code,
  pst.request_status,
  pst.timeline_type,
  pst.created_at,
  pst.updated_at,
  pst.shared_with,
  -- Template item details
  ti.name as milestone_name,
  ti.short_name as milestone_short_name,
  ti.phase,
  ti.department,
  ti.display_order,
  ti.node_type,
  ti.required,
  -- Style and plan details
  ps.style_number,
  ps.style_name,
  ps.color_name,
  p.name as plan_name,
  p.brand as plan_brand,
  -- Assignments array
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'assignee_id', ta.assignee_id,
        'source_user_id', ta.source_user_id,
        'role_name', ta.role_name,
        'role_id', ta.role_id,
        'assigned_at', ta.assigned_at
      )
    ) FILTER (WHERE ta.assignee_id IS NOT NULL),
    '[]'::jsonb
  ) as assignments
FROM tracking.tracking_plan_style_timeline pst
LEFT JOIN tracking.tracking_timeline_template_item ti ON pst.template_item_id = ti.id
LEFT JOIN tracking.tracking_plan_style ps ON pst.plan_style_id = ps.id
LEFT JOIN tracking.tracking_plan p ON ps.plan_id = p.id
LEFT JOIN tracking.tracking_timeline_assignment ta ON pst.id = ta.timeline_id
GROUP BY 
  pst.id, pst.plan_style_id, pst.template_item_id, pst.status, pst.plan_date,
  pst.rev_date, pst.final_date, pst.due_date, pst.completed_date,
  pst.start_date_plan, pst.start_date_due, pst.duration_value, pst.duration_unit,
  pst.late, pst.notes, pst.page_id, pst.page_type, pst.page_name,
  pst.request_id, pst.request_code, pst.request_status,
  pst.timeline_type, pst.created_at, pst.updated_at, pst.shared_with,
  ti.name, ti.short_name, ti.phase, ti.department, ti.display_order, ti.node_type, ti.required,
  ps.style_number, ps.style_name, ps.color_name, p.name, p.brand;

COMMENT ON VIEW tracking.tracking_plan_style_timeline_detail IS 
'Read-only view: Style timelines with ALL base table columns plus template item, style, and plan details. Use tracking_plan_style_timeline for CRUD operations.';

-- ============================================================================
-- Recreate tracking_plan_material_timeline_detail with ALL columns
-- ============================================================================

CREATE OR REPLACE VIEW tracking.tracking_plan_material_timeline_detail AS
SELECT 
  pmt.id,
  pmt.plan_material_id,
  pmt.template_item_id,
  pmt.status,
  pmt.plan_date,
  pmt.rev_date,
  pmt.final_date,
  pmt.due_date,
  pmt.completed_date,
  pmt.start_date_plan,
  pmt.start_date_due,
  pmt.duration_value,
  pmt.duration_unit,
  pmt.late,
  pmt.notes,
  pmt.page_id,
  pmt.page_type,
  pmt.page_name,
  pmt.request_id,
  pmt.request_code,
  pmt.request_status,
  pmt.timeline_type,
  pmt.created_at,
  pmt.updated_at,
  pmt.shared_with,
  -- Template item details
  ti.name as milestone_name,
  ti.short_name as milestone_short_name,
  ti.phase,
  ti.department,
  ti.display_order,
  ti.node_type,
  ti.required,
  -- Material and plan details
  pm.material_number,
  pm.material_name,
  pm.color_name,
  p.name as plan_name,
  p.brand as plan_brand,
  -- Assignments array
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'assignee_id', ta.assignee_id,
        'source_user_id', ta.source_user_id,
        'role_name', ta.role_name,
        'role_id', ta.role_id,
        'assigned_at', ta.assigned_at
      )
    ) FILTER (WHERE ta.assignee_id IS NOT NULL),
    '[]'::jsonb
  ) as assignments
FROM tracking.tracking_plan_material_timeline pmt
LEFT JOIN tracking.tracking_timeline_template_item ti ON pmt.template_item_id = ti.id
LEFT JOIN tracking.tracking_plan_material pm ON pmt.plan_material_id = pm.id
LEFT JOIN tracking.tracking_plan p ON pm.plan_id = p.id
LEFT JOIN tracking.tracking_timeline_assignment ta ON pmt.id = ta.timeline_id
GROUP BY 
  pmt.id, pmt.plan_material_id, pmt.template_item_id, pmt.status, pmt.plan_date,
  pmt.rev_date, pmt.final_date, pmt.due_date, pmt.completed_date,
  pmt.start_date_plan, pmt.start_date_due, pmt.duration_value, pmt.duration_unit,
  pmt.late, pmt.notes, pmt.page_id, pmt.page_type, pmt.page_name,
  pmt.request_id, pmt.request_code, pmt.request_status,
  pmt.timeline_type, pmt.created_at, pmt.updated_at, pmt.shared_with,
  ti.name, ti.short_name, ti.phase, ti.department, ti.display_order, ti.node_type, ti.required,
  pm.material_number, pm.material_name, pm.color_name, p.name, p.brand;

COMMENT ON VIEW tracking.tracking_plan_material_timeline_detail IS 
'Read-only view: Material timelines with ALL base table columns plus template item, material, and plan details. Use tracking_plan_material_timeline for CRUD operations.';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
  v_style_column_count integer;
  v_material_column_count integer;
BEGIN
  -- Check style view has all columns
  SELECT COUNT(*) INTO v_style_column_count
  FROM information_schema.columns
  WHERE table_schema = 'tracking'
    AND table_name = 'tracking_plan_style_timeline_detail'
    AND column_name IN ('start_date_plan', 'start_date_due', 'duration_value', 'duration_unit', 'page_id', 'request_id', 'shared_with');
  
  IF v_style_column_count < 7 THEN
    RAISE EXCEPTION 'Style timeline detail view missing columns (found %, expected 7)', v_style_column_count;
  END IF;
  
  -- Check material view has all columns
  SELECT COUNT(*) INTO v_material_column_count
  FROM information_schema.columns
  WHERE table_schema = 'tracking'
    AND table_name = 'tracking_plan_material_timeline_detail'
    AND column_name IN ('start_date_plan', 'start_date_due', 'duration_value', 'duration_unit', 'page_id', 'request_id', 'shared_with');
  
  IF v_material_column_count < 7 THEN
    RAISE EXCEPTION 'Material timeline detail view missing columns (found %, expected 7)', v_material_column_count;
  END IF;
  
  RAISE NOTICE '✅ Migration 0106 complete: Timeline detail views now include all base table columns';
END $$;

COMMIT;
