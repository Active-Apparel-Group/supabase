-- pgTAP test: Timeline/Tracking core logic
-- Place in 03-timeline/sql/test_timeline_core.sql

SET search_path TO tracking, public;

BEGIN;

-- 1. Add a style to a plan and check timeline instantiation
SELECT plan_id, id AS plan_style_id INTO TEMP test_plan_style
FROM tracking.plan_styles WHERE plan_id IS NOT NULL LIMIT 1;

-- Simulate adding a style (should trigger timeline instantiation)
-- (Assume plan_style_id is available for test)

-- 2. Validate all milestone dates are populated per template
SELECT COUNT(*) FROM tracking.plan_style_timelines WHERE plan_style_id = (SELECT plan_style_id FROM test_plan_style);

-- 3. Milestones include START DATE and END DATE
SELECT COUNT(*) FROM tracking.plan_style_timelines pst
JOIN tracking.timeline_template_items ti ON pst.template_item_id = ti.id
WHERE pst.plan_style_id = (SELECT plan_style_id FROM test_plan_style)
  AND ti.action_name IN ('START DATE', 'END DATE');

-- 4. When a due date is changed, dependant dates are changed
-- (Update a due date, then check dependants)
UPDATE tracking.plan_style_timelines SET due_date = due_date + INTERVAL '2 days'
WHERE plan_style_id = (SELECT plan_style_id FROM test_plan_style)
  AND template_item_id = (SELECT id FROM tracking.timeline_template_items WHERE action_name = 'START DATE' LIMIT 1);

-- Check that dependant milestones have updated dates
-- (This will depend on your dependency logic)

-- 5. When due date > plan date, late=TRUE

-- Update only one row by ctid (Postgres workaround for LIMIT 1 in UPDATE)
UPDATE tracking.plan_style_timelines SET due_date = plan_date + INTERVAL '3 days'
WHERE ctid = (
  SELECT ctid FROM tracking.plan_style_timelines
  WHERE plan_style_id = (SELECT plan_style_id FROM test_plan_style)
  LIMIT 1
);

SELECT late FROM tracking.plan_style_timelines WHERE plan_style_id = (SELECT plan_style_id FROM test_plan_style) LIMIT 1;

ROLLBACK;
