# Tracking & Timeline Quick Reference Guide

## Quick Navigation
- [Database Tables](#database-tables)
- [Common Queries](#common-queries)
- [API Endpoints](#api-endpoints)
- [Data Flow](#data-flow)

---

## Database Tables

### Core Tables (ops schema)

| Table | Purpose | Key Fields | Relationships |
|-------|---------|------------|---------------|
| **tracking_folder** | Brand organization | id, name, brand | → tracking_plan |
| **tracking_plan** | Plans within folders | id, folder_id, template_id, start_date, end_date | → tracking_plan_style, tracking_plan_material |
| **tracking_timeline_template** | Reusable templates | id, name, brand, season, version | ← tracking_plan, → tracking_timeline_template_item |
| **tracking_timeline_template_item** | Milestones/tasks | id, template_id, name, phase, depends_on_template_item_id | → tracking_plan_style_timeline |
| **tracking_plan_style** | Styles in plan | id, plan_id, style_number, style_name, supplier_name | → tracking_plan_style_timeline |
| **tracking_plan_style_timeline** | Milestone progress | id, plan_style_id, template_item_id, status, due_date, late | → tracking_timeline_assignment |
| **tracking_timeline_assignment** | User assignments | id, timeline_id, assignee_id | - |
| **tracking_plan_material** | Materials in plan | id, plan_id, material_name | - |

### Aggregate Views (ops schema)

| View | Purpose | Source Tables |
|------|---------|---------------|
| **tracking_folder_summary** | Folder + plan counts | tracking_folder, tracking_plan |
| **tracking_plan_summary** | Plan + style/material counts | tracking_plan, tracking_folder, tracking_timeline_template, tracking_plan_style, tracking_plan_material |
| **tracking_timeline_template_detail** | Template + item counts | tracking_timeline_template, tracking_timeline_template_item |

---

## Common Queries

### 1. Get All Folders with Statistics
```sql
SELECT * FROM ops.tracking_folder_summary ORDER BY name;
```
**Returns**: Folders with active_plan_count and total_plan_count

### 2. Get Plans in a Folder
```sql
SELECT * FROM ops.tracking_plan_summary 
WHERE folder_id = $1 
ORDER BY name;
```
**Returns**: Plans with style_count, material_count, template_name

### 3. Get Plan by ID
```sql
SELECT * FROM ops.tracking_plan_summary WHERE id = $1;
```

### 4. Get All Templates
```sql
SELECT * FROM ops.tracking_timeline_template_detail ORDER BY name;
```
**Returns**: Templates with total_items, style_items, material_items, anchor_count

### 5. Get Template Milestones
```sql
SELECT * FROM ops.tracking_timeline_template_item 
WHERE template_id = $1 
ORDER BY display_order;
```

### 6. Get Styles for a Plan
```sql
SELECT * FROM ops.tracking_plan_style 
WHERE plan_id = $1 AND active = true 
ORDER BY style_number;
```

### 7. Get Style Timelines with Template Info
```sql
SELECT 
  t.*,
  ti.name as milestone_name,
  ti.phase,
  ti.department,
  ti.display_order
FROM ops.tracking_plan_style_timeline t
JOIN ops.tracking_timeline_template_item ti ON t.template_item_id = ti.id
WHERE t.plan_style_id = $1
ORDER BY ti.display_order;
```

### 8. Get All Timelines for Plan Styles
```sql
-- Step 1: Get plan style IDs
SELECT id FROM ops.tracking_plan_style WHERE plan_id = $1;

-- Step 2: Get timelines
SELECT 
  t.*,
  ps.style_number,
  ps.style_name,
  ti.name as milestone_name,
  ti.phase
FROM ops.tracking_plan_style_timeline t
JOIN ops.tracking_plan_style ps ON t.plan_style_id = ps.id
JOIN ops.tracking_timeline_template_item ti ON t.template_item_id = ti.id
WHERE t.plan_style_id = ANY($1::uuid[])
ORDER BY ps.style_number, ti.display_order;
```

### 9. Get Assignees for Timelines
```sql
SELECT * FROM ops.tracking_timeline_assignment 
WHERE timeline_id = ANY($1::uuid[]);
```

### 10. Get Late Milestones by Phase
```sql
SELECT 
  ti.phase,
  ti.name,
  COUNT(*) as total,
  COUNT(CASE WHEN pst.late = true THEN 1 END) as late_count
FROM ops.tracking_plan_style_timeline pst
JOIN ops.tracking_timeline_template_item ti ON pst.template_item_id = ti.id
JOIN ops.tracking_plan_style ps ON pst.plan_style_id = ps.id
WHERE ps.plan_id = $1 AND ps.active = true
GROUP BY ti.phase, ti.name, ti.display_order
ORDER BY ti.phase, ti.display_order;
```

---

## API Endpoints

### Read Operations (GET)

| Endpoint | Function | Parameters | Returns |
|----------|----------|------------|---------|
| Folders List | `getFolders()` | - | `FolderView[]` |
| Folder by ID | `getFolderById(folderId)` | folderId: uuid | `FolderView` |
| Folder Plans | `getFolderPlans(folderId)` | folderId: uuid | `FolderPlanView[]` |
| Plan by ID | `getPlanById(planId)` | planId: uuid | `FolderPlanView` |
| Templates List | `getTemplates()` | - | `TimelineTemplateView[]` |
| Template by ID | `getTemplateById(templateId)` | templateId: uuid | `TimelineTemplateView` |
| Template Items | `getTemplateItems(templateId)` | templateId: uuid | `TimelineTemplateItemView[]` |
| Plan Milestones | `getPlanMilestones(planId, templateId)` | planId, templateId: uuid | `TimelineTemplateItemView[]` |
| Plan Styles | `getPlanStyles(planId)` | planId: uuid | `PlanStyle[]` |
| Style Timelines | `getPlanStyleTimelines(planId)` | planId: uuid | `Timeline[]` with joins |
| Timeline Assignments | `getTimelineAssignments(timelineIds)` | timelineIds: uuid[] | `Record<uuid, Assignment[]>` |

### Write Operations (POST/PUT/DELETE)

| Endpoint | Function | Parameters | Action |
|----------|----------|------------|--------|
| Create Template Item | `createTemplateItem(item)` | item: TemplateItemData | INSERT → returns id |
| Update Template | `updateTemplate(id, updates)` | id: uuid, updates: object | UPDATE template |
| Update Template Item | `updateTemplateItem(id, updates)` | id: uuid, updates: object | UPDATE template item |
| Delete Template Item | `deleteTemplateItem(id)` | id: uuid | DELETE template item |
| Update Plan | `updatePlan(id, updates)` | id: uuid, updates: object | UPDATE plan |
| Update Style Milestone | `updateStyleMilestone(styleId, name, updates)` | styleId: uuid, name: string, updates: object | UPDATE JSONB field |
| Update Style Milestones | `updateStyleMilestones(styleId, milestones)` | styleId: uuid, milestones: array | REPLACE JSONB array |

### Server Actions

| Action | Function | Parameters | Schema | Returns |
|--------|----------|------------|--------|---------|
| Get Folders | `getFoldersAction()` | - | tracking | brand_folders |
| Get Folder Plans | `getFolderPlansAction(folderId)` | folderId: uuid | tracking | tracking_plans |
| Create Folder | `createFolderAction(name, desc?)` | name, description | tracking | brand_folders |

---

## Data Flow

### 1. Folder → Plan → Style → Timeline Flow

```
User Request
    ↓
getFolders()
    ↓
tracking_folder_summary VIEW
    ├─ tracking_folder TABLE
    └─ tracking_plan TABLE (COUNT)
    ↓
Display Folders with Plan Counts
    ↓
User Selects Folder
    ↓
getFolderPlans(folderId)
    ↓
tracking_plan_summary VIEW
    ├─ tracking_plan TABLE
    ├─ tracking_folder TABLE (JOIN)
    ├─ tracking_timeline_template TABLE (JOIN)
    ├─ tracking_plan_style TABLE (COUNT)
    └─ tracking_plan_material TABLE (COUNT)
    ↓
Display Plans
    ↓
User Selects Plan
    ↓
getPlanById(planId) + getPlanStyles(planId) + getPlanStyleTimelines(planId)
    ↓
tracking_plan_summary VIEW + tracking_plan_style TABLE + Complex Joins
    ↓
Display Plan with Styles and Timeline Grid
```

### 2. Template Application Flow

```
Template Created
    ↓
tracking_timeline_template TABLE
    ├─ id, name, brand, season
    └─ contains →
        ↓
tracking_timeline_template_item TABLE
    ├─ Multiple milestones
    ├─ Dependencies (depends_on_template_item_id)
    └─ Offset calculations (offset_value, offset_unit, offset_relation)
    ↓
Template Assigned to Plan
    ↓
tracking_plan.template_id = template.id
    ↓
Styles Added to Plan
    ↓
tracking_plan_style TABLE
    ↓
Timeline Milestones Generated for Each Style
    ↓
tracking_plan_style_timeline TABLE
    ├─ One row per (style × template_item)
    ├─ template_item_id → tracking_timeline_template_item
    ├─ Calculated dates (plan_date, due_date)
    └─ Status tracking
```

### 3. Milestone Status Update Flow

```
User Updates Milestone Status
    ↓
updateStyleMilestone(styleId, milestoneName, { status, ... })
    ↓
Fetch Current status_summary JSONB
    ↓
tracking_plan_style.status_summary
    ↓
Modify in Application
    ↓
Update status_summary JSONB
    ↓
tracking_plan_style TABLE UPDATE
```

### 4. Assignment Flow

```
User Assigns Team Member to Milestone
    ↓
INSERT INTO tracking_timeline_assignment
    ↓
tracking_timeline_assignment TABLE
    ├─ timeline_id → tracking_plan_style_timeline
    ├─ assignee_id (user identifier)
    └─ Multiple assignments per timeline
    ↓
getTimelineAssignments(timelineIds)
    ↓
Display Assignees in Timeline Grid
```

---

## Field Reference

### Timeline Status Values
- `NOT_STARTED` - Not yet begun
- `IN_PROGRESS` - Work in progress
- `APPROVED` - Approved/accepted
- `APPROVED_WITH_CORRECTIONS` - Approved with minor changes needed
- `REJECTED` - Rejected/needs rework
- `COMPLETE` - Finished
- `BLOCKED` - Cannot proceed
- `WAITING_ON` - Waiting for input/approval

### Node Types
- `ANCHOR` - Starting point or key date
- `TASK` - Work to be completed
- `MILESTONE` - Checkpoint or deliverable
- `PHASE` - Group of related milestones

### Timeline Types
- `MASTER` - Master timeline template
- `STYLE` - Style-specific timeline
- `MATERIAL` - Material-specific timeline

### Offset Relations
- `AFTER` - Occurs after dependency
- `BEFORE` - Occurs before dependency

### Offset Units
- `DAYS` - Calendar days
- `BUSINESS_DAYS` - Working days only
- `WEEKS` - Calendar weeks

### Page Types
- `BOM` - Bill of Materials
- `SAMPLE_REQUEST` - Single sample request
- `SAMPLE_REQUEST_MULTI` - Multiple sample request
- `FORM` - Generic form
- `TECHPACK` - Technical package
- `NONE` - No associated page

---

## Schema Comparison

### Tracking Schema (Legacy)
- `brand_folders` - Folder storage
- `tracking_plans` - Plan storage
- Used by: Server Actions in `/app/(portal)/tracking/actions.ts`

### Ops Schema (Current)
- `tracking_folder` - Folder storage
- `tracking_plan` - Plan storage
- `tracking_timeline_template` - Template storage
- `tracking_timeline_template_item` - Milestone storage
- `tracking_plan_style` - Style-plan linking
- `tracking_plan_style_timeline` - Timeline progress
- `tracking_timeline_assignment` - User assignments
- `tracking_plan_material` - Material-plan linking
- All summary views
- Used by: Client API and most server-side API

---

## Performance Tips

### Indexing Recommendations
```sql
-- Foreign key indexes (if not auto-created)
CREATE INDEX idx_tracking_plan_folder_id ON ops.tracking_plan(folder_id);
CREATE INDEX idx_tracking_plan_template_id ON ops.tracking_plan(template_id);
CREATE INDEX idx_tracking_plan_style_plan_id ON ops.tracking_plan_style(plan_id);
CREATE INDEX idx_tracking_plan_style_timeline_plan_style_id 
  ON ops.tracking_plan_style_timeline(plan_style_id);
CREATE INDEX idx_tracking_plan_style_timeline_template_item_id 
  ON ops.tracking_plan_style_timeline(template_item_id);
CREATE INDEX idx_tracking_timeline_assignment_timeline_id 
  ON ops.tracking_timeline_assignment(timeline_id);

-- Status and filter indexes
CREATE INDEX idx_tracking_plan_active ON ops.tracking_plan(active);
CREATE INDEX idx_tracking_plan_style_active ON ops.tracking_plan_style(active);
CREATE INDEX idx_tracking_plan_style_timeline_late 
  ON ops.tracking_plan_style_timeline(late) WHERE late = true;
CREATE INDEX idx_tracking_plan_style_timeline_status 
  ON ops.tracking_plan_style_timeline(status);

-- JSONB indexes (if querying nested data)
CREATE INDEX idx_tracking_plan_style_status_summary_gin 
  ON ops.tracking_plan_style USING GIN(status_summary);
```

### Query Optimization
1. **Use Views**: Pre-aggregated views are faster than complex joins
2. **Batch Fetches**: Use `IN` clause to fetch multiple related records
3. **Limit Results**: Always use pagination for large datasets
4. **Index Coverage**: Ensure filtered and joined columns are indexed
5. **Avoid N+1**: Fetch related data in bulk, not per-item

### JSONB Best Practices
```sql
-- Instead of fetch-modify-update pattern:
-- 1. Fetch
SELECT status_summary FROM tracking_plan_style WHERE id = $1;
-- 2. Modify in app
-- 3. Update
UPDATE tracking_plan_style SET status_summary = $2 WHERE id = $1;

-- Use direct JSONB operators:
UPDATE tracking_plan_style
SET status_summary = jsonb_set(
  status_summary,
  '{milestones}',
  (SELECT jsonb_agg(...))
)
WHERE id = $1;
```

---

## Common Patterns

### Pattern 1: Get Plan with Full Details
```typescript
const [plan, styles, timelines] = await Promise.all([
  getPlanById(planId),
  getPlanStyles(planId),
  getPlanStyleTimelinesEnriched(planId)
]);
```

### Pattern 2: Get Template Items with Dependencies
```typescript
const items = await getTemplateItems(templateId);
// Items already include depends_on_template_item_id
const itemMap = new Map(items.map(i => [i.item_id, i]));
const dependencies = items.map(item => ({
  ...item,
  dependsOn: item.depends_on_template_item_id 
    ? itemMap.get(item.depends_on_template_item_id) 
    : null
}));
```

### Pattern 3: Group Timelines by Style
```typescript
const styleTimelinesMap = timelines.reduce((map, timeline) => {
  if (!map[timeline.plan_style_id]) map[timeline.plan_style_id] = [];
  map[timeline.plan_style_id].push(timeline);
  return map;
}, {} as Record<string, any[]>);
```

### Pattern 4: Calculate Completion Percentage
```typescript
const totalMilestones = milestones.length;
const completedMilestones = milestones.filter(
  m => m.status === 'COMPLETE' || m.status === 'COMPLETED'
).length;
const percentage = Math.round((completedMilestones / totalMilestones) * 100);
```

---

## Troubleshooting

### Issue: No data returned
**Check**:
1. Schema prefix (`ops` vs `tracking`)
2. Active flag (`active = true`)
3. Foreign key relationships
4. View vs table usage

### Issue: JSONB update not working
**Check**:
1. JSONB structure matches expected format
2. Proper array handling for milestones
3. Timestamp updates included

### Issue: Slow queries
**Check**:
1. Missing indexes on foreign keys
2. Using base tables instead of views
3. N+1 query patterns
4. Large result sets without pagination

---

## Generated On
2025-01-08

## Version
1.0.0
