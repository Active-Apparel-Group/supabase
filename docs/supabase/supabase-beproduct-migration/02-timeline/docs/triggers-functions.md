# Timeline Triggers & Functions

**Purpose:** Automated dependency recalculation, date management, and audit trail  
**Status:** Ready for Implementation  
**Date:** October 31, 2025

---

## Table of Contents
1. [Trigger Overview](#trigger-overview)
2. [Date Calculation Functions](#date-calculation-functions)
3. [Dependency Recalculation](#dependency-recalculation)
4. [Audit Trail](#audit-trail)
5. [Utility Functions](#utility-functions)
6. [Testing](#testing)

---

## Trigger Overview

| Trigger Name | Table | Event | Purpose | Priority |
|--------------|-------|-------|---------|----------|
| `trg_calculate_due_date` | `timeline_node` | INSERT, UPDATE | Auto-calculate `due_date` from plan/rev/final | BEFORE |
| `trg_calculate_is_late` | `timeline_node` | INSERT, UPDATE | Auto-calculate `is_late` flag | BEFORE |
| `trg_recalculate_downstream` | `timeline_node` | UPDATE | Cascade date changes to dependents | AFTER |
| `trg_audit_timeline_changes` | `timeline_node` | UPDATE | Log all field changes | AFTER |
| `trg_update_timestamps` | `timeline_node`, `timeline_style`, `timeline_material` | UPDATE | Update `updated_at` | BEFORE |

---

## Date Calculation Functions

### 1. Calculate Due Date

**Function:** `fn_calculate_due_date()`

```sql
CREATE OR REPLACE FUNCTION ops.fn_calculate_due_date()
RETURNS TRIGGER AS $$
BEGIN
  -- due_date = latest available date (final > rev > plan)
  NEW.due_date := COALESCE(NEW.final_date, NEW.rev_date, NEW.plan_date);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER trg_calculate_due_date
  BEFORE INSERT OR UPDATE OF plan_date, rev_date, final_date
  ON ops.timeline_node
  FOR EACH ROW
  EXECUTE FUNCTION ops.fn_calculate_due_date();
```

**Logic:**
1. If `final_date` is set (milestone completed), use that
2. Else if `rev_date` is set (milestone rescheduled), use that
3. Else use `plan_date` (original baseline)

**Test Cases:**
```sql
-- Test 1: Initial creation (only plan_date)
INSERT INTO ops.timeline_node (entity_type, entity_id, plan_id, milestone_id, plan_date)
VALUES ('style', 'style-uuid', 'plan-uuid', 'milestone-uuid', '2025-05-01');
-- Expected: due_date = '2025-05-01'

-- Test 2: Set rev_date
UPDATE ops.timeline_node 
SET rev_date = '2025-05-10' 
WHERE node_id = 'node-uuid';
-- Expected: due_date = '2025-05-10'

-- Test 3: Complete milestone with final_date
UPDATE ops.timeline_node 
SET final_date = '2025-05-08', status = 'approved' 
WHERE node_id = 'node-uuid';
-- Expected: due_date = '2025-05-08'
```

---

### 2. Calculate Late Flag

**Function:** `fn_calculate_is_late()`

```sql
CREATE OR REPLACE FUNCTION ops.fn_calculate_is_late()
RETURNS TRIGGER AS $$
BEGIN
  -- Late if: current date > due_date (overdue) OR due_date > plan_date (schedule slippage)
  -- BUT NOT if status is 'approved' or 'na'
  IF NEW.status IN ('approved', 'na') THEN
    NEW.is_late := false;
  ELSE
    NEW.is_late := (
      (CURRENT_DATE > NEW.due_date) OR 
      (NEW.due_date > NEW.plan_date)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER trg_calculate_is_late
  BEFORE INSERT OR UPDATE OF due_date, plan_date, status
  ON ops.timeline_node
  FOR EACH ROW
  EXECUTE FUNCTION ops.fn_calculate_is_late();
```

**Logic:**
1. If milestone is `approved` or `na`, always `is_late = false`
2. Else, late if:
   - Current date has passed due date (overdue), OR
   - Due date has slipped past plan date (schedule slippage)

**Test Cases:**
```sql
-- Test 1: On-time milestone
INSERT INTO ops.timeline_node (entity_type, entity_id, plan_id, milestone_id, plan_date)
VALUES ('style', 'style-uuid', 'plan-uuid', 'milestone-uuid', '2026-05-01');
-- Expected: is_late = false (future date, due_date = plan_date)

-- Test 2: Overdue milestone
INSERT INTO ops.timeline_node (entity_type, entity_id, plan_id, milestone_id, plan_date)
VALUES ('style', 'style-uuid', 'plan-uuid', 'milestone-uuid', '2024-05-01');
-- Expected: is_late = true (current date > due_date)

-- Test 3: Revised milestone (schedule slippage)
UPDATE ops.timeline_node 
SET rev_date = '2026-06-01' 
WHERE node_id = 'node-uuid' AND plan_date = '2026-05-01';
-- Expected: is_late = true (due_date > plan_date)

-- Test 4: Completed late milestone
UPDATE ops.timeline_node 
SET final_date = '2025-05-15', status = 'approved' 
WHERE node_id = 'node-uuid' AND plan_date = '2025-05-01';
-- Expected: is_late = false (status = approved overrides)
```

---

### 3. Calculate Start Dates (for Gantt Chart)

**Function:** `fn_calculate_start_dates()`

```sql
CREATE OR REPLACE FUNCTION ops.fn_calculate_start_dates()
RETURNS TRIGGER AS $$
DECLARE
  v_duration_days INTEGER;
BEGIN
  -- Get milestone duration from template
  SELECT 
    COALESCE(duration_days, 0)
  INTO v_duration_days
  FROM ops.timeline_template_milestone
  WHERE id = NEW.milestone_id;
  
  -- Calculate start dates
  NEW.start_date_plan := NEW.plan_date - (v_duration_days || ' days')::INTERVAL;
  NEW.start_date_due := NEW.due_date - (v_duration_days || ' days')::INTERVAL;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER trg_calculate_start_dates
  BEFORE INSERT OR UPDATE OF plan_date, due_date
  ON ops.timeline_node
  FOR EACH ROW
  EXECUTE FUNCTION ops.fn_calculate_start_dates();
```

**Logic:**
1. Retrieve milestone `duration_days` from template
2. Calculate `start_date_plan = plan_date - duration_days`
3. Calculate `start_date_due = due_date - duration_days`

**Enhancement:** This enables Gantt chart rendering with start and end dates (BeProduct only provides end dates)

---

## Dependency Recalculation

### 4. Recalculate Downstream Timelines

**Function:** `fn_recalculate_downstream_timelines()`

```sql
CREATE OR REPLACE FUNCTION ops.fn_recalculate_downstream_timelines()
RETURNS TRIGGER AS $$
DECLARE
  v_delta_days INTEGER;
  v_old_date DATE;
  v_new_date DATE;
BEGIN
  -- Only recalculate if rev_date or final_date changed
  IF (TG_OP = 'UPDATE' AND (
    OLD.rev_date IS DISTINCT FROM NEW.rev_date OR
    OLD.final_date IS DISTINCT FROM NEW.final_date
  )) THEN
    
    -- Determine which date changed
    IF OLD.final_date IS DISTINCT FROM NEW.final_date THEN
      v_old_date := OLD.due_date;  -- Old due_date before completion
      v_new_date := NEW.final_date;
    ELSIF OLD.rev_date IS DISTINCT FROM NEW.rev_date THEN
      v_old_date := COALESCE(OLD.rev_date, OLD.plan_date);
      v_new_date := NEW.rev_date;
    ELSE
      RETURN NEW;  -- No relevant date change
    END IF;
    
    -- Calculate delta
    v_delta_days := v_new_date - v_old_date;
    
    -- Only propagate if delta is non-zero
    IF v_delta_days != 0 THEN
      -- Recursive CTE to find all downstream dependencies
      WITH RECURSIVE downstream AS (
        -- Base case: direct dependents
        SELECT 
          td.dependent_node_id AS node_id,
          td.lag_days,
          1 AS depth
        FROM ops.timeline_dependency td
        WHERE td.predecessor_node_id = NEW.node_id
        
        UNION ALL
        
        -- Recursive case: indirect dependents
        SELECT 
          td.dependent_node_id AS node_id,
          td.lag_days,
          d.depth + 1
        FROM ops.timeline_dependency td
        JOIN downstream d ON td.predecessor_node_id = d.node_id
        WHERE d.depth < 10  -- Prevent infinite loops
      )
      -- Update all downstream milestones
      UPDATE ops.timeline_node
      SET 
        plan_date = plan_date + (v_delta_days || ' days')::INTERVAL,
        -- If rev_date exists, shift it too
        rev_date = CASE 
          WHEN rev_date IS NOT NULL THEN rev_date + (v_delta_days || ' days')::INTERVAL
          ELSE NULL
        END,
        updated_at = NOW()
      WHERE node_id IN (SELECT node_id FROM downstream)
        AND status NOT IN ('approved', 'na');  -- Don't shift completed/NA milestones
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER trg_recalculate_downstream
  AFTER UPDATE OF rev_date, final_date
  ON ops.timeline_node
  FOR EACH ROW
  EXECUTE FUNCTION ops.fn_recalculate_downstream_timelines();
```

**Logic:**
1. Detect when `rev_date` or `final_date` changes
2. Calculate delta between old and new date
3. Use recursive CTE to find all downstream dependencies
4. Shift `plan_date` (and `rev_date` if set) by delta for all dependents
5. Skip completed or N/A milestones (don't shift past work)

**CRITICAL ENHANCEMENT:** This fixes the BeProduct gap where `rev_date` changes don't cascade to downstream milestones!

**Test Cases:**
```sql
-- Setup: A → B → C dependency chain
-- A: plan_date = 2025-05-01, B: plan_date = 2025-05-06 (+5 lag), C: plan_date = 2025-05-11 (+5 lag)

-- Test 1: Complete A early (final_date = 2025-04-29, delta = -2)
UPDATE ops.timeline_node SET final_date = '2025-04-29', status = 'approved' WHERE milestone_name = 'A';
-- Expected: B.plan_date = 2025-05-04 (-2), C.plan_date = 2025-05-09 (-2)

-- Test 2: Reschedule B (rev_date = 2025-05-10, delta = +4)
UPDATE ops.timeline_node SET rev_date = '2025-05-10' WHERE milestone_name = 'B';
-- Expected: C.plan_date = 2025-05-15 (+4)

-- Test 3: Complete C (should NOT shift anything - it's a leaf node)
UPDATE ops.timeline_node SET final_date = '2025-05-15', status = 'approved' WHERE milestone_name = 'C';
-- Expected: No changes to A or B
```

---

## Audit Trail

### 5. Audit Timeline Changes

**Function:** `fn_audit_timeline_changes()`

```sql
CREATE OR REPLACE FUNCTION ops.fn_audit_timeline_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_field TEXT;
  v_old_value TEXT;
  v_new_value TEXT;
BEGIN
  -- Track changes to key fields
  FOREACH v_field IN ARRAY ARRAY['status', 'plan_date', 'rev_date', 'due_date', 'final_date', 'is_late'] LOOP
    -- Get old and new values dynamically
    EXECUTE format('SELECT ($1).%I::TEXT', v_field) INTO v_old_value USING OLD;
    EXECUTE format('SELECT ($1).%I::TEXT', v_field) INTO v_new_value USING NEW;
    
    -- Log if changed
    IF v_old_value IS DISTINCT FROM v_new_value THEN
      INSERT INTO ops.timeline_audit_log (
        node_id,
        changed_field,
        old_value,
        new_value,
        changed_by
      ) VALUES (
        NEW.node_id,
        v_field,
        v_old_value,
        v_new_value,
        NEW.updated_by
      );
    END IF;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER trg_audit_timeline_changes
  AFTER UPDATE ON ops.timeline_node
  FOR EACH ROW
  EXECUTE FUNCTION ops.fn_audit_timeline_changes();
```

**Logic:**
1. Compare OLD and NEW values for tracked fields
2. Insert audit record for each changed field
3. Capture user who made the change (`updated_by`)

**Tracked Fields:**
- `status` - Milestone status changes
- `plan_date` - Baseline date changes (rare, but possible)
- `rev_date` - Revision tracking
- `due_date` - Working date changes
- `final_date` - Completion tracking
- `is_late` - Late flag changes

---

## Utility Functions

### 6. Get Critical Path

**Function:** `fn_get_critical_path(p_plan_id UUID)`

```sql
CREATE OR REPLACE FUNCTION ops.fn_get_critical_path(p_plan_id UUID)
RETURNS TABLE(
  node_id UUID,
  milestone_name TEXT,
  due_date DATE,
  path_length INTEGER
) AS $$
BEGIN
  -- Find the longest dependency chain (critical path)
  RETURN QUERY
  WITH RECURSIVE path AS (
    -- Base case: milestones with no predecessors (start nodes)
    SELECT 
      tn.node_id,
      COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
      tn.due_date,
      0 AS path_length,
      ARRAY[tn.node_id] AS path_nodes
    FROM ops.timeline_node tn
    LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
    LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
    WHERE tn.plan_id = p_plan_id
      AND NOT EXISTS (
        SELECT 1 FROM ops.timeline_dependency td 
        WHERE td.dependent_node_id = tn.node_id
      )
    
    UNION ALL
    
    -- Recursive case: follow dependency chain
    SELECT 
      tn.node_id,
      COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
      tn.due_date,
      p.path_length + 1,
      p.path_nodes || tn.node_id
    FROM ops.timeline_node tn
    LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
    LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
    JOIN ops.timeline_dependency td ON tn.node_id = td.dependent_node_id
    JOIN path p ON td.predecessor_node_id = p.node_id
    WHERE tn.plan_id = p_plan_id
      AND NOT (tn.node_id = ANY(p.path_nodes))  -- Prevent cycles
  )
  -- Return the longest path
  SELECT 
    path.node_id,
    path.milestone_name,
    path.due_date,
    path.path_length
  FROM path
  WHERE path.path_length = (SELECT MAX(path_length) FROM path)
  ORDER BY path.path_length, path.due_date;
END;
$$ LANGUAGE plpgsql;
```

**Usage:**
```sql
SELECT * FROM ops.fn_get_critical_path('plan-uuid');
```

**Output:**
```
node_id                                | milestone_name        | due_date   | path_length
---------------------------------------+-----------------------+------------+-------------
a1b2c3d4-...                           | START DATE            | 2025-05-01 | 0
e5f6g7h8-...                           | TECHPACKS PASS OFF    | 2025-05-01 | 1
i9j0k1l2-...                           | PROTO PRODUCTION      | 2025-05-05 | 2
...
z9y8x7w6-...                           | END DATE              | 2026-01-05 | 24
```

---

### 7. Get User Workload

**Function:** `fn_get_user_workload(p_user_id UUID)`

```sql
CREATE OR REPLACE FUNCTION ops.fn_get_user_workload(p_user_id UUID)
RETURNS TABLE(
  node_id UUID,
  entity_type ops.timeline_entity_type,
  entity_name TEXT,
  plan_name TEXT,
  milestone_name TEXT,
  status ops.timeline_status,
  due_date DATE,
  is_late BOOLEAN,
  assigned_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    tn.node_id,
    tn.entity_type,
    CASE 
      WHEN tn.entity_type = 'style' THEN s.name
      WHEN tn.entity_type = 'material' THEN m.name
      ELSE 'Unknown'
    END AS entity_name,
    p.name AS plan_name,
    COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
    tn.status,
    tn.due_date,
    tn.is_late,
    ta.assigned_at
  FROM ops.tracking_timeline_assignment ta
  JOIN ops.timeline_node tn ON ta.node_id = tn.node_id
  JOIN ops.tracking_plan p ON tn.plan_id = p.id
  LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
  LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
  LEFT JOIN pim.styles s ON ts.style_id = s.id
  LEFT JOIN pim.materials m ON tm.material_id = m.id
  WHERE ta.user_id = p_user_id
    AND tn.status NOT IN ('approved', 'na')
  ORDER BY tn.due_date, tn.is_late DESC;
END;
$$ LANGUAGE plpgsql;
```

**Usage:**
```sql
SELECT * FROM ops.fn_get_user_workload('user-uuid');
```

**Output:**
```
node_id      | entity_type | entity_name           | plan_name             | milestone_name  | status      | due_date   | is_late | assigned_at
-------------+-------------+-----------------------+-----------------------+-----------------+-------------+------------+---------+-------------
node-uuid-1  | style       | MONTAUK SHORT         | GREYSON 2026 SPRING   | PROTO SAMPLE    | in_progress | 2025-11-05 | true    | 2025-10-15
node-uuid-2  | material    | POLY SPANDEX BLEND    | GREYSON 2026 SPRING   | LAB DIP APPROVE | not_started | 2025-11-10 | false   | 2025-10-20
```

---

### 8. Bulk Update Status

**Function:** `fn_bulk_update_timeline_status(p_node_ids UUID[], p_status ops.timeline_status, p_updated_by UUID)`

```sql
CREATE OR REPLACE FUNCTION ops.fn_bulk_update_timeline_status(
  p_node_ids UUID[],
  p_status ops.timeline_status,
  p_updated_by UUID DEFAULT NULL
)
RETURNS TABLE(
  node_id UUID,
  old_status ops.timeline_status,
  new_status ops.timeline_status,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  WITH updates AS (
    UPDATE ops.timeline_node
    SET 
      status = p_status,
      updated_by = COALESCE(p_updated_by, updated_by),
      updated_at = NOW()
    WHERE node_id = ANY(p_node_ids)
    RETURNING 
      timeline_node.node_id,
      timeline_node.status AS old_status,
      p_status AS new_status,
      timeline_node.updated_at
  )
  SELECT * FROM updates;
END;
$$ LANGUAGE plpgsql;
```

**Usage:**
```sql
-- Approve multiple milestones at once
SELECT * FROM ops.fn_bulk_update_timeline_status(
  ARRAY['node-uuid-1', 'node-uuid-2', 'node-uuid-3']::UUID[],
  'approved'::ops.timeline_status,
  'user-uuid'::UUID
);
```

---

## Testing

### Test Suite Setup

```sql
-- Create test plan
INSERT INTO ops.tracking_plan (id, name, start_date, end_date, template_id)
VALUES (
  'test-plan-uuid',
  'Test Plan for Trigger Validation',
  '2025-05-01',
  '2026-01-01',
  'template-uuid'
);

-- Create test milestones
INSERT INTO ops.timeline_node (node_id, entity_type, entity_id, plan_id, milestone_id, plan_date)
VALUES 
  ('node-a', 'style', 'style-uuid', 'test-plan-uuid', 'milestone-a', '2025-05-01'),
  ('node-b', 'style', 'style-uuid', 'test-plan-uuid', 'milestone-b', '2025-05-06'),
  ('node-c', 'style', 'style-uuid', 'test-plan-uuid', 'milestone-c', '2025-05-11');

-- Create dependencies: A → B → C
INSERT INTO ops.timeline_dependency (dependent_node_id, predecessor_node_id, lag_days)
VALUES 
  ('node-b', 'node-a', 5),
  ('node-c', 'node-b', 5);
```

### Test Cases

#### Test 1: Due Date Calculation
```sql
-- Verify due_date auto-calculation
SELECT node_id, plan_date, rev_date, due_date 
FROM ops.timeline_node 
WHERE node_id = 'node-a';
-- Expected: due_date = plan_date (no rev_date yet)

UPDATE ops.timeline_node SET rev_date = '2025-05-05' WHERE node_id = 'node-a';
SELECT node_id, plan_date, rev_date, due_date 
FROM ops.timeline_node 
WHERE node_id = 'node-a';
-- Expected: due_date = '2025-05-05'
```

#### Test 2: Late Flag Calculation
```sql
-- Verify is_late flag
SELECT node_id, plan_date, due_date, is_late 
FROM ops.timeline_node 
WHERE node_id = 'node-a';
-- Expected: is_late = true (due_date > plan_date)
```

#### Test 3: Downstream Recalculation
```sql
-- Complete A early and verify cascade
UPDATE ops.timeline_node 
SET final_date = '2025-04-29', status = 'approved' 
WHERE node_id = 'node-a';

SELECT node_id, milestone_name, plan_date, due_date 
FROM ops.timeline_node 
WHERE node_id IN ('node-a', 'node-b', 'node-c')
ORDER BY plan_date;
-- Expected: B and C plan_date shifted by -2 days
```

#### Test 4: Audit Trail
```sql
-- Verify audit log entries
SELECT changed_field, old_value, new_value, changed_at
FROM ops.timeline_audit_log
WHERE node_id = 'node-a'
ORDER BY changed_at DESC;
-- Expected: Multiple entries for status, final_date, due_date changes
```

---

**Document Status:** ✅ Ready for Implementation  
**Last Updated:** October 31, 2025  
**Version:** 1.0
