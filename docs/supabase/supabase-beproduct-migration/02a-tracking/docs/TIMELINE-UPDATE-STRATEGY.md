# Timeline Update Strategy - Phased Approach

**Date:** November 9, 2025  
**Purpose:** Define phased approach for timeline updates based on architectural guidance  
**Requested By:** @ChrisKalathas

---

## Update Strategy

### Phase 1a (Week 1-2): BeProduct-First Updates

**Approach:** Developers update BeProduct → Webhook → Supabase

**Why:**
- BeProduct is source of truth
- Webhook infrastructure already built
- Some timeline events can ONLY be updated in BeProduct
- Lower risk (proven pattern)

**User Flow:**
```
User → Update in BeProduct UI
  ↓
BeProduct triggers webhook (OnChange)
  ↓
Edge function (beproduct-tracking-webhook) receives event
  ↓
Supabase tracking tables updated
```

**Issue Impact:**
- ✅ **Issue #0A (CRUD):** Focus on READ operations only in early Phase 1
- ✅ **Issue #0B (Progress):** Read-only aggregations (no updates)
- ✅ **Issue #0D (Documentation):** Document read-only usage patterns first

---

### Phase 1b/2 (Later): Supabase-First Updates

**Approach:** Developers update Supabase → Trigger BeProduct API → Webhook confirms

**Why:**
- Easier API for frontend developers
- Better performance (direct database access)
- More flexible (can update fields BeProduct doesn't expose)
- Webhook remains as backup/confirmation mechanism

**User Flow:**
```
User → Update via Supabase API (PostgREST or Edge Function)
  ↓
Supabase tracking tables updated immediately
  ↓
Trigger BeProduct API update (reverse sync)
  ↓
BeProduct webhook confirms change (OnChange)
  ↓
Edge function validates sync (optional reconciliation)
```

**Issue Impact:**
- 🔄 **Issue #0A (CRUD):** Add UPDATE/DELETE operations
- 🔄 **New Issue #0F:** Create reverse sync edge function (Supabase → BeProduct)
- 🔄 **Issue #0D (Documentation):** Add write operation patterns

---

## Revised Issue Sequence

### Phase 1a (Week 1-2): Read Operations + Webhook Sync

#### Issue #0E: Validate Existing Functions (1 day)
- Test 21 existing read functions
- Verify schema matches expectations
- **No write operations**

#### Issue #0A: Enable READ via PostgREST (1 day) 🔄 REVISED
- Grant SELECT only (not INSERT/UPDATE/DELETE yet)
- Enable RLS with read-only policies
- Document read patterns

**Changes from original:**
```sql
-- BEFORE (original Issue #0A):
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.* TO authenticated;

-- AFTER (revised for Phase 1a):
GRANT SELECT ON tracking.* TO authenticated;
-- (INSERT/UPDATE/DELETE deferred to Phase 1b/2)
```

#### Issue #0B: Progress/Aggregation Endpoints (2 days)
- Read-only progress queries
- No update operations
- **Unchanged** (already read-only)

#### Issue #0D: API Documentation (5 days) 🔄 REVISED
- Document read-only patterns FIRST
- Include webhook-based update flow
- Add "Coming in Phase 1b/2: Direct updates"

**Changes from original:**
- Focus on GET operations
- Document BeProduct update → webhook → Supabase flow
- Defer write operation documentation

---

### Phase 1b/2 (Later): Write Operations + Reverse Sync

#### Issue #0A (Part 2): Enable WRITE via PostgREST (1 day) 🆕
- Grant INSERT, UPDATE, DELETE
- Enable RLS with write policies
- Add validation rules

#### Issue #0F: Reverse Sync Edge Function (3-5 days) 🆕 NEW
**Purpose:** Supabase → BeProduct sync

**Endpoint:** `POST /functions/v1/tracking-reverse-sync`

**Features:**
- Update BeProduct via API when Supabase changes
- Validate changes before syncing
- Handle conflicts (last-write-wins or manual resolution)
- Log all sync operations

**Architecture:**
```typescript
// Trigger options:
// 1. Database trigger (on UPDATE to timeline tables)
// 2. Edge function API (explicit sync call)
// 3. Scheduled job (batch sync every N minutes)

async function syncToBeProduct(timelineUpdate: TimelineUpdate) {
  // 1. Validate change is allowed
  // 2. Call BeProduct API to update
  // 3. Wait for webhook confirmation
  // 4. Log sync status
  // 5. Handle conflicts if webhook shows different value
}
```

**Deliverables:**
- Edge function implementation
- Conflict resolution strategy
- Sync status logging
- Rollback procedures

#### Issue #0D (Part 2): Document Write Operations (2 days) 🆕
- Add write operation examples
- Document reverse sync flow
- Include conflict resolution patterns
- Add troubleshooting guide

---

## Read vs Write Operations

### Read Operations (Phase 1a)

**Available immediately:**
```typescript
// ✅ Get folders
const folders = await supabase
  .from('tracking_folder')
  .select('*');

// ✅ Get plan timelines
const timelines = await supabase
  .from('tracking_plan_style_timeline')
  .select('*')
  .eq('plan_id', planId);

// ✅ Get progress
const progress = await fetch('/functions/v1/tracking-plan-progress?plan_id=' + planId);

// ✅ Get dependencies
const deps = await supabase
  .from('tracking_plan_style_dependency')
  .select('*')
  .eq('plan_id', planId);
```

**Updates via BeProduct:**
```typescript
// Phase 1a approach: Update BeProduct, webhook updates Supabase
await updateBeProductTimeline(timelineId, {
  status: 'In Progress',
  revDate: '2025-11-15'
});
// Wait for webhook to update Supabase (< 5 seconds)
```

---

### Write Operations (Phase 1b/2)

**Direct Supabase updates:**
```typescript
// Phase 1b/2 approach: Update Supabase, trigger reverse sync
const { data, error } = await supabase
  .from('tracking_plan_style_timeline')
  .update({
    status: 'In Progress',
    rev_date: '2025-11-15'
  })
  .eq('id', timelineId);

// Trigger reverse sync (automatic via trigger or explicit call)
await fetch('/functions/v1/tracking-reverse-sync', {
  method: 'POST',
  body: JSON.stringify({
    timeline_id: timelineId,
    operation: 'update'
  })
});
```

---

## Why This Phased Approach?

### Advantages

**Phase 1a (BeProduct-first):**
- ✅ Lower risk (proven webhook pattern)
- ✅ No new infrastructure needed
- ✅ Respects BeProduct as source of truth
- ✅ Handles BeProduct-only fields correctly
- ✅ Faster time to read-only access

**Phase 1b/2 (Supabase-first):**
- ✅ Better developer experience (simpler API)
- ✅ Faster updates (no BeProduct round-trip)
- ✅ More flexible (can update fields BeProduct doesn't expose)
- ✅ Better offline support
- ✅ Webhook remains as validation/backup

### Some Timeline Events ONLY in BeProduct

**Why this matters:**
- BeProduct may have business logic we don't replicate
- Some fields may be calculated/derived
- Some workflows may require BeProduct UI interaction
- Certain validations may exist only in BeProduct

**Examples that might be BeProduct-only:**
- Milestone approval workflows
- Supplier visibility changes (may require BeProduct permissions)
- Status transitions with business rules
- Submission quantity updates (linked to file uploads)

**Solution:** Keep webhook active even in Phase 1b/2 for these cases.

---

## Updated Timeline

### Week 1 (Phase 1a - Read Operations)
- **Day 1:** Issue #0E - Validate existing functions
- **Day 2:** Issue #0A (Part 1) - Enable READ via PostgREST
- **Day 3-4:** Issue #0B - Progress endpoints (read-only)
- **Day 5-9:** Issue #0D (Part 1) - Document read operations

**Output:** Frontend can READ all tracking data, updates still via BeProduct

---

### Week 2 (Webhook Deployment - Parallel)
- Issues #1-13 from original proposal
- Deploy beproduct-tracking-webhook
- Real-time BeProduct → Supabase sync

**Output:** Real-time sync operational

---

### Week 3-4 (Phase 1b/2 - Write Operations)
- **Day 1:** Issue #0A (Part 2) - Enable WRITE via PostgREST
- **Day 2-6:** Issue #0F - Reverse sync edge function
- **Day 7-8:** Issue #0D (Part 2) - Document write operations

**Output:** Frontend can UPDATE Supabase directly, reverse sync to BeProduct

---

## Conflict Resolution Strategy

### Scenario: User updates in BeProduct while frontend updating Supabase

**Without reverse sync (Phase 1a):**
- No conflict possible (only BeProduct updates)

**With reverse sync (Phase 1b/2):**

**Option 1: Last-Write-Wins**
```typescript
// Supabase update triggers reverse sync
// BeProduct webhook confirms change
// If values differ, webhook value wins (overwrite Supabase)
```

**Option 2: Timestamp-Based**
```typescript
// Compare updated_at timestamps
// Most recent update wins
// Log conflicts for review
```

**Option 3: Manual Resolution**
```typescript
// Detect conflict
// Show UI: "Value changed in BeProduct, accept or override?"
// User chooses which value to keep
```

**Recommendation:** Start with Option 1 (Last-Write-Wins) for simplicity.

---

## Migration Path for Frontend

### Phase 1a Code (BeProduct-first)
```typescript
// Read from Supabase
const timelines = await supabase
  .from('tracking_plan_style_timeline')
  .select('*')
  .eq('plan_id', planId);

// Update via BeProduct API
await beproductClient.updateTimeline(timelineId, {
  status: 'In Progress'
});

// Wait for webhook (optional polling)
await pollForUpdate(timelineId);
```

### Phase 1b/2 Code (Supabase-first)
```typescript
// Read from Supabase (unchanged)
const timelines = await supabase
  .from('tracking_plan_style_timeline')
  .select('*')
  .eq('plan_id', planId);

// Update Supabase directly (NEW)
await supabase
  .from('tracking_plan_style_timeline')
  .update({ status: 'In Progress' })
  .eq('id', timelineId);

// Reverse sync happens automatically
// No polling needed
```

**Migration:** Change ~10 update functions in frontend codebase.

---

## Issue Template Updates Required

### Update `.github/ISSUE_TEMPLATE/02a-tracking-api-crud.md`

**Before:**
```markdown
## Required Changes

Grant CRUD permissions:
- SELECT, INSERT, UPDATE, DELETE on tracking.* tables
```

**After:**
```markdown
## Required Changes (Phase 1a - Read Only)

Grant READ permissions:
- SELECT on tracking.* tables

## Deferred to Phase 1b/2:
- INSERT, UPDATE, DELETE (after reverse sync implemented)
```

### Create `.github/ISSUE_TEMPLATE/02a-tracking-reverse-sync.md` (NEW)

```markdown
---
name: 02a-Tracking Reverse Sync Edge Function
about: Create edge function for Supabase → BeProduct sync
title: '[02a-Tracking] Create reverse sync edge function (Supabase → BeProduct)'
labels: ['phase-02a-tracking', 'edge-function', 'api', 'phase-1b']
assignees: ''
---

## Context
Enable direct Supabase updates that sync back to BeProduct while keeping webhook as validation mechanism.

## Required Edge Function

**File:** `supabase/functions/tracking-reverse-sync/index.ts`

**Endpoint:** `POST /functions/v1/tracking-reverse-sync`

...
```

---

## Summary

**Key Changes:**
- ✅ Phase 1a: READ operations only (via PostgREST)
- ✅ Phase 1a: Updates via BeProduct → webhook → Supabase
- 🔄 Phase 1b/2: WRITE operations (via PostgREST)
- 🔄 Phase 1b/2: Reverse sync (Supabase → BeProduct)
- ✅ Webhook remains active in both phases

**Issue Impact:**
- Issue #0A split into Part 1 (read) and Part 2 (write)
- Issue #0D split into Part 1 (read docs) and Part 2 (write docs)
- New Issue #0F for reverse sync
- Issues #0B, #0E unchanged

**Timeline:**
- Week 1: Read operations + documentation
- Week 2: Webhook deployment (parallel)
- Week 3-4: Write operations + reverse sync

---

**Status:** ✅ Strategy Defined  
**Next Action:** Update issue templates and review documents  
**Timeline Impact:** +3-5 days for reverse sync (Phase 1b/2)
