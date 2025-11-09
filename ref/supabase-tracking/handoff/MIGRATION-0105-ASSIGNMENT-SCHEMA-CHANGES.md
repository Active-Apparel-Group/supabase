# Migration 0105: Timeline Assignment Schema Changes

**Date:** 2025-10-26  
**Status:** ✅ **APPLIED**  
**Migration:** `0105_simplify_timeline_assignment_pk.sql`

---

## What Changed?

### `tracking.tracking_timeline_assignment` Table

**BEFORE (0096-0104):**
```sql
CREATE TABLE tracking.tracking_timeline_assignment (
    timeline_id uuid NOT NULL,
    timeline_type tracking.timeline_type_enum NOT NULL,  -- ❌ REMOVED
    assignee_id uuid NOT NULL,  -- ❌ Was NOT NULL, now nullable
    source_user_id uuid,
    role_name text,
    role_id uuid,
    assigned_at timestamptz DEFAULT timezone('utc', now()) NOT NULL,
    PRIMARY KEY (timeline_id, timeline_type, assignee_id)  -- ❌ REMOVED
);
```

**AFTER (0105):**
```sql
CREATE TABLE tracking.tracking_timeline_assignment (
    id bigserial PRIMARY KEY,  -- ✅ NEW: Auto-increment PK
    timeline_id uuid NOT NULL,
    assignee_id uuid,  -- ✅ CHANGED: Now nullable
    source_user_id uuid,
    role_name text,
    role_id uuid,
    assigned_at timestamptz DEFAULT timezone('utc', now()) NOT NULL
);
-- ✅ timeline_type column REMOVED (redundant)
-- ✅ Composite PK REMOVED (too restrictive)
-- ✅ Index added on timeline_id for fast lookups
```

---

## Why This Change?

### Problem 1: `timeline_type` Was Redundant
- The `timeline_type` enum (STYLE/MATERIAL/MASTER) was redundant
- We can infer the type from `timeline_id` itself (which table it references)
- No business logic needs to query by `timeline_type` separately

### Problem 2: `assignee_id` in PK Prevented NULLs
- Timelines are created FIRST (by triggers when styles/materials added to plan)
- Assignments are created LATER (by users/imports)
- Old PK required `assignee_id` to be NOT NULL, blocking this workflow

### Problem 3: Composite PK Prevented Updates
- To change an assignee, you had to DELETE old row + INSERT new row
- Couldn't UPDATE because `assignee_id` was part of PK
- Error-prone and breaks audit trails

---

## Frontend Impact

### ✅ No Breaking Changes for Reads
The summary views (`tracking_plan_style_timeline_detail` and `tracking_plan_material_timeline_detail`) were updated to remove the `timeline_type` filter, but the `assignments` JSON array structure **remains identical**:

```javascript
// ✅ UNCHANGED: Read assignments from summary view
const { data, error } = await supabase
  .from('tracking.tracking_plan_style_timeline_detail')
  .select('*')
  .eq('id', timelineId)
  .single();

// assignments array structure is EXACTLY the same:
console.log(data.assignments);
// [
//   {
//     "assignee_id": "uuid-here",
//     "source_user_id": "uuid-here",
//     "role_name": "Tech Designer",
//     "role_id": "uuid-here",
//     "assigned_at": "2025-10-26T12:00:00Z"
//   }
// ]
```

### ⚠️ Breaking Changes for Writes

**OLD (BROKEN - Don't use):**
```javascript
// ❌ OLD: Required timeline_type in INSERT
await supabase
  .from('tracking.tracking_timeline_assignment')
  .insert({
    timeline_id: 'uuid-here',
    timeline_type: 'STYLE',  // ❌ Column doesn't exist anymore
    assignee_id: 'uuid-here',
    role_name: 'Tech Designer'
  });

// ❌ OLD: Couldn't UPDATE assignee (was part of PK)
await supabase
  .from('tracking.tracking_timeline_assignment')
  .update({ assignee_id: 'new-uuid' })  // ❌ Would fail
  .eq('timeline_id', 'uuid-here')
  .eq('timeline_type', 'STYLE')
  .eq('assignee_id', 'old-uuid');
```

**NEW (CORRECT):**
```javascript
// ✅ NEW: Insert assignment (no timeline_type, assignee_id can be NULL)
const { data, error } = await supabase
  .from('tracking.tracking_timeline_assignment')
  .insert({
    timeline_id: 'uuid-here',  // FK to style/material timeline
    assignee_id: 'uuid-here',  // Optional! Can be NULL initially
    role_name: 'Tech Designer',
    role_id: 'optional-role-uuid'
  })
  .select();

// ✅ NEW: Update assignee (simple UPDATE by id)
await supabase
  .from('tracking.tracking_timeline_assignment')
  .update({ assignee_id: 'new-uuid' })
  .eq('id', assignmentId);  // Use auto-increment ID, not composite key

// ✅ NEW: Delete assignment (simple DELETE by id)
await supabase
  .from('tracking.tracking_timeline_assignment')
  .delete()
  .eq('id', assignmentId);
```

---

## Common Patterns

### Create Timeline First, Assign Later (Now Supported!)

```javascript
// Step 1: Create plan style (trigger creates timelines automatically)
const { data: newStyle } = await supabase
  .from('tracking.tracking_plan_style')
  .insert({
    plan_id: 'plan-uuid',
    style_number: 'TEST-001',
    style_name: 'Test Style'
  })
  .select()
  .single();

// Step 2: Get timelines created by trigger
const { data: timelines } = await supabase
  .from('tracking.tracking_plan_style_timeline')
  .select('id')
  .eq('plan_style_id', newStyle.id);

// Step 3: Assign users to timelines (can do later!)
for (const timeline of timelines) {
  await supabase
    .from('tracking.tracking_timeline_assignment')
    .insert({
      timeline_id: timeline.id,
      assignee_id: null,  // ✅ NULL is fine! Assign later
      role_name: 'To Be Assigned'
    });
}

// Step 4: Update assignment when user is assigned
await supabase
  .from('tracking.tracking_timeline_assignment')
  .update({ assignee_id: 'user-uuid', role_name: 'Tech Designer' })
  .eq('timeline_id', timeline.id);
```

### Query Assignments for a Timeline

```javascript
// Get all assignments for a specific timeline
const { data: assignments } = await supabase
  .from('tracking.tracking_timeline_assignment')
  .select('*')
  .eq('timeline_id', 'timeline-uuid');

// Each assignment has:
// - id: bigint (PK)
// - timeline_id: uuid
// - assignee_id: uuid | null
// - source_user_id: uuid | null
// - role_name: text
// - role_id: uuid | null
// - assigned_at: timestamptz
```

---

## Migration Checklist for Frontend

### Immediate Actions Required

- [ ] **Search codebase** for `timeline_type` references in assignment queries
  - Remove `timeline_type` from all INSERT/UPDATE/DELETE operations
  - Update queries to use `id` instead of composite key

- [ ] **Update assignment creation** code
  - Remove `timeline_type` parameter
  - Allow `assignee_id` to be `null`
  - Don't enforce NOT NULL validation in UI

- [ ] **Update assignment updates** code
  - Use `id` as filter (not `timeline_id + timeline_type + assignee_id`)
  - Allow updating `assignee_id` directly

- [ ] **Test assignment workflows**
  - Create timeline without assignment
  - Assign user later
  - Update assignee
  - Remove assignment

### No Changes Needed For

- ✅ Reading `assignments` from summary views (structure unchanged)
- ✅ Displaying assignment data in UI (fields unchanged)
- ✅ Timeline creation triggers (don't insert assignments)

---

## Database Schema Reference

### Updated Table: `tracking.tracking_timeline_assignment`

| Column | Type | Nullable | Default | Notes |
| --- | --- | --- | --- | --- |
| `id` | bigint | NO | auto-increment | **NEW:** Primary key |
| `timeline_id` | uuid | NO | — | FK to style/material timeline |
| `assignee_id` | uuid | **YES** | — | **CHANGED:** Now nullable |
| `source_user_id` | uuid | YES | — | Upstream BeProduct user |
| `role_name` | text | YES | — | Descriptive role name |
| `role_id` | uuid | YES | — | Optional role FK |
| `assigned_at` | timestamptz | NO | `now()` | Assignment timestamp |

**PK:** `id` (bigint, auto-increment)  
**Indexes:** `idx_timeline_assignment_timeline_id` on `timeline_id`

### Removed

- ❌ `timeline_type` column (STYLE/MATERIAL enum)
- ❌ Composite PK `(timeline_id, timeline_type, assignee_id)`

---

## Questions?

**Q: Do I need to update summary view queries?**  
A: No! The views were updated automatically. The `assignments` JSON array structure is identical.

**Q: How do I know if a timeline_id is STYLE or MATERIAL?**  
A: Query the timeline ID against both tables:
```javascript
// Check which table the timeline belongs to
const { data: styleTimeline } = await supabase
  .from('tracking.tracking_plan_style_timeline')
  .select('id')
  .eq('id', timelineId)
  .maybeSingle();

const { data: materialTimeline } = await supabase
  .from('tracking.tracking_plan_material_timeline')
  .select('id')
  .eq('id', timelineId)
  .maybeSingle();

const timelineType = styleTimeline ? 'STYLE' : materialTimeline ? 'MATERIAL' : null;
```

**Q: Can I have multiple assignments for the same timeline?**  
A: Yes! The new PK (`id`) allows multiple rows with the same `timeline_id`. This supports scenarios like:
- Multiple users assigned to same milestone
- Assignment history (old + new assignees)

**Q: What happens to existing assignment data?**  
A: This is a new database (no production data). If you had test data, it was preserved during migration.

---

## Summary

✅ **Removed redundant `timeline_type` column**  
✅ **Simplified PK** from composite `(timeline_id, timeline_type, assignee_id)` to auto-increment `id`  
✅ **Made `assignee_id` nullable** to support deferred assignment workflow  
✅ **Updated 2 summary views** to remove `timeline_type` filter (no frontend changes needed)  
✅ **Added index** on `timeline_id` for fast lookups  
✅ **Preserved RLS policies** and permissions

**Frontend Action:** Update write operations to remove `timeline_type` and use `id` for updates/deletes.
