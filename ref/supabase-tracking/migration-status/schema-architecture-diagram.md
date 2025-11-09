# Gantt Timeline Schema Architecture

## Complete Table Hierarchy

```
tracking_timeline_template
├── id
├── name
├── brand
├── season
└── (template metadata)
    │
    ├──> tracking_timeline_template_item (27 rows)
    │    ├── id
    │    ├── template_id (FK to template)
    │    ├── name
    │    ├── depends_on_template_item_id (self-referencing FK)
    │    ├── offset_relation (AFTER/BEFORE)
    │    ├── offset_value (gap after predecessor)
    │    ├── offset_unit (DAYS/BUSINESS_DAYS)
    │    ├── ✨ duration_value (NEW - task length)
    │    └── ✨ duration_unit (NEW - DAYS/BUSINESS_DAYS)
    │
    └──> tracking_plan
         ├── id
         ├── template_id (FK to template)
         ├── start_date
         └── end_date
             │
             ├──> tracking_plan_style
             │    ├── id
             │    ├── plan_id (FK to plan)
             │    ├── style_id
             │    └── (style metadata)
             │        │
             │        └──> tracking_plan_style_timeline (108 rows)
             │             ├── id
             │             ├── plan_style_id (FK to plan_style)
             │             ├── template_item_id (FK to template_item)
             │             ├── plan_date (end date - original)
             │             ├── due_date (end date - committed)
             │             ├── rev_date (end date - revised)
             │             ├── final_date (end date - actual)
             │             ├── ✨ start_date_plan (NEW - planned start)
             │             ├── ✨ start_date_due (NEW - committed start)
             │             ├── ✨ duration_value (NEW - task length)
             │             ├── ✨ duration_unit (NEW - DAYS/BUSINESS_DAYS)
             │             ├── late (calculated flag)
             │             └── status (NOT_STARTED/IN_PROGRESS/COMPLETE/etc)
             │                 │
             │                 └──> tracking_plan_style_dependency (100 rows)
             │                      ├── predecessor_id (FK to timeline)
             │                      ├── successor_id (FK to timeline)
             │                      ├── offset_relation (AFTER/BEFORE)
             │                      ├── offset_value (gap)
             │                      └── offset_unit (DAYS/BUSINESS_DAYS)
             │
             └──> tracking_plan_material
                  ├── id
                  ├── plan_id (FK to plan)
                  ├── material_id
                  └── (material metadata)
                      │
                      └──> tracking_plan_material_timeline (0 rows)
                           ├── id
                           ├── plan_material_id (FK to plan_material)
                           ├── template_item_id (FK to template_item)
                           ├── plan_date (end date - original)
                           ├── due_date (end date - committed)
                           ├── ✨ start_date_plan (NEW)
                           ├── ✨ start_date_due (NEW)
                           ├── ✨ duration_value (NEW)
                           ├── ✨ duration_unit (NEW)
                           └── late (calculated flag)
                               │
                               └──> tracking_plan_material_dependency
                                    ├── predecessor_id
                                    ├── successor_id
                                    ├── offset_relation
                                    ├── offset_value
                                    └── offset_unit
```

---

## Date Field Relationships

### Template Level (Definition)
```
tracking_timeline_template_item
├── duration_value: 7
└── duration_unit: DAYS

↓ DEFINES DEFAULT FOR ↓
```

### Instance Level (Execution)
```
tracking_plan_style_timeline
├── start_date_plan ──────┐
│   (planned start)        │
│                          │  duration_value: 7
├── plan_date ────────────┤  duration_unit: DAYS
│   (planned end)          │
│                          │
├── start_date_due ───────┤
│   (committed start)      │
│                          │
└── due_date ─────────────┘
    (committed end)

Calculated:
  late = (due_date > plan_date)
```

---

## Trigger Flow Diagram

### Insert/Update Timeline Entry

```
User Action:
  UPDATE timeline SET duration_value = 10

↓ BEFORE TRIGGER

calculate_timeline_dates()
  ├─ Has start_date_plan + duration? → Calculate plan_date
  ├─ Has plan_date + duration? → Calculate start_date_plan
  ├─ Has predecessor? → Calculate start from predecessor.plan_date + offset
  └─ Calculate late flag: due_date > plan_date

↓ ROW UPDATED IN DB

↓ AFTER TRIGGER

cascade_timeline_updates()
  ├─ Find all successors (where predecessor_id = this.id)
  ├─ For each successor:
  │   ├─ Update start_date_plan = this.plan_date + offset
  │   ├─ Update plan_date = new_start + duration
  │   └─ RECURSIVELY triggers cascade for successor's successors
  └─ Update timestamps

↓ CASCADE COMPLETE
```

### Update Plan Dates

```
User Action:
  UPDATE tracking_plan SET start_date = '2024-02-01'

↓ AFTER TRIGGER

recalculate_plan_timelines()
  ├─ SELECT all style timelines for this plan
  ├─ For each timeline:
  │   ├─ Recalculate based on new plan dates
  │   └─ Apply template offsets/durations
  │
  ├─ SELECT all material timelines for this plan
  └─ For each timeline:
      ├─ Recalculate based on new plan dates
      └─ Apply template offsets/durations

↓ ALL TIMELINES UPDATED
```

---

## Gantt Chart View Modes

### Mode 1: Planned (Baseline)
```
Timeline Entry:
  start_date_plan: 2024-02-01
  plan_date: 2024-02-08
  
Gantt Bar:
  [═══════════════════════]
  Feb 1              Feb 8
  (7 days)
  
Color: Blue (baseline)
```

### Mode 2: Committed (Current Forecast)
```
Timeline Entry:
  start_date_due: 2024-02-01
  due_date: 2024-02-10
  
Gantt Bar:
  [═══════════════════════════]
  Feb 1                  Feb 10
  (9 days - pushed out)
  
Color: Orange (if late = true)
       Green (if late = false)
```

### Mode 3: Actual (Completed)
```
Timeline Entry:
  start_date_due: 2024-02-01
  final_date: 2024-02-12
  
Gantt Bar:
  [═══════════════════════════════]
  Feb 1                      Feb 12
  (11 days - actual)
  
Color: Red (late)
       Green (on time)
```

---

## Key Concepts

### 1. Duration vs Offset

**Duration** = How long the task itself takes
```
Task: "Fit Comments Review"
duration_value: 7
duration_unit: DAYS

Meaning: The review process takes 7 days from start to finish
```

**Offset** = Gap between tasks
```
Dependency: "Proto FIT Comments DUE" → "2nd Proto Production"
offset_value: 4
offset_unit: DAYS
offset_relation: AFTER

Meaning: 4 days AFTER fit comments are due, start 2nd proto production
```

### 2. Template Inheritance

```
Template Definition:
  tracking_timeline_template_item
  ├── name: "Proto Production"
  ├── duration_value: 14
  └── duration_unit: DAYS

↓ INSTANTIATE PLAN ↓

Plan Instance:
  tracking_plan_style_timeline
  ├── milestone_name: "Proto Production"
  ├── duration_value: 14  ← copied from template
  └── duration_unit: DAYS ← copied from template
  
User can override:
  ├── duration_value: 10  ← changed for this plan only
  └── duration_unit: BUSINESS_DAYS
```

### 3. Late Flag Logic

```sql
late = (due_date > plan_date)

Examples:
  plan_date: 2024-02-08, due_date: 2024-02-08 → late = FALSE (on time)
  plan_date: 2024-02-08, due_date: 2024-02-10 → late = TRUE (2 days late)
  plan_date: 2024-02-08, due_date: 2024-02-06 → late = FALSE (2 days early)
```

---

## Example Data Flow

### Creating a Plan from Template

```sql
-- Step 1: User creates plan
INSERT INTO tracking_plan (name, template_id, start_date)
VALUES ('Spring 2024 Production', 'tmpl-uuid', '2024-02-01');

-- Step 2: System creates timeline entries from template
INSERT INTO tracking_plan_style_timeline (
  plan_style_id,
  template_item_id,
  duration_value,
  duration_unit
)
SELECT 
  'plan-style-uuid',
  tti.id,
  tti.duration_value,  -- Copy from template
  tti.duration_unit    -- Copy from template
FROM tracking_timeline_template_item tti
WHERE tti.template_id = 'tmpl-uuid';

-- Step 3: Triggers calculate dates
-- calculate_timeline_dates() fires for each INSERT
-- Calculates start_date_plan based on:
--   - Plan start date (for first milestone)
--   - Predecessor end date + offset (for dependent milestones)
-- Calculates plan_date as: start_date_plan + duration_value

-- Result: Fully calculated timeline with dates
```

### Updating Duration Cascades Downstream

```sql
-- User changes "Proto Production" duration from 14 to 10 days
UPDATE tracking_plan_style_timeline
SET duration_value = 10
WHERE id = 'proto-production-uuid';

-- BEFORE trigger calculates new plan_date
-- Old: start_date_plan = Feb 1, duration = 14 → plan_date = Feb 15
-- New: start_date_plan = Feb 1, duration = 10 → plan_date = Feb 11

-- AFTER trigger cascades to successors
-- "Proto Ex-Factory" depends on "Proto Production"
-- Old: start_date_plan = Feb 15 + 0 days = Feb 15
-- New: start_date_plan = Feb 11 + 0 days = Feb 11

-- "Proto Costing Due" depends on "Proto Ex-Factory"
-- Old: start_date_plan = Feb 15 + 2 days = Feb 17
-- New: start_date_plan = Feb 11 + 2 days = Feb 13

-- Entire timeline shifts by 4 days
```

---

## Summary

### ✨ New Capabilities

1. **Task Bars in Gantt**: Can now show start-to-end bars instead of just end dates
2. **Duration Tracking**: Explicitly model how long tasks take
3. **Template Defaults**: Define standard durations at template level
4. **Auto-Calculation**: Triggers handle date math automatically
5. **Auto-Cascade**: Changes propagate through dependency chain
6. **Three View Modes**: Compare planned vs committed vs actual timelines
7. **Late Tracking**: Visual indicators for tasks running behind schedule

### 🎯 Business Value

- **Better Planning**: Merchandisers can see realistic timelines, not just milestones
- **Proactive Management**: Late flags highlight issues before they cascade
- **Consistency**: Templates ensure standard durations across all plans
- **Flexibility**: Override durations per plan when needed
- **Visibility**: Three view modes show variance from baseline

### 🔧 Technical Debt

- **Business Days**: Current implementation uses calendar days; business day logic needs custom function
- **Existing Data**: 108 timeline rows have null duration values (need migration)
- **Template Data**: 27 template items need duration values populated
- **Testing**: Cascade logic needs comprehensive testing with complex dependency graphs