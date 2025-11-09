-- Migration: 0102_enable_rls_with_permissive_policies
-- Description: Enable RLS on all tracking tables with temporary "allow all" policies
-- Date: 2025-10-24
-- Purpose: Expose PostgREST endpoints immediately while maintaining RLS framework for Phase 4
-- Security: Permissive policies grant full access - REPLACE with brand-scoped policies in Phase 4

BEGIN;

-- ============================================================================
-- PART 1: ENABLE RLS ON ALL TRACKING TABLES
-- ============================================================================

ALTER TABLE tracking.tracking_folder ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_folder_style_link ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_view ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_style ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_style_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_style_dependency ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_material ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_material_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_material_dependency ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_timeline_template ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_timeline_template_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_timeline_template_visibility ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_timeline_assignment ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_timeline_status_history ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PART 2: CREATE PERMISSIVE POLICIES (TEMPORARY - PHASE 1 ONLY)
-- ============================================================================

-- Folder policies (allow all)
CREATE POLICY "temp_allow_all_folder_select" ON tracking.tracking_folder FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_folder_insert" ON tracking.tracking_folder FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_folder_update" ON tracking.tracking_folder FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_folder_delete" ON tracking.tracking_folder FOR DELETE USING (true);

-- Plan policies (allow all)
CREATE POLICY "temp_allow_all_plan_select" ON tracking.tracking_plan FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_plan_insert" ON tracking.tracking_plan FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_plan_update" ON tracking.tracking_plan FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_plan_delete" ON tracking.tracking_plan FOR DELETE USING (true);

-- Plan view policies (allow all)
CREATE POLICY "temp_allow_all_plan_view_select" ON tracking.tracking_plan_view FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_plan_view_insert" ON tracking.tracking_plan_view FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_plan_view_update" ON tracking.tracking_plan_view FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_plan_view_delete" ON tracking.tracking_plan_view FOR DELETE USING (true);

-- Style policies (allow all)
CREATE POLICY "temp_allow_all_style_select" ON tracking.tracking_plan_style FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_style_insert" ON tracking.tracking_plan_style FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_style_update" ON tracking.tracking_plan_style FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_style_delete" ON tracking.tracking_plan_style FOR DELETE USING (true);

-- Style timeline policies (allow all)
CREATE POLICY "temp_allow_all_style_timeline_select" ON tracking.tracking_plan_style_timeline FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_style_timeline_insert" ON tracking.tracking_plan_style_timeline FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_style_timeline_update" ON tracking.tracking_plan_style_timeline FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_style_timeline_delete" ON tracking.tracking_plan_style_timeline FOR DELETE USING (true);

-- Style dependency policies (allow all)
CREATE POLICY "temp_allow_all_style_dep_select" ON tracking.tracking_plan_style_dependency FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_style_dep_insert" ON tracking.tracking_plan_style_dependency FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_style_dep_delete" ON tracking.tracking_plan_style_dependency FOR DELETE USING (true);

-- Material policies (allow all)
CREATE POLICY "temp_allow_all_material_select" ON tracking.tracking_plan_material FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_material_insert" ON tracking.tracking_plan_material FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_material_update" ON tracking.tracking_plan_material FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_material_delete" ON tracking.tracking_plan_material FOR DELETE USING (true);

-- Material timeline policies (allow all)
CREATE POLICY "temp_allow_all_material_timeline_select" ON tracking.tracking_plan_material_timeline FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_material_timeline_insert" ON tracking.tracking_plan_material_timeline FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_material_timeline_update" ON tracking.tracking_plan_material_timeline FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_material_timeline_delete" ON tracking.tracking_plan_material_timeline FOR DELETE USING (true);

-- Material dependency policies (allow all)
CREATE POLICY "temp_allow_all_material_dep_select" ON tracking.tracking_plan_material_dependency FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_material_dep_insert" ON tracking.tracking_plan_material_dependency FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_material_dep_delete" ON tracking.tracking_plan_material_dependency FOR DELETE USING (true);

-- Template policies (allow all)
CREATE POLICY "temp_allow_all_template_select" ON tracking.tracking_timeline_template FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_template_insert" ON tracking.tracking_timeline_template FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_template_update" ON tracking.tracking_timeline_template FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_template_delete" ON tracking.tracking_timeline_template FOR DELETE USING (true);

-- Template item policies (allow all)
CREATE POLICY "temp_allow_all_template_item_select" ON tracking.tracking_timeline_template_item FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_template_item_insert" ON tracking.tracking_timeline_template_item FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_template_item_update" ON tracking.tracking_timeline_template_item FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_template_item_delete" ON tracking.tracking_timeline_template_item FOR DELETE USING (true);

-- Template visibility policies (allow all)
CREATE POLICY "temp_allow_all_template_vis_select" ON tracking.tracking_timeline_template_visibility FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_template_vis_insert" ON tracking.tracking_timeline_template_visibility FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_template_vis_update" ON tracking.tracking_timeline_template_visibility FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_template_vis_delete" ON tracking.tracking_timeline_template_visibility FOR DELETE USING (true);

-- Folder style link policies (allow all)
CREATE POLICY "temp_allow_all_folder_link_select" ON tracking.tracking_folder_style_link FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_folder_link_insert" ON tracking.tracking_folder_style_link FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_folder_link_delete" ON tracking.tracking_folder_style_link FOR DELETE USING (true);

-- Assignment policies (allow all)
CREATE POLICY "temp_allow_all_assignment_select" ON tracking.tracking_timeline_assignment FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_assignment_insert" ON tracking.tracking_timeline_assignment FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_assignment_delete" ON tracking.tracking_timeline_assignment FOR DELETE USING (true);

-- Status history policies (read-only for users)
CREATE POLICY "temp_allow_all_status_history_select" ON tracking.tracking_timeline_status_history FOR SELECT USING (true);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  rls_enabled_count int;
  policy_count int;
BEGIN
  -- Check RLS enabled on all 15 tables
  SELECT COUNT(*) INTO rls_enabled_count
  FROM pg_tables 
  WHERE schemaname = 'tracking' 
    AND tablename LIKE 'tracking_%'
    AND rowsecurity = true;
  
  IF rls_enabled_count < 15 THEN
    RAISE EXCEPTION 'RLS verification failed: expected 15 tables, found % with RLS enabled', rls_enabled_count;
  END IF;
  
  -- Check policies created
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'tracking'
    AND policyname LIKE 'temp_allow_all_%';
  
  IF policy_count < 50 THEN
    RAISE WARNING 'Policy count low: expected ~58 policies, found %', policy_count;
  END IF;
  
  RAISE NOTICE 'Migration 0102 successful: RLS enabled on 15 tables, % permissive policies created', policy_count;
  RAISE NOTICE 'PostgREST endpoints now exposed at /rest/v1/tracking_*';
  RAISE NOTICE 'PHASE 4 ACTION REQUIRED: Replace temp_allow_all_* policies with brand-scoped policies';
END $$;

COMMIT;
