# Frontend Gantt Chart Implementation Guide

## Overview

This guide provides comprehensive instructions for implementing the new timeline/Gantt chart features with start dates, duration, and cascade behavior. All database migrations are complete and the system is ready for frontend integration.

## Database Schema Changes Summary

### New Columns Added

Both `tracking.tracking_plan_style_timeline` and `tracking.tracking_plan_material_timeline` tables now include:

| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `start_date_plan` | `date` | null | Planned start date for the task |
| `start_date_due` | `date` | null | Committed/due start date for the task |
| `duration_value` | `integer` | null | Task duration (numeric value) |
| `duration_unit` | `offset_unit_enum` | 'DAYS' | Unit for duration (DAYS or BUSINESS_DAYS) |

### Existing Date Columns Reference

| Column | Purpose |
|--------|---------|
| `plan_date` | Planned end date (original milestone date) |
| `due_date` | Committed/due end date |
| `rev_date` | Revised target date (if needed) |
| `final_date` | Actual completion date |
| `completed_date` | Timestamp when marked complete |
| `late` | Boolean flag: true if task is running late |

---

## TypeScript Types

```typescript
// Enums
export type OffsetUnit = 'DAYS' | 'BUSINESS_DAYS';
export type OffsetRelation = 'AFTER' | 'BEFORE';
export type TimelineStatus = 
  | 'NOT_STARTED' 
  | 'IN_PROGRESS' 
  | 'APPROVED' 
  | 'REJECTED' 
  | 'COMPLETE' 
  | 'BLOCKED';

// Timeline Row Type (from generated types - tracking schema)
export interface StyleTimeline {
  id: string;
  plan_id: string;
  template_entry_id: string;
  milestone_name: string;
  
  // End dates (existing)
  plan_date: string | null;           // Planned end date
  due_date: string | null;            // Committed end date
  rev_date: string | null;            // Revised end date
  final_date: string | null;          // Actual completion date
  completed_date: string | null;      // Completion timestamp
  
  // NEW: Start dates
  start_date_plan: string | null;     // Planned start date
  start_date_due: string | null;      // Committed start date
  
  // NEW: Duration
  duration_value: number | null;      // Task duration (e.g., 7)
  duration_unit: OffsetUnit;          // 'DAYS' or 'BUSINESS_DAYS'
  
  // Status and flags
  status: TimelineStatus;
  late: boolean;                      // Auto-calculated: true if due_date > plan_date
  
  // Metadata
  notes: string | null;
  created_at: string;
  updated_at: string;
}

// Dependency Type
export interface StyleDependency {
  id: string;
  plan_id: string;
  predecessor_id: string;             // Timeline entry that must complete first
  successor_id: string;               // Timeline entry that depends on predecessor
  offset_value: number;               // Offset after predecessor (e.g., 2)
  offset_unit: OffsetUnit;            // 'DAYS' or 'BUSINESS_DAYS'
  offset_relation: OffsetRelation;    // 'AFTER' or 'BEFORE'
}
```

---

## UI Components to Update

### 1. Timeline Template Editor

**Location**: Admin/Settings area where users define timeline templates

**Changes Needed**:

```typescript
// Add duration fields to milestone configuration form
interface MilestoneFormData {
  milestone_name: string;
  duration_value: number;           // NEW: Default duration for this milestone
  duration_unit: OffsetUnit;        // NEW: Default unit (DAYS/BUSINESS_DAYS)
  
  // Dependencies (existing)
  depends_on: string | null;        // Predecessor milestone ID
  offset_value: number;
  offset_unit: OffsetUnit;
  offset_relation: OffsetRelation;
}

// Example form fields to add:
<FormGroup>
  <Label>Task Duration</Label>
  <Input 
    type="number" 
    min="1"
    value={formData.duration_value || 7} 
    onChange={(e) => setFormData({
      ...formData, 
      duration_value: parseInt(e.target.value)
    })}
  />
  <Select 
    value={formData.duration_unit || 'DAYS'}
    onChange={(e) => setFormData({
      ...formData,
      duration_unit: e.target.value as OffsetUnit
    })}
  >
    <option value="DAYS">Calendar Days</option>
    <option value="BUSINESS_DAYS">Business Days</option>
  </Select>
</FormGroup>
```

**User Story**: 
> "As a merchandiser, when I create a timeline template, I want to specify how long each milestone task should take (e.g., 'Tech Pack Review' takes 5 business days), so that my Gantt chart shows realistic task bars instead of just milestone dots."

---

### 2. Plan Editor (Individual Timeline Instance)

**Location**: Where users edit a specific tracking plan's timeline

**Changes Needed**:

```typescript
// Allow users to override duration for this specific plan
interface TimelineEditForm {
  milestone_name: string;           // Read-only (from template)
  
  // NEW: Editable duration override
  duration_value: number | null;
  duration_unit: OffsetUnit;
  
  // Dates (existing, now with start dates)
  start_date_plan: string | null;   // Auto-calculated, but can be manually set
  plan_date: string | null;         // End date (existing)
  start_date_due: string | null;    // Auto-calculated from start_date_plan + duration
  due_date: string | null;          // Committed end date (existing)
  
  status: TimelineStatus;
  notes: string;
}

// Example duration override UI:
<FormGroup>
  <Label>Override Task Duration (leave blank to use template default)</Label>
  <Input 
    type="number"
    placeholder={`Default: ${templateDuration} ${templateUnit}`}
    value={timeline.duration_value || ''}
    onChange={(e) => updateTimeline({
      ...timeline,
      duration_value: e.target.value ? parseInt(e.target.value) : null
    })}
  />
</FormGroup>
```

**User Story**:
> "As a merchandiser, when editing a plan, I want to adjust the duration of specific milestones (e.g., make 'Lab Dip Approval' 10 days instead of the template's 7 days) without affecting other plans or the template."

---

### 3. Gantt Chart Component

**Location**: Main timeline visualization

**Changes Needed**:

#### A. Render Task Bars (Not Just Milestones)

**Before**: Gantt showed only end date markers (diamonds/dots)
**After**: Gantt shows task bars spanning from start date to end date

```typescript
interface GanttTaskBar {
  id: string;
  name: string;
  startDate: Date;
  endDate: Date;
  status: TimelineStatus;
  late: boolean;
  dependencies: string[];  // Array of predecessor IDs
}

// Convert timeline data to Gantt tasks
function timelineToGanttTask(
  timeline: StyleTimeline, 
  mode: 'PLAN' | 'COMMITTED' | 'ACTUAL'
): GanttTaskBar {
  let startDate: Date | null = null;
  let endDate: Date | null = null;
  
  switch (mode) {
    case 'PLAN':
      // Show planned timeline
      startDate = timeline.start_date_plan ? new Date(timeline.start_date_plan) : null;
      endDate = timeline.plan_date ? new Date(timeline.plan_date) : null;
      break;
      
    case 'COMMITTED':
      // Show committed/due timeline
      startDate = timeline.start_date_due ? new Date(timeline.start_date_due) : null;
      endDate = timeline.due_date ? new Date(timeline.due_date) : null;
      break;
      
    case 'ACTUAL':
      // Show actual execution (final_date vs due)
      startDate = timeline.start_date_due ? new Date(timeline.start_date_due) : null;
      endDate = timeline.final_date ? new Date(timeline.final_date) : 
                timeline.due_date ? new Date(timeline.due_date) : null;
      break;
  }
  
  // Fallback: if no start date but we have duration, calculate it
  if (!startDate && endDate && timeline.duration_value) {
    const duration = timeline.duration_value;
    startDate = new Date(endDate);
    startDate.setDate(startDate.getDate() - duration);
  }
  
  return {
    id: timeline.id,
    name: timeline.milestone_name,
    startDate: startDate || new Date(), // Fallback to today if missing
    endDate: endDate || new Date(),
    status: timeline.status,
    late: timeline.late,
    dependencies: [] // Fetch from tracking_plan_style_dependency table
  };
}
```

#### B. View Modes Switcher

```typescript
type ViewMode = 'PLAN' | 'COMMITTED' | 'ACTUAL';

// UI Component
<SegmentedControl>
  <Button 
    active={viewMode === 'PLAN'}
    onClick={() => setViewMode('PLAN')}
  >
    Planned
  </Button>
  <Button 
    active={viewMode === 'COMMITTED'}
    onClick={() => setViewMode('COMMITTED')}
  >
    Committed
  </Button>
  <Button 
    active={viewMode === 'ACTUAL'}
    onClick={() => setViewMode('ACTUAL')}
  >
    Actual
  </Button>
</SegmentedControl>
```

**User Story**:
> "As a merchandiser, I want to toggle between 'Planned', 'Committed', and 'Actual' views on my Gantt chart, so I can compare our original plan vs committed dates vs what actually happened."

#### C. Visual Styling for Task Bars

```typescript
// Color coding based on status
const getTaskBarColor = (status: TimelineStatus, late: boolean): string => {
  if (late) return '#FF4444'; // Red for late tasks
  
  switch (status) {
    case 'NOT_STARTED': return '#CCCCCC';
    case 'IN_PROGRESS': return '#4A90E2';
    case 'APPROVED': return '#7ED321';
    case 'REJECTED': return '#D0021B';
    case 'COMPLETE': return '#50E3C2';
    case 'BLOCKED': return '#F5A623';
    default: return '#CCCCCC';
  }
};

// Example with react-gantt-chart library
<GanttChart
  tasks={tasks.map(task => ({
    ...task,
    styles: {
      backgroundColor: getTaskBarColor(task.status, task.late),
      border: task.late ? '2px solid #CC0000' : 'none'
    }
  }))}
/>
```

#### D. Dependency Lines

```typescript
// Fetch dependencies for a plan
async function loadDependencies(planId: string): Promise<StyleDependency[]> {
  const { data, error } = await supabase
    .from('tracking_plan_style_dependency')
    .select('*')
    .eq('plan_id', planId);
  
  if (error) throw error;
  return data;
}

// Render dependency arrows
<GanttChart
  tasks={tasks}
  dependencies={dependencies.map(dep => ({
    from: dep.predecessor_id,
    to: dep.successor_id,
    type: 'finish-to-start' // Predecessor must finish before successor starts
  }))}
/>
```

---

## API Integration

### Fetching Timeline Data

```typescript
// GET timeline with new fields
async function fetchPlanTimelines(planId: string): Promise<StyleTimeline[]> {
  const { data, error } = await supabase
    .from('tracking_plan_style_timeline')
    .select(`
      id,
      plan_id,
      template_entry_id,
      milestone_name,
      plan_date,
      due_date,
      rev_date,
      final_date,
      completed_date,
      start_date_plan,
      start_date_due,
      duration_value,
      duration_unit,
      status,
      late,
      notes,
      created_at,
      updated_at
    `)
    .eq('plan_id', planId)
    .order('start_date_plan', { ascending: true, nullsFirst: false });
  
  if (error) throw error;
  return data;
}
```

### Updating Timeline Entry

```typescript
// PUT/PATCH timeline - triggers will auto-calculate dates
async function updateTimelineEntry(
  timelineId: string, 
  updates: Partial<StyleTimeline>
): Promise<void> {
  const { error } = await supabase
    .from('tracking_plan_style_timeline')
    .update({
      duration_value: updates.duration_value,
      duration_unit: updates.duration_unit,
      start_date_plan: updates.start_date_plan,
      start_date_due: updates.start_date_due,
      due_date: updates.due_date,
      rev_date: updates.rev_date,
      final_date: updates.final_date,
      status: updates.status,
      notes: updates.notes
    })
    .eq('id', timelineId);
  
  if (error) throw error;
}
```

**Important**: When you update `duration_value`, `start_date_plan`, or `due_date`, the database triggers will automatically:
1. Calculate the opposite date (if start is set, calculate end; if end is set, calculate start)
2. Update the `late` flag
3. Cascade changes to all downstream tasks that depend on this milestone

### Creating New Timeline Entry

```typescript
// POST new timeline entry
async function createTimelineEntry(
  planId: string,
  templateEntryId: string,
  overrides?: Partial<StyleTimeline>
): Promise<StyleTimeline> {
  const { data, error } = await supabase
    .from('tracking_plan_style_timeline')
    .insert({
      plan_id: planId,
      template_entry_id: templateEntryId,
      milestone_name: overrides?.milestone_name || 'New Milestone',
      duration_value: overrides?.duration_value || 7,
      duration_unit: overrides?.duration_unit || 'DAYS',
      status: 'NOT_STARTED',
      ...overrides
    })
    .select()
    .single();
  
  if (error) throw error;
  return data;
}
```

---

## Trigger Logic Reference (For Frontend Understanding)

### Automatic Date Calculations

The database handles these calculations automatically via triggers:

#### 1. `calculate_timeline_dates()` - BEFORE INSERT/UPDATE

**Trigger Logic**:
```sql
-- If setting start_date_plan and duration, calculate plan_date (end)
IF NEW.start_date_plan IS NOT NULL AND NEW.duration_value IS NOT NULL THEN
  NEW.plan_date = NEW.start_date_plan + NEW.duration_value;
END IF;

-- If setting plan_date and duration, calculate start_date_plan
IF NEW.plan_date IS NOT NULL AND NEW.duration_value IS NOT NULL AND NEW.start_date_plan IS NULL THEN
  NEW.start_date_plan = NEW.plan_date - NEW.duration_value;
END IF;

-- Same logic for start_date_due <-> due_date

-- Calculate late flag
IF NEW.due_date IS NOT NULL AND NEW.plan_date IS NOT NULL THEN
  NEW.late = (NEW.due_date > NEW.plan_date);
END IF;

-- Handle predecessor dependencies (if configured)
-- Finds predecessor's end date and applies offset to calculate start_date_plan
```

**Frontend Impact**: 
- You can set EITHER start date OR end date (not both) along with duration
- The trigger will calculate the missing date
- If you set both start and end, the trigger respects your input (no override)

#### 2. `cascade_timeline_updates()` - AFTER UPDATE

**Trigger Logic**:
```sql
-- When a timeline entry's end date changes, update all successors
UPDATE tracking_plan_style_timeline
SET start_date_plan = [predecessor_end_date + offset],
    plan_date = [new_start + duration],
    updated_at = NOW()
WHERE id IN (
  SELECT successor_id 
  FROM tracking_plan_style_dependency 
  WHERE predecessor_id = [updated_timeline_id]
);
```

**Frontend Impact**:
- When user changes a milestone's date or duration, the UI should refetch timeline data to show cascaded updates
- Consider showing a loading spinner during cascade operations
- Optionally, show a notification: "Updated 3 downstream tasks"

#### 3. `recalculate_plan_timelines()` - AFTER UPDATE on `tracking_plan`

**Trigger Logic**:
```sql
-- When plan start_date or end_date changes, recalculate ALL timelines
UPDATE tracking_plan_style_timeline
SET [recalculated dates]
WHERE plan_id = [updated_plan_id];
```

**Frontend Impact**:
- When user changes the plan's overall start/end date, expect ALL timeline entries to update
- Show a full-page loading state or progress indicator
- After update completes, refetch entire timeline and re-render Gantt

---

## Data Migration Strategy

### Handling Existing Records

**Current State**: Existing timeline records have `null` for all new columns:
- `start_date_plan = null`
- `start_date_due = null`
- `duration_value = null`
- `duration_unit = 'DAYS'` (default)

**Migration Approach**:

```typescript
// Option 1: Auto-populate on first edit
// When user opens a plan for the first time, calculate missing data
async function migrateTimelineData(planId: string): Promise<void> {
  const timelines = await fetchPlanTimelines(planId);
  
  const updates = timelines
    .filter(t => !t.start_date_plan && !t.duration_value)
    .map(timeline => {
      // Set default duration
      const duration_value = 7; // Default to 7 days
      
      // Calculate start date from end date
      let start_date_plan = null;
      if (timeline.plan_date) {
        const endDate = new Date(timeline.plan_date);
        endDate.setDate(endDate.getDate() - duration_value);
        start_date_plan = endDate.toISOString().split('T')[0];
      }
      
      return {
        id: timeline.id,
        duration_value,
        duration_unit: 'DAYS' as OffsetUnit,
        start_date_plan
      };
    });
  
  // Batch update
  for (const update of updates) {
    await supabase
      .from('tracking_plan_style_timeline')
      .update({
        duration_value: update.duration_value,
        duration_unit: update.duration_unit,
        start_date_plan: update.start_date_plan
      })
      .eq('id', update.id);
  }
}

// Option 2: Show migration wizard
// Display a one-time setup dialog for existing plans
<MigrationWizard>
  <p>We've added task duration tracking to your timelines.</p>
  <p>Please set default durations for your milestones:</p>
  {templates.map(template => (
    <FormGroup key={template.id}>
      <Label>{template.milestone_name}</Label>
      <Input 
        type="number"
        defaultValue={7}
        onChange={(e) => setDuration(template.id, e.target.value)}
      />
    </FormGroup>
  ))}
  <Button onClick={applyMigration}>Apply to All Plans</Button>
</MigrationWizard>
```

---

## Testing Checklist

### Unit Tests

- [ ] Timeline data model correctly converts to Gantt tasks
- [ ] View mode switcher updates task dates correctly
- [ ] Duration calculation helper functions work (manual override logic)
- [ ] Late flag styling applies correctly

### Integration Tests

- [ ] **Create new timeline entry**: Verify start/end dates auto-calculate
- [ ] **Update duration**: Verify end date recalculates and successors cascade
- [ ] **Update predecessor date**: Verify successor dates update via cascade
- [ ] **Change plan start/end date**: Verify all timelines recalculate
- [ ] **Set rev_date or final_date**: Verify late flag updates

### User Acceptance Tests

- [ ] Merchandiser can set task duration in template editor
- [ ] Merchandiser can override duration for specific plan
- [ ] Gantt chart shows task bars (start to end) instead of just end dates
- [ ] View modes (Planned/Committed/Actual) switch correctly
- [ ] Dependency arrows render correctly
- [ ] Late tasks visually stand out (red bars/borders)
- [ ] Cascade updates complete within 2-3 seconds for plans with 50+ milestones

---

## Performance Considerations

### Optimization Tips

1. **Batch Fetch**: Load all timeline entries and dependencies in a single query
   ```typescript
   const { data } = await supabase
     .from('tracking_plan_style_timeline')
     .select(`
       *,
       predecessors:tracking_plan_style_dependency!successor_id(*)
     `)
     .eq('plan_id', planId);
   ```

2. **Debounce Updates**: When user drags a task bar, debounce the API call
   ```typescript
   const debouncedUpdate = useMemo(
     () => debounce(updateTimelineEntry, 500),
     []
   );
   ```

3. **Optimistic UI Updates**: Update local state immediately, then sync with server
   ```typescript
   // Optimistic update
   setTimelines(prev => prev.map(t => 
     t.id === updatedTimeline.id ? updatedTimeline : t
   ));
   
   // Server sync
   await updateTimelineEntry(updatedTimeline.id, updates);
   
   // Refresh to get cascaded changes
   const fresh = await fetchPlanTimelines(planId);
   setTimelines(fresh);
   ```

4. **Index Usage**: The migrations created indexes on `start_date_plan` and `start_date_due` for fast sorting

---

## Troubleshooting

### Issue: Start dates not calculating automatically

**Cause**: Missing `duration_value` or `plan_date`

**Solution**: Ensure both are set when creating/updating timeline entries

### Issue: Cascade updates not reflecting in UI

**Cause**: Frontend not refetching after update

**Solution**: After any timeline update, refetch the entire plan timeline:
```typescript
await updateTimelineEntry(id, updates);
await fetchPlanTimelines(planId); // Refresh to see cascade effects
```

### Issue: Late flag showing incorrect value

**Cause**: Trigger calculates late as `due_date > plan_date` (due is later than plan)

**Solution**: Verify your logic matches:
- `late = true` means the task is LATE (due date pushed out beyond plan)
- `late = false` means on schedule or early

### Issue: Business days calculation not working

**Cause**: The enum `BUSINESS_DAYS` is stored, but the trigger currently uses simple date arithmetic

**Solution**: If you need true business day logic (excluding weekends/holidays), you'll need to:
1. Create a PL/pgSQL function for business day math
2. Update the trigger to call that function when `duration_unit = 'BUSINESS_DAYS'`

---

## Example: Complete Feature Flow

### Scenario: Create a New Tracking Plan with Gantt

1. **User selects timeline template** (e.g., "Spring 2024 Production")
2. **Frontend creates plan record**:
   ```typescript
   const plan = await createPlan({
     name: 'Product Line A - Spring 2024',
     template_id: 'tmpl_12345',
     start_date: '2024-01-15',
     end_date: '2024-06-30'
   });
   ```

3. **Trigger creates timeline entries** from template (with `duration_value` defaults)

4. **Frontend fetches timeline data**:
   ```typescript
   const timelines = await fetchPlanTimelines(plan.id);
   const dependencies = await loadDependencies(plan.id);
   ```

5. **Frontend renders Gantt chart**:
   ```typescript
   const tasks = timelines.map(t => timelineToGanttTask(t, 'PLAN'));
   return <GanttChart tasks={tasks} dependencies={dependencies} />;
   ```

6. **User drags a task bar** to adjust dates:
   ```typescript
   onTaskChange={(task) => {
     updateTimelineEntry(task.id, {
       start_date_plan: task.startDate.toISOString().split('T')[0]
     });
     // Triggers will calculate plan_date and cascade to successors
   }}
   ```

7. **Frontend refetches to show cascade**:
   ```typescript
   const updated = await fetchPlanTimelines(plan.id);
   setTimelines(updated);
   ```

---

## Summary

### Key Points for Frontend Developers

1. **Four new columns** (`start_date_plan`, `start_date_due`, `duration_value`, `duration_unit`) enable proper Gantt task bars
2. **Triggers handle calculations** - you don't need to manually calculate opposite dates or cascade logic
3. **Three view modes** (Planned, Committed, Actual) map to different date field combinations
4. **Always refetch after updates** to see cascaded changes from database triggers
5. **Migration needed** for existing plans - use wizard or auto-populate on first edit

### Next Steps

1. Update template editor UI to include duration fields
2. Update plan editor UI to allow duration overrides
3. Enhance Gantt component to render task bars (not just milestones)
4. Add view mode switcher (Planned/Committed/Actual)
5. Implement dependency arrows visualization
6. Add late task visual indicators
7. Create data migration flow for existing records
8. Write integration tests for cascade behavior

---

## Resources

- **Database Migrations**: `supabase-tracking/migrations/`
  - `20240101000001_add_start_dates_and_duration_to_timelines.sql`
  - `20240101000002_update_timeline_calculation_triggers.sql`
  - `20240101000003_create_cascade_update_trigger.sql`
  - `20240101000004_create_plan_date_cascade_trigger.sql`

- **Type Definitions**: Generate fresh types with `supabase gen types typescript`

- **Trigger Source**: See migration files for full trigger logic and edge cases

---

## Support

For questions or issues during implementation:
- Check trigger logic in migration files
- Verify data with direct SQL queries: `SELECT * FROM tracking.tracking_plan_style_timeline WHERE plan_id = '...'`
- Test cascade behavior with manual updates: `UPDATE tracking.tracking_plan_style_timeline SET duration_value = 10 WHERE id = '...'`
- Monitor performance with `EXPLAIN ANALYZE` on timeline queries

Good luck with the implementation! 🚀
