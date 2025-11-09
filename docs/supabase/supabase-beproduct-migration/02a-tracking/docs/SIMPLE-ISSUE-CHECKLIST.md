# 02a-Tracking: Simple Issue Checklist (In Order of Operation)

**Date:** November 9, 2025  
**Purpose:** Simple, actionable checklist for creating and executing GitHub issues  
**Status:** ✅ Ready to execute

---

## Phase 1a: Read Operations + Webhook Sync (Week 1-2)

### Issue #0E: Validate Existing API Functions
**Priority:** 🔴 CRITICAL  
**Effort:** 1 day  
**Owner:** Backend Developer  

**What to do:**
1. Use MCP Supabase tools to test all 21 existing functions in `tracking-api-client.ts`
2. Query each tracking table to verify schema matches documentation
3. Test read operations return expected data
4. Document any broken functions or schema mismatches

**Deliverable:** Validation report showing what works vs what needs fixing

**Blocks:** All other issues (must know current state first)

---

### Issue #0A-Part1: Enable READ via PostgREST
**Priority:** 🔴 CRITICAL  
**Effort:** 1 day  
**Owner:** Backend Developer

**What to do:**
1. Create migration `014_enable_tracking_read_access.sql`:
```sql
-- Grant SELECT on tracking tables
GRANT SELECT ON tracking.tracking_folder TO authenticated;
GRANT SELECT ON tracking.tracking_plan TO authenticated;
GRANT SELECT ON tracking.tracking_plan_style TO authenticated;
GRANT SELECT ON tracking.tracking_plan_style_timeline TO authenticated;
GRANT SELECT ON tracking.tracking_timeline_assignment TO authenticated;
GRANT SELECT ON tracking.tracking_plan_dependencies TO authenticated;
GRANT SELECT ON tracking.tracking_plan_style_dependency TO authenticated;

-- Grant usage on enums
GRANT USAGE ON TYPE department_enum TO authenticated;
GRANT USAGE ON TYPE phase_enum TO authenticated;
GRANT USAGE ON TYPE relationship_type_enum TO authenticated;
GRANT USAGE ON TYPE offset_unit_enum TO authenticated;

-- Enable RLS with read-only policies
ALTER TABLE tracking.tracking_folder ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow read for authenticated" ON tracking.tracking_folder FOR SELECT TO authenticated USING (true);
-- (repeat for all tracking tables)
```

2. Test read access via PostgREST
3. Document read-only usage patterns

**Deliverable:** Frontend can read all tracking data via Supabase

**Dependencies:** Issue #0E (validation complete)

---

### Issue #0B: Create Progress/Aggregation Edge Functions
**Priority:** 🟡 HIGH  
**Effort:** 2 days  
**Owner:** Backend Developer

**What to do:**
1. Create `supabase/functions/tracking-plan-progress/index.ts`:
   - Aggregate timeline status by plan
   - Calculate completion percentage
   - Count late milestones
   
2. Create `supabase/functions/tracking-folder-progress/index.ts`:
   - Aggregate across all plans in folder
   
3. Create `supabase/functions/tracking-user-workload/index.ts`:
   - Get all assignments for a user
   - Sort by due date

4. Deploy functions:
```bash
npx supabase functions deploy tracking-plan-progress --no-verify-jwt
npx supabase functions deploy tracking-folder-progress --no-verify-jwt
npx supabase functions deploy tracking-user-workload --no-verify-jwt
```

**Deliverable:** 3 edge functions for progress queries

**Dependencies:** Issue #0A-Part1 (read access enabled)

---

### Issue #0D-Part1: Document Read Operations
**Priority:** 🟡 HIGH  
**Effort:** 3 days  
**Owner:** Backend Developer + Technical Writer

**What to do:**
1. Create `API-REFERENCE.md`:
   - Document all tracking tables and columns
   - Include PostgREST query examples
   - Document 3 progress edge functions
   - Include enum values and JSONB structures

2. Create `BEPRODUCT-TO-SUPABASE-MIGRATION.md`:
   - BeProduct API → Supabase API mapping
   - Code examples (before/after)
   - **Document BeProduct-first update flow:** Update BeProduct → webhook → Supabase

3. Create `typescript-types.ts`:
   - TypeScript interfaces for all tables
   - Enum definitions

4. Create Postman collection with read-only examples

**Deliverable:** Complete documentation for read operations

**Dependencies:** Issues #0A-Part1, #0B (endpoints available)

---

### Webhook Deployment (Parallel with Phase 1a)

Use existing issues #1-13 from original proposal:

1. ✅ Code review for `beproduct-tracking-webhook`
2. ✅ Validate database schema
3. ✅ Run migration 009 (disable date triggers)
4. ✅ Configure Supabase secrets
5. ✅ Deploy edge function to staging
6-9. ✅ Test with sample payloads (OnCreate, OnChange, OnDelete)
10. ✅ Deploy to staging environment
11. ✅ Monitor for 24 hours
12. ✅ Deploy to production
13. ✅ Update documentation

**Deliverable:** Real-time BeProduct → Supabase sync operational

---

## Phase 1b/2: Write Operations + Reverse Sync (Week 3-4)

### Issue #0A-Part2: Enable WRITE via PostgREST
**Priority:** 🟡 HIGH (deferred)  
**Effort:** 1 day  
**Owner:** Backend Developer

**What to do:**
1. Create migration `015_enable_tracking_write_access.sql`:
```sql
-- Grant INSERT, UPDATE, DELETE
GRANT INSERT, UPDATE, DELETE ON tracking.tracking_plan_style_timeline TO authenticated;
GRANT INSERT, UPDATE, DELETE ON tracking.tracking_timeline_assignment TO authenticated;
-- (add for tables that need write access)

-- Update RLS policies for write operations
DROP POLICY "Allow read for authenticated" ON tracking.tracking_plan_style_timeline;
CREATE POLICY "Allow all for authenticated" ON tracking.tracking_plan_style_timeline FOR ALL TO authenticated USING (true) WITH CHECK (true);
```

2. Test write operations
3. Add validation rules (business logic)

**Deliverable:** Frontend can update tracking data directly

**Dependencies:** Phase 1a complete, webhook deployed

---

### Issue #0F: Create Reverse Sync Edge Function
**Priority:** 🟡 HIGH (deferred)  
**Effort:** 3-5 days  
**Owner:** Backend Developer

**What to do:**
1. Create `supabase/functions/tracking-reverse-sync/index.ts`:
   - Accept timeline update payload
   - Validate changes
   - Call BeProduct API to sync
   - Wait for webhook confirmation
   - Handle conflicts (last-write-wins)
   - Log sync status

2. Add database trigger (optional):
```sql
-- Auto-trigger reverse sync on UPDATE
CREATE TRIGGER trigger_reverse_sync
AFTER UPDATE ON tracking.tracking_plan_style_timeline
FOR EACH ROW
EXECUTE FUNCTION notify_reverse_sync();
```

3. Deploy function
4. Test bidirectional sync

**Deliverable:** Supabase → BeProduct sync operational

**Dependencies:** Issue #0A-Part2 (write access enabled)

---

### Issue #0D-Part2: Document Write Operations
**Priority:** 🟢 MEDIUM (deferred)  
**Effort:** 2 days  
**Owner:** Backend Developer + Technical Writer

**What to do:**
1. Update `API-REFERENCE.md`:
   - Add write operation examples
   - Document reverse sync endpoint

2. Update `BEPRODUCT-TO-SUPABASE-MIGRATION.md`:
   - Add Supabase-first update flow
   - Document conflict resolution
   - Add troubleshooting guide

3. Update `typescript-types.ts` with write payloads

4. Update Postman collection with write examples

**Deliverable:** Complete documentation for write operations

**Dependencies:** Issues #0A-Part2, #0F (write + reverse sync available)

---

## Summary Table

| # | Issue | Phase | Priority | Days | Start After | Deliverable |
|---|-------|-------|----------|------|-------------|-------------|
| **0E** | Validate Functions | 1a | 🔴 CRITICAL | 1 | Immediately | Validation report |
| **0A-1** | Enable READ | 1a | 🔴 CRITICAL | 1 | #0E | PostgREST read access |
| **0B** | Progress Endpoints | 1a | 🟡 HIGH | 2 | #0A-1 | 3 edge functions |
| **0D-1** | Document READ | 1a | 🟡 HIGH | 3 | #0A-1, #0B | Read API docs |
| **1-13** | Webhook Deploy | 1a | 🟡 HIGH | 5-7 | Parallel | Real-time sync |
| **0A-2** | Enable WRITE | 1b/2 | 🟡 HIGH | 1 | Phase 1a done | PostgREST write access |
| **0F** | Reverse Sync | 1b/2 | 🟡 HIGH | 3-5 | #0A-2 | Bidirectional sync |
| **0D-2** | Document WRITE | 1b/2 | 🟢 MEDIUM | 2 | #0A-2, #0F | Write API docs |

---

## Week-by-Week Execution Plan

### Week 1: Foundation
**Monday:**
- Create Issue #0E in GitHub
- Assign to backend developer
- Execute: Validate all 21 existing functions

**Tuesday:**
- Review validation results
- Create Issue #0A-Part1 in GitHub
- Execute: Write migration for read access

**Wednesday:**
- Test read access
- Create Issue #0B in GitHub
- Start: Progress edge functions

**Thursday-Friday:**
- Complete progress edge functions
- Deploy to staging
- Test endpoints

---

### Week 2: Documentation + Webhook (Parallel)
**Monday-Wednesday:**
- Create Issue #0D-Part1 in GitHub
- Write API documentation
- Create TypeScript types

**Thursday-Friday:**
- Review documentation with frontend team
- Finalize and publish

**Parallel Track:**
- Execute webhook issues #1-13
- Deploy webhook to staging/production
- Monitor for issues

---

### Week 3-4: Write Operations (Optional Phase 1b/2)

**Only proceed if:**
- Frontend team requests direct write access
- Phase 1a stable and working
- Team has bandwidth

**Monday:**
- Create Issue #0A-Part2 in GitHub
- Write migration for write access

**Tuesday-Friday:**
- Create Issue #0F in GitHub
- Build reverse sync edge function
- Test bidirectional sync

**Week 4:**
- Create Issue #0D-Part2 in GitHub
- Document write operations
- Frontend migration to Supabase-first updates

---

## Decision Points

### After Issue #0E (Day 1):
**Question:** Do all 21 existing functions work?
- ✅ YES → Proceed with Phase 1a
- ❌ NO → Fix broken functions first (add issue #0E-Fix)

### After Issue #0D-Part1 (Week 2):
**Question:** Is frontend team satisfied with read-only + BeProduct updates?
- ✅ YES → Defer Phase 1b/2, focus on webhook stability
- ❌ NO → Proceed with Phase 1b/2 (write operations)

### After Webhook Deployment (Week 2):
**Question:** Is webhook stable and reliable?
- ✅ YES → Safe to add reverse sync (Phase 1b/2)
- ❌ NO → Fix webhook issues before adding complexity

---

## Quick Reference: Create Issues in GitHub

### Use these issue templates:
1. ✅ `.github/ISSUE_TEMPLATE/02a-tracking-api-crud.md` (for #0A-1 and #0A-2)
2. ✅ `.github/ISSUE_TEMPLATE/02a-tracking-api-progress.md` (for #0B)
3. ✅ `.github/ISSUE_TEMPLATE/02a-tracking-api-documentation.md` (for #0D-1 and #0D-2)
4. 🆕 Need to create: `02a-tracking-validate-functions.md` (for #0E)
5. 🆕 Need to create: `02a-tracking-reverse-sync.md` (for #0F)

### Issue labels to use:
- `phase-02a-tracking`
- `api`
- `database`
- `edge-function`
- `documentation`
- `critical` / `high` / `medium` priority

---

## Success Criteria

### End of Week 1:
- ✅ Frontend can read all tracking data from Supabase
- ✅ 3 progress endpoints deployed and tested
- ✅ Validation report shows what works

### End of Week 2:
- ✅ Complete API documentation published
- ✅ Webhook deployed and syncing real-time
- ✅ Frontend team trained on read-only APIs

### End of Week 4 (if Phase 1b/2):
- ✅ Frontend can update Supabase directly
- ✅ Reverse sync operational
- ✅ Both update paths working (BeProduct-first + Supabase-first)

---

## NOT Included (Phase 2)

These are valuable but deferred to Phase 2:
- Style-level progress/health endpoints
- Critical path calculation
- Risk/health thresholds
- Advanced search/filter
- Gantt chart support

Focus on core functionality first, add enhancements later.

---

**Status:** ✅ Ready to execute  
**Next Action:** Create Issue #0E in GitHub and assign to backend developer  
**Timeline:** 2-4 weeks depending on whether Phase 1b/2 is needed
