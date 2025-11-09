# Phase 02a-Tracking: GitHub Issues Review & Revision

**Date:** November 9, 2025  
**Status:** ✅ Review Complete  
**Purpose:** Second-eyes review of proposed GitHub issues with focus on API endpoints

---

## Executive Summary

### Key Findings

1. **✅ Webhook Implementation Complete**: Edge function fully implemented and documented
2. **✅ Database Migration 009 Already Created**: Critical migration exists and is ready to apply
3. **❌ Missing API Endpoint Requirements**: Proposed issues don't include Supabase API endpoints needed to replace BeProduct APIs
4. **⚠️ Some Steps Already Complete**: Several proposed issues are for work already done
5. **⚠️ Some Steps Incorrect**: A few issue descriptions don't match current architecture

### Impact on Frontend Development

**CRITICAL GAP**: Frontend developers need Supabase REST API endpoints equivalent to BeProduct's tracking APIs before they can migrate UI components. The proposed issues don't include tasks for building these endpoints.

**Required BeProduct API Equivalents:**
- `GET /api/tracking/plans/{planId}` → Supabase equivalent needed
- `GET /api/tracking/plans/{planId}/styles` → Supabase equivalent needed  
- `PATCH /api/tracking/timeline/bulk` → Supabase equivalent needed
- Enhanced filtering/sorting capabilities (better than BeProduct)

---

## Detailed Review

### Section 1: Pre-Deployment Issues

#### ✅ Issue #1: Code Review (VALID)
**Status:** Ready to create  
**Changes Needed:** None

**Validation:**
- Edge function exists: `supabase/functions/beproduct-tracking-webhook/index.ts` (500+ lines)
- Comprehensive implementation with error handling
- TypeScript types are explicit
- Code is ready for review

---

#### ⚠️ Issue #2: Validate Database Schema (PARTIALLY COMPLETE)
**Status:** Needs revision  
**Problem:** Tables exist but not all in `ops` schema as described

**Current State:**
```sql
-- Tables actually exist in tracking schema (from ref/supabase-tracking)
-- NOT in ops schema as issue describes
tracking.tracking_folder
tracking.tracking_plan
tracking.tracking_plan_style
tracking.tracking_plan_style_timeline
tracking.tracking_timeline_assignment
```

**What's in ops schema:**
```sql
ops.tracking_plan_dependencies  -- Only this table uses ops schema
```

**Proposed Fix:**
- Update issue to reference `tracking` schema (not `ops`)
- Verify tables from Phase 1 (ref/supabase-tracking) are accessible
- Confirm webhook can write to these tables
- Check that migrations 001-013 have been applied

**Revised Acceptance Criteria:**
- [ ] All `tracking.*` tables exist and are accessible
- [ ] Edge function has INSERT/UPDATE permissions
- [ ] Webhook sync log tables exist
- [ ] RLS policies allow webhook writes

---

#### ✅ Issue #3: Run Migration 009 (VALID - HIGH PRIORITY)
**Status:** Ready to create  
**Changes Needed:** None

**Validation:**
- Migration file exists: `supabase/migrations/009_disable_timeline_date_calculation_triggers.sql`
- Purpose is critical: Disables triggers that would conflict with webhook dates
- Must be run before webhook deployment
- Well documented with clear rationale

**Note:** This is correctly marked as CRITICAL priority.

---

### Section 2: Deployment Issues

#### ✅ Issue #4: Configure Secrets (VALID)
**Status:** Ready to create  
**Changes Needed:** None

**Validation:**
- All required environment variables identified
- Clear instructions for setting secrets
- Webhook secret generation guidance provided

---

#### ✅ Issue #5: Deploy Edge Function (VALID)
**Status:** Ready to create  
**Changes Needed:** Minor enhancement

**Proposed Addition:**
- Add validation step to check function responds with 401 for unauthorized requests
- Include smoke test with sample payload

---

#### ✅ Issues #6-9: Testing (VALID)
**Status:** Ready to create  
**Changes Needed:** None

**Validation:**
- Test payloads exist: `docs/supabase/supabase-beproduct-migration/99-webhook-payloads/tracking/`
- Clear acceptance criteria
- Good coverage of all event types

---

#### ✅ Issues #10-12: Staging & Production (VALID)
**Status:** Ready to create  
**Changes Needed:** None

---

#### ✅ Issue #13: Documentation (VALID)
**Status:** Ready to create  
**Changes Needed:** None

---

## Section 3: MISSING API ENDPOINT ISSUES

### ⚠️ CRITICAL GAP IDENTIFIED

The proposed issues focus exclusively on **webhook deployment** (BeProduct → Supabase sync). However, frontend developers need **Supabase REST API endpoints** to replace their current BeProduct API calls.

### Current BeProduct APIs Frontend Uses

From `beproduct-api-mapping.md` and `endpoint-design.md`, frontend currently calls:

#### 1. Plan Search & Retrieval
```
BeProduct: GET /api/{company}/Tracking/Folders
Supabase: ❌ NOT AVAILABLE YET

BeProduct: GET /api/{company}/Tracking/Plan/{planId}
Supabase: ❌ NOT AVAILABLE YET
```

#### 2. Style Timeline Queries
```
BeProduct: Operation: planStyleTimeline (pagination, filtering)
Supabase: ❌ NOT AVAILABLE YET

Needed capabilities:
- Get all styles in a plan
- Filter by status, late flag, colorway
- Paginate results (50-100 items per page)
- Sort by multiple columns
```

#### 3. Timeline Updates
```
BeProduct: PATCH to update milestone status/dates
Supabase: ❌ NOT AVAILABLE YET

Needed capabilities:
- Bulk update milestones
- Update individual milestone
- Trigger date recalculation for dependencies
```

#### 4. Progress/Reporting
```
BeProduct: Progress aggregation by phase/department
Supabase: ❌ NOT AVAILABLE YET

Needed capabilities:
- Plan completion percentage
- Status breakdown (not_started, in_progress, approved)
- Late milestone count
- Group by phase/department
```

### What EXISTS Today

From `ref/supabase-tracking/api-endpoints/CURRENT-ENDPOINTS.md`:

**✅ Available (9 Read-Only Endpoints):**
1. `/rest/v1/v_folder` - Folder list
2. `/rest/v1/v_folder_plan` - Plan metadata
3. `/rest/v1/v_folder_plan_columns` - Column configs
4. `/rest/v1/v_timeline_template` - Templates
5. `/rest/v1/v_timeline_template_item` - Template items
6. `/rest/v1/v_plan_styles` - Style summaries
7. `/rest/v1/v_plan_style_timelines_enriched` - Detailed timelines
8. `/rest/v1/v_plan_materials` - Material summaries (empty)
9. `/rest/v1/v_plan_material_timelines_enriched` - Material timelines (empty)

**❌ Missing:**
- No CRUD operations (POST/PATCH/DELETE)
- No bulk update endpoints
- No progress/aggregation endpoints
- No enhanced filtering beyond PostgREST standard
- No permission/sharing endpoints

### Gap Analysis

| Functionality | BeProduct API | Supabase Current | Gap |
|--------------|---------------|------------------|-----|
| **Read Operations** |
| Get folders | ✅ Available | ✅ `/v_folder` | None |
| Get plans in folder | ✅ Available | ✅ `/v_folder_plan` | None |
| Get plan details | ✅ Available | ✅ `/v_folder_plan` | None |
| Get styles in plan | ✅ Available | ✅ `/v_plan_styles` | None |
| Get style timelines | ✅ Available | ✅ `/v_plan_style_timelines_enriched` | None |
| Get plan progress | ✅ Available | ❌ Not available | **MISSING** |
| Search/filter styles | ✅ Advanced | ⚠️ Basic PostgREST | **ENHANCEMENT NEEDED** |
| **Write Operations** |
| Update milestone status | ✅ Available | ❌ Not available | **MISSING** |
| Bulk update milestones | ✅ Available | ❌ Not available | **MISSING** |
| Add style to plan | ✅ Available | ❌ Not available | **MISSING** |
| Remove style from plan | ✅ Available | ❌ Not available | **MISSING** |
| Update assignments | ✅ Available | ❌ Not available | **MISSING** |
| Update sharing | ✅ Available | ❌ Not available | **MISSING** |

### Recommended Approach

From `ref/supabase-tracking/plans/endpoint-consolidation-and-naming-plan.md`:

**Phase 1: Enable Direct Table Access** (Quickest)
- Grant CRUD permissions on `tracking.*` tables
- Enable RLS with permissive policies
- Frontend uses PostgREST directly
- Timeline: 1-2 days

**Phase 2: Build Edge Functions** (Better performance/business logic)
- Create edge functions for complex operations
- Implement bulk updates with dependency recalculation
- Add progress/aggregation endpoints
- Timeline: 1-2 weeks

---

## Revised Issue Breakdown

### NEW: API Endpoint Issues (Insert BEFORE Issue #1)

#### Issue #0A: Enable CRUD on Tracking Tables
**Title:** `[02a-Tracking] Enable CRUD operations on tracking schema tables`  
**Labels:** `phase-02a-tracking`, `database`, `api`  
**Priority:** 🔴 CRITICAL - Blocks frontend development

**Description:**
```markdown
## Context
Frontend needs to perform CRUD operations on tracking data. Phase 1 approach: Grant direct table access via PostgREST.

## Required Changes

### 1. Grant Permissions
```sql
-- Grant CRUD on all tracking tables
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_folder TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style_timeline TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_assignment TO authenticated;
-- ... (all tracking tables)

GRANT USAGE ON ALL SEQUENCES IN SCHEMA tracking TO authenticated;
```

### 2. Enable RLS with Permissive Policies
```sql
-- Enable RLS (required for PostgREST exposure)
ALTER TABLE tracking.tracking_folder ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan ENABLE ROW LEVEL SECURITY;
-- ... (all tables)

-- Temporary: Allow all operations (refine in Phase 3)
CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_folder
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
-- ... (all tables)
```

### 3. Expose via PostgREST
```sql
-- Grant schema usage to anon role (public endpoints)
GRANT USAGE ON SCHEMA tracking TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA tracking TO anon;
```

## Testing

### Test CRUD Operations
```bash
# Test SELECT
curl "https://[project-id].supabase.co/rest/v1/tracking_folder" \
  -H "apikey: [key]" -H "Authorization: Bearer [key]"

# Test INSERT
curl -X POST "https://[project-id].supabase.co/rest/v1/tracking_plan" \
  -H "apikey: [key]" -H "Authorization: Bearer [key]" \
  -H "Content-Type: application/json" \
  -d '{"folder_id":"uuid","name":"Test Plan","season":"2026 Fall"}'

# Test UPDATE
curl -X PATCH "https://[project-id].supabase.co/rest/v1/tracking_plan_style_timeline?id=eq.uuid" \
  -H "apikey: [key]" -H "Authorization: Bearer [key]" \
  -H "Content-Type: application/json" \
  -d '{"status":"IN_PROGRESS","rev_date":"2025-11-15"}'

# Test DELETE (soft delete preferred)
curl -X PATCH "https://[project-id].supabase.co/rest/v1/tracking_plan_style?id=eq.uuid" \
  -H "apikey: [key]" -H "Authorization: Bearer [key]" \
  -H "Content-Type: application/json" \
  -d '{"active":false}'
```

## Success Criteria
- [ ] All tracking tables accessible via PostgREST
- [ ] Authenticated users can SELECT
- [ ] Authenticated users can INSERT
- [ ] Authenticated users can UPDATE
- [ ] Authenticated users can DELETE (or soft delete)
- [ ] Anon users can SELECT (read-only)
- [ ] No SQL errors in any CRUD operation
- [ ] All endpoints return correct JSON

## Dependencies
- Blocks: #[frontend migration issue]
- Depends on: Migration 009 (triggers disabled)

## Security Note
⚠️ Permissive RLS policies allow all authenticated users to access all data.  
Phase 3 will add proper user/brand/supplier filtering.
```

---

#### Issue #0B: Create Progress/Aggregation Endpoints
**Title:** `[02a-Tracking] Create edge functions for plan progress and aggregations`  
**Labels:** `phase-02a-tracking`, `edge-function`, `api`

**Description:**
```markdown
## Context
Frontend needs plan progress metrics (completion %, late count, status breakdown). PostgREST can't efficiently aggregate across tables.

## Required Edge Functions

### 1. Plan Progress
**Endpoint:** `GET /functions/v1/tracking-plan-progress?plan_id={uuid}`

**Response:**
```json
{
  "plan_id": "uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "total_milestones": 125,
  "by_status": {
    "NOT_STARTED": 109,
    "IN_PROGRESS": 11,
    "APPROVED": 5
  },
  "late_count": 10,
  "completion_percentage": 4.0,
  "by_phase": {
    "DEVELOPMENT": {
      "total": 50,
      "completed": 5,
      "late": 8
    }
  }
}
```

### 2. Folder Progress
**Endpoint:** `GET /functions/v1/tracking-folder-progress?folder_id={uuid}`

**Response:** Aggregates across all plans in folder

### 3. User Workload
**Endpoint:** `GET /functions/v1/tracking-user-workload?user_id={uuid}`

**Response:**
```json
{
  "user_id": "uuid",
  "user_name": "Natalie James",
  "total_assigned": 45,
  "by_status": {...},
  "late_count": 12,
  "assignments": [
    {
      "plan_name": "GREYSON 2026 SPRING DROP 1",
      "style_number": "MSP26B26",
      "milestone_name": "PROTO PRODUCTION",
      "due_date": "2025-09-16",
      "status": "IN_PROGRESS",
      "is_late": true
    }
  ]
}
```

## Implementation
- See `docs/supabase/supabase-beproduct-migration/02-timeline/docs/endpoint-design.md`
- Use Supabase client with SQL queries
- Enable CORS
- Add error handling
- Log all requests

## Testing
- Test with real plan data
- Validate aggregation accuracy
- Check performance (< 500ms for typical plan)
- Test with empty plans

## Success Criteria
- [ ] All 3 endpoints deployed
- [ ] Response times < 500ms
- [ ] Aggregation accuracy 100%
- [ ] CORS headers correct
- [ ] Error handling comprehensive

## Dependencies
- Depends on: #[enable CRUD issue]
```

---

#### Issue #0C: Create Bulk Update Endpoint
**Title:** `[02a-Tracking] Create edge function for bulk milestone updates`  
**Labels:** `phase-02a-tracking`, `edge-function`, `api`

**Description:**
```markdown
## Context
Frontend needs to update multiple milestones in a single operation (e.g., approve all SMS milestones).

## Required Edge Function

**Endpoint:** `POST /functions/v1/tracking-bulk-update`

**Request:**
```json
{
  "updates": [
    {
      "timeline_id": "uuid",
      "status": "IN_PROGRESS",
      "rev_date": "2025-11-15"
    },
    {
      "timeline_id": "uuid",
      "status": "APPROVED",
      "final_date": "2025-11-01"
    }
  ],
  "updated_by": "user-uuid"
}
```

**Response:**
```json
{
  "updated_count": 2,
  "errors": [],
  "updates": [
    {
      "timeline_id": "uuid",
      "old_status": "NOT_STARTED",
      "new_status": "IN_PROGRESS",
      "success": true
    }
  ]
}
```

## Business Logic
1. Validate all timeline_ids exist
2. Apply updates in transaction
3. Update `updated_at`, `updated_by` fields
4. Log to status history table
5. Return success/failure for each update

## Testing
- Test with 1, 10, 100 updates
- Test with invalid timeline_id
- Test with conflicting updates
- Test transaction rollback on error

## Success Criteria
- [ ] Endpoint deployed
- [ ] Handles up to 100 updates per request
- [ ] Transaction safety (all or nothing)
- [ ] Detailed error messages
- [ ] Performance < 2 seconds for 50 updates

## Dependencies
- Depends on: #[enable CRUD issue]
```

---

#### Issue #0D: Create API Documentation for Frontend
**Title:** `[02a-Tracking] Document Supabase tracking APIs for frontend migration`  
**Labels:** `phase-02a-tracking`, `documentation`, `frontend`  
**Priority:** 🔴 HIGH - Blocks frontend development

**Description:**
```markdown
## Context
Frontend developers need comprehensive API documentation to migrate from BeProduct APIs to Supabase APIs.

## Required Documentation

### 1. API Reference Document
**File:** `docs/supabase/supabase-beproduct-migration/02a-tracking/API-REFERENCE.md`

**Contents:**
- Base URL and authentication
- All available endpoints (PostgREST + Edge Functions)
- Request/response examples
- Error codes and handling
- Rate limiting (if applicable)
- Pagination patterns
- Filtering and sorting syntax

### 2. Migration Guide
**File:** `docs/supabase/supabase-beproduct-migration/02a-tracking/BEPRODUCT-TO-SUPABASE-MIGRATION.md`

**Contents:**
- BeProduct API → Supabase API mapping table
- Code examples (before/after)
- Breaking changes
- Enhanced capabilities (filtering, performance)
- Deprecation timeline

**Example Mapping:**
| BeProduct Operation | BeProduct Endpoint | Supabase Endpoint | Notes |
|---------------------|-------------------|-------------------|-------|
| Get folders | `GET /api/{co}/Tracking/Folders` | `GET /rest/v1/tracking_folder` | Same response structure |
| Get plan styles | `planStyleTimeline` | `GET /rest/v1/v_plan_styles?plan_id=eq.{uuid}` | Paginate with `limit` and `offset` |
| Update milestone | `PATCH /tracking/milestone/{id}` | `PATCH /rest/v1/tracking_plan_style_timeline?id=eq.{uuid}` | Direct table access |
| Bulk update | Not available | `POST /functions/v1/tracking-bulk-update` | New capability |

### 3. TypeScript Types
**File:** `docs/supabase/supabase-beproduct-migration/02a-tracking/typescript-types.ts`

**Contents:**
- Interface definitions for all API responses
- Request payload types
- Enum definitions (status, entity_type, etc.)
- Supabase client configuration examples

### 4. Postman Collection
**File:** `docs/supabase/supabase-beproduct-migration/02a-tracking/Supabase-Tracking-API.postman_collection.json`

**Contents:**
- Pre-configured requests for all endpoints
- Environment variables (project ID, API key)
- Example payloads
- Tests for each request

## Success Criteria
- [ ] API Reference document complete
- [ ] Migration guide complete with 10+ examples
- [ ] TypeScript types generated from schema
- [ ] Postman collection tested with all endpoints
- [ ] Frontend team reviews and approves documentation
- [ ] All examples tested and working

## Deliverables
1. `API-REFERENCE.md` (comprehensive endpoint documentation)
2. `BEPRODUCT-TO-SUPABASE-MIGRATION.md` (migration guide)
3. `typescript-types.ts` (type definitions)
4. `Supabase-Tracking-API.postman_collection.json` (Postman collection)

## Dependencies
- Depends on: #[enable CRUD issue]
- Depends on: #[progress endpoints issue]
- Depends on: #[bulk update issue]
```

---

### Revised Issue Sequence

**Updated Order (with new issues):**

1. **Issue #0A**: Enable CRUD on tracking tables 🔴 CRITICAL
2. **Issue #0B**: Create progress/aggregation endpoints
3. **Issue #0C**: Create bulk update endpoint
4. **Issue #0D**: Create API documentation for frontend 🔴 HIGH
5. **Issue #1**: Code review for webhook (original)
6. **Issue #2**: Validate database schema (REVISED - use `tracking` schema)
7. **Issue #3**: Run migration 009 (original) 🔴 CRITICAL
8. **Issue #4**: Configure Supabase secrets (original)
9. **Issue #5**: Deploy edge function (original)
10. **Issue #6-9**: Testing (original)
11. **Issue #10-12**: Staging & production (original)
12. **Issue #13**: Update documentation (original)

---

## Priority & Dependencies

### Critical Path 1: API Enablement (Unblocks Frontend)
```
#0A (Enable CRUD) 
  ↓
#0B (Progress endpoints) 
  ↓
#0C (Bulk update)
  ↓
#0D (API documentation)
  ↓
Frontend can begin migration
```

**Timeline:** 3-5 days  
**Owner:** Backend team

### Critical Path 2: Webhook Deployment (Unblocks Real-time Sync)
```
#1 (Code review)
  ↓
#2 (Validate schema) + #3 (Run migration 009) 🔴 MUST DO FIRST
  ↓
#4 (Configure secrets)
  ↓
#5 (Deploy function)
  ↓
#6-9 (Testing)
  ↓
#10 (Staging)
  ↓
#11 (Monitor)
  ↓
#12 (Production)
  ↓
#13 (Documentation)
```

**Timeline:** 5-7 days  
**Owner:** DevOps + Backend team

### Parallel Execution
- Critical Path 1 and 2 can run in parallel
- API work (Path 1) should start FIRST to unblock frontend
- Webhook work (Path 2) can proceed independently

---

## Summary of Changes

### Issues to ADD (4 new)
1. **#0A**: Enable CRUD on tracking tables
2. **#0B**: Create progress/aggregation endpoints  
3. **#0C**: Create bulk update endpoint
4. **#0D**: Create API documentation for frontend

### Issues to REVISE (1)
- **#2**: Change from `ops` schema to `tracking` schema validation

### Issues to KEEP AS-IS (12)
- Issues #1, #3-13 are valid and ready to create

---

## Recommendations

### Immediate Actions

1. **Create new API endpoint issues (#0A-0D)** BEFORE starting webhook deployment
2. **Assign #0A-0D to backend team** with HIGH priority
3. **Block frontend migration work** until #0D complete
4. **Revise #2** to reference `tracking` schema instead of `ops`
5. **Create all issues in GitHub** using provided templates

### Timeline

| Week | Focus | Deliverables |
|------|-------|-------------|
| Week 1 | API Enablement | Issues #0A-0D complete, frontend documentation ready |
| Week 1-2 | Webhook Pre-Deploy | Issues #1-3 complete, code reviewed, migration run |
| Week 2 | Webhook Testing | Issues #4-9 complete, all tests passing |
| Week 2-3 | Staging | Issues #10-11 complete, 24hr monitoring |
| Week 3 | Production | Issues #12-13 complete, full deployment |
| Week 3+ | Frontend Migration | Frontend team migrates from BeProduct APIs |

**Total Duration:** 3-4 weeks (with parallel execution)

### Success Metrics

#### API Enablement (Week 1)
- ✅ All CRUD operations working via PostgREST
- ✅ Progress endpoints returning accurate data
- ✅ Bulk update handles 100+ milestones
- ✅ API documentation complete
- ✅ Frontend team trained on new APIs

#### Webhook Deployment (Weeks 1-3)
- ✅ Migration 009 applied successfully
- ✅ Webhook processing success rate > 99%
- ✅ Average processing time < 2 seconds
- ✅ Zero data loss
- ✅ Production stable for 24+ hours

#### Frontend Migration (Week 3+)
- ✅ All BeProduct API calls replaced
- ✅ No degradation in UI performance
- ✅ Enhanced filtering/sorting working
- ✅ Zero production incidents

---

## Attachments

### Related Documents
- [Original Issues Breakdown](./GITHUB-ISSUES-BREAKDOWN.md)
- [Deployment Checklist](./DEPLOYMENT-CHECKLIST.md)
- [Implementation Summary](./IMPLEMENTATION-SUMMARY.md)
- [Endpoint Design Spec](../02-timeline/docs/endpoint-design.md)
- [Current Endpoints Status](../../../ref/supabase-tracking/api-endpoints/CURRENT-ENDPOINTS.md)
- [BeProduct API Mapping](../02-timeline/docs/beproduct-api-mapping.md)
- [Endpoint Consolidation Plan](../../../ref/supabase-tracking/plans/endpoint-consolidation-and-naming-plan.md)

---

**Review Status:** ✅ Complete  
**Reviewer:** Supabase Agent  
**Date:** November 9, 2025  
**Next Action:** Create revised issues in GitHub
