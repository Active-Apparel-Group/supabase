-- 0003_create_core_tables.sql
-- Creates folders, plans, views, and core style/material tracking tables.

BEGIN;

-- Folder management
-- Note: Tracking folders organize by brand only. Season is tracked at plan level.
CREATE TABLE IF NOT EXISTS tracking.folders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    brand text,
    style_folder_id uuid,
    style_folder_name text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    raw_payload jsonb
);

COMMENT ON TABLE tracking.folders IS 
'Tracking folders organize plans by brand. Season is tracked at the plan level, not folder level.';

CREATE TABLE IF NOT EXISTS tracking.folder_style_links (
    folder_id uuid NOT NULL REFERENCES tracking.folders(id) ON DELETE CASCADE,
    style_folder_id uuid NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    linked_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    PRIMARY KEY (folder_id, style_folder_id)
);

-- Plans
CREATE TABLE IF NOT EXISTS tracking.plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    folder_id uuid REFERENCES tracking.folders(id) ON DELETE SET NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    season text,
    brand text,
    start_date date,
    end_date date,
    description text,
    default_view_id uuid,
    template_id uuid REFERENCES tracking.timeline_templates(id) ON DELETE SET NULL,
    timezone text,
    color_theme text,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    created_by text,
    updated_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    updated_by text,
    raw_payload jsonb
);

CREATE TABLE IF NOT EXISTS tracking.plan_views (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id uuid NOT NULL REFERENCES tracking.plans(id) ON DELETE CASCADE,
    name text NOT NULL,
    view_type tracking.view_type_enum NOT NULL,
    active boolean DEFAULT true NOT NULL,
    sort_order integer,
    template_id uuid REFERENCES tracking.timeline_templates(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL
);

-- Add foreign key constraint for default_view_id
ALTER TABLE tracking.plans
    DROP CONSTRAINT IF EXISTS plans_default_view_fk;

ALTER TABLE tracking.plans
    ADD CONSTRAINT plans_default_view_fk
    FOREIGN KEY (default_view_id)
    REFERENCES tracking.plan_views(id) ON DELETE SET NULL;

-- Style tracking
CREATE TABLE IF NOT EXISTS tracking.plan_styles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id uuid NOT NULL REFERENCES tracking.plans(id) ON DELETE CASCADE,
    view_id uuid REFERENCES tracking.plan_views(id) ON DELETE SET NULL,
    style_id uuid,
    style_header_id uuid,
    color_id uuid,
    style_number text,
    style_name text,
    color_name text,
    season text,
    delivery text,
    factory text,
    supplier_id uuid,
    supplier_name text,
    brand text,
    status_summary jsonb,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc', now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS tracking.plan_style_timelines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_style_id uuid NOT NULL REFERENCES tracking.plan_styles(id) ON DELETE CASCADE,
    template_item_id uuid REFERENCES tracking.timeline_template_items(id) ON DELETE SET NULL,
    status tracking.timeline_status_enum DEFAULT 'NOT_STARTED' NOT NULL,
    plan_date date,
    rev_date date,
    final_date date,
    due_date date,
    completed_date date,
    late boolean DEFAULT false NOT NULL,
    notes text,
    page_id uuid,
    page_type tracking.page_type_enum,
    page_name text,
    request_id uuid,
    request_code text,
    request_status text,
    timeline_type tracking.timeline_type_enum DEFAULT 'STYLE' NOT NULL,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    UNIQUE (plan_style_id, template_item_id)
);

CREATE TABLE IF NOT EXISTS tracking.plan_style_dependencies (
    successor_id uuid REFERENCES tracking.plan_style_timelines(id) ON DELETE CASCADE,
    predecessor_id uuid REFERENCES tracking.plan_style_timelines(id) ON DELETE CASCADE,
    offset_relation tracking.offset_relation_enum NOT NULL,
    offset_value integer NOT NULL,
    offset_unit tracking.offset_unit_enum NOT NULL,
    PRIMARY KEY (successor_id, predecessor_id)
);

-- Material tracking
CREATE TABLE IF NOT EXISTS tracking.plan_materials (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id uuid NOT NULL REFERENCES tracking.plans(id) ON DELETE CASCADE,
    view_id uuid REFERENCES tracking.plan_views(id) ON DELETE SET NULL,
    material_id uuid,
    material_header_id uuid,
    color_id uuid,
    material_number text,
    material_name text,
    color_name text,
    supplier_id uuid,
    supplier_name text,
    bom_item_id uuid,
    style_links jsonb,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc', now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS tracking.plan_material_timelines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_material_id uuid NOT NULL REFERENCES tracking.plan_materials(id) ON DELETE CASCADE,
    template_item_id uuid REFERENCES tracking.timeline_template_items(id) ON DELETE SET NULL,
    status tracking.timeline_status_enum DEFAULT 'NOT_STARTED' NOT NULL,
    plan_date date,
    rev_date date,
    final_date date,
    due_date date,
    completed_date date,
    late boolean DEFAULT false NOT NULL,
    notes text,
    page_id uuid,
    page_type tracking.page_type_enum,
    page_name text,
    request_id uuid,
    request_code text,
    request_status text,
    timeline_type tracking.timeline_type_enum DEFAULT 'MATERIAL' NOT NULL,
    created_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    UNIQUE (plan_material_id, template_item_id)
);

CREATE TABLE IF NOT EXISTS tracking.plan_material_dependencies (
    successor_id uuid REFERENCES tracking.plan_material_timelines(id) ON DELETE CASCADE,
    predecessor_id uuid REFERENCES tracking.plan_material_timelines(id) ON DELETE CASCADE,
    offset_relation tracking.offset_relation_enum NOT NULL,
    offset_value integer NOT NULL,
    offset_unit tracking.offset_unit_enum NOT NULL,
    PRIMARY KEY (successor_id, predecessor_id)
);

COMMIT;
