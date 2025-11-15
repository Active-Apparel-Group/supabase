-- Seed Data for RLS Testing
-- Purpose: Populate test data for RLS implementation testing
-- Author: GitHub Copilot
-- Date: 2025-11-15

-- This file provides sample data for testing the RLS implementation
-- Run this after migrations 014-017 are applied

BEGIN;

-- ============================================================================
-- 1. CREATE TEST COMPANIES
-- ============================================================================

INSERT INTO mdm.company (id, code, name, company_type, is_internal, active) VALUES
-- Our company (internal)
('10000000-0000-0000-0000-000000000001', 'AAG', 'Active Apparel Group', 'internal', true, true),

-- Customer companies
('10000000-0000-0000-0000-000000000002', 'NIKE', 'Nike Inc', 'customer', false, true),
('10000000-0000-0000-0000-000000000003', 'ADIDAS', 'Adidas AG', 'customer', false, true),
('10000000-0000-0000-0000-000000000004', 'PUMA', 'Puma SE', 'customer', false, true),

-- Supplier companies
('10000000-0000-0000-0000-000000000005', 'TEXTILE_CORP', 'Global Textile Corporation', 'supplier', false, true),
('10000000-0000-0000-0000-000000000006', 'APPAREL_MFG', 'Apparel Manufacturing Ltd', 'supplier', false, true)

ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  active = EXCLUDED.active,
  updated_at = now();

-- ============================================================================
-- 2. CREATE TEST FACTORIES
-- ============================================================================

INSERT INTO mdm.factory (id, code, name, factory_type, company_id, active) VALUES
('20000000-0000-0000-0000-000000000001', 'CHINA_01', 'China Textile Factory 01', 'manufacturing', '10000000-0000-0000-0000-000000000005', true),
('20000000-0000-0000-0000-000000000002', 'CHINA_02', 'China Apparel Factory 02', 'manufacturing', '10000000-0000-0000-0000-000000000005', true),
('20000000-0000-0000-0000-000000000003', 'VIETNAM_01', 'Vietnam Garment Factory 01', 'manufacturing', '10000000-0000-0000-0000-000000000006', true),
('20000000-0000-0000-0000-000000000004', 'INDIA_01', 'India Textile Mill 01', 'manufacturing', '10000000-0000-0000-0000-000000000006', true),
('20000000-0000-0000-0000-000000000005', 'WAREHOUSE_US', 'US Distribution Warehouse', 'warehouse', '10000000-0000-0000-0000-000000000001', true)

ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  active = EXCLUDED.active,
  updated_at = now();

-- ============================================================================
-- 3. CREATE TEST BRANDS
-- ============================================================================

INSERT INTO mdm.brand (id, code, name, owner_company_id, active) VALUES
-- Nike brands
('30000000-0000-0000-0000-000000000001', 'NIKE_SPORT', 'Nike Sport', '10000000-0000-0000-0000-000000000002', true),
('30000000-0000-0000-0000-000000000002', 'NIKE_CASUAL', 'Nike Casual', '10000000-0000-0000-0000-000000000002', true),
('30000000-0000-0000-0000-000000000003', 'JORDAN', 'Jordan Brand', '10000000-0000-0000-0000-000000000002', true),

-- Adidas brands
('30000000-0000-0000-0000-000000000004', 'ADIDAS_SPORT', 'Adidas Sport Performance', '10000000-0000-0000-0000-000000000003', true),
('30000000-0000-0000-0000-000000000005', 'ADIDAS_ORIGINALS', 'Adidas Originals', '10000000-0000-0000-0000-000000000003', true),

-- Puma brands
('30000000-0000-0000-0000-000000000006', 'PUMA_SPORT', 'Puma Sport', '10000000-0000-0000-0000-000000000004', true),

-- AAG internal brands
('30000000-0000-0000-0000-000000000007', 'AAG_CORE', 'AAG Core Collection', '10000000-0000-0000-0000-000000000001', true),
('30000000-0000-0000-0000-000000000008', 'AAG_PREMIUM', 'AAG Premium Line', '10000000-0000-0000-0000-000000000001', true)

ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  active = EXCLUDED.active,
  updated_at = now();

-- ============================================================================
-- 4. CREATE TEST USER PROFILES
-- ============================================================================

-- Note: In production, these would be created via auth.users signup
-- For testing, we'll insert directly into user_profile

INSERT INTO public.user_profile (id, user_type, company_id, factory_id, full_name, role, active) VALUES
-- Internal users (AAG staff)
('40000000-0000-0000-0000-000000000001', 'internal', NULL, NULL, 'Admin User', 'admin', true),
('40000000-0000-0000-0000-000000000002', 'internal', NULL, NULL, 'Manager User', 'manager', true),
('40000000-0000-0000-0000-000000000003', 'internal', NULL, NULL, 'Developer User', 'developer', true),

-- Customer users (brand owners)
('40000000-0000-0000-0000-000000000004', 'customer', '10000000-0000-0000-0000-000000000002', NULL, 'Nike Brand Manager', 'manager', true),
('40000000-0000-0000-0000-000000000005', 'customer', '10000000-0000-0000-0000-000000000002', NULL, 'Nike Designer', 'designer', true),
('40000000-0000-0000-0000-000000000006', 'customer', '10000000-0000-0000-0000-000000000003', NULL, 'Adidas Product Manager', 'manager', true),
('40000000-0000-0000-0000-000000000007', 'customer', '10000000-0000-0000-0000-000000000004', NULL, 'Puma Merchandiser', 'merchandiser', true),

-- Factory users (suppliers)
('40000000-0000-0000-0000-000000000008', 'factory', NULL, '20000000-0000-0000-0000-000000000001', 'China Factory Manager', 'manager', true),
('40000000-0000-0000-0000-000000000009', 'factory', NULL, '20000000-0000-0000-0000-000000000002', 'China Apparel Supervisor', 'supervisor', true),
('40000000-0000-0000-0000-000000000010', 'factory', NULL, '20000000-0000-0000-0000-000000000003', 'Vietnam Factory Coordinator', 'coordinator', true)

ON CONFLICT (id) DO UPDATE SET
  user_type = EXCLUDED.user_type,
  company_id = EXCLUDED.company_id,
  factory_id = EXCLUDED.factory_id,
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role,
  active = EXCLUDED.active,
  updated_at = now();

-- ============================================================================
-- 5. CREATE EXPLICIT BRAND ACCESS GRANTS (Optional)
-- ============================================================================

-- Grant Nike designer access to Jordan brand (cross-brand collaboration)
INSERT INTO public.user_brand_access (user_id, brand_id, access_level, can_view_styles, can_edit_styles, active) VALUES
('40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000003', 'read', true, false, true)

ON CONFLICT (user_id, brand_id) DO UPDATE SET
  access_level = EXCLUDED.access_level,
  can_view_styles = EXCLUDED.can_view_styles,
  can_edit_styles = EXCLUDED.can_edit_styles,
  active = EXCLUDED.active,
  updated_at = now();

-- ============================================================================
-- 6. CREATE TEST STYLES IN PIM SCHEMA
-- ============================================================================

-- Insert sample styles with different brands
INSERT INTO pim.style (id, header_name, brand, season, year, product_type, status, deleted) VALUES
-- Nike styles
('50000000-0000-0000-0000-000000000001', 'Nike Air Max 2025', 'NIKE_SPORT', 'SPRING', '2025', 'FOOTWEAR', 'ACTIVE', false),
('50000000-0000-0000-0000-000000000002', 'Nike Cortez Retro', 'NIKE_CASUAL', 'FALL', '2025', 'FOOTWEAR', 'ACTIVE', false),
('50000000-0000-0000-0000-000000000003', 'Jordan Flight 2025', 'JORDAN', 'SUMMER', '2025', 'FOOTWEAR', 'ACTIVE', false),

-- Adidas styles
('50000000-0000-0000-0000-000000000004', 'Adidas Ultraboost 25', 'ADIDAS_SPORT', 'SPRING', '2025', 'FOOTWEAR', 'ACTIVE', false),
('50000000-0000-0000-0000-000000000005', 'Adidas Superstar Classic', 'ADIDAS_ORIGINALS', 'FALL', '2025', 'FOOTWEAR', 'ACTIVE', false),

-- Puma styles
('50000000-0000-0000-0000-000000000006', 'Puma Velocity 2025', 'PUMA_SPORT', 'SPRING', '2025', 'FOOTWEAR', 'ACTIVE', false),

-- AAG styles
('50000000-0000-0000-0000-000000000007', 'AAG Performance Tee', 'AAG_CORE', 'SPRING', '2025', 'APPAREL', 'ACTIVE', false),
('50000000-0000-0000-0000-000000000008', 'AAG Premium Polo', 'AAG_PREMIUM', 'SUMMER', '2025', 'APPAREL', 'ACTIVE', false)

ON CONFLICT (id) DO UPDATE SET
  header_name = EXCLUDED.header_name,
  brand = EXCLUDED.brand,
  season = EXCLUDED.season,
  year = EXCLUDED.year,
  updated_at = now();

-- ============================================================================
-- 7. CREATE TEST TRACKING FOLDERS (if tracking schema exists)
-- ============================================================================

-- Only insert if tracking.folders table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'tracking' AND table_name = 'folders') THEN
    INSERT INTO tracking.folders (id, name, brand, active) VALUES
    ('60000000-0000-0000-0000-000000000001', 'Nike 2025 Spring Collection', 'NIKE_SPORT', true),
    ('60000000-0000-0000-0000-000000000002', 'Nike 2025 Fall Collection', 'NIKE_CASUAL', true),
    ('60000000-0000-0000-0000-000000000003', 'Adidas 2025 Sport Collection', 'ADIDAS_SPORT', true),
    ('60000000-0000-0000-0000-000000000004', 'AAG Core 2025', 'AAG_CORE', true)
    
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      brand = EXCLUDED.brand,
      active = EXCLUDED.active,
      updated_at = now();
  END IF;
END $$;

-- ============================================================================
-- 8. CREATE TEST TRACKING PLANS (if tracking schema exists)
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'tracking' AND table_name = 'plans') THEN
    INSERT INTO tracking.plans (id, folder_id, name, brand, season, active) VALUES
    ('70000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 'Nike Spring 2025 Production Plan', 'NIKE_SPORT', 'SPRING', true),
    ('70000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002', 'Nike Fall 2025 Production Plan', 'NIKE_CASUAL', 'FALL', true),
    ('70000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000003', 'Adidas Sport 2025 Plan', 'ADIDAS_SPORT', 'SPRING', true),
    ('70000000-0000-0000-0000-000000000004', '60000000-0000-0000-0000-000000000004', 'AAG Core 2025 Plan', 'AAG_CORE', 'SPRING', true)
    
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      brand = EXCLUDED.brand,
      season = EXCLUDED.season,
      active = EXCLUDED.active,
      updated_at = now();
  END IF;
END $$;

-- ============================================================================
-- 9. CREATE TEST PLAN STYLES (if tracking schema exists)
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'tracking' AND table_name = 'plan_styles') THEN
    INSERT INTO tracking.plan_styles (id, plan_id, style_number, style_name, brand) VALUES
    ('80000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 'AM2025', 'Nike Air Max 2025', 'NIKE_SPORT'),
    ('80000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000002', 'CRT2025', 'Nike Cortez Retro', 'NIKE_CASUAL'),
    ('80000000-0000-0000-0000-000000000003', '70000000-0000-0000-0000-000000000003', 'UB25', 'Adidas Ultraboost 25', 'ADIDAS_SPORT'),
    ('80000000-0000-0000-0000-000000000004', '70000000-0000-0000-0000-000000000004', 'AAGPT', 'AAG Performance Tee', 'AAG_CORE')
    
    ON CONFLICT (id) DO UPDATE SET
      style_number = EXCLUDED.style_number,
      style_name = EXCLUDED.style_name,
      brand = EXCLUDED.brand,
      updated_at = now();
  END IF;
END $$;

-- ============================================================================
-- 10. CREATE TEST FACTORY ALLOCATIONS (triggers access grants)
-- ============================================================================

-- Allocate China Factory 01 to Nike Air Max
INSERT INTO ops.style_factory_allocation (
  tracking_plan_id,
  plan_style_id,
  factory_id,
  style_number,
  style_name,
  brand,
  allocated_quantity,
  active
) VALUES
('70000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'AM2025', 'Nike Air Max 2025', 'NIKE_SPORT', 5000, true),
('70000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'CRT2025', 'Nike Cortez Retro', 'NIKE_CASUAL', 3000, true),
('70000000-0000-0000-0000-000000000003', '80000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'UB25', 'Adidas Ultraboost 25', 'ADIDAS_SPORT', 4000, true)

ON CONFLICT (plan_style_id, factory_id) DO UPDATE SET
  allocated_quantity = EXCLUDED.allocated_quantity,
  active = EXCLUDED.active,
  updated_at = now();

-- Note: The above INSERT will trigger automatic creation of:
-- - ops.factory_tracking_plan_access entries
-- - ops.factory_tracking_folder_access entries

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify data was inserted
DO $$
BEGIN
  RAISE NOTICE 'Companies: %', (SELECT COUNT(*) FROM mdm.company);
  RAISE NOTICE 'Factories: %', (SELECT COUNT(*) FROM mdm.factory);
  RAISE NOTICE 'Brands: %', (SELECT COUNT(*) FROM mdm.brand);
  RAISE NOTICE 'User Profiles: %', (SELECT COUNT(*) FROM public.user_profile);
  RAISE NOTICE 'Styles: %', (SELECT COUNT(*) FROM pim.style);
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'tracking' AND table_name = 'folders') THEN
    RAISE NOTICE 'Tracking Folders: %', (SELECT COUNT(*) FROM tracking.folders);
    RAISE NOTICE 'Tracking Plans: %', (SELECT COUNT(*) FROM tracking.plans);
    RAISE NOTICE 'Plan Styles: %', (SELECT COUNT(*) FROM tracking.plan_styles);
  END IF;
  
  RAISE NOTICE 'Factory Allocations: %', (SELECT COUNT(*) FROM ops.style_factory_allocation);
  RAISE NOTICE 'Factory Plan Access: %', (SELECT COUNT(*) FROM ops.factory_tracking_plan_access);
  
  RAISE NOTICE '===============================================';
  RAISE NOTICE 'Seed data loaded successfully!';
  RAISE NOTICE 'Use the test user IDs in your application to test RLS';
  RAISE NOTICE '===============================================';
END $$;
