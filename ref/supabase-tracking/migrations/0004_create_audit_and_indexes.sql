-- 0004_create_audit_and_indexes.sql
-- Creates assignments, history, import logging tables, and all indexes.

BEGIN;

-- Assignments & history
CREATE TABLE IF NOT EXISTS tracking.timeline_assignments (
    timeline_id uuid NOT NULL,
    timeline_type tracking.timeline_type_enum NOT NULL,
    assignee_id uuid NOT NULL,
    source_user_id uuid,
    role_name text,
    role_id uuid,
    assigned_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    PRIMARY KEY (timeline_id, timeline_type, assignee_id)
);

CREATE TABLE IF NOT EXISTS tracking.timeline_status_history (
    id bigserial PRIMARY KEY,
    timeline_id uuid NOT NULL,
    timeline_type tracking.timeline_type_enum NOT NULL,
    previous_status tracking.timeline_status_enum,
    new_status tracking.timeline_status_enum NOT NULL,
    changed_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    changed_by uuid,
    source text DEFAULT 'import' NOT NULL
);

-- Import logging
CREATE TABLE IF NOT EXISTS tracking.import_batches (
    id bigserial PRIMARY KEY,
    source text NOT NULL,
    source_folder_id uuid,
    hash text,
    started_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    completed_at timestamptz,
    status text,
    error_count integer DEFAULT 0 NOT NULL,
    payload jsonb
);

CREATE TABLE IF NOT EXISTS tracking.import_errors (
    id bigserial PRIMARY KEY,
    batch_id bigint NOT NULL REFERENCES tracking.import_batches(id) ON DELETE CASCADE,
    entity_type text,
    entity_id uuid,
    error_code text,
    error_message text,
    payload jsonb,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS tracking.beproduct_sync_log (
    id bigserial PRIMARY KEY,
    batch_id bigint REFERENCES tracking.import_batches(id) ON DELETE SET NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    action text,
    processed_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    payload jsonb
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_plan_styles_plan_id ON tracking.plan_styles (plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_styles_style_header_id ON tracking.plan_styles (style_header_id);
CREATE INDEX IF NOT EXISTS idx_plan_styles_status_summary ON tracking.plan_styles USING gin (status_summary);

CREATE INDEX IF NOT EXISTS idx_plan_style_timelines_plan_style ON tracking.plan_style_timelines (plan_style_id, template_item_id);
CREATE INDEX IF NOT EXISTS idx_plan_style_timelines_due_date ON tracking.plan_style_timelines (due_date) WHERE status <> 'APPROVED';

CREATE INDEX IF NOT EXISTS idx_plan_materials_plan_id ON tracking.plan_materials (plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_materials_material_header_id ON tracking.plan_materials (material_header_id);

CREATE INDEX IF NOT EXISTS idx_plan_material_timelines_plan_material ON tracking.plan_material_timelines (plan_material_id, template_item_id);
CREATE INDEX IF NOT EXISTS idx_plan_material_timelines_due_date ON tracking.plan_material_timelines (due_date) WHERE status <> 'APPROVED';

CREATE INDEX IF NOT EXISTS idx_timeline_status_history_timeline ON tracking.timeline_status_history (timeline_id, timeline_type);
CREATE INDEX IF NOT EXISTS idx_timeline_assignments_assignee ON tracking.timeline_assignments (assignee_id);

COMMIT;
