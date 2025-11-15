-- Migration: Create Factory Tracking Access Tables and Triggers
-- Purpose: Manage factory access to tracking plans/folders based on allocations
-- Author: GitHub Copilot
-- Date: 2025-11-15

-- This migration creates tables to track factory access to tracking plans
-- and folders, with automatic triggers to update access when factories are
-- allocated to styles on tracking plans.

BEGIN;

-- ============================================================================
-- 1. CREATE OPS SCHEMA (if not exists)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS ops;

COMMENT ON SCHEMA ops IS 'Operational data - tracking plans, timelines, allocations, and sync logs';

-- ============================================================================
-- 2. CREATE FACTORY TRACKING FOLDER ACCESS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS ops.factory_tracking_folder_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Factory and Folder
    factory_id UUID NOT NULL REFERENCES mdm.factory(id) ON DELETE CASCADE,
    tracking_folder_id UUID NOT NULL, -- Links to tracking.folders or ops tracking folder
    folder_name TEXT,
    brand TEXT,
    
    -- Access Details
    access_granted_at TIMESTAMPTZ DEFAULT now(),
    access_granted_by UUID REFERENCES auth.users(id),
    access_reason TEXT, -- 'allocation', 'manual_grant', etc.
    
    -- Status
    active BOOLEAN DEFAULT true,
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES auth.users(id),
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(factory_id, tracking_folder_id)
);

CREATE INDEX idx_factory_folder_access_factory ON ops.factory_tracking_folder_access(factory_id);
CREATE INDEX idx_factory_folder_access_folder ON ops.factory_tracking_folder_access(tracking_folder_id);
CREATE INDEX idx_factory_folder_access_active ON ops.factory_tracking_folder_access(active) WHERE active = true;
CREATE INDEX idx_factory_folder_access_brand ON ops.factory_tracking_folder_access(brand);

COMMENT ON TABLE ops.factory_tracking_folder_access IS 'Tracks which factories have access to which tracking folders';
COMMENT ON COLUMN ops.factory_tracking_folder_access.access_reason IS 'Why access was granted (allocation, manual_grant, etc.)';

-- ============================================================================
-- 3. CREATE FACTORY TRACKING PLAN ACCESS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS ops.factory_tracking_plan_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Factory and Plan
    factory_id UUID NOT NULL REFERENCES mdm.factory(id) ON DELETE CASCADE,
    tracking_plan_id UUID NOT NULL, -- Links to tracking.plans or ops tracking plan
    plan_name TEXT,
    season TEXT,
    brand TEXT,
    
    -- Access Details
    access_granted_at TIMESTAMPTZ DEFAULT now(),
    access_granted_by UUID REFERENCES auth.users(id),
    access_reason TEXT, -- 'style_allocation', 'manual_grant', etc.
    allocation_count INTEGER DEFAULT 0, -- Number of styles/timelines allocated
    
    -- Status
    active BOOLEAN DEFAULT true,
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES auth.users(id),
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(factory_id, tracking_plan_id)
);

CREATE INDEX idx_factory_plan_access_factory ON ops.factory_tracking_plan_access(factory_id);
CREATE INDEX idx_factory_plan_access_plan ON ops.factory_tracking_plan_access(tracking_plan_id);
CREATE INDEX idx_factory_plan_access_active ON ops.factory_tracking_plan_access(active) WHERE active = true;
CREATE INDEX idx_factory_plan_access_brand ON ops.factory_tracking_plan_access(brand);

COMMENT ON TABLE ops.factory_tracking_plan_access IS 'Tracks which factories have access to which tracking plans based on allocations';
COMMENT ON COLUMN ops.factory_tracking_plan_access.allocation_count IS 'Number of active style allocations to this factory in this plan';

-- ============================================================================
-- 4. CREATE STYLE FACTORY ALLOCATION TABLE
-- ============================================================================

-- This table tracks which factory is allocated to which style in a tracking plan
-- Used to determine factory access to tracking data

CREATE TABLE IF NOT EXISTS ops.style_factory_allocation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Style and Factory
    tracking_plan_id UUID NOT NULL, -- Links to tracking.plans
    plan_style_id UUID NOT NULL, -- Links to tracking.plan_styles
    factory_id UUID NOT NULL REFERENCES mdm.factory(id) ON DELETE CASCADE,
    
    -- Style Details (denormalized for performance)
    style_number TEXT,
    style_name TEXT,
    color_name TEXT,
    brand TEXT,
    
    -- Allocation Details
    allocated_quantity INTEGER,
    allocated_at TIMESTAMPTZ DEFAULT now(),
    allocated_by UUID REFERENCES auth.users(id),
    
    -- Production Details
    target_ship_date DATE,
    target_delivery_date DATE,
    notes TEXT,
    
    -- Status
    active BOOLEAN DEFAULT true,
    completed BOOLEAN DEFAULT false,
    cancelled BOOLEAN DEFAULT false,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(plan_style_id, factory_id)
);

CREATE INDEX idx_style_allocation_plan ON ops.style_factory_allocation(tracking_plan_id);
CREATE INDEX idx_style_allocation_style ON ops.style_factory_allocation(plan_style_id);
CREATE INDEX idx_style_allocation_factory ON ops.style_factory_allocation(factory_id);
CREATE INDEX idx_style_allocation_active ON ops.style_factory_allocation(active) WHERE active = true;
CREATE INDEX idx_style_allocation_brand ON ops.style_factory_allocation(brand);

COMMENT ON TABLE ops.style_factory_allocation IS 'Tracks factory allocations to styles in tracking plans - triggers access grants';
COMMENT ON COLUMN ops.style_factory_allocation.plan_style_id IS 'References tracking.plan_styles.id';

-- ============================================================================
-- 5. CREATE TRIGGER FUNCTION TO AUTO-GRANT ACCESS ON ALLOCATION
-- ============================================================================

-- When a factory is allocated to a style, automatically grant access to the
-- plan and folder

CREATE OR REPLACE FUNCTION ops.grant_factory_access_on_allocation()
RETURNS TRIGGER AS $$
DECLARE
    v_folder_id UUID;
    v_folder_name TEXT;
    v_plan_name TEXT;
    v_season TEXT;
    v_brand TEXT;
BEGIN
    -- Skip if not active
    IF NEW.active = false THEN
        RETURN NEW;
    END IF;
    
    -- Get plan and folder details from tracking.plans
    -- Note: Adjust this query based on your actual tracking schema
    SELECT 
        p.folder_id,
        f.name,
        p.name,
        p.season,
        p.brand
    INTO 
        v_folder_id,
        v_folder_name,
        v_plan_name,
        v_season,
        v_brand
    FROM tracking.plans p
    LEFT JOIN tracking.folders f ON f.id = p.folder_id
    WHERE p.id = NEW.tracking_plan_id;
    
    -- Grant access to tracking plan
    INSERT INTO ops.factory_tracking_plan_access (
        factory_id,
        tracking_plan_id,
        plan_name,
        season,
        brand,
        access_granted_by,
        access_reason,
        allocation_count,
        active
    )
    VALUES (
        NEW.factory_id,
        NEW.tracking_plan_id,
        v_plan_name,
        v_season,
        COALESCE(NEW.brand, v_brand),
        NEW.allocated_by,
        'style_allocation',
        1,
        true
    )
    ON CONFLICT (factory_id, tracking_plan_id) DO UPDATE
    SET 
        allocation_count = ops.factory_tracking_plan_access.allocation_count + 1,
        active = true,
        updated_at = now();
    
    -- Grant access to tracking folder (if folder exists)
    IF v_folder_id IS NOT NULL THEN
        INSERT INTO ops.factory_tracking_folder_access (
            factory_id,
            tracking_folder_id,
            folder_name,
            brand,
            access_granted_by,
            access_reason,
            active
        )
        VALUES (
            NEW.factory_id,
            v_folder_id,
            v_folder_name,
            COALESCE(NEW.brand, v_brand),
            NEW.allocated_by,
            'plan_allocation',
            true
        )
        ON CONFLICT (factory_id, tracking_folder_id) DO UPDATE
        SET 
            active = true,
            updated_at = now();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION ops.grant_factory_access_on_allocation IS 'Auto-grant factory access to plan and folder when allocated to a style';

-- Create trigger
DROP TRIGGER IF EXISTS on_style_allocation_grant_access ON ops.style_factory_allocation;
CREATE TRIGGER on_style_allocation_grant_access
    AFTER INSERT OR UPDATE OF active, factory_id ON ops.style_factory_allocation
    FOR EACH ROW
    EXECUTE FUNCTION ops.grant_factory_access_on_allocation();

-- ============================================================================
-- 6. CREATE TRIGGER TO REVOKE ACCESS WHEN NO ALLOCATIONS REMAIN
-- ============================================================================

-- When a factory allocation is deactivated, check if there are any remaining
-- active allocations. If not, revoke access to the plan.

CREATE OR REPLACE FUNCTION ops.revoke_factory_access_if_no_allocations()
RETURNS TRIGGER AS $$
DECLARE
    v_remaining_count INTEGER;
BEGIN
    -- Only process if allocation is being deactivated
    IF NEW.active = false AND OLD.active = true THEN
        -- Count remaining active allocations for this factory in this plan
        SELECT COUNT(*)
        INTO v_remaining_count
        FROM ops.style_factory_allocation
        WHERE 
            factory_id = NEW.factory_id
            AND tracking_plan_id = NEW.tracking_plan_id
            AND active = true
            AND id <> NEW.id;
        
        -- Update allocation count
        UPDATE ops.factory_tracking_plan_access
        SET 
            allocation_count = GREATEST(0, allocation_count - 1),
            updated_at = now()
        WHERE 
            factory_id = NEW.factory_id
            AND tracking_plan_id = NEW.tracking_plan_id;
        
        -- If no remaining allocations, mark access as inactive
        IF v_remaining_count = 0 THEN
            UPDATE ops.factory_tracking_plan_access
            SET 
                active = false,
                revoked_at = now(),
                updated_at = now()
            WHERE 
                factory_id = NEW.factory_id
                AND tracking_plan_id = NEW.tracking_plan_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION ops.revoke_factory_access_if_no_allocations IS 'Auto-revoke factory plan access when no active allocations remain';

DROP TRIGGER IF EXISTS on_style_allocation_revoke_access ON ops.style_factory_allocation;
CREATE TRIGGER on_style_allocation_revoke_access
    AFTER UPDATE OF active ON ops.style_factory_allocation
    FOR EACH ROW
    EXECUTE FUNCTION ops.revoke_factory_access_if_no_allocations();

-- ============================================================================
-- 7. CREATE HELPER FUNCTIONS FOR FACTORY ACCESS
-- ============================================================================

-- Get tracking plans accessible by a factory user
CREATE OR REPLACE FUNCTION public.get_factory_accessible_plans(p_user_id UUID DEFAULT auth.uid())
RETURNS TABLE(plan_id UUID, plan_name TEXT, brand TEXT, season TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        fpa.tracking_plan_id AS plan_id,
        fpa.plan_name,
        fpa.brand,
        fpa.season
    FROM ops.factory_tracking_plan_access fpa
    JOIN public.user_profile up ON up.factory_id = fpa.factory_id
    WHERE 
        up.id = p_user_id
        AND up.user_type = 'factory'
        AND fpa.active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_factory_accessible_plans IS 'Returns tracking plans accessible by a factory user';

-- Get tracking folders accessible by a factory user
CREATE OR REPLACE FUNCTION public.get_factory_accessible_folders(p_user_id UUID DEFAULT auth.uid())
RETURNS TABLE(folder_id UUID, folder_name TEXT, brand TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        ffa.tracking_folder_id AS folder_id,
        ffa.folder_name,
        ffa.brand
    FROM ops.factory_tracking_folder_access ffa
    JOIN public.user_profile up ON up.factory_id = ffa.factory_id
    WHERE 
        up.id = p_user_id
        AND up.user_type = 'factory'
        AND ffa.active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_factory_accessible_folders IS 'Returns tracking folders accessible by a factory user';

-- ============================================================================
-- 8. CREATE UPDATE TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION ops.update_tracking_access_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_factory_folder_access_updated_at
    BEFORE UPDATE ON ops.factory_tracking_folder_access
    FOR EACH ROW
    EXECUTE FUNCTION ops.update_tracking_access_updated_at();

CREATE TRIGGER set_factory_plan_access_updated_at
    BEFORE UPDATE ON ops.factory_tracking_plan_access
    FOR EACH ROW
    EXECUTE FUNCTION ops.update_tracking_access_updated_at();

CREATE TRIGGER set_style_allocation_updated_at
    BEFORE UPDATE ON ops.style_factory_allocation
    FOR EACH ROW
    EXECUTE FUNCTION ops.update_tracking_access_updated_at();

-- ============================================================================
-- 9. GRANT PERMISSIONS
-- ============================================================================

GRANT USAGE ON SCHEMA ops TO authenticated, anon, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA ops TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA ops TO service_role;

GRANT EXECUTE ON FUNCTION public.get_factory_accessible_plans TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_factory_accessible_folders TO authenticated;

-- ============================================================================
-- 10. ENABLE RLS
-- ============================================================================

ALTER TABLE ops.factory_tracking_folder_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE ops.factory_tracking_plan_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE ops.style_factory_allocation ENABLE ROW LEVEL SECURITY;

-- Factory users can view their own access
CREATE POLICY "Factory users can view own folder access"
    ON ops.factory_tracking_folder_access FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.factory_id = ops.factory_tracking_folder_access.factory_id
            AND up.user_type = 'factory'
        )
    );

CREATE POLICY "Factory users can view own plan access"
    ON ops.factory_tracking_plan_access FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.factory_id = ops.factory_tracking_plan_access.factory_id
            AND up.user_type = 'factory'
        )
    );

CREATE POLICY "Factory users can view own allocations"
    ON ops.style_factory_allocation FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.factory_id = ops.style_factory_allocation.factory_id
            AND up.user_type = 'factory'
        )
    );

-- Internal users can view all access
CREATE POLICY "Internal users can view all factory access"
    ON ops.factory_tracking_folder_access FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() AND up.user_type = 'internal'
        )
    );

CREATE POLICY "Internal users can view all plan access"
    ON ops.factory_tracking_plan_access FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() AND up.user_type = 'internal'
        )
    );

CREATE POLICY "Internal users can view all allocations"
    ON ops.style_factory_allocation FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() AND up.user_type = 'internal'
        )
    );

-- Service role has full access
CREATE POLICY "Service role full access to folder access"
    ON ops.factory_tracking_folder_access FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to plan access"
    ON ops.factory_tracking_plan_access FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to allocations"
    ON ops.style_factory_allocation FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Factory tracking access tables and triggers created successfully';
END $$;
