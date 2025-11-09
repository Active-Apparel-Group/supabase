# Tracking System Schema Migration Guide

## Overview

This document outlines the migration from template-based timeline architecture to the new simplified schema where milestone configurations are stored directly in timeline tables. Based on actual Supabase schema analysis (ops schema only, tracking* tables).

**Status**: Template tables (`tracking_timeline_template`, `tracking_timeline_template_item`) are being phased out.

---

## Schema Changes Summary

### ❌ Deprecated Tables (Being Removed)
- `tracking_timeline_template` - Template definitions
- `tracking_timeline_template_item` - Template milestone configurations

### ✅ Current Active Tables (Already Implemented)
- `tracking_plan_style_timeline` - Style timelines with embedded milestone configs
- `tracking_plan_material_timeline` - Material timelines with embedded milestone configs
- `tracking_timeline_assignment` - User assignments to milestones
- `tracking_plan_dependencies` - Dependency chains for plans
- `tracking_plan_style_dependency` - Dependencies between style milestones
- `tracking_plan_material_dependency` - Dependencies between material milestones

---

## Key Schema Differences

### OLD (Template-Based) Architecture
```
tracking_timeline_template (template definition)
    ↓
tracking_timeline_template_item (milestone configuration)
    ↓
tracking_plan_style_timeline (timeline instance referencing template_item_id)
```

### NEW (Direct) Architecture  
```
tracking_plan_style_timeline (timeline with embedded milestone config)
    ↓
tracking_plan_style_dependency (milestone dependencies)
```

---

## Updated Table Structures

### 1. tracking_plan_style_timeline (372 rows)

**New Columns Added** (milestone configuration now embedded):
```sql
-- Milestone Identity
milestone_name TEXT              -- Full milestone name (from BeProduct TaskDescription)
milestone_short_name TEXT        -- Short name (from BeProduct ShortDescription)
milestone_page_name TEXT         -- Associated page (e.g., "Proto Sample", "Tech Pack")

-- Department & Phase (ENUMS)
department department_enum       -- Internal enum: PLAN, CUSTOMER, PD, ACCOUNT_MANAGER, etc.
phase phase_enum                 -- Internal enum: DEVELOPMENT, PRE-PRODUCTION, PRODUCTION, etc.
dept_customer TEXT              -- Original BeProduct department value (audit trail)

-- Duration & Offset
duration_value INTEGER           -- Task duration
duration_unit offset_unit_enum   -- DAYS or BUSINESS_DAYS
offset_days INTEGER             -- Number of offset days from predecessor
calendar_days INTEGER           -- Calendar days for duration calculation
calendar_name TEXT              -- Calendar system identifier

-- Dependencies (replacing template dependencies)
dependency_uuid UUID            -- UUID of predecessor milestone
depends_on TEXT                 -- Name of predecessor milestone
relationship relationship_type_enum  -- start-to-start, end-to-start, etc.
row_number INTEGER              -- Sequential order (0=START, 99=END)

-- Status (BeProduct compatible)
status TEXT CHECK (...)         -- 'Not Started', 'In Progress', 'Approved', etc.
default_status TEXT            -- Default status when created
submits_quantity INTEGER       -- Number of submissions

-- Visibility & Sharing
customer_visible BOOLEAN        -- Show to customers
supplier_visible BOOLEAN        -- Show to suppliers
shared_with JSONB              -- Array of company IDs: ["companyId1", "companyId2"]
external_share_with JSONB      -- External sharing config

-- Task Configuration
group_task TEXT                 -- Task grouping identifier
when_rule TEXT                  -- Timing rule for activation
share_when_rule TEXT            -- Sharing timing rule
activity_description TEXT       -- Detailed description
revised_days INTEGER            -- Revised offset if schedule changes
auto_share_linked_page BOOLEAN  -- Auto-share linked pages
sync_with_group_task BOOLEAN    -- Sync with group task dates

-- Legacy/Reference
template_item_id UUID           -- NULLABLE - legacy reference, will be removed
raw_payload JSONB              -- Full BeProduct payload for audit
```

**Removed Dependency** on template tables:
- `template_item_id` is now NULLABLE
- All milestone configuration is self-contained in the timeline row

### 2. tracking_plan_material_timeline (1 row)

Same structure as `tracking_plan_style_timeline` but for materials:

```sql
-- Identical milestone configuration columns
milestone_name TEXT
milestone_short_name TEXT
department TEXT                 -- Text type (not enum) for materials
milestone_page_name TEXT
duration_value INTEGER
duration_unit offset_unit_enum
dependency_uuid UUID
offset_days INTEGER
calendar_days INTEGER
status TEXT CHECK (...)
customer_visible BOOLEAN
supplier_visible BOOLEAN
shared_with JSONB
-- ... (same additional columns)
```

### 3. tracking_plan_dependencies (26 rows)

**Purpose**: Plan-level dependency chain (fetched from BeProduct)

```sql
id BIGSERIAL PRIMARY KEY
plan_id UUID REFERENCES tracking_plan(id)
row_number INTEGER              -- Sequential order (0=START, 99=END)
department TEXT
action_description TEXT         -- Milestone name
short_description TEXT          -- Short milestone name
share_with TEXT                 -- Sharing configuration
page TEXT                       -- Associated page
days INTEGER                    -- Offset days
depends_on TEXT                 -- Predecessor action_description (NULL for START)
duration INTEGER                -- Task duration
duration_unit TEXT              -- DAYS or BUSINESS_DAYS
relationship TEXT               -- start-to-start, end-to-start, start-to-end
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

**Comment**: "Stores dependency chain for tracking plan milestones. Fetched via Lindy.ai webhook from BeProduct UI."

### 4. tracking_plan_style_dependency (200 rows)

**Purpose**: Dependencies between style timeline milestones

```sql
successor_id UUID               -- The milestone that depends on predecessor
predecessor_id UUID             -- The milestone that must complete first
offset_relation offset_relation_enum  -- AFTER or BEFORE
offset_value INTEGER            -- Number of units to offset
offset_unit offset_unit_enum    -- DAYS or BUSINESS_DAYS

PRIMARY KEY (successor_id, predecessor_id)
```

**Comment**: "Dependency relationships between timeline milestones (predecessor/successor). Foreign key constraints removed for Phase 1. Dependencies will be implemented in Phase 2."

### 5. tracking_plan_material_dependency (0 rows)

Same structure as style dependencies but for materials:

```sql
successor_id UUID
predecessor_id UUID
offset_relation offset_relation_enum
offset_value INTEGER
offset_unit offset_unit_enum

PRIMARY KEY (successor_id, predecessor_id)
```

### 6. tracking_timeline_assignment (1 row)

**Simplified PK** - now uses BIGSERIAL id:

```sql
id BIGSERIAL PRIMARY KEY        -- New: simplified PK
timeline_id UUID                -- References either style or material timeline
assignee_id UUID                -- Can be NULL
source_user_id UUID             -- Who made the assignment
role_name TEXT
role_id UUID
assigned_at TIMESTAMPTZ
```

**Comment**: "Assigns users/roles to timeline milestones. Simplified PK (id) allows NULL assignee_id and easy updates. No timeline_type needed (inferred from timeline_id source)."

### 7. tracking_timeline_status_history (0 rows)

**Purpose**: Audit trail for status changes

```sql
id BIGSERIAL PRIMARY KEY
timeline_id UUID
timeline_type timeline_type_enum  -- MASTER, STYLE, MATERIAL
changed_at TIMESTAMPTZ
changed_by UUID                 -- User who made change
source TEXT DEFAULT 'import'    -- 'import', 'manual', 'webhook'
previous_status TEXT
new_status TEXT
submits_quantity INTEGER DEFAULT 0
```

---

## ENUMS Reference

### offset_unit_enum
```sql
'DAYS' | 'BUSINESS_DAYS'
```

### offset_relation_enum
```sql
'AFTER' | 'BEFORE'
```

### timeline_type_enum
```sql
'MASTER' | 'STYLE' | 'MATERIAL'
```

### page_type_enum
```sql
'BOM' | 'SAMPLE_REQUEST_MULTI' | 'SAMPLE_REQUEST' | 'FORM' | 'TECHPACK' | 'NONE'
```

### department_enum (for style timelines)
```sql
'PLAN' | 'CUSTOMER' | 'PD' | 'ACCOUNT_MANAGER' | 'ALLOCATION' | 'PRODUCTION' |
'PRE-PRODUCTION | CUSTOMER' | 'PRE-PRODUCTION | PD' | 'PRE-PRODUCTION | ACCOUNT MANAGER' |
'DEVELOPMENT | CUSTOMER' | 'DEVELOPMENT | PD' | 'DEVELOPMENT | ACCOUNT MANAGER'
```

### phase_enum
```sql
'DEVELOPMENT' | 'PRE-PRODUCTION' | 'PRODUCTION' | 'POST-PRODUCTION' | 'PLANNING'
```

### relationship_type_enum
```sql
'start-to-start' | 'end-to-start' | 'start-to-end' | 'end-to-end'
```

### node_type_enum (legacy - from templates)
```sql
'ANCHOR' | 'TASK'
```

---

## Code Changes Required

### 1. API Functions to Update

#### File: `/lib/tracking-api-client.ts`

##### ❌ Remove Template Functions:
```typescript
// DELETE these functions:
getTemplates()
getTemplateById(templateId)
getTemplateItems(templateId)
getPlanMilestones(planId, templateId)
updateTemplate(templateId, updates)
createTemplateItem(item)
updateTemplateItem(itemId, updates)
deleteTemplateItem(itemId)
```

##### ✅ Update Style Timeline Functions:

**BEFORE**:
```typescript
export async function getPlanStyleTimelines(planId: string): Promise<any[]> {
  const selectQuery = `
    *,
    template_item:tracking_timeline_template_item!fkey(
      id, name, short_name, phase, department, ...
    )
  `
  
  await supabase
    .schema("ops")
    .from("tracking_plan_style_timeline")
    .select(selectQuery)
    .in("plan_style_id", planStyleIds)
}
```

**AFTER**:
```typescript
export async function getPlanStyleTimelines(planId: string): Promise<any[]> {
  // Simpler - no joins needed, milestone config is embedded
  const { data: planStyles } = await supabase
    .schema("ops")
    .from("tracking_plan_style")
    .select("id")
    .eq("plan_id", planId)

  const planStyleIds = planStyles.map(ps => ps.id)

  const { data, error } = await supabase
    .schema("ops")
    .from("tracking_plan_style_timeline")
    .select("*")  // All milestone config is in the row
    .in("plan_style_id", planStyleIds)
    .order("row_number", { ascending: true })  // Use row_number for ordering

  if (error) throw error
  return data || []
}
```

**Equivalent SQL**:
```sql
-- Step 1: Get plan style IDs
SELECT id FROM ops.tracking_plan_style WHERE plan_id = $1;

-- Step 2: Get timelines (no joins!)
SELECT *
FROM ops.tracking_plan_style_timeline
WHERE plan_style_id = ANY($1::uuid[])
ORDER BY row_number ASC;
```

##### ✅ Add Dependency Functions:

```typescript
/**
 * Fetch plan dependencies (from BeProduct)
 */
export async function getPlanDependencies(planId: string): Promise<any[]> {
  const { data, error } = await supabase
    .schema("ops")
    .from("tracking_plan_dependencies")
    .select("*")
    .eq("plan_id", planId)
    .order("row_number", { ascending: true })

  if (error) throw error
  return data || []
}
```

**Equivalent SQL**:
```sql
SELECT *
FROM ops.tracking_plan_dependencies
WHERE plan_id = $1
ORDER BY row_number ASC;
```

```typescript
/**
 * Fetch style milestone dependencies
 */
export async function getStyleDependencies(planId: string): Promise<any[]> {
  // Get all timeline IDs for this plan first
  const { data: planStyles } = await supabase
    .schema("ops")
    .from("tracking_plan_style")
    .select("id")
    .eq("plan_id", planId)

  const { data: timelines } = await supabase
    .schema("ops")
    .from("tracking_plan_style_timeline")
    .select("id")
    .in("plan_style_id", planStyles.map(ps => ps.id))

  const timelineIds = timelines.map(t => t.id)

  const { data, error } = await supabase
    .schema("ops")
    .from("tracking_plan_style_dependency")
    .select("*")
    .in("successor_id", timelineIds)

  if (error) throw error
  return data || []
}
```

**Equivalent SQL**:
```sql
-- Get dependencies for all timelines in a plan
SELECT d.*
FROM ops.tracking_plan_style_dependency d
JOIN ops.tracking_plan_style_timeline t ON d.successor_id = t.id
JOIN ops.tracking_plan_style ps ON t.plan_style_id = ps.id
WHERE ps.plan_id = $1;
```

##### ✅ Add Status History Function:

```typescript
/**
 * Fetch timeline status history
 */
export async function getTimelineStatusHistory(
  timelineId: string
): Promise<any[]> {
  const { data, error } = await supabase
    .schema("ops")
    .from("tracking_timeline_status_history")
    .select("*")
    .eq("timeline_id", timelineId)
    .order("changed_at", { ascending: false })

  if (error) throw error
  return data || []
}
```

**Equivalent SQL**:
```sql
SELECT *
FROM ops.tracking_timeline_status_history
WHERE timeline_id = $1
ORDER BY changed_at DESC;
```

### 2. Type Definitions to Update

#### File: `/types/tracking.ts`

##### ❌ Remove Template Types:
```typescript
// DELETE these:
export interface TimelineTemplateView { ... }
export interface TimelineTemplateItemView { ... }
```

##### ✅ Add/Update Timeline Types:

```typescript
export interface StyleTimeline {
  id: string
  plan_style_id: string
  
  // Status & Dates
  status: 'Not Started' | 'In Progress' | 'Approved' | 'Approved with corrections' | 'Rejected' | 'Complete' | 'Waiting On' | 'NA'
  plan_date: string | null
  rev_date: string | null
  final_date: string | null
  due_date: string | null
  completed_date: string | null
  start_date_plan: string | null
  start_date_due: string | null
  late: boolean
  
  // Milestone Configuration (embedded)
  milestone_name: string | null
  milestone_short_name: string | null
  milestone_page_name: string | null
  department: string | null
  phase: 'DEVELOPMENT' | 'PRE-PRODUCTION' | 'PRODUCTION' | 'POST-PRODUCTION' | 'PLANNING' | null
  
  // Duration & Dependencies
  duration_value: number | null
  duration_unit: 'DAYS' | 'BUSINESS_DAYS' | null
  offset_days: number | null
  calendar_days: number | null
  calendar_name: string | null
  dependency_uuid: string | null
  depends_on: string | null
  relationship: 'start-to-start' | 'end-to-start' | 'start-to-end' | 'end-to-end' | null
  row_number: number | null
  
  // Page Association
  page_id: string | null
  page_type: 'BOM' | 'SAMPLE_REQUEST_MULTI' | 'SAMPLE_REQUEST' | 'FORM' | 'TECHPACK' | 'NONE' | null
  page_name: string | null
  
  // Visibility
  customer_visible: boolean | null
  supplier_visible: boolean | null
  shared_with: string[] | null  // JSONB array of company IDs
  
  // Request Tracking
  request_id: string | null
  request_code: string | null
  request_status: string | null
  
  // Additional Config
  group_task: string | null
  when_rule: string | null
  share_when_rule: string | null
  activity_description: string | null
  revised_days: number | null
  default_status: string | null
  auto_share_linked_page: boolean | null
  sync_with_group_task: boolean | null
  external_share_with: any | null  // JSONB
  submits_quantity: number
  
  // Audit
  dept_customer: string | null  // Original BeProduct value
  raw_payload: any | null  // JSONB
  
  // Legacy (will be removed)
  template_item_id: string | null
  
  // Metadata
  timeline_type: 'MASTER' | 'STYLE' | 'MATERIAL'
  notes: string | null
  created_at: string
  updated_at: string
}

export interface PlanDependency {
  id: number
  plan_id: string
  row_number: number  // 0 = START DATE, 99 = END DATE
  department: string | null
  action_description: string  // Milestone name
  short_description: string | null
  share_with: string | null
  page: string | null
  days: number | null
  depends_on: string | null  // Predecessor action_description
  duration: number | null
  duration_unit: string | null
  relationship: string | null  // start-to-start, end-to-start, etc.
  created_at: string
  updated_at: string
}

export interface TimelineDependency {
  successor_id: string  // Milestone that depends on predecessor
  predecessor_id: string  // Milestone that must complete first
  offset_relation: 'AFTER' | 'BEFORE'
  offset_value: number
  offset_unit: 'DAYS' | 'BUSINESS_DAYS'
}

export interface TimelineStatusHistory {
  id: number
  timeline_id: string
  timeline_type: 'MASTER' | 'STYLE' | 'MATERIAL'
  changed_at: string
  changed_by: string | null
  source: string  // 'import', 'manual', 'webhook'
  previous_status: string | null
  new_status: string | null
  submits_quantity: number
}

export interface TimelineAssignment {
  id: number  // New: BIGSERIAL PK
  timeline_id: string
  assignee_id: string | null  // Can be NULL
  source_user_id: string | null
  role_name: string | null
  role_id: string | null
  assigned_at: string
}
```

### 3. UI Component Updates

#### File: `/app/tracking/[folderId]/[planId]/page.tsx`

##### Before (Template-based):
```typescript
// OLD: Fetch template items separately
const milestonesData = await getTemplateItems(planData.template_id)
setMilestones(milestonesData)

// OLD: Map template items to display
{milestones.map((milestone) => (
  <th key={milestone.item_id}>
    <div className="text-xs">{milestone.phase}</div>
    <div className="text-sm">{milestone.short_name || milestone.item_name}</div>
    <div className="text-xs">{milestone.department}</div>
  </th>
))}
```

##### After (Direct from timelines):
```typescript
// NEW: Milestones come from timeline rows themselves
const timelinesData = await getPlanStyleTimelines(planId)
setTimelines(timelinesData)

// NEW: Extract unique milestones from timeline rows
const uniqueMilestones = useMemo(() => {
  const seen = new Map()
  timelines.forEach(timeline => {
    const key = timeline.milestone_name || timeline.row_number
    if (!seen.has(key)) {
      seen.set(key, {
        id: timeline.id,  // Use first occurrence ID
        name: timeline.milestone_name,
        short_name: timeline.milestone_short_name,
        phase: timeline.phase,
        department: timeline.department,
        row_number: timeline.row_number,
        page_name: timeline.milestone_page_name
      })
    }
  })
  return Array.from(seen.values()).sort((a, b) => 
    (a.row_number || 0) - (b.row_number || 0)
  )
}, [timelines])

// NEW: Map unique milestones to display
{uniqueMilestones.map((milestone) => (
  <th key={milestone.id}>
    <div className="text-xs">{milestone.phase}</div>
    <div className="text-sm">{milestone.short_name || milestone.name}</div>
    <div className="text-xs">{milestone.department}</div>
  </th>
))}
```

##### Finding Timeline for Style x Milestone:
```typescript
// OLD: Match by template_item_id
const timeline = styleTimelines.find(t => 
  t.template_item_id === milestone.item_id
)

// NEW: Match by milestone_name or row_number
const timeline = timelines.find(t => 
  t.plan_style_id === style.id && 
  (t.milestone_name === milestone.name || t.row_number === milestone.row_number)
)
```

---

## Migration Checklist for Frontend Developers

### Phase 1: Read-Only Migration (No Breaking Changes)

- [ ] **1. Update Type Definitions**
  - [ ] Add new `StyleTimeline` interface with embedded milestone config
  - [ ] Add `PlanDependency` interface
  - [ ] Add `TimelineDependency` interface
  - [ ] Add `TimelineStatusHistory` interface
  - [ ] Update `TimelineAssignment` with new `id` field
  - [ ] Mark template types as `@deprecated`

- [ ] **2. Update API Functions (Backward Compatible)**
  - [ ] Add `getPlanDependencies(planId)` function
  - [ ] Add `getStyleDependencies(planId)` function
  - [ ] Add `getTimelineStatusHistory(timelineId)` function
  - [ ] Update `getPlanStyleTimelines()` to remove template joins
  - [ ] Update `getPlanStyleMilestones()` to read embedded config
  - [ ] Keep template functions but mark as `@deprecated`

- [ ] **3. Update Timeline Grid Components**
  - [ ] Extract unique milestones from timeline rows (not template)
  - [ ] Use `row_number` for milestone ordering
  - [ ] Use `milestone_name` / `milestone_short_name` for display
  - [ ] Use `phase` enum for phase grouping
  - [ ] Use `department` enum for department display
  - [ ] Update timeline matching logic (milestone_name vs template_item_id)

- [ ] **4. Add Dependency Visualization**
  - [ ] Fetch and display `tracking_plan_dependencies`
  - [ ] Show dependency chains using `depends_on` field
  - [ ] Visualize `relationship` type (start-to-start, end-to-start, etc.)
  - [ ] Display `offset_value` and `offset_unit` on edges

- [ ] **5. Add Status History**
  - [ ] Fetch status history for timeline detail views
  - [ ] Display timeline of status changes with timestamps
  - [ ] Show who made changes (`changed_by`)
  - [ ] Differentiate between import/manual/webhook sources

### Phase 2: Remove Template Dependencies

- [ ] **6. Remove Template UI**
  - [ ] Remove template management pages (`/tracking/templates/*`)
  - [ ] Remove template selection from plan creation
  - [ ] Remove template editing interfaces

- [ ] **7. Remove Template API Calls**
  - [ ] Delete `getTemplates()` function
  - [ ] Delete `getTemplateById()` function
  - [ ] Delete `getTemplateItems()` function
  - [ ] Delete `getPlanMilestones()` function
  - [ ] Delete template CRUD functions (create/update/delete)
  - [ ] Remove template type definitions

- [ ] **8. Database Cleanup**
  - [ ] Set `template_item_id` to NULL in all timeline rows
  - [ ] Drop `template_item_id` column from timeline tables
  - [ ] Archive `tracking_timeline_template` table data
  - [ ] Archive `tracking_timeline_template_item` table data
  - [ ] Drop template tables

### Phase 3: Enhanced Features

- [ ] **9. Dependency Management UI**
  - [ ] UI to view/edit dependencies between milestones
  - [ ] Drag-and-drop dependency editor
  - [ ] Validation for circular dependencies
  - [ ] Bulk dependency operations

- [ ] **10. Advanced Timeline Features**
  - [ ] Group task synchronization UI
  - [ ] Visibility controls (customer/supplier toggles)
  - [ ] Sharing rules configuration
  - [ ] Auto-share linked pages feature

---

## Database Migration Scripts

### Step 1: Verify Data Migration
```sql
-- Check if template_item_id is still in use
SELECT 
  COUNT(*) as total_rows,
  COUNT(template_item_id) as rows_with_template_ref,
  COUNT(milestone_name) as rows_with_milestone_name
FROM ops.tracking_plan_style_timeline;

-- Should show most/all rows have milestone_name populated
```

### Step 2: Nullify Template References (When Ready)
```sql
-- Set template_item_id to NULL (Phase 2)
UPDATE ops.tracking_plan_style_timeline
SET template_item_id = NULL
WHERE template_item_id IS NOT NULL;

UPDATE ops.tracking_plan_material_timeline
SET template_item_id = NULL
WHERE template_item_id IS NOT NULL;
```

### Step 3: Drop Template Columns (Phase 2 Complete)
```sql
-- Remove template_item_id column
ALTER TABLE ops.tracking_plan_style_timeline
DROP COLUMN IF EXISTS template_item_id;

ALTER TABLE ops.tracking_plan_material_timeline
DROP COLUMN IF EXISTS template_item_id;

-- Remove template_id from plans
ALTER TABLE ops.tracking_plan
DROP COLUMN IF EXISTS template_id;
```

### Step 4: Archive Template Tables
```sql
-- Create archive schema if needed
CREATE SCHEMA IF NOT EXISTS archive;

-- Move template tables to archive
ALTER TABLE ops.tracking_timeline_template
SET SCHEMA archive;

ALTER TABLE ops.tracking_timeline_template_item
SET SCHEMA archive;

-- Or drop completely if not needed
-- DROP TABLE ops.tracking_timeline_template_item CASCADE;
-- DROP TABLE ops.tracking_timeline_template CASCADE;
```

---

## Key Benefits of New Schema

### ✅ Advantages

1. **Simpler Queries**: No joins needed to get milestone config
2. **Flexibility**: Each timeline can have unique milestone config
3. **BeProduct Sync**: Direct mapping from BeProduct webhook data
4. **Performance**: Fewer joins = faster queries
5. **No Template Maintenance**: Templates eliminated as abstraction layer
6. **Audit Trail**: `raw_payload` stores original BeProduct data
7. **Version Control**: Status history tracks all changes

### ⚠️ Considerations

1. **Data Duplication**: Milestone config repeated per style (trade-off for simplicity)
2. **Update Complexity**: Changing milestone config requires updating multiple rows
3. **Consistency**: Need to ensure milestone names are consistent across styles in same plan

---

## Testing Checklist

- [ ] Verify timeline data loads without template joins
- [ ] Confirm milestone ordering works with `row_number`
- [ ] Test dependency resolution with new schema
- [ ] Validate status updates work with BeProduct sync
- [ ] Ensure assignments work with simplified PK
- [ ] Test visibility controls (customer/supplier flags)
- [ ] Verify shared_with JSONB arrays populate correctly
- [ ] Confirm status history recording works
- [ ] Test plan dependencies display correctly
- [ ] Validate phase and department enums render properly

---

## Rollback Plan

If issues arise during migration:

1. **Keep template tables** in archive schema temporarily
2. **Restore template_item_id** column if needed:
   ```sql
   ALTER TABLE ops.tracking_plan_style_timeline
   ADD COLUMN template_item_id UUID;
   ```
3. **Re-enable template joins** in API functions
4. **Revert UI** to template-based display

---

## Support & Questions

For migration support:
- Review actual schema: Use Supabase MCP tools to inspect `ops.tracking_*` tables
- Reference original docs: See `TRACKING_SUPABASE_DOCUMENTATION.md` for old schema
- Compare schemas: This doc shows differences between old and new

---

**Generated**: 2025-01-08  
**Version**: 1.0.0  
**Status**: Draft - Pending Review
