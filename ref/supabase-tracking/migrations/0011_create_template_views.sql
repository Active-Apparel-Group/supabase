-- =====================================================
-- Migration: 0011_create_template_views
-- Description: Create views for timeline templates and template items, expose via public schema
-- Author: System
-- Date: 2025-10-23
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: Create tracking schema views
-- =====================================================

-- View: v_timeline_template
-- Purpose: Template list with metadata and item counts
CREATE OR REPLACE VIEW tracking.v_timeline_template AS
SELECT 
    t.id AS template_id,
    t.name AS template_name,
    t.brand,
    t.season,
    t.version,
    t.is_active,
    t.timezone,
    t.anchor_strategy,
    t.conflict_policy,
    t.business_days_calendar,
    t.created_at,
    t.created_by,
    t.updated_at,
    t.updated_by,
    -- Computed counts
    COUNT(DISTINCT ti.id) AS total_item_count,
    COUNT(DISTINCT ti.id) FILTER (WHERE ti.applies_to_style = true) AS style_item_count,
    COUNT(DISTINCT ti.id) FILTER (WHERE ti.applies_to_material = true) AS material_item_count,
    COUNT(DISTINCT ti.id) FILTER (WHERE ti.node_type = 'TASK') AS milestone_count,
    COUNT(DISTINCT ti.id) FILTER (WHERE ti.node_type = 'ANCHOR') AS phase_count,
    -- Active plans using this template
    COUNT(DISTINCT p.id) AS active_plan_count
FROM tracking.timeline_templates t
LEFT JOIN tracking.timeline_template_items ti ON ti.template_id = t.id
LEFT JOIN tracking.plan p ON p.template_id = t.id AND p.active = true
GROUP BY 
    t.id, t.name, t.brand, t.season, t.version, t.is_active, 
    t.timezone, t.anchor_strategy, t.conflict_policy, 
    t.business_days_calendar, t.created_at, t.created_by, 
    t.updated_at, t.updated_by;

COMMENT ON VIEW tracking.v_timeline_template IS 
'Timeline template list with computed item counts and active plan usage. Endpoint: /rest/v1/v_timeline_template';

-- View: v_timeline_template_item
-- Purpose: Template item details with parent template info
CREATE OR REPLACE VIEW tracking.v_timeline_template_item AS
SELECT 
    -- Template info
    t.id AS template_id,
    t.name AS template_name,
    t.brand,
    t.season,
    t.version,
    t.is_active AS template_active,
    -- Item details
    ti.id AS item_id,
    ti.node_type,
    ti.name AS item_name,
    ti.short_name,
    ti.phase,
    ti.department,
    ti.display_order,
    ti.depends_on_template_item_id,
    ti.depends_on_action,
    ti.offset_relation,
    ti.offset_value,
    ti.offset_unit,
    ti.page_type,
    ti.page_label,
    ti.applies_to_style,
    ti.applies_to_material,
    ti.timeline_type,
    ti.required,
    ti.notes,
    -- Dependency info (if exists)
    dep.name AS depends_on_item_name,
    dep.node_type AS depends_on_node_type,
    -- Visibility summary (jsonb array)
    (
        SELECT jsonb_agg(
            jsonb_build_object(
                'view_type', v.view_type,
                'is_visible', v.is_visible
            )
        )
        FROM tracking.timeline_template_visibility v
        WHERE v.template_item_id = ti.id
    ) AS visibility_config
FROM tracking.timeline_template_items ti
INNER JOIN tracking.timeline_templates t ON t.id = ti.template_id
LEFT JOIN tracking.timeline_template_items dep ON dep.id = ti.depends_on_template_item_id;

COMMENT ON VIEW tracking.v_timeline_template_item IS 
'Timeline template items with parent template and dependency details. Endpoint: /rest/v1/v_timeline_template_item';

-- =====================================================
-- SECTION 2: Create public views
-- =====================================================

CREATE OR REPLACE VIEW public.v_timeline_template AS
SELECT * FROM tracking.v_timeline_template;

COMMENT ON VIEW public.v_timeline_template IS 
'Public view exposing tracking.v_timeline_template for PostgREST API access. Endpoint: /rest/v1/v_timeline_template';

CREATE OR REPLACE VIEW public.v_timeline_template_item AS
SELECT * FROM tracking.v_timeline_template_item;

COMMENT ON VIEW public.v_timeline_template_item IS 
'Public view exposing tracking.v_timeline_template_item for PostgREST API access. Endpoint: /rest/v1/v_timeline_template_item';

-- =====================================================
-- SECTION 3: Grant permissions
-- =====================================================

GRANT SELECT ON tracking.v_timeline_template TO anon, authenticated;
GRANT SELECT ON tracking.v_timeline_template_item TO anon, authenticated;

GRANT SELECT ON public.v_timeline_template TO anon, authenticated;
GRANT SELECT ON public.v_timeline_template_item TO anon, authenticated;

COMMIT;

-- =====================================================
-- Post-Migration Verification
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE 'Testing template views...';
  PERFORM COUNT(*) FROM public.v_timeline_template;
  RAISE NOTICE 'public.v_timeline_template accessible';
  PERFORM COUNT(*) FROM public.v_timeline_template_item;
  RAISE NOTICE 'public.v_timeline_template_item accessible';
  RAISE NOTICE 'Template views created successfully!';
END $$;
