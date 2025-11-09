-- Migration: 004_create_material_related_tables.sql
-- This migration creates normalized tables for material-related entities: colorways, size ranges, suppliers, tags, and plan links.

BEGIN;

-- Colorways table
CREATE TABLE pim.material_colorway (
    id BIGSERIAL PRIMARY KEY,
    material_id BIGINT NOT NULL REFERENCES pim.material(id) ON DELETE CASCADE,
    colorway_id TEXT NOT NULL,
    name TEXT,
    code TEXT,
    hex TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Size Ranges table
CREATE TABLE pim.material_size_range (
    id BIGSERIAL PRIMARY KEY,
    material_id BIGINT NOT NULL REFERENCES pim.material(id) ON DELETE CASCADE,
    size_range_id TEXT NOT NULL,
    name TEXT,
    sizes JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Suppliers table
CREATE TABLE pim.material_supplier (
    id BIGSERIAL PRIMARY KEY,
    material_id BIGINT NOT NULL REFERENCES pim.material(id) ON DELETE CASCADE,
    supplier_id TEXT NOT NULL,
    name TEXT,
    code TEXT,
    is_primary BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tags table
CREATE TABLE pim.material_tag (
    id BIGSERIAL PRIMARY KEY,
    material_id BIGINT NOT NULL REFERENCES pim.material(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Plan Links table
CREATE TABLE pim.material_plan_link (
    id BIGSERIAL PRIMARY KEY,
    material_id BIGINT NOT NULL REFERENCES pim.material(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMIT;
