-- 0105_simplify_timeline_assignment_pk.sql
-- Simplify tracking_timeline_assignment primary key and remove redundant timeline_type column
--
-- PROBLEM:
-- 1. timeline_type is redundant (can infer from timeline_id's source table)
-- 2. assignee_id in PK prevents NULL values (assignments created after timelines)
-- 3. Composite PK prevents updating assignees (must delete + re-insert)
--
-- SOLUTION:
-- 1. Drop composite PK (timeline_id, timeline_type, assignee_id)
-- 2. Add auto-increment id column as new PK
-- 3. Remove timeline_type column entirely
-- 4. Keep timeline_id indexed for fast lookups
-- 5. Update summary view to remove timeline_type filter

BEGIN;

-- ============================================================================
-- STEP 1: Drop dependent views (will recreate later)
-- ============================================================================

DROP VIEW IF EXISTS tracking.tracking_plan_style_timeline_detail;
DROP VIEW IF EXISTS tracking.tracking_plan_material_timeline_detail;

-- ============================================================================
-- STEP 2: Drop existing PK constraint
-- ============================================================================

ALTER TABLE tracking.tracking_timeline_assignment 
  DROP CONSTRAINT timeline_assignments_pkey;

-- ============================================================================
-- STEP 3: Add auto-increment ID column as new PK
-- ============================================================================

ALTER TABLE tracking.tracking_timeline_assignment
  ADD COLUMN id BIGSERIAL PRIMARY KEY;

-- ============================================================================
-- STEP 4: Drop timeline_type column (redundant)
-- ============================================================================

ALTER TABLE tracking.tracking_timeline_assignment
  DROP COLUMN timeline_type;

-- ============================================================================
-- STEP 5: Allow NULL values for assignee_id (assignments may not exist yet)
-- ============================================================================

ALTER TABLE tracking.tracking_timeline_assignment
  ALTER COLUMN assignee_id DROP NOT NULL;

-- ============================================================================
-- STEP 6: Ensure timeline_id has index for fast lookups
-- ============================================================================

-- Check if index already exists, create if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'tracking' 
      AND tablename = 'tracking_timeline_assignment' 
      AND indexname = 'idx_timeline_assignment_timeline_id'
  ) THEN
    CREATE INDEX idx_timeline_assignment_timeline_id 
      ON tracking.tracking_timeline_assignment (timeline_id);
  END IF;
END $$;

-- ============================================================================
-- STEP 7: Recreate views WITHOUT timeline_type filter
-- ============================================================================

-- VIEW: tracking_plan_style_timeline_detail
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
  -- Style and plan details
  ps.style_number,
  ps.style_name,
  ps.color_name,
  p.name as plan_name,
  p.brand as plan_brand,
  -- Assignments array (no timeline_type filter needed!)
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
  pst.rev_date, pst.final_date, pst.due_date, pst.completed_date, pst.late,
  pst.notes, pst.page_type, pst.page_name, pst.timeline_type, pst.created_at, pst.updated_at,
  ti.name, ti.short_name, ti.phase, ti.department, ti.display_order, ti.node_type, ti.required,
  ps.style_number, ps.style_name, ps.color_name, p.name, p.brand;

COMMENT ON VIEW tracking.tracking_plan_style_timeline_detail IS 
'Read-only view: Style timelines with template item, style, and plan details. Use tracking_plan_style_timeline for CRUD operations.';

-- VIEW: tracking_plan_material_timeline_detail
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
  pmt.page_type,
  pmt.page_name,
  pmt.timeline_type,
  pmt.created_at,
  pmt.updated_at,
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
  -- Assignments array (no timeline_type filter needed!)
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
  pmt.rev_date, pmt.final_date, pmt.due_date, pmt.completed_date, pmt.start_date_plan,
  pmt.start_date_due, pmt.duration_value, pmt.duration_unit, pmt.late, pmt.notes,
  pmt.page_type, pmt.page_name, pmt.timeline_type, pmt.created_at, pmt.updated_at,
  ti.name, ti.short_name, ti.phase, ti.department, ti.display_order, ti.node_type, ti.required,
  pm.material_number, pm.material_name, pm.color_name, p.name, p.brand;

COMMENT ON VIEW tracking.tracking_plan_material_timeline_detail IS 
'Read-only view: Material timelines with template item, material, and plan details. Use tracking_plan_material_timeline for CRUD operations.';

-- ============================================================================
-- STEP 8: Update table comment
-- ============================================================================

COMMENT ON TABLE tracking.tracking_timeline_assignment IS 
'Assigns users/roles to timeline milestones. Simplified PK (id) allows NULL assignee_id and easy updates. No timeline_type needed (inferred from timeline_id source).';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  v_new_pk_count integer;
  v_index_count integer;
  v_column_exists boolean;
BEGIN
  -- Check new PK exists (any PK on id column is fine)
  SELECT COUNT(*) INTO v_new_pk_count
  FROM pg_constraint c
  JOIN pg_class cl ON cl.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = cl.relnamespace
  WHERE cl.relname = 'tracking_timeline_assignment'
    AND n.nspname = 'tracking'
    AND c.contype = 'p';
  
  IF v_new_pk_count = 0 THEN
    RAISE EXCEPTION 'New PK not created on tracking_timeline_assignment';
  END IF;
  
  -- Check timeline_type column removed
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'tracking' 
      AND table_name = 'tracking_timeline_assignment' 
      AND column_name = 'timeline_type'
  ) INTO v_column_exists;
  
  IF v_column_exists THEN
    RAISE EXCEPTION 'timeline_type column still exists';
  END IF;
  
  -- Check view recreated
  SELECT COUNT(*) INTO v_index_count
  FROM information_schema.views
  WHERE table_schema = 'tracking'
    AND table_name IN ('tracking_plan_style_timeline_detail', 'tracking_plan_material_timeline_detail');
  
  IF v_index_count < 2 THEN
    RAISE EXCEPTION 'Views not recreated (found %, expected 2)', v_index_count;
  END IF;
  
  RAISE NOTICE '✅ Migration 0105 complete: PK simplified, timeline_type removed, view updated';
END $$;

COMMIT;
