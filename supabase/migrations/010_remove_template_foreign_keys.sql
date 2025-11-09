-- Migration: 010_remove_template_foreign_keys.sql
-- Purpose: Drop foreign key constraints referencing local timeline template tables
-- Rationale: Template records are now managed exclusively in BeProduct.

BEGIN;

-- Drop plan-level template reference constraint
ALTER TABLE ops.tracking_plan
  DROP CONSTRAINT IF EXISTS plans_template_id_fkey;

-- Drop plan view template reference constraint
ALTER TABLE ops.tracking_plan_view
  DROP CONSTRAINT IF EXISTS plan_views_template_id_fkey;

-- Drop style timeline template item constraint
ALTER TABLE ops.tracking_plan_style_timeline
  DROP CONSTRAINT IF EXISTS plan_style_timelines_template_item_id_fkey;

-- Drop material timeline template item constraint
ALTER TABLE ops.tracking_plan_material_timeline
  DROP CONSTRAINT IF EXISTS plan_material_timelines_template_item_id_fkey;

-- Drop internal template item dependency constraint
ALTER TABLE ops.tracking_timeline_template_item
  DROP CONSTRAINT IF EXISTS timeline_template_items_depends_on_template_item_id_fkey;

-- Drop template item to template constraint
ALTER TABLE ops.tracking_timeline_template_item
  DROP CONSTRAINT IF EXISTS timeline_template_items_template_id_fkey;

-- Drop template visibility constraint to template items
ALTER TABLE ops.tracking_timeline_template_visibility
  DROP CONSTRAINT IF EXISTS timeline_template_visibility_template_item_id_fkey;

COMMIT;
