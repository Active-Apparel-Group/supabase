-- Migration: Implement RLS Policies for PIM and Tracking Tables
-- Purpose: Apply brand-based and factory-based access control to existing tables
-- Author: GitHub Copilot
-- Date: 2025-11-15

-- This migration applies Row-Level Security policies to pim.style and tracking
-- tables to enforce brand-based access for customers and factory-based access
-- for suppliers.

BEGIN;

-- ============================================================================
-- 1. DROP EXISTING PERMISSIVE POLICIES (if any)
-- ============================================================================

-- Drop old permissive policies to replace with restrictive ones
-- Note: We're keeping this safe by only dropping if exists

DO $$
BEGIN
    -- For tracking.folders
    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'tracking' AND tablename = 'folders' 
        AND policyname = 'Enable read access for all users'
    ) THEN
        DROP POLICY "Enable read access for all users" ON tracking.folders;
    END IF;
END $$;

-- ============================================================================
-- 2. APPLY RLS TO PIM SCHEMA TABLES
-- ============================================================================

-- Enable RLS on pim.style if not already enabled
ALTER TABLE pim.style ENABLE ROW LEVEL SECURITY;
ALTER TABLE pim.style_colorway ENABLE ROW LEVEL SECURITY;
ALTER TABLE pim.style_size_class ENABLE ROW LEVEL SECURITY;
ALTER TABLE pim.color_folder ENABLE ROW LEVEL SECURITY;
ALTER TABLE pim.color_palette ENABLE ROW LEVEL SECURITY;
ALTER TABLE pim.color_palette_color ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. PIM.STYLE RLS POLICIES
-- ============================================================================

-- Policy: Internal users can see all styles
CREATE POLICY "Internal users can view all styles"
    ON pim.style FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- Policy: Customer users can see styles for their brands
CREATE POLICY "Customer users can view styles for their brands"
    ON pim.style FOR SELECT
    USING (
        brand = ANY(public.get_accessible_brand_codes(auth.uid()))
    );

-- Policy: Users with explicit brand access can see styles
CREATE POLICY "Users with brand access can view styles"
    ON pim.style FOR SELECT
    USING (
        brand IN (
            SELECT b.code 
            FROM mdm.brand b
            JOIN public.user_brand_access uba ON uba.brand_id = b.id
            WHERE uba.user_id = auth.uid() 
            AND uba.active = true
            AND uba.can_view_styles = true
        )
    );

-- Policy: Internal users can insert/update/delete styles
CREATE POLICY "Internal users can manage styles"
    ON pim.style FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- Policy: Users with write access can update styles for their brands
CREATE POLICY "Users with write access can update styles"
    ON pim.style FOR UPDATE
    USING (
        brand IN (
            SELECT b.code 
            FROM mdm.brand b
            JOIN public.user_brand_access uba ON uba.brand_id = b.id
            WHERE uba.user_id = auth.uid() 
            AND uba.active = true
            AND uba.can_edit_styles = true
        )
    )
    WITH CHECK (
        brand IN (
            SELECT b.code 
            FROM mdm.brand b
            JOIN public.user_brand_access uba ON uba.brand_id = b.id
            WHERE uba.user_id = auth.uid() 
            AND uba.active = true
            AND uba.can_edit_styles = true
        )
    );

-- ============================================================================
-- 4. PIM.STYLE_COLORWAY RLS POLICIES (Inherit from parent style)
-- ============================================================================

CREATE POLICY "Users can view colorways for accessible styles"
    ON pim.style_colorway FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM pim.style s
            WHERE s.id = pim.style_colorway.style_id
        )
    );

CREATE POLICY "Internal users can manage colorways"
    ON pim.style_colorway FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- ============================================================================
-- 5. PIM.STYLE_SIZE_CLASS RLS POLICIES (Inherit from parent style)
-- ============================================================================

CREATE POLICY "Users can view size classes for accessible styles"
    ON pim.style_size_class FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM pim.style s
            WHERE s.id = pim.style_size_class.style_id
        )
    );

CREATE POLICY "Internal users can manage size classes"
    ON pim.style_size_class FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- ============================================================================
-- 6. COLOR PALETTE RLS POLICIES (Brand-based)
-- ============================================================================

CREATE POLICY "Users can view color palettes for accessible brands"
    ON pim.color_palette FOR SELECT
    USING (
        brand = ANY(public.get_accessible_brand_codes(auth.uid()))
        OR
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

CREATE POLICY "Users can view all color folders"
    ON pim.color_folder FOR SELECT
    USING (active = true);

CREATE POLICY "Users can view color palette colors for accessible palettes"
    ON pim.color_palette_color FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM pim.color_palette cp
            WHERE cp.id = pim.color_palette_color.palette_id
        )
    );

CREATE POLICY "Internal users can manage color data"
    ON pim.color_palette FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

CREATE POLICY "Internal users can manage color folders"
    ON pim.color_folder FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

CREATE POLICY "Internal users can manage palette colors"
    ON pim.color_palette_color FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- ============================================================================
-- 7. TRACKING SCHEMA RLS POLICIES
-- ============================================================================

-- Enable RLS on tracking tables if not already enabled
ALTER TABLE tracking.folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.plan_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.plan_styles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.plan_style_timelines ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 8. TRACKING.FOLDERS RLS POLICIES
-- ============================================================================

-- Internal users see all folders
CREATE POLICY "Internal users can view all tracking folders"
    ON tracking.folders FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- Customer users see folders for their brands
CREATE POLICY "Customer users can view folders for their brands"
    ON tracking.folders FOR SELECT
    USING (
        brand = ANY(public.get_accessible_brand_codes(auth.uid()))
    );

-- Factory users see folders they have access to
CREATE POLICY "Factory users can view accessible folders"
    ON tracking.folders FOR SELECT
    USING (
        id IN (
            SELECT folder_id FROM public.get_factory_accessible_folders(auth.uid())
        )
    );

-- ============================================================================
-- 9. TRACKING.PLANS RLS POLICIES
-- ============================================================================

-- Internal users see all plans
CREATE POLICY "Internal users can view all tracking plans"
    ON tracking.plans FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- Customer users see plans for their brands
CREATE POLICY "Customer users can view plans for their brands"
    ON tracking.plans FOR SELECT
    USING (
        brand = ANY(public.get_accessible_brand_codes(auth.uid()))
    );

-- Factory users see plans they have access to
CREATE POLICY "Factory users can view accessible plans"
    ON tracking.plans FOR SELECT
    USING (
        id IN (
            SELECT plan_id FROM public.get_factory_accessible_plans(auth.uid())
        )
    );

-- ============================================================================
-- 10. TRACKING.PLAN_STYLES RLS POLICIES
-- ============================================================================

-- Internal users see all plan styles
CREATE POLICY "Internal users can view all plan styles"
    ON tracking.plan_styles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- Customer users see plan styles for their brands
CREATE POLICY "Customer users can view plan styles for their brands"
    ON tracking.plan_styles FOR SELECT
    USING (
        brand = ANY(public.get_accessible_brand_codes(auth.uid()))
    );

-- Factory users see plan styles they are allocated to
CREATE POLICY "Factory users can view allocated plan styles"
    ON tracking.plan_styles FOR SELECT
    USING (
        id IN (
            SELECT sfa.plan_style_id 
            FROM ops.style_factory_allocation sfa
            JOIN public.user_profile up ON up.factory_id = sfa.factory_id
            WHERE up.id = auth.uid() 
            AND up.user_type = 'factory'
            AND sfa.active = true
        )
        OR
        -- Also allow if factory has access to the plan
        plan_id IN (
            SELECT plan_id FROM public.get_factory_accessible_plans(auth.uid())
        )
    );

-- ============================================================================
-- 11. TRACKING.PLAN_STYLE_TIMELINES RLS POLICIES
-- ============================================================================

-- Internal users see all timelines
CREATE POLICY "Internal users can view all style timelines"
    ON tracking.plan_style_timelines FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profile up
            WHERE up.id = auth.uid() 
            AND up.user_type = 'internal'
            AND up.active = true
        )
    );

-- Users see timelines for accessible plan styles
CREATE POLICY "Users can view timelines for accessible plan styles"
    ON tracking.plan_style_timelines FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM tracking.plan_styles ps
            WHERE ps.id = tracking.plan_style_timelines.plan_style_id
        )
    );

-- ============================================================================
-- 12. TRACKING.PLAN_VIEWS RLS POLICIES
-- ============================================================================

CREATE POLICY "Users can view plan views for accessible plans"
    ON tracking.plan_views FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM tracking.plans p
            WHERE p.id = tracking.plan_views.plan_id
        )
    );

-- ============================================================================
-- 13. SERVICE ROLE FULL ACCESS POLICIES
-- ============================================================================

-- Service role gets full access to everything for backend operations

CREATE POLICY "Service role full access to styles"
    ON pim.style FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to colorways"
    ON pim.style_colorway FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to size classes"
    ON pim.style_size_class FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to tracking folders"
    ON tracking.folders FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to tracking plans"
    ON tracking.plans FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to plan views"
    ON tracking.plan_views FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to plan styles"
    ON tracking.plan_styles FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to style timelines"
    ON tracking.plan_style_timelines FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'RLS policies applied successfully to PIM and tracking tables';
END $$;
