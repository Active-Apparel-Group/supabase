# Frontend Endpoint Migration Guide

**Date:** 2025-10-24  
**Version:** 1.0  
**Status:** 🚧 PLACEHOLDER - To be completed after Phase 1 migrations

---

## Overview

This guide provides the frontend development team with everything needed to migrate from the old view-based endpoints to the new CRUD-enabled table endpoints.

**Key Changes:**
1. All endpoints now prefixed with `tracking_`
2. Plural table names changed to singular
3. Public views (`v_*`) dropped - use base tables instead
4. Full CRUD operations enabled (GET, POST, PATCH, DELETE)
5. **RLS enabled with permissive policies** (temporary - Phase 4 will restrict)

## 🔒 Security Status: RLS Enabled (Permissive)

**Current State (Phase 1):**
- ✅ Row Level Security (RLS) **enabled** on all 15 tracking tables
- ⚠️ Policies are **permissive**: All authenticated users see all data
- 📊 No brand filtering applied yet

**Phase 4 Impact (Future):**
- 🔒 Permissive policies will be **replaced** with brand-scoped policies
- 🚫 Users will only see data matching their `user_metadata.brands` JWT claim
- ⚠️ Frontend must handle 401/403 responses when users access restricted data
- 📝 Implement error handling for "No rows returned" vs "Forbidden" scenarios

**Frontend Action Items:**
- [ ] Test with anon and authenticated JWT tokens
- [ ] Prepare error handling for future brand restrictions
- [ ] Discuss user metadata population strategy with backend team

---

## Endpoint Mapping Table

### Old → New Endpoint URLs

| Old Endpoint (Phase 1) | New Endpoint (Phase 2) | Change Type |
| --- | --- | --- |
| `/rest/v1/v_folder` | `/rest/v1/tracking_folder` | Prefix + drop view |
| `/rest/v1/v_folder_plan` | `/rest/v1/tracking_plan` | Prefix + drop view + separate folder join |
| `/rest/v1/v_folder_plan_columns` | `/rest/v1/tracking_plan_view` | Prefix + drop view + singular |
| `/rest/v1/v_timeline_template` | `/rest/v1/tracking_timeline_template` | Prefix + drop view + singular |
| `/rest/v1/v_timeline_template_item` | `/rest/v1/tracking_timeline_template_item` | Prefix + drop view + singular |
| `/rest/v1/v_plan_styles` | `/rest/v1/tracking_plan_style` | Prefix + drop view + singular |
| `/rest/v1/v_plan_style_timelines_enriched` | `/rest/v1/tracking_plan_style_timeline` | Prefix + drop view + singular |
| `/rest/v1/v_plan_materials` | `/rest/v1/tracking_plan_material` | Prefix + drop view + singular |
| `/rest/v1/v_plan_material_timelines_enriched` | `/rest/v1/tracking_plan_material_timeline` | Prefix + drop view + singular |

---

## Breaking Changes

### ✅ SOLVED: Backend Summary Views

**Good News!** We've created `_summary` and `_detail` views in the tracking schema that handle all aggregations and joins for you. **No client-side computation needed!**

### Read Operations: Use `_summary` Views

| Entity | Summary View Endpoint | What It Provides |
| --- | --- | --- |
| Folders | `/rest/v1/tracking_folder_summary` | Plan counts (active + total) |
| Plans | `/rest/v1/tracking_plan_summary` | Folder/template names, style/material/view counts |
| Styles | `/rest/v1/tracking_plan_style_summary` | Plan/folder names, milestone counts, status_breakdown JSON |
| Materials | `/rest/v1/tracking_plan_material_summary` | Plan/folder names, milestone counts, status_breakdown JSON |
| Timelines | `/rest/v1/tracking_plan_style_timeline_detail` | Template item details, style/plan names, assignments array |
| Templates | `/rest/v1/tracking_timeline_template_detail` | Item counts (style/material/anchor/task) |

### Write Operations: Use Base Tables

| Operation | Base Table Endpoint | Methods |
| --- | --- | --- |
| Create folder | `/rest/v1/tracking_folder` | POST |
| Update plan | `/rest/v1/tracking_plan` | PATCH |
| Update timeline status | `/rest/v1/tracking_plan_style_timeline` | PATCH |
| Delete style | `/rest/v1/tracking_plan_style` | DELETE |

## ⚠️ CRITICAL: Use Schema Prefix with `.from()`

**The Problem:**
The Supabase JS client's `.from()` method defaults to the `public` schema. When you call `.from('tracking_folder_summary')`, it looks for `public.tracking_folder_summary` and fails with:

```
Could not find the table 'public.tracking_folder_summary' in the schema cache
```

**❌ This fails:**
```javascript
// ❌ BAD - Looks in public schema by default
const { data } = await supabase
  .from('tracking_plan_style_summary')
  .select('*');
```

**✅ Use schema prefix:**
```javascript
// ✅ GOOD - Explicitly specify tracking schema
const { data, error } = await supabase
  .from('tracking.tracking_plan_style_summary')
  .select('*')
  .eq('plan_id', planId);
```

**Why `.from()` is Recommended:**
- ✅ **Automatic RLS:** Applies Row Level Security based on authenticated session
- ✅ **No manual headers:** Uses session token automatically
- ✅ **Type-safe:** Works with TypeScript types
- ✅ **Full CRUD:** Supports `.select()`, `.insert()`, `.update()`, `.delete()`
- ✅ **Error handling:** Returns consistent `{ data, error }` objects
- ✅ **Real-time ready:** Can add `.on()` subscriptions for live updates

### Example: Old vs New (with Schema Prefix)

**Old (Public View):**
```javascript
const { data: styles } = await supabase
  .from('v_plan_styles')
  .select('*')
  .eq('plan_id', planId);

// styles[0].milestones_total = 27 (computed in view)
// styles[0].folder_name = "GREYSON MENS" (joined in view)
```

**New (Summary View with schema prefix):**
```javascript
const { data: styles, error } = await supabase
  .from('tracking.tracking_plan_style_summary')  // ← Add schema prefix
  .select('*')
  .eq('plan_id', planId);

if (error) throw error;

// styles[0].milestones_total = 27 ✅ (computed in backend)
// styles[0].folder_name = "GREYSON MENS" ✅ (joined in backend)
// styles[0].status_breakdown = { NOT_STARTED: 20, ... } ✅ (JSON aggregate)
```

**For Updates (with schema prefix):**
```javascript
const { data, error } = await supabase
  .from('tracking.tracking_plan_style')  // ← Schema prefix on base table
  .update({ active: false })
  .eq('id', styleId)
  .select();

if (error) throw error;
```

### Complete Pattern: Read + Write (Supabase Client)

```javascript
// 1️⃣ Load data for display (use summary view with schema prefix)
const { data: styles, error } = await supabase
  .from('tracking.tracking_plan_style_summary')
  .select('*')
  .eq('plan_id', planId)
  .order('created_at', { ascending: false });

if (error) throw error;

// Render grid with aggregates (no client-side computation!)
styles.forEach(style => {
  console.log(`${style.style_number}: ${style.milestones_completed}/${style.milestones_total} complete`);
  console.log(`Status: ${JSON.stringify(style.status_breakdown)}`);
});

// 2️⃣ User updates a style (use base table with schema prefix)
const { data: updated, error: updateError } = await supabase
  .from('tracking.tracking_plan_style')
  .update({ notes: 'Updated from frontend' })
  .eq('id', styleId)
  .select();

if (updateError) throw updateError;

// 3️⃣ Refresh display (summary view auto-reflects update)
const { data: refreshed, error: refreshError } = await supabase
  .from('tracking.tracking_plan_style_summary')
  .select('*')
  .eq('id', styleId)
  .single();

if (refreshError) throw refreshError;
```

### Common Query Patterns

```javascript
// Filtering
.eq('plan_id', planId)              // Exact match
.is('active', true)                 // Boolean
.like('style_number', '%TEST%')     // Pattern match
.gte('created_at', '2025-01-01')    // Greater than or equal
.in('status', ['COMPLETE', 'IN_PROGRESS'])  // Multiple values

// Ordering
.order('created_at', { ascending: false })   // Sort descending
.order('style_number')                       // Sort ascending (default)

// Limiting
.limit(10)                          // First 10 rows
.range(20, 29)                      // Rows 20-29 (pagination)

// Selecting columns
.select('id, style_number, milestones_total')  // Specific columns
.select('*')                                    // All columns

// Combining
.select('*')
.eq('plan_id', planId)
.is('active', true)
.order('created_at', { ascending: false })
.limit(20)
```

### Why This Approach?

✅ **Simple Frontend Code**: No aggregation logic, no joins, no multi-step queries  
✅ **Backend Aggregation**: COUNT FILTER, jsonb_build_object, LEFT JOIN handled in SQL  
✅ **RLS Inheritance**: Views use `security_invoker = true` to inherit base table policies  
✅ **CRUD Enabled**: Base tables support full INSERT/UPDATE/DELETE operations  
✅ **Future-Proof**: Phase 4 brand-scoping works seamlessly (views inherit new policies)

---

## Summary View Schemas

### `tracking_folder_summary`

**Endpoint:** `/rest/v1/tracking_folder_summary`

**Fields:**
- `id` (uuid) - Folder identifier
- `name` (text) - Folder name
- `brand` (text) - Brand identifier
- `active_plan_count` (bigint) - Count of active plans in folder
- `total_plan_count` (bigint) - Total count of all plans in folder
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Use Case:** Folder list view, folder dashboard

---

### `tracking_plan_summary`

**Endpoint:** `/rest/v1/tracking_plan_summary`

**Fields:**
- `id` (uuid) - Plan identifier
- `name` (text) - Plan name
- `folder_id` (uuid) - Parent folder FK
- `folder_name` (text) - Joined folder name
- `folder_brand` (text) - Joined folder brand
- `template_id` (uuid) - Timeline template FK
- `template_name` (text) - Joined template name
- `style_count` (bigint) - Count of styles in plan
- `material_count` (bigint) - Count of materials in plan
- `view_count` (bigint) - Count of views in plan
- `active` (boolean)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Use Case:** Plan list view, plan detail header

---

### `tracking_plan_style_summary`

**Endpoint:** `/rest/v1/tracking_plan_style_summary`

**Fields:**
- `id` (uuid) - Style identifier
- `plan_id` (uuid) - Parent plan FK
- `plan_name` (text) - Joined plan name
- `plan_brand` (text) - Joined plan brand
- `folder_name` (text) - Joined folder name
- `style_number` (text) - Style number
- `style_name` (text) - Style name
- `milestones_total` (bigint) - Total milestone count
- `milestones_completed` (bigint) - Completed milestone count
- `milestones_in_progress` (bigint) - In-progress milestone count
- `milestones_not_started` (bigint) - Not-started milestone count
- `milestones_late` (bigint) - Late milestone count
- `milestones_blocked` (bigint) - Blocked milestone count
- `status_breakdown` (jsonb) - Status distribution `{ "NOT_STARTED": 20, "COMPLETE": 5, ... }`
- `active` (boolean)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Use Case:** Style grid with milestones, style progress dashboard

---

### `tracking_plan_material_summary`

**Endpoint:** `/rest/v1/tracking_plan_material_summary`

**Fields:** Same as `tracking_plan_style_summary` but for materials  
- `material_number` (text) instead of `style_number`
- `material_name` (text) instead of `style_name`

**Use Case:** Material grid with milestones, material progress dashboard

---

### `tracking_plan_style_timeline_detail`

**Endpoint:** `/rest/v1/tracking_plan_style_timeline_detail`

**Fields:**
- `id` (uuid) - Timeline identifier
- `plan_style_id` (uuid) - Parent style FK
- `template_item_id` (uuid) - Template item FK
- `milestone_name` (text) - Joined template item name
- `phase` (text) - Joined template item phase
- `department` (text) - Joined template item department
- `style_number` (text) - Joined style number
- `style_name` (text) - Joined style name
- `plan_name` (text) - Joined plan name
- `start_date` (date)
- `target_date` (date)
- `actual_date` (date)
- `status` (text)
- `assignments` (jsonb) - Assigned users `[{ user_id, user_name }, ...]`
- `notes` (text)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Use Case:** Timeline Gantt chart, milestone detail view

---

### `tracking_timeline_template_detail`

**Endpoint:** `/rest/v1/tracking_timeline_template_detail`

**Fields:**
- `id` (uuid) - Template identifier
- `name` (text) - Template name
- `description` (text)
- `total_items` (bigint) - Total item count
- `style_items` (bigint) - Items with applies_to_style=true
- `material_items` (bigint) - Items with applies_to_material=true
- `anchor_count` (bigint) - Items with is_anchor=true
- `task_count` (bigint) - Items with is_anchor=false
- `active` (boolean)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Use Case:** Template selection dropdown, template detail view

---

## Code Migration Examples

### Example 1: Fetch Folders

**Before:**
```javascript
const { data: folders } = await supabase
  .from('v_folder')
  .select('*')
  .eq('active', true);
```

**After:**
```javascript
const { data: folders } = await supabase
  .from('tracking_folder')
  .select('*')
  .eq('active', true);

// If you need plan counts (previously in view):
// Option 1: Count client-side after fetching plans
// Option 2: Use PostgREST count
const { data: folders } = await supabase
  .from('tracking_folder')
  .select('*, tracking_plan(count)')
  .eq('active', true);
```

### Example 2: Fetch Plans with Folder Info

**Before:**
```javascript
const { data: plans } = await supabase
  .from('v_folder_plan')
  .select('*')
  .eq('folder_id', folderId);
```

**After:**
```javascript
const { data: plans } = await supabase
  .from('tracking_plan')
  .select('*, tracking_folder(name, brand)')
  .eq('folder_id', folderId);
```

### Example 3: Fetch Styles with Milestone Counts

**Before:**
```javascript
const { data: styles } = await supabase
  .from('v_plan_styles')
  .select('*')
  .eq('plan_id', planId);

// styles[0].milestones_total available directly
```

**After:**
```javascript
// Option 1: Fetch with count
const { data: styles } = await supabase
  .from('tracking_plan_style')
  .select('*, tracking_plan_style_timeline(count)')
  .eq('plan_id', planId);

// Access: styles[0].tracking_plan_style_timeline[0].count

// Option 2: Fetch separately and aggregate
const { data: styles } = await supabase
  .from('tracking_plan_style')
  .select('*')
  .eq('plan_id', planId);

const { data: timelines } = await supabase
  .from('tracking_plan_style_timeline')
  .select('plan_style_id, status')
  .in('plan_style_id', styles.map(s => s.id));

// Compute counts client-side
const styleMap = styles.map(style => ({
  ...style,
  milestones_total: timelines.filter(t => t.plan_style_id === style.id).length,
  milestones_completed: timelines.filter(t => 
    t.plan_style_id === style.id && 
    ['COMPLETE', 'APPROVED'].includes(t.status)
  ).length
}));
```

### Example 4: Update Timeline Status

**Before:**
```javascript
// Views were read-only - couldn't update
```

**After:**
```javascript
const { data, error } = await supabase
  .from('tracking_plan_style_timeline')
  .update({
    status: 'COMPLETE',
    completed_date: new Date().toISOString().split('T')[0]
  })
  .eq('id', timelineId)
  .select()
  .single();

if (error) console.error('Update failed:', error);
```

### Example 5: Create New Plan

**Before:**
```javascript
// Not possible - views were read-only
```

**After:**
```javascript
const { data: newPlan, error } = await supabase
  .from('tracking_plan')
  .insert({
    folder_id: selectedFolderId,
    name: '2026 Spring Drop 4',
    brand: 'GREYSON',
    season: '2026 Spring',
    start_date: '2025-11-01',
    end_date: '2026-02-28',
    template_id: selectedTemplateId,
    active: true
  })
  .select()
  .single();

if (!error) {
  console.log('Created plan:', newPlan.id);
}
```

---

## TypeScript Type Updates

**Regenerate types after migration:**

```bash
npx supabase gen types typescript --project-id wjpbryjgtmmaqjbhjgap > types/supabase.ts
```

**Type changes:**

```typescript
// Before
type Folder = Database['public']['Views']['v_folder']['Row'];
type Plan = Database['public']['Views']['v_folder_plan']['Row'];

// After
type Folder = Database['public']['Tables']['tracking_folder']['Row'];
type Plan = Database['public']['Tables']['tracking_plan']['Row'];
```

---

## Testing Checklist

### Pre-Migration Testing
- [ ] Document all current API calls in use
- [ ] Identify which views provide aggregates you rely on
- [ ] List all CRUD operations needed (create plan, update timeline, etc.)

### During Migration
- [ ] Replace endpoint URLs one component at a time
- [ ] Test each component in isolation
- [ ] Verify aggregate computations match old values
- [ ] Test CRUD operations (POST, PATCH, DELETE)

### Post-Migration Testing
- [ ] Run full regression suite
- [ ] Verify no console errors
- [ ] Check network tab for correct endpoints
- [ ] Validate data integrity (counts, statuses, relationships)
- [ ] Test edge cases (empty states, null values, large datasets)

---

## Performance Considerations

### Potential Issues:
1. **Multiple API calls** (where views previously joined data)
2. **Client-side aggregation** (where views computed counts)

### Recommendations:
- Use PostgREST `select` with joins when possible
- Cache frequently-accessed reference data (folders, templates)
- Consider React Query or SWR for data fetching
- Request backend to create specific views if aggregation becomes a bottleneck

---

## Support & Questions

**Slack Channel:** #tracking-migration  
**Backend Contact:** @backend-team  
**Documentation:** `supabase-tracking/docs/`

**Common Questions:**
- Q: How do I get milestone counts?  
  A: See Example 3 above - use PostgREST count or aggregate client-side

- Q: Can I still use anonymous key?  
  A: Yes for GET requests, but POST/PATCH/DELETE require authenticated JWT

- Q: What if I need a complex aggregate?  
  A: Request a tracking schema view or RPC function from backend team

---

## Rollback Plan

If issues arise, backend can:
1. Restore public views temporarily
2. Provide dual endpoints during migration window
3. Revert to Phase 1 state (coordinate with backend)

---

**Status:** 🚧 PLACEHOLDER - Will be completed with:
- [ ] Actual endpoint URLs after migration
- [ ] Sample responses from new endpoints
- [ ] Postman collection with example requests
- [ ] Performance benchmarks
- [ ] Known issues and workarounds

**Handover Date:** TBD (after Phase 1 complete)  
**Migration Deadline:** TBD (coordinate with product/frontend)
