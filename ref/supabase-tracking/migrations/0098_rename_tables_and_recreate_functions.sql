-- Migration: 0098_rename_tables_and_recreate_functions
-- Description: Rename tables to tracking_ prefix, recreate functions and trigger
-- Date: 2025-10-24
-- Purpose: Complete refactoring with updated table names
-- Breaking: All old table names invalid, trigger recreated with new table reference

BEGIN;

-- ============================================================================
-- PART 1: RENAME TABLES (alphabetical order)
-- Foreign keys auto-update via CASCADE
-- ============================================================================

ALTER TABLE tracking.folder RENAME TO tracking_folder;
ALTER TABLE tracking.folder_style_links RENAME TO tracking_folder_style_link;
ALTER TABLE tracking.plan RENAME TO tracking_plan;
ALTER TABLE tracking.plan_materials RENAME TO tracking_plan_material;
ALTER TABLE tracking.plan_material_dependencies RENAME TO tracking_plan_material_dependency;
ALTER TABLE tracking.plan_material_timelines RENAME TO tracking_plan_material_timeline;
ALTER TABLE tracking.plan_styles RENAME TO tracking_plan_style;
ALTER TABLE tracking.plan_style_dependencies RENAME TO tracking_plan_style_dependency;
ALTER TABLE tracking.plan_style_timelines RENAME TO tracking_plan_style_timeline;
ALTER TABLE tracking.plan_views RENAME TO tracking_plan_view;
ALTER TABLE tracking.timeline_assignments RENAME TO tracking_timeline_assignment;
ALTER TABLE tracking.timeline_status_history RENAME TO tracking_timeline_status_history;
ALTER TABLE tracking.timeline_templates RENAME TO tracking_timeline_template;
ALTER TABLE tracking.timeline_template_items RENAME TO tracking_timeline_template_item;
ALTER TABLE tracking.timeline_template_visibility RENAME TO tracking_timeline_template_visibility;

-- Tables NOT renamed (internal use only):
-- - tracking.import_batches
-- - tracking.import_errors

-- ============================================================================
-- PART 2: RECREATE FUNCTION - instantiate_timeline_from_template()
-- Updated with tracking_ table names
-- ============================================================================

CREATE OR REPLACE FUNCTION tracking.instantiate_timeline_from_template()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_template_id uuid;
    v_plan_start_date date;
    v_plan_end_date date;
    v_timeline_count integer;
BEGIN
    -- Get plan's template and anchor dates
    SELECT template_id, start_date, end_date 
    INTO v_template_id, v_plan_start_date, v_plan_end_date
    FROM tracking.tracking_plan 
    WHERE id = NEW.plan_id;
    
    -- Only proceed if plan has a template assigned
    IF v_template_id IS NULL THEN
        RAISE NOTICE 'Plan % has no template assigned, skipping timeline instantiation', NEW.plan_id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE 'Instantiating timeline for plan_style % from template %', NEW.id, v_template_id;
    
    -- Insert timeline records from template (only items that apply to styles)
    INSERT INTO tracking.tracking_plan_style_timeline (
        id, plan_style_id, template_item_id, status,
        timeline_type, page_type, page_name, late, 
        created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        NEW.id,
        ti.id,
        'NOT_STARTED'::tracking.timeline_status_enum,
        CASE 
            WHEN ti.timeline_type = 'MASTER'::tracking.timeline_type_enum THEN 'STYLE'::tracking.timeline_type_enum
            ELSE ti.timeline_type
        END,
        ti.page_type,
        COALESCE(ti.page_label, ti.name),
        false,
        NOW(),
        NOW()
    FROM tracking.tracking_timeline_template_item ti
    WHERE ti.template_id = v_template_id
        AND (ti.applies_to_style = true OR ti.name IN ('START DATE', 'END DATE'));
    
    GET DIAGNOSTICS v_timeline_count = ROW_COUNT;
    RAISE NOTICE 'Created % timeline records for plan_style %', v_timeline_count, NEW.id;
    
    -- Insert dependencies based on template relationships
    INSERT INTO tracking.tracking_plan_style_dependency (
        successor_id, predecessor_id, offset_relation, offset_value, offset_unit
    )
    SELECT 
        succ.id,
        pred.id,
        ti.offset_relation,
        ti.offset_value,
        ti.offset_unit
    FROM tracking.tracking_timeline_template_item ti
    JOIN tracking.tracking_plan_style_timeline succ 
        ON succ.template_item_id = ti.id 
        AND succ.plan_style_id = NEW.id
    JOIN tracking.tracking_plan_style_timeline pred 
        ON pred.template_item_id = ti.depends_on_template_item_id 
        AND pred.plan_style_id = NEW.id
    WHERE ti.depends_on_template_item_id IS NOT NULL
        AND ti.template_id = v_template_id;
    
    GET DIAGNOSTICS v_timeline_count = ROW_COUNT;
    RAISE NOTICE 'Created % dependency relationships for plan_style %', v_timeline_count, NEW.id;
    
    -- Automatically calculate timeline dates after creating structure
    -- Run calculations when at least one anchor is defined so dependent items get dates
    IF v_plan_start_date IS NOT NULL OR v_plan_end_date IS NOT NULL THEN
        RAISE NOTICE 'Calculating dates for plan_style % using anchors % to %', NEW.id, v_plan_start_date, v_plan_end_date;
        
        -- Call the date calculation function
        PERFORM tracking.calculate_timeline_dates(NEW.id);
        
        RAISE NOTICE 'Date calculation completed for plan_style %', NEW.id;
    ELSE
        RAISE NOTICE 'Plan % missing start_date and end_date, skipping date calculation', NEW.plan_id;
    END IF;
    
    RETURN NEW;
END;
$function$;

-- ============================================================================
-- PART 3: RECREATE FUNCTION - calculate_timeline_dates()
-- Updated with tracking_ table names
-- ============================================================================

CREATE OR REPLACE FUNCTION tracking.calculate_timeline_dates(p_plan_style_id uuid)
RETURNS TABLE(timeline_id uuid, timeline_name text, plan_date date, due_date date, is_late boolean, is_anchor boolean)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_plan_id uuid;
    v_plan_start_date date;
    v_plan_end_date date;
    v_business_calendar jsonb;
    v_timezone text;
    v_updated_count integer;
    v_current_date date := CURRENT_DATE;
BEGIN
    -- Get plan details
    SELECT 
        ps.plan_id,
        p.start_date,
        p.end_date,
        COALESCE(t.business_days_calendar, '{}'::jsonb),
        COALESCE(p.timezone, t.timezone, 'UTC')
    INTO v_plan_id, v_plan_start_date, v_plan_end_date, v_business_calendar, v_timezone
    FROM tracking.tracking_plan_style ps
    JOIN tracking.tracking_plan p ON ps.plan_id = p.id
    LEFT JOIN tracking.tracking_timeline_template t ON p.template_id = t.id
    WHERE ps.id = p_plan_style_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Plan style % not found', p_plan_style_id;
    END IF;
    
    -- Create temp table for calculation
    DROP TABLE IF EXISTS temp_timeline_calc;
    CREATE TEMP TABLE temp_timeline_calc (
        tid uuid PRIMARY KEY,
        tname text,
        ntype text,
        calc_date date,
        is_calc boolean DEFAULT false,
        is_anc boolean DEFAULT false,
        stat text
    );
    
    -- Insert all timeline nodes with current status
    INSERT INTO temp_timeline_calc (tid, tname, ntype, is_anc, stat)
    SELECT 
        pst.id,
        ti.name,
        ti.node_type::text,
        ti.node_type = 'ANCHOR' OR ti.name IN ('START DATE', 'END DATE'),
        pst.status::text
    FROM tracking.tracking_plan_style_timeline pst
    JOIN tracking.tracking_timeline_template_item ti ON pst.template_item_id = ti.id
    WHERE pst.plan_style_id = p_plan_style_id;
    
    -- Set anchor dates
    UPDATE temp_timeline_calc
    SET calc_date = v_plan_start_date, is_calc = true, is_anc = true
    WHERE tname = 'START DATE';
    
    UPDATE temp_timeline_calc
    SET calc_date = v_plan_end_date, is_calc = true, is_anc = true
    WHERE tname = 'END DATE';
    
    -- Iteratively calculate dependent dates (max 50 iterations)
    FOR i IN 1..50 LOOP
        WITH ready_to_calc AS (
            SELECT 
                pst.id as tid,
                pred_dates.calc_date as pred_date,
                dep.offset_relation,
                dep.offset_value,
                dep.offset_unit
            FROM tracking.tracking_plan_style_timeline pst
            JOIN tracking.tracking_plan_style_dependency dep ON pst.id = dep.successor_id
            JOIN temp_timeline_calc pred_dates ON dep.predecessor_id = pred_dates.tid
            JOIN temp_timeline_calc curr_dates ON pst.id = curr_dates.tid
            WHERE pred_dates.is_calc = true
                AND curr_dates.is_calc = false
                AND pred_dates.calc_date IS NOT NULL
        )
        UPDATE temp_timeline_calc ttc
        SET 
            calc_date = CASE 
                WHEN rtc.offset_relation = 'AFTER' THEN 
                    rtc.pred_date + (rtc.offset_value || ' days')::interval
                WHEN rtc.offset_relation = 'BEFORE' THEN 
                    rtc.pred_date - (ABS(rtc.offset_value) || ' days')::interval
                ELSE rtc.pred_date
            END::date,
            is_calc = true
        FROM ready_to_calc rtc
        WHERE ttc.tid = rtc.tid;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        EXIT WHEN v_updated_count = 0;
    END LOOP;
    
    -- Update actual timeline table
    UPDATE tracking.tracking_plan_style_timeline pst
    SET 
        plan_date = COALESCE(pst.plan_date, ttc.calc_date),
        due_date = ttc.calc_date,
        late = CASE 
            WHEN pst.status IN ('COMPLETE', 'APPROVED') THEN false
            WHEN ttc.calc_date < v_current_date THEN true
            ELSE false
        END,
        updated_at = NOW()
    FROM temp_timeline_calc ttc
    WHERE pst.id = ttc.tid
        AND ttc.calc_date IS NOT NULL;
    
    -- Return results with late flag
    RETURN QUERY
    SELECT 
        ttc.tid,
        ttc.tname,
        pst.plan_date,
        pst.due_date,
        pst.late,
        ttc.is_anc
    FROM temp_timeline_calc ttc
    JOIN tracking.tracking_plan_style_timeline pst ON ttc.tid = pst.id
    ORDER BY pst.plan_date NULLS LAST, pst.id;
    
    DROP TABLE IF EXISTS temp_timeline_calc;
END;
$function$;

-- ============================================================================
-- PART 4: RECREATE TRIGGER on renamed table
-- ============================================================================

CREATE TRIGGER trg_instantiate_style_timeline
    AFTER INSERT ON tracking.tracking_plan_style
    FOR EACH ROW
    EXECUTE FUNCTION tracking.instantiate_timeline_from_template();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  expected_tables text[] := ARRAY[
    'tracking_folder',
    'tracking_folder_style_link',
    'tracking_plan',
    'tracking_plan_material',
    'tracking_plan_material_dependency',
    'tracking_plan_material_timeline',
    'tracking_plan_style',
    'tracking_plan_style_dependency',
    'tracking_plan_style_timeline',
    'tracking_plan_view',
    'tracking_timeline_assignment',
    'tracking_timeline_status_history',
    'tracking_timeline_template',
    'tracking_timeline_template_item',
    'tracking_timeline_template_visibility'
  ];
  tbl text;
  missing_count int := 0;
  func_count int;
  trigger_count int;
BEGIN
  -- Verify tables renamed
  FOREACH tbl IN ARRAY expected_tables
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'tracking' AND table_name = tbl
    ) THEN
      RAISE WARNING 'Table tracking.% does not exist after rename', tbl;
      missing_count := missing_count + 1;
    END IF;
  END LOOP;
  
  IF missing_count > 0 THEN
    RAISE EXCEPTION 'Table verification failed: % tables missing', missing_count;
  END IF;
  
  -- Verify functions recreated
  SELECT COUNT(*) INTO func_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'tracking'
    AND p.proname IN ('instantiate_timeline_from_template', 'calculate_timeline_dates');
  
  IF func_count < 2 THEN
    RAISE EXCEPTION 'Function verification failed: expected 2, found %', func_count;
  END IF;
  
  -- Verify trigger recreated
  SELECT COUNT(*) INTO trigger_count
  FROM pg_trigger t
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'tracking'
    AND c.relname = 'tracking_plan_style'
    AND t.tgname = 'trg_instantiate_style_timeline';
  
  IF trigger_count < 1 THEN
    RAISE EXCEPTION 'Trigger verification failed: trg_instantiate_style_timeline not found';
  END IF;
  
  RAISE NOTICE 'Migration 0098 successful: 15 tables renamed, 2 functions recreated, 1 trigger recreated';
END $$;

COMMIT;
