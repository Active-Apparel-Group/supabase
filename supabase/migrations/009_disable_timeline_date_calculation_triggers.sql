-- Migration: Disable timeline date calculation triggers for BeProduct webhook integration
-- 
-- CONTEXT:
-- BeProduct webhooks provide pre-calculated dates for all timeline milestones.
-- The existing trigger functions (calculate_timeline_dates, cascade updates, recalculate plan)
-- were designed for manual entry scenarios where dates need to be computed based on dependencies.
-- 
-- With webhook integration, these triggers CONFLICT with BeProduct's authoritative dates:
-- 1. Webhook inserts timeline with BeProduct's calculated dates
-- 2. Trigger fires and recalculates dates based on template dependencies
-- 3. BeProduct dates get overwritten with locally calculated dates
-- 4. Data sync breaks - Supabase diverges from BeProduct
--
-- SOLUTION:
-- Drop the date calculation triggers (but KEEP the instantiation trigger).
-- The instantiation trigger is still needed to:
-- - Create timeline records from template when style is added to plan
-- - Populate dependency records (tracking_plan_style_dependency)
-- - Set up the milestone structure
--
-- The webhook will then update the dates with BeProduct's authoritative values.
--
-- TRIGGERS TO DROP:
-- 1. calculate_timeline_dates_trigger (BEFORE INSERT/UPDATE on tracking_plan_style_timeline)
--    - Auto-calculates start_date_plan, plan_date based on predecessor dates
--    - Overwrites webhook dates
-- 2. cascade_timeline_updates_trigger (AFTER UPDATE on tracking_plan_style_timeline)
--    - Cascades date changes to successor milestones
--    - Triggers recalculation chain
-- 3. recalculate_plan_timelines_trigger (AFTER UPDATE on tracking_plan)
--    - Recalculates all timeline dates when plan start/end dates change
--    - Overwrites webhook dates
-- 4. calculate_material_timeline_dates_trigger (BEFORE INSERT/UPDATE on tracking_plan_material_timeline)
--    - Same issue for material timelines (though not in scope for Phase 1)
-- 5. cascade_material_timeline_updates_trigger (AFTER UPDATE on tracking_plan_material_timeline)
--    - Cascades material timeline updates
--
-- TRIGGERS TO KEEP:
-- - trg_instantiate_style_timeline (AFTER INSERT on tracking_plan_style)
--   This creates the initial timeline structure from template, which is essential.
--   Webhook updates will then populate the correct dates.

-- Drop style timeline calculation triggers
DROP TRIGGER IF EXISTS calculate_timeline_dates_trigger ON ops.tracking_plan_style_timeline;
DROP TRIGGER IF EXISTS cascade_timeline_updates_trigger ON ops.tracking_plan_style_timeline;
DROP TRIGGER IF EXISTS recalculate_plan_timelines_trigger ON ops.tracking_plan;

-- Drop material timeline calculation triggers (for consistency, even though not in scope yet)
DROP TRIGGER IF EXISTS calculate_material_timeline_dates_trigger ON ops.tracking_plan_material_timeline;
DROP TRIGGER IF EXISTS cascade_material_timeline_updates_trigger ON ops.tracking_plan_material_timeline;

-- Document the change
COMMENT ON TABLE ops.tracking_plan_style_timeline IS 
  'Timeline milestones for styles in tracking plans. Dates are synced from BeProduct webhooks (source of truth). ' ||
  'Date calculation triggers have been disabled to prevent conflicts with webhook data.';

COMMENT ON TABLE ops.tracking_plan_style_dependency IS 
  'Dependency relationships between timeline milestones (predecessor/successor). ' ||
  'Foreign key constraints removed for Phase 1. Dependencies will be implemented in Phase 2.';

COMMENT ON TABLE ops.tracking_plan_material_dependency IS 
  'Dependency relationships between material timeline milestones. ' ||
  'Foreign key constraints removed for Phase 1. Dependencies will be implemented in Phase 2.';

-- Note: The instantiation trigger (trg_instantiate_style_timeline) remains active
-- It creates timeline records from template when a style is added to a tracking planwebhooks (source of truth). ' ||
  'Date calculation triggers have been disabled to prevent conflicts with webhook data.';

COMMENT ON TABLE ops.tracking_plan_style_dependency IS 
  'Dependency relationships between timeline milestones (predecessor/successor). ' ||
  'Populated by instantiation trigger from template dependencies. ' ||
  'Used for Gantt chart visualization, but dates come from BeProduct, not calculated locally.';

-- Note: The instantiation trigger (trg_instantiate_style_timeline) remains active
-- It creates timeline records from template when a style is added to a tracking plan
