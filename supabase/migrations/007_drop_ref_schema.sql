-- Migration: Drop ref schema tables and schema
-- Purpose: Clean up old ref tables after successful migration to config.app_config
-- Author: Generated
-- Date: 2025-11-05
-- WARNING: This is a destructive operation. Ensure migration 006 has completed successfully before running this.

-- Drop all ref tables in dependency order

-- First drop the metadata table that has a self-reference
DROP TABLE IF EXISTS ref.masterdata_field_metadata CASCADE;

-- Drop timeline/template reference tables
DROP TABLE IF EXISTS ref.ref_department CASCADE;
DROP TABLE IF EXISTS ref.ref_node_type CASCADE;
DROP TABLE IF EXISTS ref.ref_offset_relation CASCADE;
DROP TABLE IF EXISTS ref.ref_offset_unit CASCADE;
DROP TABLE IF EXISTS ref.ref_page_type CASCADE;
DROP TABLE IF EXISTS ref.ref_phase CASCADE;
DROP TABLE IF EXISTS ref.ref_timeline_status CASCADE;
DROP TABLE IF EXISTS ref.ref_timeline_type CASCADE;
DROP TABLE IF EXISTS ref.ref_view_type CASCADE;

-- Drop BeProduct masterdata tables
DROP TABLE IF EXISTS ref.ref_product_type CASCADE;
DROP TABLE IF EXISTS ref.ref_delivery CASCADE;
DROP TABLE IF EXISTS ref.ref_gender CASCADE;
DROP TABLE IF EXISTS ref.ref_product_category CASCADE;
DROP TABLE IF EXISTS ref.ref_year CASCADE;
DROP TABLE IF EXISTS ref.ref_season CASCADE;
DROP TABLE IF EXISTS ref.ref_fabric_group CASCADE;
DROP TABLE IF EXISTS ref.ref_classification CASCADE;
DROP TABLE IF EXISTS ref.ref_status CASCADE;
DROP TABLE IF EXISTS ref.ref_account_manager CASCADE;
DROP TABLE IF EXISTS ref.ref_senior_product_developer CASCADE;
DROP TABLE IF EXISTS ref.ref_color_number_ls CASCADE;

-- Drop the ref schema
DROP SCHEMA IF EXISTS ref CASCADE;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Successfully dropped ref schema and all ref tables. Data has been migrated to config.app_config.';
END $$;
