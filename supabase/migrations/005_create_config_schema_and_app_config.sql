-- Migration: Create config schema and app_config table
-- Purpose: Consolidate all ref tables into a single unified config table
-- Author: Generated
-- Date: 2025-11-05

-- Create the config schema
CREATE SCHEMA IF NOT EXISTS config;

-- Create the unified app_config table
CREATE TABLE config.app_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Core identification
  category TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  
  -- Display and type information
  display_label TEXT,
  data_type TEXT NOT NULL DEFAULT 'text',
  config_type TEXT NOT NULL DEFAULT 'enum',
  
  -- Ordering and hierarchy
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  parent_id UUID REFERENCES config.app_config(id) ON DELETE SET NULL,
  
  -- Extended metadata
  metadata JSONB DEFAULT '{}'::jsonb,
  
  -- Additional fields for migrated ref data
  description TEXT,
  color_hex TEXT,
  icon TEXT,
  allowed_for JSONB,
  is_terminal BOOLEAN DEFAULT false,
  
  -- Sync tracking (for BeProduct masterdata)
  last_synced_at TIMESTAMPTZ,
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  
  -- Unique constraint
  UNIQUE(category, key)
);

-- Create indexes for performance
CREATE INDEX idx_app_config_category ON config.app_config(category, is_active);
CREATE INDEX idx_app_config_type ON config.app_config(config_type, category);
CREATE INDEX idx_app_config_parent ON config.app_config(parent_id);
CREATE INDEX idx_app_config_key ON config.app_config(key);
CREATE INDEX idx_app_config_sort ON config.app_config(category, sort_order);
CREATE INDEX idx_app_config_metadata ON config.app_config USING gin(metadata);
CREATE INDEX idx_app_config_allowed_for ON config.app_config USING gin(allowed_for);

-- Add table comment
COMMENT ON TABLE config.app_config IS 'Unified configuration and reference data table. Replaces individual ref_* tables.';

-- Add column comments
COMMENT ON COLUMN config.app_config.category IS 'Category/domain of the config (e.g., department, product_type, season)';
COMMENT ON COLUMN config.app_config.key IS 'Unique key within the category (typically the code field from old ref tables)';
COMMENT ON COLUMN config.app_config.value IS 'Display value or label';
COMMENT ON COLUMN config.app_config.config_type IS 'Type of config: enum (dropdown), setting (app config), flag (feature flag), hierarchical (parent-child)';
COMMENT ON COLUMN config.app_config.data_type IS 'Data type: text, number, boolean, date, json, array';
COMMENT ON COLUMN config.app_config.parent_id IS 'Parent config for hierarchical relationships (e.g., product_type -> product_category)';
COMMENT ON COLUMN config.app_config.allowed_for IS 'JSON array of parent keys this config is allowed for (BeProduct cascade filtering)';
COMMENT ON COLUMN config.app_config.last_synced_at IS 'Last sync timestamp for BeProduct masterdata';

-- Create audit trigger function
CREATE OR REPLACE FUNCTION config.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  NEW.updated_by = auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to table
CREATE TRIGGER set_updated_at
BEFORE UPDATE ON config.app_config
FOR EACH ROW
EXECUTE FUNCTION config.update_updated_at();

-- Grant schema usage
GRANT USAGE ON SCHEMA config TO authenticated, anon, service_role;

-- Grant table permissions
GRANT SELECT ON config.app_config TO authenticated, anon;
GRANT ALL ON config.app_config TO service_role;

-- Enable RLS
ALTER TABLE config.app_config ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read active configs
CREATE POLICY "Anyone can read active configs"
ON config.app_config FOR SELECT
USING (is_active = true);

-- Policy: Service role can do everything (for sync operations)
CREATE POLICY "Service role has full access"
ON config.app_config FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy: Authenticated admins can manage configs
CREATE POLICY "Admins can manage configs"
ON config.app_config FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'admin'
      OR auth.users.raw_user_meta_data->>'is_admin' = 'true'
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'admin'
      OR auth.users.raw_user_meta_data->>'is_admin' = 'true'
    )
  )
);

-- Create helper function for upsert operations (for Edge Function compatibility)
CREATE OR REPLACE FUNCTION config.upsert_config(
  p_category TEXT,
  p_key TEXT,
  p_value TEXT,
  p_display_label TEXT DEFAULT NULL,
  p_config_type TEXT DEFAULT 'enum',
  p_data_type TEXT DEFAULT 'text',
  p_sort_order INTEGER DEFAULT 0,
  p_is_active BOOLEAN DEFAULT true,
  p_allowed_for JSONB DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_color_hex TEXT DEFAULT NULL,
  p_icon TEXT DEFAULT NULL,
  p_is_terminal BOOLEAN DEFAULT false,
  p_last_synced_at TIMESTAMPTZ DEFAULT now()
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO config.app_config (
    category, key, value, display_label, config_type, data_type, 
    sort_order, is_active, allowed_for, metadata, description, 
    color_hex, icon, is_terminal, last_synced_at
  )
  VALUES (
    p_category, p_key, p_value, p_display_label, p_config_type, p_data_type,
    p_sort_order, p_is_active, p_allowed_for, p_metadata, p_description,
    p_color_hex, p_icon, p_is_terminal, p_last_synced_at
  )
  ON CONFLICT (category, key) DO UPDATE SET
    value = EXCLUDED.value,
    display_label = EXCLUDED.display_label,
    config_type = EXCLUDED.config_type,
    data_type = EXCLUDED.data_type,
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active,
    allowed_for = EXCLUDED.allowed_for,
    metadata = EXCLUDED.metadata,
    description = EXCLUDED.description,
    color_hex = EXCLUDED.color_hex,
    icon = EXCLUDED.icon,
    is_terminal = EXCLUDED.is_terminal,
    last_synced_at = EXCLUDED.last_synced_at,
    updated_at = now()
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on upsert function
GRANT EXECUTE ON FUNCTION config.upsert_config TO service_role;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Config schema and app_config table created successfully';
END $$;
