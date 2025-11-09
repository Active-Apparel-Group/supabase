-- Migration: Restore ref schema and reference tables
-- Date: 2025-11-05

CREATE SCHEMA IF NOT EXISTS ref;

-- Table template for all reference tables
-- Columns: code, label, description, display_order, is_active, created_at, updated_at, color_hex, icon, is_terminal

-- 1. Department
CREATE TABLE IF NOT EXISTS ref.ref_department (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  color_hex TEXT,
  icon TEXT,
  is_terminal BOOLEAN
);
COMMENT ON TABLE ref.ref_department IS 'Department assignments for timeline and plan.';

-- 2. Node Type
CREATE TABLE IF NOT EXISTS ref.ref_node_type (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE ref.ref_node_type IS 'Node type for timeline template items.';

-- 3. Offset Relation
CREATE TABLE IF NOT EXISTS ref.ref_offset_relation (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE ref.ref_offset_relation IS 'Offset relation for timeline dependencies.';

-- 4. Offset Unit
CREATE TABLE IF NOT EXISTS ref.ref_offset_unit (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE ref.ref_offset_unit IS 'Offset unit for timeline dependencies.';

-- 5. Page Type
CREATE TABLE IF NOT EXISTS ref.ref_page_type (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE ref.ref_page_type IS 'Page type for timeline template items.';

-- 6. Phase
CREATE TABLE IF NOT EXISTS ref.ref_phase (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  color_hex TEXT
);
COMMENT ON TABLE ref.ref_phase IS 'Phase reference for timeline and plan.';

-- 7. Timeline Status
CREATE TABLE IF NOT EXISTS ref.ref_timeline_status (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  color_hex TEXT,
  is_terminal BOOLEAN
);
COMMENT ON TABLE ref.ref_timeline_status IS 'Timeline status reference for milestones.';

-- 8. Timeline Type
CREATE TABLE IF NOT EXISTS ref.ref_timeline_type (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE ref.ref_timeline_type IS 'Timeline type reference.';

-- 9. View Type
CREATE TABLE IF NOT EXISTS ref.ref_view_type (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE ref.ref_view_type IS 'View type reference for plan views.';

-- Indexes for active records and ordering
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN SELECT tablename FROM pg_tables WHERE schemaname = 'ref' LOOP
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I_is_active_idx ON ref.%I (is_active);', tbl, tbl);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I_display_order_idx ON ref.%I (display_order);', tbl, tbl);
  END LOOP;
END $$;

-- Enable RLS and add SELECT policies
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN SELECT tablename FROM pg_tables WHERE schemaname = 'ref' LOOP
    EXECUTE format('ALTER TABLE ref.%I ENABLE ROW LEVEL SECURITY;', tbl);
    EXECUTE format('CREATE POLICY IF NOT EXISTS allow_read_access ON ref.%I FOR SELECT USING (true);', tbl);
  END LOOP;
END $$;
