-- =====================================================
-- Migration: 0015_create_plan_entity_views
-- Description: Expose plan styles/materials and enriched timeline views for UI grids
-- Author: GitHub Copilot
-- Date: 2025-10-24
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: Style-level views
-- =====================================================

CREATE OR REPLACE VIEW tracking.v_plan_styles AS
SELECT
    ps.id AS plan_style_id,
    ps.plan_id,
    p.name AS plan_name,
    p.season AS plan_season,
    p.brand AS plan_brand,
    p.folder_id,
    f.name AS folder_name,
    ps.view_id,
    pv.view_type,
    ps.style_id,
    ps.style_header_id,
    ps.color_id,
    ps.style_number,
    ps.style_name,
    ps.color_name,
    ps.season AS style_season,
    ps.delivery,
    ps.factory,
    ps.supplier_id,
    ps.supplier_name,
    ps.brand AS style_brand,
    ps.status_summary,
    ps.suppliers,
    ps.created_at,
    ps.updated_at,
    COUNT(pst.id) FILTER (WHERE pst.id IS NOT NULL) AS milestones_total,
    COUNT(pst.id) FILTER (WHERE pst.status IN ('APPROVED', 'COMPLETE')) AS milestones_completed,
    COUNT(pst.id) FILTER (WHERE pst.status = 'IN_PROGRESS') AS milestones_in_progress,
    COUNT(pst.id) FILTER (WHERE pst.status = 'NOT_STARTED') AS milestones_not_started,
    COUNT(pst.id) FILTER (WHERE pst.status = 'BLOCKED') AS milestones_blocked,
    COUNT(pst.id) FILTER (WHERE pst.late = true AND pst.status NOT IN ('APPROVED', 'COMPLETE')) AS milestones_late,
    MIN(pst.due_date) AS earliest_due_date,
    MAX(pst.due_date) AS latest_due_date,
    MAX(pst.updated_at) AS last_milestone_updated_at,
    jsonb_strip_nulls(jsonb_build_object(
        'NOT_STARTED', NULLIF(COUNT(pst.id) FILTER (WHERE pst.status = 'NOT_STARTED'), 0),
        'IN_PROGRESS', NULLIF(COUNT(pst.id) FILTER (WHERE pst.status = 'IN_PROGRESS'), 0),
        'APPROVED', NULLIF(COUNT(pst.id) FILTER (WHERE pst.status = 'APPROVED'), 0),
        'COMPLETE', NULLIF(COUNT(pst.id) FILTER (WHERE pst.status = 'COMPLETE'), 0),
        'BLOCKED', NULLIF(COUNT(pst.id) FILTER (WHERE pst.status = 'BLOCKED'), 0),
        'REJECTED', NULLIF(COUNT(pst.id) FILTER (WHERE pst.status = 'REJECTED'), 0)
    )) AS status_breakdown
FROM tracking.plan_styles ps
JOIN tracking.plan p ON p.id = ps.plan_id
LEFT JOIN tracking.folder f ON f.id = p.folder_id
LEFT JOIN tracking.plan_views pv ON pv.id = ps.view_id
LEFT JOIN tracking.plan_style_timelines pst ON pst.plan_style_id = ps.id
WHERE ps.active = true
GROUP BY
    ps.id,
    ps.plan_id,
    p.name,
    p.season,
    p.brand,
    p.folder_id,
    f.name,
    ps.view_id,
    pv.view_type,
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
    ps.status_summary,
    ps.suppliers,
    ps.created_at,
    ps.updated_at;

COMMENT ON VIEW tracking.v_plan_styles IS
'Plan styles with milestone aggregates, supplier metadata, and folder context. Endpoint: /rest/v1/v_plan_styles';

CREATE OR REPLACE VIEW tracking.v_plan_style_timelines_enriched AS
SELECT
    pst.id AS timeline_id,
    pst.plan_style_id,
    ps.plan_id,
    p.name AS plan_name,
    p.folder_id,
    f.name AS folder_name,
    ps.view_id,
    pv.view_type,
    ps.style_number,
    ps.style_name,
    ps.color_name,
    ps.supplier_name,
    ps.factory,
    pst.template_item_id,
    tti.name AS milestone_name,
    tti.short_name,
    tti.node_type,
    tti.phase,
    tti.department,
    tti.display_order,
    tti.timeline_type,
    tti.applies_to_style,
    tti.required,
    tti.supplier_visible,
    tti.depends_on_template_item_id,
    dep.name AS depends_on_milestone_name,
    dep.node_type AS depends_on_node_type,
    pst.status,
    pst.plan_date,
    pst.rev_date,
    pst.final_date,
    pst.due_date,
    pst.completed_date,
    pst.late,
    CASE WHEN pst.status IN ('APPROVED', 'COMPLETE') THEN true ELSE false END AS is_completed,
    CASE
        WHEN pst.status IN ('APPROVED', 'COMPLETE') THEN false
        WHEN pst.due_date IS NOT NULL AND pst.due_date < CURRENT_DATE THEN true
        ELSE false
    END AS is_overdue,
    pst.notes,
    pst.page_id,
    pst.page_type,
    pst.page_name,
    pst.request_id,
    pst.request_code,
    pst.request_status,
    pst.shared_with,
    COALESCE((
        SELECT jsonb_agg(assignments_row ORDER BY assignments_row->>'assigned_at')
        FROM (
            SELECT jsonb_build_object(
                'assignee_id', ta.assignee_id,
                'role_name', ta.role_name,
                'source_user_id', ta.source_user_id,
                'assigned_at', ta.assigned_at
            ) AS assignments_row
            FROM tracking.timeline_assignments ta
            WHERE ta.timeline_id = pst.id AND ta.timeline_type = 'STYLE'
        ) assignments_sub(assignments_row)
    ), '[]'::jsonb) AS assignments,
    COALESCE((
        SELECT jsonb_agg(history_row ORDER BY history_row->>'changed_at')
        FROM (
            SELECT jsonb_build_object(
                'changed_at', tsh.changed_at,
                'changed_by', tsh.changed_by,
                'previous_status', tsh.previous_status,
                'new_status', tsh.new_status,
                'source', tsh.source
            ) AS history_row
            FROM tracking.timeline_status_history tsh
            WHERE tsh.timeline_id = pst.id AND tsh.timeline_type = 'STYLE'
            ORDER BY tsh.changed_at DESC
            LIMIT 10
        ) history_sub(history_row)
    ), '[]'::jsonb) AS recent_status_history,
    COALESCE((
        SELECT jsonb_agg(dependency_row)
        FROM (
            SELECT jsonb_build_object(
                'predecessor_timeline_id', psd.predecessor_id,
                'offset_relation', psd.offset_relation,
                'offset_value', psd.offset_value,
                'offset_unit', psd.offset_unit
            ) AS dependency_row
            FROM tracking.plan_style_dependencies psd
            WHERE psd.successor_id = pst.id
        ) dependency_sub(dependency_row)
    ), '[]'::jsonb) AS predecessors,
    pst.created_at,
    pst.updated_at
FROM tracking.plan_style_timelines pst
JOIN tracking.plan_styles ps ON ps.id = pst.plan_style_id
JOIN tracking.plan p ON p.id = ps.plan_id
LEFT JOIN tracking.folder f ON f.id = p.folder_id
LEFT JOIN tracking.plan_views pv ON pv.id = ps.view_id
LEFT JOIN tracking.timeline_template_items tti ON tti.id = pst.template_item_id
LEFT JOIN tracking.timeline_template_items dep ON dep.id = tti.depends_on_template_item_id
WHERE ps.active = true
ORDER BY ps.style_number, tti.display_order;

COMMENT ON VIEW tracking.v_plan_style_timelines_enriched IS
'Enriched style timeline rows with template metadata, assignments, dependencies, and status history. Endpoint: /rest/v1/v_plan_style_timelines_enriched';

-- =====================================================
-- SECTION 2: Material-level views
-- =====================================================

CREATE OR REPLACE VIEW tracking.v_plan_materials AS
SELECT
    pm.id AS plan_material_id,
    pm.plan_id,
    p.name AS plan_name,
    p.season AS plan_season,
    p.brand AS plan_brand,
    p.folder_id,
    f.name AS folder_name,
    pm.view_id,
    pv.view_type,
    pm.material_id,
    pm.material_header_id,
    pm.color_id,
    pm.material_number,
    pm.material_name,
    pm.color_name,
    pm.supplier_id,
    pm.supplier_name,
    pm.bom_item_id,
    pm.style_links,
    pm.bom_references,
    pm.suppliers,
    pm.created_at,
    pm.updated_at,
    COUNT(pmt.id) FILTER (WHERE pmt.id IS NOT NULL) AS milestones_total,
    COUNT(pmt.id) FILTER (WHERE pmt.status IN ('APPROVED', 'COMPLETE')) AS milestones_completed,
    COUNT(pmt.id) FILTER (WHERE pmt.status = 'IN_PROGRESS') AS milestones_in_progress,
    COUNT(pmt.id) FILTER (WHERE pmt.status = 'NOT_STARTED') AS milestones_not_started,
    COUNT(pmt.id) FILTER (WHERE pmt.status = 'BLOCKED') AS milestones_blocked,
    COUNT(pmt.id) FILTER (WHERE pmt.late = true AND pmt.status NOT IN ('APPROVED', 'COMPLETE')) AS milestones_late,
    MIN(pmt.due_date) AS earliest_due_date,
    MAX(pmt.due_date) AS latest_due_date,
    MAX(pmt.updated_at) AS last_milestone_updated_at,
    jsonb_strip_nulls(jsonb_build_object(
        'NOT_STARTED', NULLIF(COUNT(pmt.id) FILTER (WHERE pmt.status = 'NOT_STARTED'), 0),
        'IN_PROGRESS', NULLIF(COUNT(pmt.id) FILTER (WHERE pmt.status = 'IN_PROGRESS'), 0),
        'APPROVED', NULLIF(COUNT(pmt.id) FILTER (WHERE pmt.status = 'APPROVED'), 0),
        'COMPLETE', NULLIF(COUNT(pmt.id) FILTER (WHERE pmt.status = 'COMPLETE'), 0),
        'BLOCKED', NULLIF(COUNT(pmt.id) FILTER (WHERE pmt.status = 'BLOCKED'), 0),
        'REJECTED', NULLIF(COUNT(pmt.id) FILTER (WHERE pmt.status = 'REJECTED'), 0)
    )) AS status_breakdown
FROM tracking.plan_materials pm
JOIN tracking.plan p ON p.id = pm.plan_id
LEFT JOIN tracking.folder f ON f.id = p.folder_id
LEFT JOIN tracking.plan_views pv ON pv.id = pm.view_id
LEFT JOIN tracking.plan_material_timelines pmt ON pmt.plan_material_id = pm.id
WHERE pm.active = true
GROUP BY
    pm.id,
    pm.plan_id,
    p.name,
    p.season,
    p.brand,
    p.folder_id,
    f.name,
    pm.view_id,
    pv.view_type,
    pm.material_id,
    pm.material_header_id,
    pm.color_id,
    pm.material_number,
    pm.material_name,
    pm.color_name,
    pm.supplier_id,
    pm.supplier_name,
    pm.bom_item_id,
    pm.style_links,
    pm.bom_references,
    pm.suppliers,
    pm.created_at,
    pm.updated_at;

COMMENT ON VIEW tracking.v_plan_materials IS
'Plan materials with milestone aggregates, BOM references, and supplier metadata. Endpoint: /rest/v1/v_plan_materials';

CREATE OR REPLACE VIEW tracking.v_plan_material_timelines_enriched AS
SELECT
    pmt.id AS timeline_id,
    pmt.plan_material_id,
    pm.plan_id,
    p.name AS plan_name,
    p.folder_id,
    f.name AS folder_name,
    pm.view_id,
    pv.view_type,
    pm.material_number,
    pm.material_name,
    pm.color_name,
    pm.supplier_name,
    pmt.template_item_id,
    tti.name AS milestone_name,
    tti.short_name,
    tti.node_type,
    tti.phase,
    tti.department,
    tti.display_order,
    tti.timeline_type,
    tti.applies_to_material,
    tti.required,
    tti.supplier_visible,
    tti.depends_on_template_item_id,
    dep.name AS depends_on_milestone_name,
    dep.node_type AS depends_on_node_type,
    pmt.status,
    pmt.plan_date,
    pmt.rev_date,
    pmt.final_date,
    pmt.due_date,
    pmt.completed_date,
    pmt.late,
    CASE WHEN pmt.status IN ('APPROVED', 'COMPLETE') THEN true ELSE false END AS is_completed,
    CASE
        WHEN pmt.status IN ('APPROVED', 'COMPLETE') THEN false
        WHEN pmt.due_date IS NOT NULL AND pmt.due_date < CURRENT_DATE THEN true
        ELSE false
    END AS is_overdue,
    pmt.notes,
    pmt.page_id,
    pmt.page_type,
    pmt.page_name,
    pmt.request_id,
    pmt.request_code,
    pmt.request_status,
    pmt.shared_with,
    COALESCE((
        SELECT jsonb_agg(assignments_row ORDER BY assignments_row->>'assigned_at')
        FROM (
            SELECT jsonb_build_object(
                'assignee_id', ta.assignee_id,
                'role_name', ta.role_name,
                'source_user_id', ta.source_user_id,
                'assigned_at', ta.assigned_at
            ) AS assignments_row
            FROM tracking.timeline_assignments ta
            WHERE ta.timeline_id = pmt.id AND ta.timeline_type = 'MATERIAL'
        ) assignments_sub(assignments_row)
    ), '[]'::jsonb) AS assignments,
    COALESCE((
        SELECT jsonb_agg(history_row ORDER BY history_row->>'changed_at')
        FROM (
            SELECT jsonb_build_object(
                'changed_at', tsh.changed_at,
                'changed_by', tsh.changed_by,
                'previous_status', tsh.previous_status,
                'new_status', tsh.new_status,
                'source', tsh.source
            ) AS history_row
            FROM tracking.timeline_status_history tsh
            WHERE tsh.timeline_id = pmt.id AND tsh.timeline_type = 'MATERIAL'
            ORDER BY tsh.changed_at DESC
            LIMIT 10
        ) history_sub(history_row)
    ), '[]'::jsonb) AS recent_status_history,
    COALESCE((
        SELECT jsonb_agg(dependency_row)
        FROM (
            SELECT jsonb_build_object(
                'predecessor_timeline_id', pmd.predecessor_id,
                'offset_relation', pmd.offset_relation,
                'offset_value', pmd.offset_value,
                'offset_unit', pmd.offset_unit
            ) AS dependency_row
            FROM tracking.plan_material_dependencies pmd
            WHERE pmd.successor_id = pmt.id
        ) dependency_sub(dependency_row)
    ), '[]'::jsonb) AS predecessors,
    pmt.created_at,
    pmt.updated_at
FROM tracking.plan_material_timelines pmt
JOIN tracking.plan_materials pm ON pm.id = pmt.plan_material_id
JOIN tracking.plan p ON p.id = pm.plan_id
LEFT JOIN tracking.folder f ON f.id = p.folder_id
LEFT JOIN tracking.plan_views pv ON pv.id = pm.view_id
LEFT JOIN tracking.timeline_template_items tti ON tti.id = pmt.template_item_id
LEFT JOIN tracking.timeline_template_items dep ON dep.id = tti.depends_on_template_item_id
WHERE pm.active = true
ORDER BY pm.material_number, tti.display_order;

COMMENT ON VIEW tracking.v_plan_material_timelines_enriched IS
'Enriched material timeline rows with template metadata, assignments, dependencies, and status history. Endpoint: /rest/v1/v_plan_material_timelines_enriched';

-- =====================================================
-- SECTION 3: Expose views via public schema and permissions
-- =====================================================

CREATE OR REPLACE VIEW public.v_plan_styles AS
SELECT * FROM tracking.v_plan_styles;

CREATE OR REPLACE VIEW public.v_plan_style_timelines_enriched AS
SELECT * FROM tracking.v_plan_style_timelines_enriched;

CREATE OR REPLACE VIEW public.v_plan_materials AS
SELECT * FROM tracking.v_plan_materials;

CREATE OR REPLACE VIEW public.v_plan_material_timelines_enriched AS
SELECT * FROM tracking.v_plan_material_timelines_enriched;

GRANT SELECT ON tracking.v_plan_styles TO anon, authenticated;
GRANT SELECT ON tracking.v_plan_style_timelines_enriched TO anon, authenticated;
GRANT SELECT ON tracking.v_plan_materials TO anon, authenticated;
GRANT SELECT ON tracking.v_plan_material_timelines_enriched TO anon, authenticated;

GRANT SELECT ON public.v_plan_styles TO anon, authenticated;
GRANT SELECT ON public.v_plan_style_timelines_enriched TO anon, authenticated;
GRANT SELECT ON public.v_plan_materials TO anon, authenticated;
GRANT SELECT ON public.v_plan_material_timelines_enriched TO anon, authenticated;

COMMIT;

-- =====================================================
-- Post-migration verification (optional notices)
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'tracking.v_plan_styles rows: %', (SELECT COUNT(*) FROM tracking.v_plan_styles LIMIT 1);
    RAISE NOTICE 'tracking.v_plan_style_timelines_enriched rows: %', (SELECT COUNT(*) FROM tracking.v_plan_style_timelines_enriched LIMIT 1);
    RAISE NOTICE 'tracking.v_plan_materials rows: %', (SELECT COUNT(*) FROM tracking.v_plan_materials LIMIT 1);
    RAISE NOTICE 'tracking.v_plan_material_timelines_enriched rows: %', (SELECT COUNT(*) FROM tracking.v_plan_material_timelines_enriched LIMIT 1);
END$$;
