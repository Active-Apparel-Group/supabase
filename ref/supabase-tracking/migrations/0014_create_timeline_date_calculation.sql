-- Migration 0014: Calculate timeline dates based on anchors and dependencies
-- Implements date calculation algorithm for plan_style_timelines
-- Applied: 2025-10-23

CREATE OR REPLACE FUNCTION tracking.calculate_timeline_dates(p_plan_style_id uuid)
RETURNS TABLE(
    timeline_id uuid,
    timeline_name text,
    plan_date date,
    due_date date,
    is_late boolean,
    is_anchor boolean
) AS $$
DECLARE
    v_plan_id uuid;
    v_plan_start_date date;
    v_plan_end_date date;
    v_template_id uuid;
    v_iteration integer := 0;
    v_max_iterations integer := 50;
    v_updated_count integer;
BEGIN
    -- Get plan details and template
    SELECT ps.plan_id INTO v_plan_id
    FROM tracking.plan_styles ps
    WHERE ps.id = p_plan_style_id;
    
    SELECT p.start_date, p.end_date, p.template_id
    INTO v_plan_start_date, v_plan_end_date, v_template_id
    FROM tracking.plan p
    WHERE p.id = v_plan_id;
    
    -- Create temp table for calculation
    CREATE TEMP TABLE IF NOT EXISTS temp_timeline_calc (
        id uuid PRIMARY KEY,
        template_item_id uuid,
        node_type tracking.node_type_enum,
        action_name text,
        calculated_date date,
        is_processed boolean DEFAULT false
    );
    
    DELETE FROM temp_timeline_calc;
    
    -- Load timeline items
    INSERT INTO temp_timeline_calc (id, template_item_id, node_type, action_name)
    SELECT 
        pst.id,
        pst.template_item_id,
        ti.node_type,
        ti.action_name
    FROM tracking.plan_style_timelines pst
    JOIN tracking.timeline_template_items ti ON ti.id = pst.template_item_id
    WHERE pst.plan_style_id = p_plan_style_id;
    
    -- Set ANCHOR dates
    UPDATE temp_timeline_calc ttc
    SET calculated_date = CASE 
            WHEN action_name = 'START DATE' THEN v_plan_start_date
            WHEN action_name = 'END DATE' THEN v_plan_end_date
        END,
        is_processed = true
    WHERE node_type = 'ANCHOR';
    
    -- Iteratively calculate dependent dates
    LOOP
        v_iteration := v_iteration + 1;
        
        -- Update dates for items whose predecessors are calculated
        UPDATE temp_timeline_calc succ
        SET calculated_date = CASE
                WHEN d.offset_unit = 'DAYS' THEN
                    pred.calculated_date + (CASE WHEN d.offset_relation = 'AFTER' THEN d.offset_value ELSE -d.offset_value END)
                WHEN d.offset_unit = 'BUSINESS_DAYS' THEN
                    -- For now, treat business days same as calendar days
                    -- TODO: Implement actual business day calculation with calendar
                    pred.calculated_date + (CASE WHEN d.offset_relation = 'AFTER' THEN d.offset_value ELSE -d.offset_value END)
            END,
            is_processed = true
        FROM tracking.plan_style_dependencies d
        JOIN temp_timeline_calc pred ON pred.id = d.predecessor_id
        WHERE succ.id = d.successor_id
            AND succ.is_processed = false
            AND pred.is_processed = true;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        EXIT WHEN v_updated_count = 0 OR v_iteration >= v_max_iterations;
    END LOOP;
    
    -- Update plan_style_timelines with calculated dates
    UPDATE tracking.plan_style_timelines pst
    SET 
        plan_date = COALESCE(pst.plan_date, ttc.calculated_date),
        due_date = ttc.calculated_date,
        late = CASE 
            WHEN pst.status IN ('COMPLETE', 'APPROVED') THEN false
            WHEN ttc.calculated_date < CURRENT_DATE THEN true
            ELSE false
        END,
        updated_at = NOW()
    FROM temp_timeline_calc ttc
    WHERE pst.id = ttc.id;
    
    -- Return results ordered by date
    RETURN QUERY
    SELECT 
        ttc.id,
        ttc.action_name,
        pst.plan_date,
        pst.due_date,
        pst.late,
        (ttc.node_type = 'ANCHOR') as is_anchor
    FROM temp_timeline_calc ttc
    JOIN tracking.plan_style_timelines pst ON pst.id = ttc.id
    ORDER BY ttc.calculated_date NULLS LAST;
    
    DROP TABLE IF EXISTS temp_timeline_calc;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tracking.calculate_timeline_dates(uuid) IS
'Calculates timeline dates for a plan_style based on anchors and dependencies. Updates plan_date (baseline), due_date (forecast), and late flag. Returns ordered timeline with 4 date columns.';
