-- =====================================================
-- Migration: 0005_add_sharing_and_visibility
-- Description: Add sharing, visibility, and supplier access (simplified)
-- Author: System
-- Date: 2025-01-23
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: Template Configuration
-- =====================================================

-- Add supplier visibility flag to template items
-- Controls whether this milestone type shows to suppliers by default
ALTER TABLE tracking.timeline_template_items 
ADD COLUMN IF NOT EXISTS supplier_visible BOOLEAN DEFAULT false;

-- Add default assignedTo array to template items (optional)
ALTER TABLE tracking.timeline_template_items
ADD COLUMN IF NOT EXISTS default_assigned_to JSONB DEFAULT '[]'::jsonb;

-- Add default shareWith array to template items (optional)
ALTER TABLE tracking.timeline_template_items
ADD COLUMN IF NOT EXISTS default_shared_with JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN tracking.timeline_template_items.supplier_visible IS 
'Controls whether this type of milestone is visible to supplier/factory users by default. Examples: "Submit to Factory" = true, "Internal Design Review" = false.';

COMMENT ON COLUMN tracking.timeline_template_items.default_assigned_to IS 
'Default assignedTo array for this milestone type. Array of user IDs. Copied to timeline when template is applied. Format: ["uuid1", "uuid2"]';

COMMENT ON COLUMN tracking.timeline_template_items.default_shared_with IS 
'Default shareWith array for this milestone type. Array of company IDs. Copied to timeline when template is applied. Format: ["companyId1", "companyId2"]';

-- =====================================================
-- SECTION 2: Plan-Level Supplier Configuration
-- =====================================================

-- Add suppliers array to plans (plan-level access control)
ALTER TABLE tracking.plans
ADD COLUMN IF NOT EXISTS suppliers JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN tracking.plans.suppliers IS 
'Array of supplier company IDs that have access to this tracking plan. First gate for supplier portal access. Format: [{"companyId": "uuid", "companyName": "...", "accessLevel": "view|edit", "canUpdateTimelines": true|false}]';

-- =====================================================
-- SECTION 3: Style/Material Supplier Assignments
-- =====================================================

-- Add supplier arrays to plan_styles for quote/production assignments
ALTER TABLE tracking.plan_styles
ADD COLUMN IF NOT EXISTS suppliers JSONB DEFAULT '[]'::jsonb;

ALTER TABLE tracking.plan_materials
ADD COLUMN IF NOT EXISTS suppliers JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN tracking.plan_styles.suppliers IS 
'Array of supplier company IDs assigned to quote on or manufacture this style. Second gate: within an accessible plan, which styles can this supplier see? Format: [{"companyId": "uuid", "companyName": "...", "role": "quote|production"}]';

COMMENT ON COLUMN tracking.plan_materials.suppliers IS 
'Array of supplier company IDs assigned to this material. Format: [{"companyId": "uuid", "companyName": "...", "role": "quote|production"}]';

-- =====================================================
-- SECTION 4: Timeline Sharing (Runtime)
-- =====================================================

-- Add shareWith arrays to timeline tables (per-milestone sharing)
ALTER TABLE tracking.plan_style_timelines
ADD COLUMN IF NOT EXISTS shared_with JSONB DEFAULT '[]'::jsonb;

ALTER TABLE tracking.plan_material_timelines
ADD COLUMN IF NOT EXISTS shared_with JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN tracking.plan_style_timelines.shared_with IS 
'Array of supplier company IDs that can see this specific timeline milestone (shareWith in BeProduct). Allows per-milestone visibility control. Format: ["companyId1", "companyId2"]';

COMMENT ON COLUMN tracking.plan_material_timelines.shared_with IS 
'Array of supplier company IDs that can see this specific timeline milestone. Format: ["companyId1", "companyId2"]';

-- =====================================================
-- SECTION 5: Indexes for Performance
-- =====================================================

-- GIN indexes for JSONB array queries
CREATE INDEX IF NOT EXISTS idx_plans_suppliers ON tracking.plans USING gin(suppliers);
CREATE INDEX IF NOT EXISTS idx_plan_styles_suppliers ON tracking.plan_styles USING gin(suppliers);
CREATE INDEX IF NOT EXISTS idx_plan_materials_suppliers ON tracking.plan_materials USING gin(suppliers);
CREATE INDEX IF NOT EXISTS idx_style_timelines_shared_with ON tracking.plan_style_timelines USING gin(shared_with);
CREATE INDEX IF NOT EXISTS idx_material_timelines_shared_with ON tracking.plan_material_timelines USING gin(shared_with);

COMMIT;
