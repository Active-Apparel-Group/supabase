-- Migration: 0103_create_tracking_summary_views
-- Description: Create tracking schema views with aggregates and joins for frontend consumption
-- Date: 2025-10-24
-- Purpose: Provide rich read-only views while maintaining clean base tables for CRUD
-- Pattern: Base tables for writes, summary views for reads

BEGIN;

-- ============================================================================
-- VIEW 1: tracking_folder_summary
-- Provides folder with plan counts
-- ============================================================================

CREATE OR REPLACE VIEW tracking.tracking_folder_summary AS
SELECT 
  f.id,
  f.name,
  f.brand,
  f.style_folder_id,
  f.style_folder_name,
  f.active,
  f.created_at,
  f.updated_at,
  COUNT(DISTINCT p.id) FILTER (WHERE p.active = true) as active_plan_count,
  COUNT(DISTINCT p.id) as total_plan_count
FROM tracking.tracking_folder f
LEFT JOIN tracking.tracking_plan p ON f.id = p.folder_id
GROUP BY f.id, f.name, f.brand, f.style_folder_id, f.style_folder_name, f.active, f.created_at, f.updated_at;

COMMENT ON VIEW tracking.tracking_folder_summary IS 
'Read-only view: Folders with plan counts. Use tracking_folder for CRUD operations.';

-- ============================================================================
-- VIEW 2: tracking_plan_summary
-- Provides plan with folder, template, and entity counts
-- ============================================================================

CREATE OR REPLACE VIEW tracking.tracking_plan_summary AS
SELECT 
  p.id,
  p.folder_id,
  p.name,
  p.active,
  p.season,
  p.brand,
  p.start_date,
  p.end_date,
  p.description,
  p.template_id,
  p.timezone,
  p.created_at,
  p.updated_at,
  -- Joined data
  f.name as folder_name,
  f.brand as folder_brand,
  t.name as template_name,
  -- Aggregates
  COUNT(DISTINCT ps.id) FILTER (WHERE ps.active = true) as style_count,
  COUNT(DISTINCT pm.id) FILTER (WHERE pm.active = true) as material_count,
  COUNT(DISTINCT pv.id) FILTER (WHERE pv.active = true) as view_count
FROM tracking.tracking_plan p
LEFT JOIN tracking.tracking_folder f ON p.folder_id = f.id
LEFT JOIN tracking.tracking_timeline_template t ON p.template_id = t.id
LEFT JOIN tracking.tracking_plan_style ps ON p.id = ps.plan_id
LEFT JOIN tracking.tracking_plan_material pm ON p.id = pm.plan_id
LEFT JOIN tracking.tracking_plan_view pv ON p.id = pv.plan_id
GROUP BY 
  p.id, p.folder_id, p.name, p.active, p.season, p.brand, 
  p.start_date, p.end_date, p.description, p.template_id, p.timezone,
  p.created_at, p.updated_at, f.name, f.brand, t.name;

COMMENT ON VIEW tracking.tracking_plan_summary IS 
'Read-only view: Plans with folder/template joins and entity counts. Use tracking_plan for CRUD operations.';

-- ============================================================================
-- VIEW 3: tracking_plan_style_summary
-- Provides style with plan info and milestone aggregates
-- ============================================================================

CREATE OR REPLACE VIEW tracking.tracking_plan_style_summary AS
SELECT 
  ps.id,
  ps.plan_id,
  ps.view_id,
  ps.style_id,
  ps.style_header_id,
  ps.color_id,
  ps.style_number,
  ps.style_name,
  ps.color_name,
  ps.season,
  ps.delivery,
  ps.factory,
  ps.supplier_id,
  ps.supplier_name,
  ps.brand,
  ps.active,
  ps.created_at,
  ps.updated_at,
  -- Joined data
  p.name as plan_name,
  p.brand as plan_brand,
  f.name as folder_name,
  -- Milestone aggregates
  COUNT(pst.id) as milestones_total,
  COUNT(pst.id) FILTER (WHERE pst.status IN ('COMPLETE', 'APPROVED')) as milestones_completed,
  COUNT(pst.id) FILTER (WHERE pst.status = 'IN_PROGRESS') as milestones_in_progress,
  COUNT(pst.id) FILTER (WHERE pst.status = 'NOT_STARTED') as milestones_not_started,
  COUNT(pst.id) FILTER (WHERE pst.late = true AND pst.status NOT IN ('COMPLETE', 'APPROVED')) as milestones_late,
  COUNT(pst.id) FILTER (WHERE pst.status = 'BLOCKED') as milestones_blocked,
  -- Status breakdown JSON
  jsonb_build_object(
    'NOT_STARTED', COUNT(pst.id) FILTER (WHERE pst.status = 'NOT_STARTED'),
    'IN_PROGRESS', COUNT(pst.id) FILTER (WHERE pst.status = 'IN_PROGRESS'),
    'COMPLETE', COUNT(pst.id) FILTER (WHERE pst.status = 'COMPLETE'),
    'APPROVED', COUNT(pst.id) FILTER (WHERE pst.status = 'APPROVED'),
    'REJECTED', COUNT(pst.id) FILTER (WHERE pst.status = 'REJECTED'),
    'BLOCKED', COUNT(pst.id) FILTER (WHERE pst.status = 'BLOCKED')
  ) as status_breakdown
FROM tracking.tracking_plan_style ps
LEFT JOIN tracking.tracking_plan p ON ps.plan_id = p.id
LEFT JOIN tracking.tracking_folder f ON p.folder_id = f.id
LEFT JOIN tracking.tracking_plan_style_timeline pst ON ps.id = pst.plan_style_id
GROUP BY 
  ps.id, ps.plan_id, ps.view_id, ps.style_id, ps.style_header_id, ps.color_id,
  ps.style_number, ps.style_name, ps.color_name, ps.season, ps.delivery,
  ps.factory, ps.supplier_id, ps.supplier_name, ps.brand, ps.active,
  ps.created_at, ps.updated_at, p.name, p.brand, f.name;

COMMENT ON VIEW tracking.tracking_plan_style_summary IS 
'Read-only view: Styles with plan/folder joins and milestone aggregates. Use tracking_plan_style for CRUD operations.';

-- ============================================================================
-- VIEW 4: tracking_plan_material_summary
-- Provides material with plan info and milestone aggregates
-- ============================================================================

CREATE OR REPLACE VIEW tracking.tracking_plan_material_summary AS
SELECT 
  pm.id,
  pm.plan_id,
  pm.view_id,
  pm.material_id,
  pm.material_header_id,
  pm.color_id,
  pm.material_number,
  pm.material_name,
  pm.color_name,
  pm.supplier_id,
  pm.supplier_name,
  pm.active,
  pm.created_at,
  pm.updated_at,
  -- Joined data
  p.name as plan_name,
  p.brand as plan_brand,
  f.name as folder_name,
  -- Milestone aggregates
  COUNT(pmt.id) as milestones_total,
  COUNT(pmt.id) FILTER (WHERE pmt.status IN ('COMPLETE', 'APPROVED')) as milestones_completed,
  COUNT(pmt.id) FILTER (WHERE pmt.status = 'IN_PROGRESS') as milestones_in_progress,
  COUNT(pmt.id) FILTER (WHERE pmt.status = 'NOT_STARTED') as milestones_not_started,
  COUNT(pmt.id) FILTER (WHERE pmt.late = true AND pmt.status NOT IN ('COMPLETE', 'APPROVED')) as milestones_late,
  COUNT(pmt.id) FILTER (WHERE pmt.status = 'BLOCKED') as milestones_blocked,
  -- Status breakdown JSON
  jsonb_build_object(
    'NOT_STARTED', COUNT(pmt.id) FILTER (WHERE pmt.status = 'NOT_STARTED'),
    'IN_PROGRESS', COUNT(pmt.id) FILTER (WHERE pmt.status = 'IN_PROGRESS'),
    'COMPLETE', COUNT(pmt.id) FILTER (WHERE pmt.status = 'COMPLETE'),
    'APPROVED', COUNT(pmt.id) FILTER (WHERE pmt.status = 'APPROVED'),
    'REJECTED', COUNT(pmt.id) FILTER (WHERE pmt.status = 'REJECTED'),
    'BLOCKED', COUNT(pmt.id) FILTER (WHERE pmt.status = 'BLOCKED')
  ) as status_breakdown
FROM tracking.tracking_plan_material pm
LEFT JOIN tracking.tracking_plan p ON pm.plan_id = p.id
LEFT JOIN tracking.tracking_folder f ON p.folder_id = f.id
LEFT JOIN tracking.tracking_plan_material_timeline pmt ON pm.id = pmt.plan_material_id
GROUP BY 
  pm.id, pm.plan_id, pm.view_id, pm.material_id, pm.material_header_id, pm.color_id,
  pm.material_number, pm.material_name, pm.color_name, pm.supplier_id, pm.supplier_name,
  pm.active, pm.created_at, pm.updated_at, p.name, p.brand, f.name;

COMMENT ON VIEW tracking.tracking_plan_material_summary IS 
'Read-only view: Materials with plan/folder joins and milestone aggregates. Use tracking_plan_material for CRUD operations.';

-- ============================================================================
-- VIEW 5: tracking_plan_style_timeline_detail
-- Provides timeline with template item details and assignment info
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
  pst.late,
  pst.notes,
  pst.page_type,
  pst.page_name,
  pst.timeline_type,
  pst.created_at,
  pst.updated_at,
  -- Template item details
  ti.name as milestone_name,
  ti.short_name as milestone_short_name,
  ti.phase,
  ti.department,
  ti.display_order,
  ti.node_type,
  ti.required,
  -- Style details
  ps.style_number,
  ps.style_name,
  ps.color_name,
  -- Plan details
  p.name as plan_name,
  p.brand as plan_brand,
  -- Assignments (aggregated)
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'assignee_id', ta.assignee_id,
        'role_name', ta.role_name,
        'assigned_at', ta.assigned_at
      )
    ) FILTER (WHERE ta.assignee_id IS NOT NULL),
    '[]'::jsonb
  ) as assignments
FROM tracking.tracking_plan_style_timeline pst
LEFT JOIN tracking.tracking_timeline_template_item ti ON pst.template_item_id = ti.id
LEFT JOIN tracking.tracking_plan_style ps ON pst.plan_style_id = ps.id
LEFT JOIN tracking.tracking_plan p ON ps.plan_id = p.id
LEFT JOIN tracking.tracking_timeline_assignment ta ON pst.id = ta.timeline_id AND ta.timeline_type = 'STYLE'
GROUP BY 
  pst.id, pst.plan_style_id, pst.template_item_id, pst.status, pst.plan_date,
  pst.rev_date, pst.final_date, pst.due_date, pst.completed_date, pst.late,
  pst.notes, pst.page_type, pst.page_name, pst.timeline_type, pst.created_at, pst.updated_at,
  ti.name, ti.short_name, ti.phase, ti.department, ti.display_order, ti.node_type, ti.required,
  ps.style_number, ps.style_name, ps.color_name, p.name, p.brand;

COMMENT ON VIEW tracking.tracking_plan_style_timeline_detail IS 
'Read-only view: Style timelines with template item, style, and plan details. Use tracking_plan_style_timeline for CRUD operations.';

-- ============================================================================
-- VIEW 6: tracking_timeline_template_detail
-- Provides template with item counts and brand/season info
-- ============================================================================

CREATE OR REPLACE VIEW tracking.tracking_timeline_template_detail AS
SELECT 
  t.id,
  t.name,
  t.brand,
  t.season,
  t.version,
  t.is_active,
  t.timezone,
  t.anchor_strategy,
  t.created_at,
  t.updated_at,
  -- Item counts
  COUNT(ti.id) as total_items,
  COUNT(ti.id) FILTER (WHERE ti.applies_to_style = true) as style_items,
  COUNT(ti.id) FILTER (WHERE ti.applies_to_material = true) as material_items,
  COUNT(ti.id) FILTER (WHERE ti.node_type = 'ANCHOR') as anchor_count,
  COUNT(ti.id) FILTER (WHERE ti.node_type = 'TASK') as task_count
FROM tracking.tracking_timeline_template t
LEFT JOIN tracking.tracking_timeline_template_item ti ON t.id = ti.template_id
GROUP BY 
  t.id, t.name, t.brand, t.season, t.version, t.is_active, t.timezone,
  t.anchor_strategy, t.created_at, t.updated_at;

COMMENT ON VIEW tracking.tracking_timeline_template_detail IS 
'Read-only view: Templates with item counts. Use tracking_timeline_template for CRUD operations.';

-- ============================================================================
-- GRANT PERMISSIONS ON VIEWS
-- ============================================================================

GRANT SELECT ON tracking.tracking_folder_summary TO anon, authenticated;
GRANT SELECT ON tracking.tracking_plan_summary TO anon, authenticated;
GRANT SELECT ON tracking.tracking_plan_style_summary TO anon, authenticated;
GRANT SELECT ON tracking.tracking_plan_material_summary TO anon, authenticated;
GRANT SELECT ON tracking.tracking_plan_style_timeline_detail TO anon, authenticated;
GRANT SELECT ON tracking.tracking_timeline_template_detail TO anon, authenticated;

-- ============================================================================
-- ENABLE RLS ON VIEWS (inherit from base tables)
-- ============================================================================

ALTER VIEW tracking.tracking_folder_summary SET (security_invoker = true);
ALTER VIEW tracking.tracking_plan_summary SET (security_invoker = true);
ALTER VIEW tracking.tracking_plan_style_summary SET (security_invoker = true);
ALTER VIEW tracking.tracking_plan_material_summary SET (security_invoker = true);
ALTER VIEW tracking.tracking_plan_style_timeline_detail SET (security_invoker = true);
ALTER VIEW tracking.tracking_timeline_template_detail SET (security_invoker = true);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  view_count int;
BEGIN
  SELECT COUNT(*) INTO view_count
  FROM information_schema.views
  WHERE table_schema = 'tracking'
    AND table_name LIKE '%_summary'
    OR table_name LIKE '%_detail';
  
  IF view_count < 6 THEN
    RAISE EXCEPTION 'View verification failed: expected 6 summary/detail views, found %', view_count;
  END IF;
  
  RAISE NOTICE 'Migration 0103 successful: 6 summary/detail views created in tracking schema';
  RAISE NOTICE 'Frontend can now use summary views for reads, base tables for writes';
END $$;

COMMIT;
