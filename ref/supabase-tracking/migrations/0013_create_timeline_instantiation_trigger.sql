-- Migration 0013: Auto-instantiate timeline from template when style added to plan
-- Creates trigger that automatically generates plan_style_timelines records from template
-- Applied: 2025-10-23

CREATE OR REPLACE FUNCTION tracking.instantiate_timeline_from_template()
RETURNS TRIGGER AS $$
DECLARE
    v_template_id uuid;
    v_plan_start_date date;
    v_plan_end_date date;
    v_timeline_count integer;
BEGIN
    -- Get plan's template and anchor dates
    SELECT template_id, start_date, end_date 
    INTO v_template_id, v_plan_start_date, v_plan_end_date
    FROM tracking.plan 
    WHERE id = NEW.plan_id;
    
    -- Only proceed if plan has a template assigned
    IF v_template_id IS NULL THEN
        RAISE NOTICE 'Plan % has no template assigned, skipping timeline instantiation', NEW.plan_id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE 'Instantiating timeline for plan_style % from template %', NEW.id, v_template_id;
    
    -- Insert timeline records from template (only items that apply to styles)
    INSERT INTO tracking.plan_style_timelines (
        id, plan_style_id, template_item_id, status,
        timeline_type, page_type, page_name, late, 
        created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        NEW.id,
        ti.id,
        'NOT_STARTED'::tracking.timeline_status_enum,
        ti.timeline_type,
        ti.page_type,
        ti.page_label,
        false,
        NOW(),
        NOW()
    FROM tracking.timeline_template_items ti
    WHERE ti.template_id = v_template_id
        AND ti.applies_to_style = true;
    
    GET DIAGNOSTICS v_timeline_count = ROW_COUNT;
    RAISE NOTICE 'Created % timeline records for plan_style %', v_timeline_count, NEW.id;
    
    -- Insert dependencies based on template relationships
    INSERT INTO tracking.plan_style_dependencies (
        successor_id, predecessor_id, offset_relation, offset_value, offset_unit
    )
    SELECT 
        succ.id,
        pred.id,
        ti.offset_relation,
        ti.offset_value,
        ti.offset_unit
    FROM tracking.timeline_template_items ti
    JOIN tracking.plan_style_timelines succ 
        ON succ.template_item_id = ti.id 
        AND succ.plan_style_id = NEW.id
    JOIN tracking.plan_style_timelines pred 
        ON pred.template_item_id = ti.depends_on_template_item_id 
        AND pred.plan_style_id = NEW.id
    WHERE ti.depends_on_template_item_id IS NOT NULL
        AND ti.template_id = v_template_id;
    
    GET DIAGNOSTICS v_timeline_count = ROW_COUNT;
    RAISE NOTICE 'Created % dependency relationships for plan_style %', v_timeline_count, NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on plan_styles INSERT
CREATE TRIGGER trg_instantiate_style_timeline
    AFTER INSERT ON tracking.plan_styles
    FOR EACH ROW
    EXECUTE FUNCTION tracking.instantiate_timeline_from_template();

COMMENT ON FUNCTION tracking.instantiate_timeline_from_template() IS 
'Automatically creates plan_style_timelines records when a style is added to a plan. Copies structure from the plan''s assigned timeline_template.';

COMMENT ON TRIGGER trg_instantiate_style_timeline ON tracking.plan_styles IS
'Auto-instantiates timeline from template for each new style added to a plan.';
