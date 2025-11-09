-- Migration: Migrate data from ref schema to config.app_config
-- Purpose: Consolidate all 22 ref tables into the unified config table
-- Author: Generated
-- Date: 2025-11-05

-- Migrate timeline/template reference tables (manually managed)

-- ref_department -> category: department
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, config_type, data_type, created_at, updated_at)
SELECT 
  'department' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_department
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  updated_at = EXCLUDED.updated_at;

-- ref_node_type -> category: node_type
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, config_type, data_type, created_at, updated_at)
SELECT 
  'node_type' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_node_type
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  updated_at = EXCLUDED.updated_at;

-- ref_offset_relation -> category: offset_relation
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, config_type, data_type, created_at, updated_at)
SELECT 
  'offset_relation' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_offset_relation
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  updated_at = EXCLUDED.updated_at;

-- ref_offset_unit -> category: offset_unit
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, config_type, data_type, created_at, updated_at)
SELECT 
  'offset_unit' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_offset_unit
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  updated_at = EXCLUDED.updated_at;

-- ref_page_type -> category: page_type
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, config_type, data_type, created_at, updated_at)
SELECT 
  'page_type' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_page_type
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  updated_at = EXCLUDED.updated_at;

-- ref_phase -> category: phase
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, color_hex, config_type, data_type, created_at, updated_at)
SELECT 
  'phase' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  color_hex,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_phase
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  color_hex = EXCLUDED.color_hex,
  updated_at = EXCLUDED.updated_at;

-- ref_timeline_status -> category: timeline_status
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, color_hex, icon, is_terminal, config_type, data_type, created_at, updated_at)
SELECT 
  'timeline_status' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  color_hex,
  icon,
  is_terminal,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_timeline_status
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  color_hex = EXCLUDED.color_hex,
  icon = EXCLUDED.icon,
  is_terminal = EXCLUDED.is_terminal,
  updated_at = EXCLUDED.updated_at;

-- ref_timeline_type -> category: timeline_type
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, config_type, data_type, created_at, updated_at)
SELECT 
  'timeline_type' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_timeline_type
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  updated_at = EXCLUDED.updated_at;

-- ref_view_type -> category: view_type
INSERT INTO config.app_config (category, key, value, description, sort_order, is_active, config_type, data_type, created_at, updated_at)
SELECT 
  'view_type' as category,
  code as key,
  label as value,
  description,
  display_order as sort_order,
  is_active,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_view_type
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  updated_at = EXCLUDED.updated_at;

-- Migrate BeProduct masterdata tables (API synced)

-- ref_product_type -> category: product_type
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'product_type' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_product_type
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_delivery -> category: delivery
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'delivery' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_delivery
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_gender -> category: gender
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'gender' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_gender
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_product_category -> category: product_category
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'product_category' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_product_category
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_year -> category: year
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'year' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_year
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_season -> category: season
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'season' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_season
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_fabric_group -> category: fabric_group
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'fabric_group' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_fabric_group
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_classification -> category: classification
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'classification' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_classification
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_status -> category: status
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'status' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_status
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_account_manager -> category: account_manager
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'account_manager' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_account_manager
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_senior_product_developer -> category: senior_product_developer
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'senior_product_developer' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_senior_product_developer
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- ref_color_number_ls -> category: color_number_ls
INSERT INTO config.app_config (category, key, value, is_active, allowed_for, last_synced_at, config_type, data_type, created_at, updated_at)
SELECT 
  'color_number_ls' as category,
  code as key,
  value,
  active as is_active,
  allowed_for,
  last_synced_at,
  'enum' as config_type,
  'text' as data_type,
  created_at,
  updated_at
FROM ref.ref_color_number_ls
ON CONFLICT (category, key) DO UPDATE SET
  value = EXCLUDED.value,
  is_active = EXCLUDED.is_active,
  allowed_for = EXCLUDED.allowed_for,
  last_synced_at = EXCLUDED.last_synced_at,
  updated_at = EXCLUDED.updated_at;

-- Migrate masterdata_field_metadata to store parent field relationships
-- This will be stored in the metadata jsonb field and can be used to establish parent_id relationships
DO $$
DECLARE
  r RECORD;
  parent_config_id UUID;
BEGIN
  FOR r IN 
    SELECT field_id, parent_field_id
    FROM ref.masterdata_field_metadata
    WHERE parent_field_id IS NOT NULL
  LOOP
    -- Find the parent_id in app_config for this field
    -- The parent is in the parent_field_id category
    SELECT id INTO parent_config_id
    FROM config.app_config
    WHERE category = r.parent_field_id
    LIMIT 1;
    
    IF parent_config_id IS NOT NULL THEN
      -- Update all records in this category to reference their parent
      UPDATE config.app_config
      SET metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{parent_field}',
        to_jsonb(r.parent_field_id)
      )
      WHERE category = r.field_id;
      
      RAISE NOTICE 'Set parent_field metadata for category % -> %', r.field_id, r.parent_field_id;
    END IF;
  END LOOP;
END $$;

-- Summary
DO $$
DECLARE
  total_count INTEGER;
  category_counts TEXT;
BEGIN
  SELECT COUNT(*) INTO total_count FROM config.app_config;
  
  SELECT string_agg(category || ': ' || cnt::TEXT, ', ' ORDER BY category)
  INTO category_counts
  FROM (
    SELECT category, COUNT(*) as cnt
    FROM config.app_config
    GROUP BY category
  ) t;
  
  RAISE NOTICE 'Migration complete! Total records: %. Categories: %', total_count, category_counts;
END $$;
