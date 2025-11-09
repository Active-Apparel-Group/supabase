-- 0002_create_template_tables.sql
-- Creates timeline template tables and visibility configuration.

BEGIN;

CREATE TABLE IF NOT EXISTS tracking.timeline_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    brand text,
    season text,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    timezone text,
    anchor_strategy text,
    conflict_policy text,
    business_days_calendar jsonb,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    created_by uuid,
    updated_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    updated_by uuid
);

CREATE TABLE IF NOT EXISTS tracking.timeline_template_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id uuid NOT NULL REFERENCES tracking.timeline_templates(id) ON DELETE CASCADE,
    node_type tracking.node_type_enum NOT NULL,
    name text NOT NULL,
    short_name text,
    phase text,
    department text,
    display_order integer NOT NULL,
    depends_on_template_item_id uuid REFERENCES tracking.timeline_template_items(id) ON DELETE SET NULL,
    depends_on_action text,
    offset_relation tracking.offset_relation_enum,
    offset_value integer,
    offset_unit tracking.offset_unit_enum,
    page_type tracking.page_type_enum,
    page_label text,
    applies_to_style boolean DEFAULT true NOT NULL,
    applies_to_material boolean DEFAULT false NOT NULL,
    timeline_type tracking.timeline_type_enum DEFAULT 'MASTER' NOT NULL,
    required boolean DEFAULT true NOT NULL,
    notes text
);

CREATE TABLE IF NOT EXISTS tracking.timeline_template_visibility (
    template_item_id uuid NOT NULL REFERENCES tracking.timeline_template_items(id) ON DELETE CASCADE,
    view_type tracking.view_type_enum NOT NULL,
    is_visible boolean DEFAULT true NOT NULL,
    PRIMARY KEY (template_item_id, view_type)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_template_items_template_id ON tracking.timeline_template_items (template_id);
CREATE INDEX IF NOT EXISTS idx_template_items_display_order ON tracking.timeline_template_items (template_id, display_order);

COMMIT;
