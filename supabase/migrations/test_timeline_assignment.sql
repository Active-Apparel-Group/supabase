-- pgTAP test: Timeline/Tracking assignment, sharing, and responsibility
-- Place in 03-timeline/sql/test_timeline_assignment.sql

SET search_path TO tracking, public;

BEGIN;

-- 1. Add a style to a plan (reuse or create test plan/style as needed)
-- ...existing code to insert test plan and style...

-- 2. Assign a user to a timeline milestone
UPDATE plan_style_timelines SET assignee_id = (SELECT id FROM users LIMIT 1)
WHERE plan_style_id = (SELECT id FROM plan_styles LIMIT 1) LIMIT 1;

-- 3. Share a milestone with another user
UPDATE plan_style_timelines SET shared_with = ARRAY[(SELECT id FROM users OFFSET 1 LIMIT 1)]
WHERE plan_style_id = (SELECT id FROM plan_styles LIMIT 1) LIMIT 1;

-- 4. Query: Show all milestones assigned to a user
SELECT * FROM plan_style_timelines WHERE assignee_id = (SELECT id FROM users LIMIT 1);

-- 5. Query: Show all milestones shared with a user
SELECT * FROM plan_style_timelines WHERE (shared_with && ARRAY[(SELECT id FROM users OFFSET 1 LIMIT 1)]);

-- 6. Query: Show status of all milestones for a plan/style
SELECT status, COUNT(*) FROM plan_style_timelines WHERE plan_style_id = (SELECT id FROM plan_styles LIMIT 1) GROUP BY status;

ROLLBACK;
