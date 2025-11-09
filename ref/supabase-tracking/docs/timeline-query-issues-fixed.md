# Timeline Query Issues - Fixed ✅

## Issues Identified

### 1. Missing Columns in View ❌ → ✅ FIXED
**Error**: `column tracking_plan_style_timeline_detail.start_date_plan does not exist`

**Cause**: The detail view was created before we added the new duration/start date columns.

**Fix**: Applied migration `update_timeline_detail_views` to recreate both views:
- `tracking.tracking_plan_style_timeline_detail`
- `tracking.tracking_plan_material_timeline_detail`

**New Columns Added**:
- `start_date_plan` (date)
- `start_date_due` (date)
- `duration_value` (integer)
- `duration_unit` (offset_unit_enum)

---

### 2. Invalid Order Syntax ❌ → Needs Frontend Fix

**Error**: 
```
"failed to parse order (plan_style.style_number.asc,template_item.display_order.asc)"
```

**Cause**: Supabase PostgREST doesn't support ordering by joined table columns using dot notation like `plan_style.style_number.asc`.

**Incorrect Syntax** (from your frontend code):
```typescript
.order('plan_style.style_number.asc,template_item.display_order.asc')
```

**Correct Syntax** (PostgREST format):
```typescript
// Option 1: Order by columns in the main table only
.order('style_number', { ascending: true })
.order('display_order', { ascending: true })

// Option 2: Order by view columns (not joined table columns)
.order('milestone_name', { ascending: true })

// Option 3: Use multiple order calls
.order('style_number')
.order('display_order')
```

---

## Correct Query Examples

### Query the Detail View (Recommended)

The detail view already joins all related tables, so just query it directly:

```typescript
// ✅ CORRECT: Query the detail view
const { data, error } = await supabase
  .from('tracking_plan_style_timeline_detail')
  .select('*')
  .eq('plan_style_id', styleId)
  .order('display_order', { ascending: true });
```

**Available columns in detail view**:
- All timeline columns (including new `start_date_plan`, `duration_value`, etc.)
- `milestone_name`, `milestone_short_name`, `phase`, `department`, `display_order` (from template item)
- `style_number`, `style_name`, `color_name` (from plan style)
- `plan_name`, `plan_brand` (from plan)
- `assignments` (jsonb array)

### Query with Joins (If you need custom joins)

```typescript
// ✅ CORRECT: Query base table with select joins
const { data, error } = await supabase
  .from('tracking_plan_style_timeline')
  .select(`
    *,
    template_item:tracking_timeline_template_item(
      name,
      display_order,
      phase,
      department
    ),
    plan_style:tracking_plan_style(
      style_number,
      style_name,
      color_name
    )
  `)
  .eq('plan_style_id', styleId)
  .order('created_at', { ascending: false });
```

**Note**: You can only order by columns in the main table (`tracking_plan_style_timeline`), not by joined table columns.

---

## Sorting Options

### Option 1: Order by Main Table Columns Only

```typescript
// ✅ Works - sorts by timeline table columns
.order('plan_date', { ascending: true })
.order('created_at', { ascending: false })
.order('status')
```

### Option 2: Order by Detail View Columns

```typescript
// ✅ Works - view has flattened all columns
const { data } = await supabase
  .from('tracking_plan_style_timeline_detail')
  .select('*')
  .order('display_order', { ascending: true })  // from template_item
  .order('style_number', { ascending: true });   // from plan_style
```

### Option 3: Sort Client-Side (Post-Fetch)

```typescript
// Fetch data without ordering
const { data } = await supabase
  .from('tracking_plan_style_timeline')
  .select(`
    *,
    template_item:tracking_timeline_template_item(display_order),
    plan_style:tracking_plan_style(style_number)
  `);

// Sort client-side
const sorted = data?.sort((a, b) => {
  const styleCompare = a.plan_style.style_number.localeCompare(b.plan_style.style_number);
  if (styleCompare !== 0) return styleCompare;
  return a.template_item.display_order - b.template_item.display_order;
});
```

---

## Updated Frontend Query Pattern

### Before (Broken) ❌

```typescript
const { data: timelines, error } = await supabase
  .from('tracking_plan_style_timeline')
  .select(`
    *,
    template_item:tracking_timeline_template_item(*),
    plan_style:tracking_plan_style(*)
  `)
  .eq('plan_style_id', styleId)
  .order('plan_style.style_number.asc,template_item.display_order.asc');  // ❌ INVALID
```

### After (Fixed) ✅

```typescript
// Option A: Use the detail view
const { data: timelines, error } = await supabase
  .from('tracking_plan_style_timeline_detail')
  .select('*')
  .eq('plan_style_id', styleId)
  .order('style_number', { ascending: true })
  .order('display_order', { ascending: true });

// Option B: Fetch and sort client-side
const { data: timelines, error } = await supabase
  .from('tracking_plan_style_timeline')
  .select(`
    *,
    template_item:tracking_timeline_template_item(*),
    plan_style:tracking_plan_style(*)
  `)
  .eq('plan_style_id', styleId);

const sorted = timelines?.sort((a, b) => {
  const styleCompare = a.plan_style.style_number.localeCompare(b.plan_style.style_number);
  if (styleCompare !== 0) return styleCompare;
  return a.template_item.display_order - b.template_item.display_order;
});
```

---

## Detail View Schema

### tracking_plan_style_timeline_detail

```typescript
interface TimelineDetail {
  // Timeline core
  id: string;
  plan_style_id: string;
  template_item_id: string;
  status: TimelineStatusCode;
  
  // End dates
  plan_date: string | null;
  rev_date: string | null;
  final_date: string | null;
  due_date: string | null;
  completed_date: string | null;
  
  // ✨ NEW: Start dates and duration
  start_date_plan: string | null;
  start_date_due: string | null;
  duration_value: number | null;
  duration_unit: 'DAYS' | 'BUSINESS_DAYS';
  
  // Flags
  late: boolean;
  
  // Metadata
  notes: string | null;
  page_type: PageTypeCode | null;
  page_name: string | null;
  timeline_type: 'MASTER' | 'STYLE' | 'MATERIAL';
  created_at: string;
  updated_at: string;
  
  // From template_item (flattened)
  milestone_name: string;
  milestone_short_name: string | null;
  phase: string | null;
  department: string | null;
  display_order: number;
  node_type: 'ANCHOR' | 'TASK';
  required: boolean;
  
  // From plan_style (flattened)
  style_number: string | null;
  style_name: string | null;
  color_name: string | null;
  
  // From plan (flattened)
  plan_name: string;
  plan_brand: string | null;
  
  // Assignments (aggregated)
  assignments: Array<{
    assignee_id: string;
    role_name: string | null;
    assigned_at: string;
  }>;
}
```

---

## Common Query Patterns

### 1. Get All Timelines for a Plan Style

```typescript
const { data } = await supabase
  .from('tracking_plan_style_timeline_detail')
  .select('*')
  .eq('plan_style_id', styleId)
  .order('display_order');
```

### 2. Get Timelines by Phase

```typescript
const { data } = await supabase
  .from('tracking_plan_style_timeline_detail')
  .select('*')
  .eq('plan_style_id', styleId)
  .eq('phase', 'DEVELOPMENT')
  .order('display_order');
```

### 3. Get Late Timelines

```typescript
const { data } = await supabase
  .from('tracking_plan_style_timeline_detail')
  .select('*')
  .eq('plan_style_id', styleId)
  .eq('late', true)
  .order('due_date');
```

### 4. Get Timelines for Gantt Chart

```typescript
const { data } = await supabase
  .from('tracking_plan_style_timeline_detail')
  .select(`
    id,
    milestone_name,
    phase,
    start_date_plan,
    plan_date,
    start_date_due,
    due_date,
    duration_value,
    duration_unit,
    status,
    late,
    display_order
  `)
  .eq('plan_style_id', styleId)
  .not('start_date_plan', 'is', null)  // Only tasks with calculated dates
  .order('display_order');
```

### 5. Get Timeline with Dependencies

```typescript
// Get timeline with its predecessors
const { data: timeline } = await supabase
  .from('tracking_plan_style_timeline_detail')
  .select('*')
  .eq('id', timelineId)
  .single();

const { data: dependencies } = await supabase
  .from('tracking_plan_style_dependency')
  .select(`
    *,
    predecessor:tracking_plan_style_timeline_detail!predecessor_id(*)
  `)
  .eq('successor_id', timelineId);
```

---

## Summary of Fixes

### ✅ Database Side (FIXED)
- [x] Updated `tracking_plan_style_timeline_detail` view
- [x] Updated `tracking_plan_material_timeline_detail` view
- [x] Added `start_date_plan`, `start_date_due`, `duration_value`, `duration_unit` columns to views

### ⏳ Frontend Side (ACTION REQUIRED)

**Change This**:
```typescript
// ❌ OLD (broken)
.order('plan_style.style_number.asc,template_item.display_order.asc')
```

**To This**:
```typescript
// ✅ NEW (works)
.order('style_number', { ascending: true })
.order('display_order', { ascending: true })
```

**Or use the detail view**:
```typescript
// ✅ RECOMMENDED
const { data } = await supabase
  .from('tracking_plan_style_timeline_detail')  // ← Use the view
  .select('*')
  .eq('plan_style_id', styleId)
  .order('display_order');
```

---

## Testing

### Verify View Works

```sql
-- Check view has new columns
SELECT 
  id,
  milestone_name,
  start_date_plan,
  start_date_due,
  duration_value,
  duration_unit,
  plan_date,
  style_number,
  display_order
FROM tracking.tracking_plan_style_timeline_detail
LIMIT 5;
```

### Test REST API

```bash
# Get timelines with new columns
GET /rest/v1/tracking_plan_style_timeline_detail?select=*&order=display_order.asc

# Filter and order
GET /rest/v1/tracking_plan_style_timeline_detail?plan_style_id=eq.{uuid}&order=display_order.asc,plan_date.asc
```

---

## Migration Applied

**Migration**: `update_timeline_detail_views`  
**Date**: 2025-10-24  
**Status**: ✅ Applied successfully  

**Changes**:
- Recreated `tracking_plan_style_timeline_detail` with new columns
- Recreated `tracking_plan_material_timeline_detail` with new columns
- Both views now include: `start_date_plan`, `start_date_due`, `duration_value`, `duration_unit`

---

## Next Steps for Frontend

1. **Update queries** to use correct order syntax (remove `plan_style.` and `template_item.` prefixes)
2. **Consider using detail views** instead of manual joins for simpler queries
3. **Update TypeScript types** to include new columns in detail view interface
4. **Test Gantt chart queries** to ensure start dates are fetched correctly
