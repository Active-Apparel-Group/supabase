-- Migration: Create MDM (Master Data Management) Schema for RLS Support
-- Purpose: Establish foundation tables for multi-tenant access control
-- Author: GitHub Copilot
-- Date: 2025-11-15

-- This migration creates the MDM schema to support Row-Level Security (RLS)
-- by defining companies (customers), factories (suppliers), and brands.
-- These entities form the basis for controlling user access to data.

BEGIN;

-- ============================================================================
-- 1. CREATE MDM SCHEMA
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS mdm;

COMMENT ON SCHEMA mdm IS 'Master Data Management - Contains reference data for companies, factories, brands, and their relationships';

-- ============================================================================
-- 2. CREATE ENUMS
-- ============================================================================

-- Company type enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'company_type_enum') THEN
        CREATE TYPE mdm.company_type_enum AS ENUM ('customer', 'supplier', 'internal', 'partner');
    END IF;
END $$;

COMMENT ON TYPE mdm.company_type_enum IS 'Type of company: customer (owns brands), supplier (manufactures), internal (our company), partner (other)';

-- Factory type enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factory_type_enum') THEN
        CREATE TYPE mdm.factory_type_enum AS ENUM ('manufacturing', 'finishing', 'printing', 'embroidery', 'warehouse');
    END IF;
END $$;

COMMENT ON TYPE mdm.factory_type_enum IS 'Type of factory/facility';

-- ============================================================================
-- 3. CREATE COMPANY TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS mdm.company (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Basic Information
    code VARCHAR(50) NOT NULL UNIQUE,
    name TEXT NOT NULL,
    legal_name TEXT,
    company_type mdm.company_type_enum NOT NULL DEFAULT 'customer',
    
    -- Contact Information
    email VARCHAR(255),
    phone VARCHAR(50),
    website TEXT,
    
    -- Address
    address_line1 TEXT,
    address_line2 TEXT,
    city VARCHAR(100),
    state_province VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    
    -- Business Details
    tax_id VARCHAR(100),
    currency_code VARCHAR(3) DEFAULT 'USD',
    payment_terms VARCHAR(100),
    credit_limit NUMERIC(15, 2),
    
    -- Status & Metadata
    active BOOLEAN DEFAULT true,
    is_internal BOOLEAN DEFAULT false,
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- BeProduct Integration
    beproduct_company_id UUID,
    last_synced_at TIMESTAMPTZ,
    
    -- Audit Fields
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX idx_company_code ON mdm.company(code);
CREATE INDEX idx_company_type ON mdm.company(company_type);
CREATE INDEX idx_company_active ON mdm.company(active) WHERE active = true;
CREATE INDEX idx_company_beproduct_id ON mdm.company(beproduct_company_id) WHERE beproduct_company_id IS NOT NULL;

COMMENT ON TABLE mdm.company IS 'Companies (customers, suppliers, partners). Customers own brands and control access to style folders.';
COMMENT ON COLUMN mdm.company.code IS 'Unique company code (e.g., NIKE, ADIDAS, AAG)';
COMMENT ON COLUMN mdm.company.company_type IS 'Type of company - determines access patterns';
COMMENT ON COLUMN mdm.company.is_internal IS 'True if this is our company (Active Apparel Group)';

-- ============================================================================
-- 4. CREATE FACTORY TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS mdm.factory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Basic Information
    code VARCHAR(50) NOT NULL UNIQUE,
    name TEXT NOT NULL,
    factory_type mdm.factory_type_enum NOT NULL DEFAULT 'manufacturing',
    
    -- Ownership (link to parent company if factory is part of a supplier company)
    company_id UUID REFERENCES mdm.company(id) ON DELETE SET NULL,
    
    -- Contact Information
    contact_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    
    -- Address
    address_line1 TEXT,
    address_line2 TEXT,
    city VARCHAR(100),
    state_province VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    
    -- Capabilities
    capabilities JSONB DEFAULT '[]'::jsonb, -- Array of capability strings
    certifications JSONB DEFAULT '[]'::jsonb, -- Array of certification objects
    production_capacity INTEGER, -- Units per month
    lead_time_days INTEGER,
    
    -- Status & Metadata
    active BOOLEAN DEFAULT true,
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- BeProduct Integration
    beproduct_supplier_id UUID,
    last_synced_at TIMESTAMPTZ,
    
    -- Audit Fields
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX idx_factory_code ON mdm.factory(code);
CREATE INDEX idx_factory_type ON mdm.factory(factory_type);
CREATE INDEX idx_factory_company_id ON mdm.factory(company_id);
CREATE INDEX idx_factory_active ON mdm.factory(active) WHERE active = true;
CREATE INDEX idx_factory_beproduct_id ON mdm.factory(beproduct_supplier_id) WHERE beproduct_supplier_id IS NOT NULL;
CREATE INDEX idx_factory_capabilities ON mdm.factory USING gin(capabilities);

COMMENT ON TABLE mdm.factory IS 'Factories/suppliers that manufacture products. Linked to tracking plans via allocations.';
COMMENT ON COLUMN mdm.factory.code IS 'Unique factory code (e.g., FACTORY_001, CHINA_TEXTILE_01)';
COMMENT ON COLUMN mdm.factory.company_id IS 'Parent company if factory belongs to a supplier organization';
COMMENT ON COLUMN mdm.factory.capabilities IS 'JSON array of capabilities (e.g., ["knitting", "dyeing", "sewing"])';

-- ============================================================================
-- 5. CREATE BRAND TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS mdm.brand (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Basic Information
    code VARCHAR(50) NOT NULL UNIQUE,
    name TEXT NOT NULL,
    display_name TEXT,
    
    -- Ownership - link to customer company
    owner_company_id UUID NOT NULL REFERENCES mdm.company(id) ON DELETE CASCADE,
    
    -- Brand Details
    description TEXT,
    logo_url TEXT,
    website TEXT,
    
    -- Status & Metadata
    active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- BeProduct Integration
    beproduct_brand_code VARCHAR(100),
    last_synced_at TIMESTAMPTZ,
    
    -- Audit Fields
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    
    CONSTRAINT brand_code_format CHECK (code = upper(code))
);

CREATE INDEX idx_brand_code ON mdm.brand(code);
CREATE INDEX idx_brand_owner_company ON mdm.brand(owner_company_id);
CREATE INDEX idx_brand_active ON mdm.brand(active) WHERE active = true;
CREATE INDEX idx_brand_beproduct_code ON mdm.brand(beproduct_brand_code) WHERE beproduct_brand_code IS NOT NULL;

COMMENT ON TABLE mdm.brand IS 'Brands owned by customer companies. Used to control access to style and tracking folders.';
COMMENT ON COLUMN mdm.brand.code IS 'Unique brand code matching brand fields in pim.style and ops tables (e.g., AAG_CORE, AAG_PREMIUM)';
COMMENT ON COLUMN mdm.brand.owner_company_id IS 'Customer company that owns this brand - determines who can access brand data';

-- ============================================================================
-- 6. CREATE BRAND CONTACT TABLE (for multi-contact support)
-- ============================================================================

CREATE TABLE IF NOT EXISTS mdm.brand_contact (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID NOT NULL REFERENCES mdm.brand(id) ON DELETE CASCADE,
    
    -- Contact Information
    name VARCHAR(255) NOT NULL,
    title VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(50),
    is_primary BOOLEAN DEFAULT false,
    
    -- Audit Fields
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT brand_one_primary_contact UNIQUE (brand_id, is_primary) 
        DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX idx_brand_contact_brand ON mdm.brand_contact(brand_id);

COMMENT ON TABLE mdm.brand_contact IS 'Contact persons for brands';

-- ============================================================================
-- 7. CREATE UPDATE TRIGGER FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION mdm.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    IF TG_TABLE_NAME IN ('company', 'factory', 'brand') THEN
        NEW.updated_by = auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER set_company_updated_at
    BEFORE UPDATE ON mdm.company
    FOR EACH ROW
    EXECUTE FUNCTION mdm.update_updated_at();

CREATE TRIGGER set_factory_updated_at
    BEFORE UPDATE ON mdm.factory
    FOR EACH ROW
    EXECUTE FUNCTION mdm.update_updated_at();

CREATE TRIGGER set_brand_updated_at
    BEFORE UPDATE ON mdm.brand
    FOR EACH ROW
    EXECUTE FUNCTION mdm.update_updated_at();

CREATE TRIGGER set_brand_contact_updated_at
    BEFORE UPDATE ON mdm.brand_contact
    FOR EACH ROW
    EXECUTE FUNCTION mdm.update_updated_at();

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON SCHEMA mdm TO authenticated, anon, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA mdm TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA mdm TO service_role;

-- ============================================================================
-- 9. ENABLE RLS (Policies will be added in next migration)
-- ============================================================================

ALTER TABLE mdm.company ENABLE ROW LEVEL SECURITY;
ALTER TABLE mdm.factory ENABLE ROW LEVEL SECURITY;
ALTER TABLE mdm.brand ENABLE ROW LEVEL SECURITY;
ALTER TABLE mdm.brand_contact ENABLE ROW LEVEL SECURITY;

-- Permissive policies for now (will be restricted in migration 016)
CREATE POLICY "Allow read access to active companies"
    ON mdm.company FOR SELECT
    USING (active = true);

CREATE POLICY "Allow read access to active factories"
    ON mdm.factory FOR SELECT
    USING (active = true);

CREATE POLICY "Allow read access to active brands"
    ON mdm.brand FOR SELECT
    USING (active = true);

CREATE POLICY "Allow read access to brand contacts"
    ON mdm.brand_contact FOR SELECT
    USING (true);

-- Service role has full access
CREATE POLICY "Service role full access to companies"
    ON mdm.company FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to factories"
    ON mdm.factory FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to brands"
    ON mdm.brand FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to brand contacts"
    ON mdm.brand_contact FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'MDM schema created successfully with company, factory, and brand tables';
END $$;
