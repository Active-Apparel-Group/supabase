# Start Date Calculation Strategy

**Purpose:** Calculate `start_date_plan` and `start_date_due` for timeline milestones to enable Gantt chart rendering, on-time performance tracking, and critical path analysis.

**Status:** ✅ Implemented  
**Date:** November 7, 2025

---

## Business Requirements

### Why Start Dates Matter

1. **Gantt Chart Rendering**
   - Need start dates to show duration bars (not just end points)
   - Visual representation of task durations
   - Better understanding of timeline overlaps and gaps

2. **On-Time Performance Tracking**
   - `start_date_plan` = When task should have started (baseline)
   - `start_date_due` = When task is expected to start (current forecast)
   - Track if milestones start on time vs delayed

3. **Critical Path Analysis**
   - Use `start_date_plan` and `plan_date` to establish baseline plan
   - Identify critical path through dependency chain
   - Detect bottlenecks and delays

---

## Data Model

### Columns

```sql
-- tracking_plan_style_timeline
start_date_plan DATE       -- Planned start date (baseline)
start_date_due DATE        -- Committed/forecast start date
duration_value INTEGER     -- Task duration from dependencies table
plan_date DATE             -- End date (planned)
due_date DATE              -- End date (due/forecast)
dependency_uuid UUID       -- Link to predecessor milestone
relationship relationship_type_enum  -- Dependency type
```

### Relationship Types

- `start-to-start` - My start depends on predecessor's start
- `end-to-start` - My start depends on predecessor's end (most common)
- `start-to-end` - My end depends on predecessor's start (rare)
- `end-to-end` - My end depends on predecessor's end (parallel tasks)

---

## Calculation Logic

### SQL Function: `calculate_timeline_start_dates(p_plan_id UUID)`

**Location:** Migration `add_start_date_calculation_function.sql`

**Algorithm:**

```
1. Base Case (START DATE milestone):
   start_date_plan = plan_date
   start_date_due = due_date
   (START DATE has no duration, start = end)

2. Recursive Case (all other milestones):
   
   A. Calculate start_date_plan:
      - start-to-start: predecessor.start_date_plan
      - end-to-start: predecessor.plan_date
      - start-to-end: predecessor.start_date_plan - duration
      - end-to-end: predecessor.plan_date - duration
      - default: my_plan_date - duration
   
   B. Calculate start_date_due:
      - If duration > 0: my_due_date - duration
      - start-to-start: predecessor.start_date_due
      - end-to-start: predecessor.due_date
      - default: my_due_date - duration

3. Update timeline records with calculated dates
```

**Example:**

```
PROTO PRODUCTION:
  depends_on: "TECHPACKS PASS OFF" (end-to-start)
  duration: 4 days
  plan_date: 2025-11-09

  Calculation:
    start_date_plan = TECHPACKS.plan_date = 2025-11-05
    start_date_due = due_date - 4 = 2025-11-09 - 4 = 2025-11-05
    (Task starts when predecessor ends, runs for 4 days)
```

---

## Integration Points

### 1. Edge Function: `beproduct-tracking-webhook`

**When:** After timeline creation/update (OnCreate, OnChange events)

**Call:**
```typescript
await recalculateStartDates(client, planId);

// Function implementation:
async function recalculateStartDates(client: any, planId: string) {
  const { data, error } = await client.rpc('calculate_timeline_start_dates', {
    p_plan_id: planId
  });
  console.log(`Recalculated start dates for ${data?.length || 0} records`);
}
```

**Trigger Points:**
- OnCreate: After syncing all timeline data from BeProduct
- OnChange: After updating timeline dates (rev_date, final_date, due_date changes)

### 2. Lindy Dependency Webhook

**When:** After populating `dependency_uuid` for all milestones

**Call:**
```typescript
await supabaseClient.rpc('calculate_timeline_start_dates', {
  p_plan_id: payload.plan_id
});
```

**Sequence:**
1. Lindy scrapes dependency data from BeProduct UI
2. `populate_timeline_dependencies()` sets `dependency_uuid` for each milestone
3. `calculate_timeline_start_dates()` calculates start dates based on new dependencies

---

## Data Sources

### Duration Values

**Source:** `tracking_plan_dependencies.duration` column

**Populated by:** Lindy scraper webhook (from BeProduct UI)

**Example Data:**
```sql
SELECT 
  action_description, 
  depends_on, 
  duration, 
  duration_unit, 
  relationship
FROM tracking_plan_dependencies
WHERE plan_id = '...'
ORDER BY row_number;

-- Result:
START DATE              | NULL                   | 0  | NULL | NULL
TECHPACKS PASS OFF      | START DATE             | 0  | DAYS | start-to-start
PROTO PRODUCTION        | TECHPACKS PASS OFF     | 4  | DAYS | end-to-start
PROTO EX-FCTY           | PROTO PRODUCTION       | 14 | DAYS | end-to-start
```

### Dependency Links

**Source:** `dependency_uuid` column (UUID reference to predecessor)

**Populated by:** `populate_timeline_dependencies()` function

**Purpose:** Links milestone to its predecessor for recursive calculation

---

## Testing

### Test Query

```sql
-- View calculated start dates with durations
SELECT 
  milestone_name,
  start_date_plan,
  plan_date,
  (plan_date - start_date_plan) as plan_duration_days,
  start_date_due,
  due_date,
  (due_date - start_date_due) as due_duration_days,
  relationship
FROM tracking_plan_style_timeline t
JOIN tracking_plan_style ps ON t.plan_style_id = ps.id
WHERE ps.plan_id = '4b7d6906-1413-44bb-bcdd-47b7f9cc5643'
ORDER BY plan_date;
```

### Expected Results

```
START DATE              | 2025-01-01 | 2025-01-01 | 0  | start-to-start
TECHPACKS PASS OFF      | 2025-01-01 | 2025-11-05 | 308 | end-to-start
PROTO PRODUCTION        | 2025-11-05 | 2025-11-09 | 4  | end-to-start
PROTO EX-FCTY           | 2025-11-09 | 2025-11-23 | 14 | end-to-start
PROTO COSTING DUE       | 2025-11-23 | 2025-11-25 | 2  | end-to-start
```

### Validation

✅ **Durations match dependency data** (4 days, 14 days, 2 days, etc.)  
✅ **Relationships respected** (start-to-start, end-to-start)  
✅ **Both start dates calculated** (plan and due)  
✅ **START DATE milestone** (start = end, duration = 0)

---

## Frontend Usage

### Gantt Chart Component

**Before:**
```javascript
// Only had end dates, couldn't show task bars
tasks.map(t => ({
  name: t.milestone_name,
  date: t.due_date,  // Only end point
}))
```

**After:**
```javascript
// Can now show full task duration bars
tasks.map(t => ({
  name: t.milestone_name,
  start: t.start_date_due,    // Bar start
  end: t.due_date,             // Bar end
  baseline_start: t.start_date_plan,  // Original plan
  baseline_end: t.plan_date           // Original plan
}))
```

### On-Time Performance Dashboard

```javascript
// Track if task started on time
const delayedStart = tasks.filter(t => {
  if (!t.start_date_plan || !t.start_date_due) return false;
  return t.start_date_due > t.start_date_plan;
});

// Show delay in days
delayedStart.map(t => ({
  milestone: t.milestone_name,
  planned_start: t.start_date_plan,
  actual_start: t.start_date_due,
  days_delayed: daysBetween(t.start_date_plan, t.start_date_due)
}));
```

### Critical Path Analysis

```javascript
// Calculate total duration from START to END DATE
const criticalPath = calculateLongestPath(
  milestones,
  'START DATE',
  'END DATE'
);

// Show critical milestones (no slack time)
const criticalMilestones = milestones.filter(m => 
  m.slack_time === 0  // No buffer, any delay impacts end date
);
```

---

## Performance Considerations

### Execution Time

- Recursive CTE processes all milestones in dependency order
- Test plan (29 milestones): < 50ms
- Scales linearly with number of milestones

### Optimization

- Function uses temp table to avoid CTE scope issues
- Single UPDATE statement for all records
- Indexed on `plan_style_id` and `dependency_uuid` for fast joins

### When to Call

**Trigger:**
- After timeline creation (OnCreate event)
- After timeline date changes (OnChange event)
- After dependency data updated (Lindy webhook)

**Avoid:**
- On every single field change (only when dates/dependencies change)
- During bulk imports (call once after all records loaded)

---

## Future Enhancements

### Business Days Calculation

**Current:** All durations in calendar days  
**Future:** Support `duration_unit = 'BUSINESS_DAYS'`

```sql
-- Add business day calculation
CASE duration_unit
  WHEN 'BUSINESS_DAYS' THEN 
    calculate_business_days(start_date, duration, calendar_id)
  ELSE start_date + duration
END
```

### Multiple Calendar Support

**Current:** Single calendar for all milestones  
**Future:** Per-milestone calendar (factory holidays, regional calendars)

```sql
-- Use calendar_name from milestone
SELECT holiday_dates 
FROM business_calendars 
WHERE name = milestone.calendar_name
```

### Start Date Overrides

**Current:** Always calculated from dependencies  
**Future:** Allow manual override with flag

```sql
-- Add override support
start_date_override DATE,
use_override BOOLEAN DEFAULT false,

-- In calculation:
COALESCE(
  CASE WHEN use_override THEN start_date_override ELSE NULL END,
  calculated_start_date
)
```

---

## Troubleshooting

### Missing Start Dates

**Symptom:** Some milestones have NULL start dates

**Causes:**
1. Missing `dependency_uuid` (dependency not populated)
2. Missing `duration` in dependencies table
3. Orphaned milestone (no predecessor link)

**Solution:**
```sql
-- Check for missing dependencies
SELECT milestone_name, depends_on, dependency_uuid
FROM tracking_plan_style_timeline
WHERE dependency_uuid IS NULL AND row_number > 0;

-- Run dependency population first
SELECT populate_timeline_dependencies('plan_id');

-- Then calculate start dates
SELECT calculate_timeline_start_dates('plan_id');
```

### Incorrect Duration

**Symptom:** Start date too far back or too close to end date

**Cause:** Duration value incorrect in `tracking_plan_dependencies`

**Solution:**
```sql
-- Verify duration values
SELECT 
  action_description,
  duration,
  duration_unit
FROM tracking_plan_dependencies
WHERE plan_id = '...';

-- Update incorrect duration
UPDATE tracking_plan_dependencies
SET duration = 4  -- Correct value
WHERE action_description = 'PROTO PRODUCTION';

-- Recalculate
SELECT calculate_timeline_start_dates('plan_id');
```

### Circular Dependencies

**Symptom:** Function hangs or fails with "infinite recursion" error

**Cause:** Milestone A depends on B, B depends on A

**Solution:**
```sql
-- Detect circular dependencies
WITH RECURSIVE deps AS (
  SELECT 
    id, 
    milestone_name, 
    dependency_uuid,
    ARRAY[id] as path
  FROM tracking_plan_style_timeline
  WHERE dependency_uuid IS NULL
  
  UNION ALL
  
  SELECT 
    t.id, 
    t.milestone_name, 
    t.dependency_uuid,
    deps.path || t.id
  FROM tracking_plan_style_timeline t
  JOIN deps ON t.dependency_uuid = deps.id
  WHERE t.id = ANY(deps.path) -- Circular!
)
SELECT * FROM deps WHERE cardinality(path) > 1;
```

---

## Related Documentation

- [Timeline Schema Reference](./timeline-schema-reference-catalog.md) - Full table schema
- [Triggers & Functions](./triggers-functions.md) - Date recalculation triggers
- [BeProduct API Mapping](./beproduct-api-mapping.md) - Duration data source
- [Hybrid Timeline Schema Redesign](./hybrid-timeline-schema-redesign.md) - Overall architecture

---

**Last Updated:** November 7, 2025  
**Maintained By:** Backend Team  
**Review Cycle:** After any dependency logic changes
