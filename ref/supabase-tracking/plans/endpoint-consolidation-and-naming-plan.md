# Endpoint Consolidation & Naming Standardization Plan

**Date:** 2025-10-24  
**Status:** 🎯 Ready for Execution  
**Owner:** Backend Team → Frontend Team

---

## Objectives

1. **Consolidate endpoints**: Drop public views, use base tables only with CRUD operations
2. **Standardize naming**: Add `tracking_` prefix, enforce singular nouns
3. **Enable CRUD**: Grant permissions on base tables (defer RLS to Phase 3)
4. **Document handover**: Provide frontend team with clear migration guide

---

## Phase 1: Database Schema Refactoring ⚙️

**Duration:** 1-2 hours  
**Owner:** Backend  
**Risk:** Medium (requires table renames, view drops)

### 1.1 Rename Tables to Singular

**Changes:**

| Current Name | New Name | Reason |
| --- | --- | --- |
| `tracking.folder` | `tracking.tracking_folder` | Add prefix, prevent collisions |
| `tracking.plan` | `tracking.tracking_plan` | Add prefix, prevent collisions |
| `tracking.plan_views` | `tracking.tracking_plan_view` | Add prefix, singular |
| `tracking.plan_styles` | `tracking.tracking_plan_style` | Add prefix, singular |
| `tracking.plan_style_timelines` | `tracking.tracking_plan_style_timeline` | Add prefix, singular |
| `tracking.plan_style_dependencies` | `tracking.tracking_plan_style_dependency` | Add prefix, singular |
| `tracking.plan_materials` | `tracking.tracking_plan_material` | Add prefix, singular |
| `tracking.plan_material_timelines` | `tracking.tracking_plan_material_timeline` | Add prefix, singular |
| `tracking.plan_material_dependencies` | `tracking.tracking_plan_material_dependency` | Add prefix, singular |
| `tracking.timeline_templates` | `tracking.tracking_timeline_template` | Add prefix, singular |
| `tracking.timeline_template_items` | `tracking.tracking_timeline_template_item` | Add prefix, singular |
| `tracking.timeline_template_visibility` | `tracking.tracking_timeline_template_visibility` | Add prefix |
| `tracking.folder_style_links` | `tracking.tracking_folder_style_link` | Add prefix, singular |
| `tracking.timeline_assignments` | `tracking.tracking_timeline_assignment` | Add prefix, singular |
| `tracking.timeline_status_history` | `tracking.tracking_timeline_status_history` | Add prefix |

**Tables NOT Renamed (Internal/Support):**
- `tracking.import_batches` (internal import tracking)
- `tracking.import_errors` (internal import tracking)

**Migration:** See `supabase-tracking/migrations/0096_rename_tables_with_prefix.sql`

### 1.2 Drop Public Views

**Action:** Drop all `public.v_*` views (9 views total)

**Rationale:** Redundant with base table access; aggregates can be computed client-side or via tracking schema views

**Migration:** See `supabase-tracking/migrations/0097_drop_public_views.sql`

### 1.3 Create Tracking Schema Views (Optional - Future)

**Action:** Recreate aggregate views in `tracking` schema for complex queries

**View Naming Convention:**
- ✅ Use descriptive suffixes: `_summary`, `_aggregate`, `_rollup`
- ❌ Never use: `_enriched`, `v_` prefix

**Examples (if needed later):**
- `tracking.tracking_plan_style_summary` (with milestone aggregates)
- `tracking.tracking_plan_material_summary` (with milestone aggregates)
- `tracking.tracking_folder_plan_summary` (with counts)

### 1.4 Grant CRUD Permissions

**Action:** Grant SELECT, INSERT, UPDATE, DELETE on all tracking tables to `authenticated` role

**Migration:** See `supabase-tracking/migrations/0099_grant_crud_permissions.sql`

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_folder TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_view TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style_timeline TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_material TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_material_timeline TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_template TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_template_item TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_template_visibility TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style_dependency TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_material_dependency TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_folder_style_link TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_assignment TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_status_history TO authenticated;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA tracking TO authenticated;
```

**Security Note:** No RLS = all authenticated users see all data. Add RLS in Phase 4.;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.timeline_status_history TO authenticated;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA tracking TO authenticated;
```

**Security Note:** No RLS = all authenticated users see all data. Add RLS in Phase 3.

### 1.5 Expose Endpoints via PostgREST

**Action:** Grant schema USAGE and table SELECT to anon/authenticated roles

**Migrations:** 
- `0100_expose_tracking_endpoints.sql` (schema USAGE)
- `0101_grant_anon_select.sql` (anon SELECT on all tables)

```sql
GRANT USAGE ON SCHEMA tracking TO anon, authenticated;
GRANT SELECT ON tracking.tracking_* TO anon;
```

### 1.6 Enable RLS with Permissive Policies

**Action:** Enable RLS on all tracking tables with temporary "allow all" policies

**Migration:** See `supabase-tracking/migrations/0102_enable_rls_with_permissive_policies.sql`

**Why:** Supabase PostgREST requires RLS enabled to expose endpoints (security feature)

**Security Note:** 
- ✅ RLS enabled (PostgREST exposes endpoints)
- ⚠️ Policies are permissive (`USING (true)`) - all users see all data
- 🔒 **Phase 4 Action Required:** Replace `temp_allow_all_*` policies with brand-scoped policies

```sql
ALTER TABLE tracking.tracking_folder ENABLE ROW LEVEL SECURITY;
CREATE POLICY "temp_allow_all_folder_select" ON tracking.tracking_folder FOR SELECT USING (true);
-- Repeat for all 15 tables...
```

**Result:** Endpoints now accessible at `/rest/v1/tracking_folder`, `/rest/v1/tracking_plan`, etc.

### 1.7 Create Summary Views for Frontend

**Action:** Create tracking schema views with aggregates/joins to simplify frontend code

**Migration:** See `supabase-tracking/migrations/0103_create_tracking_summary_views.sql`

**Why:** Base tables are clean for CRUD but lack aggregates/joins from old public views

**Strategy:**
- **Reads:** Use `_summary` or `_detail` views (aggregates + joins handled in backend)
- **Writes:** Use base `tracking_*` tables (full CRUD support)

**Views Created:**
1. `tracking_folder_summary` → Plan counts per folder
2. `tracking_plan_summary` → Folder/template names + entity counts
3. `tracking_plan_style_summary` → Milestone aggregates + status_breakdown JSON
4. `tracking_plan_material_summary` → Milestone aggregates (material version)
5. `tracking_plan_style_timeline_detail` → Template item details + assignments
6. `tracking_timeline_template_detail` → Item counts per template

**Security Note:** Views use `security_invoker = true` to inherit RLS from base tables

**Frontend Impact:** No client-side aggregation needed! Views provide same simplicity as old public views.

**Migration Sequence:**
1. **0096_drop_all_views_first.sql** - Drop 19 views (10 public + 9 tracking)
2. **0097_drop_and_recreate_functions.sql** - Drop 2 functions + trigger (CASCADE)
3. **0098_rename_tables_and_recreate_functions.sql** - Rename 15 tables, recreate functions + trigger
4. **0099_grant_crud_permissions.sql** - Grant CRUD to authenticated
5. **0100_expose_tracking_endpoints.sql** - Grant schema USAGE
6. **0101_grant_anon_select.sql** - Grant SELECT to anon
7. **0102_enable_rls_with_permissive_policies.sql** - Enable RLS + 58 temp policies
8. **0103_create_tracking_summary_views.sql** - Create 6 summary views

**Exit Criteria:**
- ✅ All tables renamed to `tracking.tracking_*` (singular, prefixed)
- ✅ Public views dropped (19 views: 10 public + 9 tracking)
- ✅ Functions recreated with new table names (2 functions)
- ✅ Trigger recreated on renamed table (`trg_instantiate_style_timeline`)
- ✅ CRUD permissions granted to `authenticated` role
- ✅ SELECT permissions granted to `anon` role
- ✅ Schema usage granted to `anon` and `authenticated`
- ✅ RLS enabled on all 15 tracking tables
- ✅ Permissive policies created (58 policies: `temp_allow_all_*`)
- ✅ Summary views created (6 views) with `security_invoker = true`
- ✅ Endpoints accessible at `/rest/v1/tracking_*` and `/rest/v1/tracking_*_summary`
- ⏳ Test CRUD operations via PowerShell/Postman
- ✅ Foreign keys and indexes still functional after renames
**Owner:** Backend  
**Risk:** Low (documentation only)

### 2.1 Update Core Documentation

**Files to Update:**

1. **`docs/03-import-and-api-plan.md`**
   - Section 4.2: Replace view table with base table endpoints
   - Section 4.4: Update seed data snapshot table names
   - Section 8.2: Update view SQL to reference new table names

2. **`docs/05-frontend-implementation-plan.md`**
   - Section 2: Update backend readiness table (table names, endpoint URLs)
   - Section 4: Update API quick reference table
   - Section 5: Update task specifications (all table/view references)

3. **`docs/crud-endpoint-status.md`**
   - Section 2: Replace dual-endpoint table with single table list
   - Section 3: Update "What Phase 2 supports" capabilities
   - Section 6: Update usage examples with new table names

4. **`docs/99-phase-2-crud-enablement-plan.md`**
   - Update all SQL examples with new table names
   - Update migration sequence with actual migration numbers
   - Add note about singular naming convention

5. **`docs/AUDIT-2025-10-24.md`**
   - Section 1.1: Update table name column
   - Section 1.2: Remove public views, add tracking table endpoints

6. **`docs/prd.md`**
   - Update any table/endpoint references to singular naming

**Exit Criteria:**
- ✅ All docs reference singular table names
- ✅ All docs reference `/rest/v1/tracking_*` endpoints
- ✅ No references to `public.v_*` views
- ✅ BeProduct MCP tool mappings updated

---

## Phase 3: Frontend Handover 🎁

**Duration:** Immediate (after Phase 2 complete)  
**Owner:** Backend → Frontend  
**Risk:** Low

### 3.1 Deliver Migration Guide

**Document:** [`plans/frontend-endpoint-migration-guide.md`](./frontend-endpoint-migration-guide.md) ✅ **COMPLETE**

**Contents:**
- ✅ Endpoint mapping table (old → new)
- ✅ Summary view strategy (reads = views, writes = base tables)
- ✅ Breaking changes resolved with backend aggregation
- ✅ Complete code examples (read + write pattern)
- ✅ Summary view schema documentation (6 views)
- ✅ Security status (RLS permissive + Phase 4 roadmap)
- ✅ Testing checklist

### 3.2 Frontend Team Actions

**Checklist for Frontend Developer:**

- [ ] **Replace all endpoint URLs**
  - Find: `/rest/v1/v_folder` → Replace: `/rest/v1/tracking_folder`
  - Find: `/rest/v1/v_folder_plan` → Replace: `/rest/v1/tracking_plan` (join to folder client-side)
  - Find: `/rest/v1/v_plan_styles` → Replace: `/rest/v1/tracking_plan_style`
  - Find: `/rest/v1/v_plan_style_timelines_enriched` → Replace: `/rest/v1/tracking_plan_style_timeline`
  - *(See full mapping in handover doc)*

- [ ] **Update data fetching logic**
  - Views returned aggregates (e.g., `milestones_total`) → Compute client-side or fetch separately
  - Views returned joined data → Use PostgREST `select` with joins or fetch related entities separately

- [ ] **Handle missing computed fields**
  - Example: `v_plan_styles.milestones_total` → Count `tracking_plan_style_timeline` rows client-side
  - Example: `v_plan_styles.status_breakdown` → Aggregate statuses client-side

- [ ] **Update TypeScript types**
  - Regenerate types: `supabase gen types typescript --project-id <id> > types/supabase.ts`
  - Replace all `v_*` types with base table types

- [ ] **Test CRUD operations**
  - Test INSERT on `tracking_folder`, `tracking_plan`
  - Test UPDATE on `tracking_plan_style_timeline` (status changes)
  - Test DELETE on test entities

- [ ] **Update table/field references in code**
  - Plural → Singular (e.g., `plan_styles` → `plan_style`)
  - View names → Table names (e.g., `v_folder_plan` → `plan` + join to `folder`)

**Exit Criteria:**
- ✅ Frontend developer confirms all endpoints updated
- ✅ Frontend developer confirms CRUD operations work
- ✅ Frontend developer confirms no console errors
- ✅ QA validates UI functionality unchanged

---

## Phase 4: RLS Brand-Scoped Policies (Future) 🔒

**Duration:** TBD  
**Owner:** Backend + Auth Team  
**Risk:** High (security-critical)  
**Trigger:** After user authentication and metadata population is complete

**Current State (Phase 1):**
- ✅ RLS enabled on all 15 tracking tables
- ⚠️ Policies are permissive: `temp_allow_all_*` with `USING (true)`
- 📊 All authenticated users see all data (no brand filtering)

**Prerequisites:**
- [ ] User authentication implemented (Supabase Auth or external IDP)
- [ ] User metadata schema defined (`user_metadata.brands`, `user_metadata.role`)
- [ ] Test users created with brand assignments
- [ ] Admin UI for user/brand management built

**Actions:**
- [ ] **Drop all `temp_allow_all_*` policies** (58 policies)
- [ ] Apply brand-scoped RLS policies (from `99-phase-2-crud-enablement-plan.md`)
- [ ] Test with real JWT tokens containing `user_metadata.brands`
- [ ] Validate performance with EXPLAIN ANALYZE
- [ ] Update frontend to handle permission errors (401/403)

**Example Brand-Scoped Policy:**
```sql
-- Replace temp_allow_all_folder_select with:
DROP POLICY "temp_allow_all_folder_select" ON tracking.tracking_folder;

CREATE POLICY "brand_scoped_folder_select" ON tracking.tracking_folder
  FOR SELECT USING (
    brand = ANY(
      COALESCE(
        (auth.jwt() -> 'user_metadata' ->> 'brands')::text[],
        '{}'::text[]
      )
    )
  );
```

**See:** `docs/99-phase-2-crud-enablement-plan.md` for full RLS implementation plan

---

## Endpoint Reference (Post-Migration)

### Core Endpoints

| Entity | Endpoint | Methods | BeProduct MCP Tool |
| --- | --- | --- | --- |
| **Folders** | `/rest/v1/tracking_folder` | GET, POST, PATCH, DELETE | `beproduct-tracking.folderList` |
| **Plans** | `/rest/v1/tracking_plan` | GET, POST, PATCH, DELETE | `beproduct-tracking.planSearch`, `planGet` |
| **Plan Views** | `/rest/v1/tracking_plan_view` | GET, POST, PATCH, DELETE | (embedded in plan payloads) |
| **Styles** | `/rest/v1/tracking_plan_style` | GET, POST, PATCH, DELETE | `beproduct-tracking.planStyleView` |
| **Style Timelines** | `/rest/v1/tracking_plan_style_timeline` | GET, POST, PATCH, DELETE | `beproduct-tracking.planStyleTimeline` |
| **Materials** | `/rest/v1/tracking_plan_material` | GET, POST, PATCH, DELETE | `beproduct-tracking.planMaterialView` |
| **Material Timelines** | `/rest/v1/tracking_plan_material_timeline` | GET, POST, PATCH, DELETE | `beproduct-tracking.planMaterialTimeline` |
| **Templates** | `/rest/v1/tracking_timeline_template` | GET, POST, PATCH, DELETE | (extracted from timeline payloads) |
| **Template Items** | `/rest/v1/tracking_timeline_template_item` | GET, POST, PATCH, DELETE | (nested in template) |

### Supporting Endpoints

| Entity | Endpoint | Methods | Notes |
| --- | --- | --- | --- |
| Dependencies (Style) | `/rest/v1/tracking_plan_style_dependency` | GET, POST, DELETE | Milestone predecessors |
| Dependencies (Material) | `/rest/v1/tracking_plan_material_dependency` | GET, POST, DELETE | Milestone predecessors |
| Assignments | `/rest/v1/tracking_timeline_assignment` | GET, POST, DELETE | Per-milestone assignees |
| Status History | `/rest/v1/tracking_timeline_status_history` | GET | Audit log (read-only for users) |
| Folder Style Links | `/rest/v1/tracking_folder_style_link` | GET, POST, DELETE | Cross-folder style refs |

### Example Queries

**Fetch all folders:**
```http
GET /rest/v1/tracking_folder?active=eq.true
```

**Fetch plans in a folder:**
```http
GET /rest/v1/tracking_plan?folder_id=eq.{uuid}&select=*,tracking_folder(name,brand)
```

**Fetch styles with timeline count:**
```http
GET /rest/v1/tracking_plan_style?plan_id=eq.{uuid}&select=*,tracking_plan_style_timeline(count)
```

**Update timeline status:**
```http
PATCH /rest/v1/tracking_plan_style_timeline?id=eq.{uuid}
Content-Type: application/json

{
  "status": "COMPLETE",
  "completed_date": "2025-10-24"
}
```

---

## Risk Mitigation

| Risk | Mitigation |
| --- | --- |
| **Breaking frontend during Phase 1** | Deploy after hours; coordinate with frontend team |
| **Lost aggregates from views** | Document compute-client-side patterns; create tracking views if needed |
| **Performance degradation** | Monitor query times; add indexes if needed; consider materialized views |
| **Data inconsistency during rename** | Use transactions; test rollback procedure |
| **Anonymous access breaks** | Keep anonymous SELECT on new endpoints; adjust in Phase 4 |

---

## Success Metrics

- ✅ Zero public views remaining
- ✅ All endpoints follow `tracking_*` naming
- ✅ All tables use singular nouns
- ✅ Frontend can perform CRUD operations
- ✅ Documentation 100% accurate
- ✅ No performance regressions (<50ms for typical queries)

---

## Timeline

| Phase | Duration | Owner | Dependencies |
| --- | --- | --- | --- |
| Phase 1: Schema Refactoring | 1-2 hours | Backend | None |
| Phase 2: Doc Updates | 1 hour | Backend | Phase 1 complete |
| Phase 3: Frontend Handover | Immediate | Backend → Frontend | Phase 2 complete |
| Phase 3: Frontend Migration | 2-4 hours | Frontend | Handover doc received |
| Phase 4: RLS (Future) | TBD | Backend + Auth | Auth system ready |

**Total Estimated Time (Phases 1-3):** 4-7 hours  
**Go-Live Target:** Complete Phases 1-2 in one session; coordinate Phase 3 with frontend availability

---

## Rollback Plan

**If issues arise during Phase 1:**

1. Restore database from backup (Supabase PITR)
2. Revert migrations in reverse order
3. Re-apply old public views
4. Notify frontend team to halt changes

**Rollback Window:** 24 hours (Supabase PITR retention)

---

## Documents Affected

- ✅ `docs/03-import-and-api-plan.md`
- ✅ `docs/05-frontend-implementation-plan.md`
- ✅ `docs/crud-endpoint-status.md`
- ✅ `docs/99-phase-2-crud-enablement-plan.md`
- ✅ `docs/AUDIT-2025-10-24.md`
- ✅ `docs/prd.md`
- 📝 `plans/frontend-endpoint-migration-guide.md` ← **TO BE CREATED**

---

## Handover Gate

**Frontend team can begin work after:**
- ✅ Phase 1 migrations applied and tested
- ✅ Phase 2 documentation updated
- ✅ `plans/frontend-endpoint-migration-guide.md` delivered
- ✅ Backend confirms all endpoints operational
- ✅ Sample CRUD requests tested and documented

**Handover Checklist:**
- [ ] Email frontend team with migration guide link
- [ ] Schedule 30-min walkthrough call
- [ ] Provide test environment credentials
- [ ] Share Postman collection with example requests
- [ ] Establish Slack channel for migration questions

---

**Status:** 🟢 Ready to Execute  
**Next Action:** Apply Phase 1 migrations  
**Owner:** @backend-team  
**Reviewer:** @frontend-lead
