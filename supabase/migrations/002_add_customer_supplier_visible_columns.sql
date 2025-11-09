-- Migration: Add customer_visible and supplier_visible columns for milestone visibility
-- Adds customer_visible to template items, and both columns to plan timelines

ALTER TABLE ops.tracking_timeline_template_item
  ADD COLUMN IF NOT EXISTS supplier_visible boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS customer_visible boolean DEFAULT false;

COMMENT ON COLUMN ops.tracking_timeline_template_item.supplier_visible IS 'Is milestone visible to supplier users?';
COMMENT ON COLUMN ops.tracking_timeline_template_item.customer_visible IS 'Is milestone visible to customer users?';

ALTER TABLE ops.tracking_plan_style_timeline
  ADD COLUMN IF NOT EXISTS supplier_visible boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS customer_visible boolean DEFAULT false;

COMMENT ON COLUMN ops.tracking_plan_style_timeline.supplier_visible IS 'Is milestone visible to supplier users?';
COMMENT ON COLUMN ops.tracking_plan_style_timeline.customer_visible IS 'Is milestone visible to customer users?';

ALTER TABLE ops.tracking_plan_material_timeline
  ADD COLUMN IF NOT EXISTS supplier_visible boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS customer_visible boolean DEFAULT false;

COMMENT ON COLUMN ops.tracking_plan_material_timeline.supplier_visible IS 'Is milestone visible to supplier users?';
COMMENT ON COLUMN ops.tracking_plan_material_timeline.customer_visible IS 'Is milestone visible to customer users?';
