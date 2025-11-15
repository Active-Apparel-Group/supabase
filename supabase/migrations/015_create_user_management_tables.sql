-- Migration: Create User Management Tables for RLS Support
-- Purpose: Link auth.users to companies/factories and manage user access
-- Author: GitHub Copilot
-- Date: 2025-11-15

-- This migration creates user profile tables that extend Supabase auth.users
-- and link users to companies, factories, and brands for access control.

BEGIN;

-- ============================================================================
-- 1. CREATE USER TYPE ENUM
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_type_enum') THEN
        CREATE TYPE public.user_type_enum AS ENUM ('internal', 'customer', 'factory', 'external');
    END IF;
END $$;

COMMENT ON TYPE public.user_type_enum IS 'User type: internal (our staff), customer (brand owners), factory (suppliers), external (other)';

-- ============================================================================
-- 2. CREATE USER PROFILE TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_profile (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- User Type and Affiliation
    user_type public.user_type_enum NOT NULL DEFAULT 'external',
    company_id UUID REFERENCES mdm.company(id) ON DELETE SET NULL,
    factory_id UUID REFERENCES mdm.factory(id) ON DELETE SET NULL,
    
    -- Profile Information
    full_name VARCHAR(255),
    display_name VARCHAR(255),
    job_title VARCHAR(255),
    department VARCHAR(100),
    
    -- Contact Information
    phone VARCHAR(50),
    mobile VARCHAR(50),
    office_location VARCHAR(255),
    
    -- Role and Permissions (stored in JWT as well)
    role VARCHAR(50), -- 'admin', 'manager', 'viewer', etc.
    permissions JSONB DEFAULT '[]'::jsonb, -- Array of permission strings
    
    -- User Preferences
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(10) DEFAULT 'en',
    preferences JSONB DEFAULT '{}'::jsonb,
    
    -- Avatar/Photo
    avatar_url TEXT,
    
    -- Status
    active BOOLEAN DEFAULT true,
    email_verified BOOLEAN DEFAULT false,
    last_login_at TIMESTAMPTZ,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Audit Fields
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    -- Constraints
    CONSTRAINT user_affiliation_check CHECK (
        (user_type = 'internal' AND company_id IS NULL AND factory_id IS NULL) OR
        (user_type = 'customer' AND company_id IS NOT NULL AND factory_id IS NULL) OR
        (user_type = 'factory' AND factory_id IS NOT NULL AND company_id IS NULL) OR
        (user_type = 'external')
    )
);

CREATE INDEX idx_user_profile_type ON public.user_profile(user_type);
CREATE INDEX idx_user_profile_company ON public.user_profile(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX idx_user_profile_factory ON public.user_profile(factory_id) WHERE factory_id IS NOT NULL;
CREATE INDEX idx_user_profile_role ON public.user_profile(role);
CREATE INDEX idx_user_profile_active ON public.user_profile(active) WHERE active = true;

COMMENT ON TABLE public.user_profile IS 'Extended user profile linking auth.users to companies/factories';
COMMENT ON COLUMN public.user_profile.user_type IS 'Type of user - determines access control pattern';
COMMENT ON COLUMN public.user_profile.company_id IS 'Linked company for customer users';
COMMENT ON COLUMN public.user_profile.factory_id IS 'Linked factory for supplier users';
COMMENT ON COLUMN public.user_profile.permissions IS 'JSON array of permission strings';

-- ============================================================================
-- 3. CREATE USER BRAND ACCESS TABLE
-- ============================================================================

-- This table explicitly grants users access to specific brands
-- Useful for fine-grained control beyond company ownership

CREATE TABLE IF NOT EXISTS public.user_brand_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    brand_id UUID NOT NULL REFERENCES mdm.brand(id) ON DELETE CASCADE,
    
    -- Access Level
    access_level VARCHAR(50) DEFAULT 'read', -- 'read', 'write', 'admin'
    can_view_styles BOOLEAN DEFAULT true,
    can_edit_styles BOOLEAN DEFAULT false,
    can_view_tracking BOOLEAN DEFAULT true,
    can_edit_tracking BOOLEAN DEFAULT false,
    
    -- Status
    active BOOLEAN DEFAULT true,
    granted_by UUID REFERENCES auth.users(id),
    granted_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(user_id, brand_id)
);

CREATE INDEX idx_user_brand_access_user ON public.user_brand_access(user_id);
CREATE INDEX idx_user_brand_access_brand ON public.user_brand_access(brand_id);
CREATE INDEX idx_user_brand_access_active ON public.user_brand_access(active) WHERE active = true;

COMMENT ON TABLE public.user_brand_access IS 'Explicit brand access grants for users (overrides default company access)';
COMMENT ON COLUMN public.user_brand_access.access_level IS 'Access level: read, write, admin';

-- ============================================================================
-- 4. CREATE FUNCTION TO AUTO-CREATE USER PROFILE
-- ============================================================================

-- This function automatically creates a user_profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profile (id, user_type, full_name, email_verified)
    VALUES (
        NEW.id,
        'external', -- Default to external, admin can update
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        NEW.email_confirmed_at IS NOT NULL
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 5. CREATE FUNCTION TO SYNC USER METADATA TO PROFILE
-- ============================================================================

-- Sync changes from auth.users to user_profile
CREATE OR REPLACE FUNCTION public.sync_user_metadata()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.user_profile
    SET 
        full_name = COALESCE(NEW.raw_user_meta_data->>'full_name', full_name),
        email_verified = (NEW.email_confirmed_at IS NOT NULL),
        last_login_at = CASE 
            WHEN NEW.last_sign_in_at > OLD.last_sign_in_at THEN NEW.last_sign_in_at
            ELSE last_login_at
        END,
        updated_at = now()
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated
    AFTER UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_user_metadata();

-- ============================================================================
-- 6. CREATE HELPER FUNCTIONS FOR ACCESS CONTROL
-- ============================================================================

-- Get brands accessible by current user
CREATE OR REPLACE FUNCTION public.get_accessible_brands(p_user_id UUID DEFAULT auth.uid())
RETURNS TABLE(brand_id UUID, brand_code VARCHAR, brand_name TEXT, access_level VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        b.id AS brand_id,
        b.code AS brand_code,
        b.name AS brand_name,
        COALESCE(uba.access_level, 'read') AS access_level
    FROM mdm.brand b
    LEFT JOIN public.user_profile up ON up.id = p_user_id
    LEFT JOIN public.user_brand_access uba ON uba.user_id = p_user_id AND uba.brand_id = b.id AND uba.active = true
    WHERE 
        b.active = true
        AND (
            -- Internal users see all brands
            up.user_type = 'internal'
            OR
            -- Customer users see brands owned by their company
            (up.user_type = 'customer' AND b.owner_company_id = up.company_id)
            OR
            -- Users with explicit brand access
            uba.id IS NOT NULL
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_accessible_brands IS 'Returns brands accessible by user based on their type and explicit grants';

-- Get brand codes accessible by current user (as array)
CREATE OR REPLACE FUNCTION public.get_accessible_brand_codes(p_user_id UUID DEFAULT auth.uid())
RETURNS TEXT[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT brand_code 
        FROM public.get_accessible_brands(p_user_id)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_accessible_brand_codes IS 'Returns array of brand codes accessible by user';

-- Check if user can access a specific brand
CREATE OR REPLACE FUNCTION public.can_access_brand(p_brand_code VARCHAR, p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    RETURN p_brand_code = ANY(public.get_accessible_brand_codes(p_user_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.can_access_brand IS 'Check if user has access to a specific brand';

-- ============================================================================
-- 7. CREATE UPDATE TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_user_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_user_profile_updated_at
    BEFORE UPDATE ON public.user_profile
    FOR EACH ROW
    EXECUTE FUNCTION public.update_user_profile_updated_at();

CREATE TRIGGER set_user_brand_access_updated_at
    BEFORE UPDATE ON public.user_brand_access
    FOR EACH ROW
    EXECUTE FUNCTION public.update_user_profile_updated_at();

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================

GRANT SELECT ON public.user_profile TO authenticated;
GRANT UPDATE (full_name, display_name, phone, mobile, timezone, language, preferences, avatar_url) 
    ON public.user_profile TO authenticated;
GRANT ALL ON public.user_profile TO service_role;

GRANT SELECT ON public.user_brand_access TO authenticated;
GRANT ALL ON public.user_brand_access TO service_role;

GRANT EXECUTE ON FUNCTION public.get_accessible_brands TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_accessible_brand_codes TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_brand TO authenticated;

-- ============================================================================
-- 9. ENABLE RLS
-- ============================================================================

ALTER TABLE public.user_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_brand_access ENABLE ROW LEVEL SECURITY;

-- User can read their own profile
CREATE POLICY "Users can view own profile"
    ON public.user_profile FOR SELECT
    USING (id = auth.uid());

-- User can update their own profile (limited fields)
CREATE POLICY "Users can update own profile"
    ON public.user_profile FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Internal users can view all profiles
CREATE POLICY "Internal users can view all profiles"
    ON public.user_profile FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() AND up.user_type = 'internal' AND up.active = true
        )
    );

-- Users can view their brand access
CREATE POLICY "Users can view own brand access"
    ON public.user_brand_access FOR SELECT
    USING (user_id = auth.uid());

-- Service role has full access
CREATE POLICY "Service role full access to user profiles"
    ON public.user_profile FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to brand access"
    ON public.user_brand_access FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'User management tables created successfully';
END $$;
