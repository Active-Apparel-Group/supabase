# CRUD Endpoint Status Report

**Date:** 2025-10-24  
**Status:** Phase 2 = CRUD operations enabled via PostgREST + RLS policies

---

## 1. Summary

Phase 2 enables full CRUD operations on tracking schema tables. Direct table access is granted with Row Level Security (RLS) policies enforcing brand-based access control. The nine public views remain available for read-only queries, while base tables support INSERT, UPDATE, and DELETE operations for authenticated users.

---

## 2. Available endpoints

### 2.1 Read-Only Views (GET)

| # | View | REST endpoint | Methods | Notes |
| --- | --- | --- | --- | --- |
| 1 | `public.v_folder` | `/rest/v1/v_folder` | `GET` | Folder directory with plan counts and active seasons. |
| 2 | `public.v_folder_plan` | `/rest/v1/v_folder_plan` | `GET` | Plan roster with template linkage, style/material counts, date ranges. |
| 3 | `public.v_folder_plan_columns` | `/rest/v1/v_folder_plan_columns` | `GET` | Flattened column configuration for plan grids. |
| 4 | `public.v_timeline_template` | `/rest/v1/v_timeline_template` | `GET` | Timeline template catalog (Garment Tracking seed available). |
| 5 | `public.v_timeline_template_item` | `/rest/v1/v_timeline_template_item` | `GET` | Ordered milestone definitions with dependency offsets and supplier visibility flags. |
| 6 | `public.v_plan_styles` | `/rest/v1/v_plan_styles` | `GET` | Styles inside a plan with milestone aggregates and supplier labels. |
| 7 | `public.v_plan_style_timelines_enriched` | `/rest/v1/v_plan_style_timelines_enriched` | `GET` | Detailed style milestones (27 rows/style in GREYSON seed). |
| 8 | `public.v_plan_materials` | `/rest/v1/v_plan_materials` | `GET` | Material roster (empty until trims importer runs). |
| 9 | `public.v_plan_material_timelines_enriched` | `/rest/v1/v_plan_material_timelines_enriched` | `GET` | Material milestone payload (currently empty). |

### 2.2 Writable Tables (Full CRUD)

| # | Table | REST endpoint | Methods | RLS Policy |
| --- | --- | --- | --- | --- |
| 1 | `tracking.folder` | `/rest/v1/folder` | `GET, POST, PATCH, DELETE` | Brand-scoped access |
| 2 | `tracking.plan` | `/rest/v1/plan` | `GET, POST, PATCH, DELETE` | Brand-scoped access |
| 3 | `tracking.plan_views` | `/rest/v1/plan_views` | `GET, POST, PATCH, DELETE` | Via plan access |
| 4 | `tracking.plan_styles` | `/rest/v1/plan_styles` | `GET, POST, PATCH, DELETE` | Via plan access |
| 5 | `tracking.plan_style_timelines` | `/rest/v1/plan_style_timelines` | `GET, POST, PATCH, DELETE` | Via plan access |
| 6 | `tracking.plan_materials` | `/rest/v1/plan_materials` | `GET, POST, PATCH, DELETE` | Via plan access |
| 7 | `tracking.plan_material_timelines` | `/rest/v1/plan_material_timelines` | `GET, POST, PATCH, DELETE` | Via plan access |
| 8 | `tracking.timeline_templates` | `/rest/v1/timeline_templates` | `GET, POST, PATCH, DELETE` | Authenticated users |
| 9 | `tracking.timeline_template_items` | `/rest/v1/timeline_template_items` | `GET, POST, PATCH, DELETE` | Via template access |

**Authentication:**

Use the authenticated user JWT token (not anonymous key) for write operations:

```javascript
const headers = {
  apikey: SUPABASE_ANON_KEY,
  Authorization: `Bearer ${userSession.access_token}` // User JWT with brand claims
};
```

---

## 3. What Phase 2 supports

**Read Operations (All Users):**
- ✅ Folder & plan browsing via views
- ✅ Timeline template inspection
- ✅ Style/material timeline drill-down with aggregates
- ✅ Progress tracking and status breakdowns

**Write Operations (Authenticated Users with Brand Access):**
- ✅ Folder creation and editing
- ✅ Plan CRUD (create, update, archive)
- ✅ Plan view configuration (column layouts, filters)
- ✅ Style/material assignment to plans
- ✅ Timeline status and date updates
- ✅ Timeline assignments (assignedTo arrays)
- ✅ Supplier sharing (shareWith arrays)
- ✅ Template creation and editing

**Business Logic (Edge Functions - Future):**
- ⏳ Template application (clone template items to plan)
- ⏳ Bulk timeline updates (status propagation)
- ⏳ Analytics RPCs (`get_plan_progress_delta`, etc.)
- ⏳ Supplier portal snapshot views

---

## 4. Row Level Security (RLS) Policies

All tracking tables have RLS enabled with the following policy structure:

### 4.1 Brand-Scoped Access (Folders, Plans)

```sql
-- Users can only see/edit folders and plans for their assigned brands
CREATE POLICY "brand_access" ON tracking.folder
  FOR ALL USING (
    brand = ANY(
      (auth.jwt() -> 'user_metadata' -> 'brands')::jsonb
    )
  );

CREATE POLICY "brand_access" ON tracking.plan
  FOR ALL USING (
    brand = ANY(
      (auth.jwt() -> 'user_metadata' -> 'brands')::jsonb
    )
  );
```

### 4.2 Cascading Access (Styles, Materials, Timelines)

```sql
-- Users can access styles/materials if they can access the parent plan
CREATE POLICY "plan_access" ON tracking.plan_styles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM tracking.plan p
      WHERE p.id = plan_styles.plan_id
        AND p.brand = ANY(
          (auth.jwt() -> 'user_metadata' -> 'brands')::jsonb
        )
    )
  );
```

### 4.3 Template Access (Authenticated Users)

```sql
-- All authenticated users can read templates
CREATE POLICY "templates_read" ON tracking.timeline_templates
  FOR SELECT USING (auth.role() = 'authenticated');

-- Only admins can create/edit templates
CREATE POLICY "templates_write" ON tracking.timeline_templates
  FOR INSERT, UPDATE, DELETE USING (
    (auth.jwt() -> 'user_metadata' -> 'role')::text = 'admin'
  );
```

### 4.4 Service Role Bypass

- Import scripts use service role key (bypasses RLS)
- Edge Functions run as service role for complex operations
- User-facing APIs enforce RLS policies

---

## 5. Migration Status

**Phase 2 Migrations Applied:**
- ✅ `0096_enable_rls_on_tracking_tables` — Enable RLS on all base tables
- ✅ `0097_create_brand_access_policies` — Brand-scoped folder/plan policies
- ✅ `0098_create_cascading_access_policies` — Style/material/timeline policies
- ✅ `0099_create_template_access_policies` — Template CRUD policies
- ✅ `0100_grant_authenticated_crud_permissions` — GRANT INSERT/UPDATE/DELETE to authenticated role

**Audit Log:**
- All mutations trigger `updated_at` timestamp updates via triggers
- Status changes logged in `tracking.timeline_status_history`
- Assignment changes tracked in `tracking.timeline_assignments`

---

## 6. Usage Examples

### 6.1 Create a New Plan

```javascript
const { data, error } = await supabase
  .from('plan')
  .insert({
    folder_id: 'uuid-of-folder',
    name: '2026 Spring Drop 4',
    brand: 'GREYSON',
    season: '2026 Spring',
    start_date: '2025-11-01',
    end_date: '2026-02-28',
    template_id: 'uuid-of-template'
  })
  .select()
  .single();
```

### 6.2 Update Timeline Status

```javascript
const { data, error } = await supabase
  .from('plan_style_timelines')
  .update({
    status: 'COMPLETE',
    completed_date: new Date().toISOString().split('T')[0]
  })
  .eq('id', 'uuid-of-timeline')
  .select();
```

### 6.3 Assign Users to Milestone

```javascript
const { data, error } = await supabase
  .from('plan_style_timelines')
  .update({
    shared_with: ['supplier-company-uuid-1', 'supplier-company-uuid-2']
  })
  .eq('id', 'uuid-of-timeline')
  .select();
```

---

## 7. Next Steps

**Completed:**
- ✅ RLS enabled on all base tables
- ✅ Brand-scoped policies implemented
- ✅ Direct table access granted to authenticated users
- ✅ Documentation updated

**Remaining:**
- ⏳ Build Edge Functions for complex operations (template apply, bulk updates)
- ⏳ Integrate with frontend (swap read-only UI for editable forms)
- ⏳ Add comprehensive audit logging and alerting
- ⏳ Implement analytics RPCs for dashboard widgets# CRUD Endpoint Status Report

**Date:** 2025-10-23  
**Status:** READ-ONLY ENDPOINTS ESTABLISHED

---

## 📊 Current Endpoint Status

### ✅ Available (GET Only)

All current endpoints are **READ-ONLY** via PostgREST:

| Table/View | GET Endpoint | INSERT | UPDATE | DELETE | Notes |
|------------|--------------|--------|--------|--------|-------|
| `public.v_folder` | ✅ `/rest/v1/v_folder` | ❌ | ❌ | ❌ | View only (read-only) |
| `public.v_folder_plan` | ✅ `/rest/v1/v_folder_plan` | ❌ | ❌ | ❌ | View only (read-only) |
| `public.v_folder_plan_columns` | ✅ `/rest/v1/v_folder_plan_columns` | ❌ | ❌ | ❌ | View only (read-only) |
| `public.v_timeline_template` | ✅ `/rest/v1/v_timeline_template` | ❌ | ❌ | ❌ | View only (read-only) |
| `public.v_timeline_template_item` | ✅ `/rest/v1/v_timeline_template_item` | ❌ | ❌ | ❌ | View only (read-only) |

**Current Permissions:**
- `GRANT SELECT ON public.v_* TO anon, authenticated` ✅
- No INSERT/UPDATE/DELETE permissions granted ❌
- RLS enabled with permissive SELECT policies ✅

---

## 🔒 Base Tables (Not Currently Exposed)

The underlying `tracking.*` tables exist but are **NOT** exposed via PostgREST:

| Table | Direct Access | CRUD Operations |
|-------|---------------|-----------------|
| `tracking.folder` | ❌ Not exposed | Not available via REST |
| `tracking.plans` | ❌ Not exposed | Not available via REST |
| `tracking.timeline_templates` | ❌ Not exposed | Not available via REST |
| `tracking.timeline_template_items` | ❌ Not exposed | Not available via REST |

---

## 🎯 Phase 1 Status: READ-ONLY UI

### What's Supported Now
✅ Browse folders  
✅ View plans within folders  
✅ View template list  
✅ View template items and structure  
✅ All metadata display (counts, names, etc.)

### What's NOT Supported
❌ Create new folders  
❌ Edit folder metadata  
❌ Create new plans  
❌ Edit plan details  
❌ Create new templates  
❌ Edit template items  
❌ Delete any entities  

---

## 🚀 Recommendation: Phase 1 Complete with READ-ONLY

**Conclusion:** Phase 1 should remain **READ-ONLY** for viewing and navigation:
- Folder browsing ✅
- Plan overview ✅
- Template viewing ✅

**Phase 2** can add edit/create functionality via:
1. **Edge Functions** (recommended for complex operations)
2. **Direct table access** (expose `tracking.folder`, `tracking.plans`, etc. with RLS)
3. **Stored procedures** (for complex CRUD with validation)

---

## 📋 Future CRUD Implementation Options

### Option 1: Expose Base Tables (Simple)

```sql
-- Grant INSERT/UPDATE/DELETE on base tables
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.folder TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.plans TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.timeline_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.timeline_template_items TO authenticated;

-- Add RLS policies for brand-based access
CREATE POLICY "Users can manage their brand folders" ON tracking.folder
  FOR ALL USING (brand = ANY(auth.jwt() -> 'user_metadata' -> 'brands'));

-- Endpoints become available:
-- POST /rest/v1/folder
-- PATCH /rest/v1/folder?id=eq.{uuid}
-- DELETE /rest/v1/folder?id=eq.{uuid}
```

**Pros:**
- Simple, direct REST API
- Standard PostgREST patterns
- Auto-generated OpenAPI docs

**Cons:**
- Less control over validation
- No complex business logic
- RLS policies can get complex

---

### Option 2: Edge Functions (Recommended)

Create Edge Functions for complex operations:

```typescript
// POST /functions/v1/folder-create
// POST /functions/v1/plan-create
// PATCH /functions/v1/plan-update
// POST /functions/v1/template-create
```

**Pros:**
- Full control over validation
- Can enforce business rules
- Can trigger side effects (notifications, audit logs)
- Can compose multiple operations
- Better error handling

**Cons:**
- More code to write
- Requires deployment process

---

### Option 3: Stored Procedures (Hybrid)

Create PostgreSQL functions and call via RPC:

```sql
CREATE FUNCTION tracking.create_folder(
  p_name text,
  p_brand text,
  p_style_folder_id uuid DEFAULT NULL
) RETURNS uuid AS $$
  -- Validation logic
  -- Insert with constraints
  -- Return new folder_id
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Call via: POST /rest/v1/rpc/create_folder
```

**Pros:**
- Business logic in database
- Atomic operations
- Can return computed values
- RPC pattern familiar to devs

**Cons:**
- SQL functions harder to test
- Less flexibility than Edge Functions
- Debugging can be harder

---

## 🎬 Next Steps for CRUD

### Immediate (Phase 1 Completion)
1. ✅ Document that Phase 1 is read-only
2. ✅ No changes needed - views work as-is
3. ⬜ Frontend devs build read-only UI

### Phase 2 Planning (Edit/Create)
1. ⬜ Decide on CRUD approach (Edge Functions recommended)
2. ⬜ Design validation rules and business logic
3. ⬜ Create RLS policies for brand-based access
4. ⬜ Implement create/edit/delete operations
5. ⬜ Add audit logging
6. ⬜ Test with frontend integration

---

## ✅ Phase 1 Recommendation

**Keep Phase 1 as READ-ONLY:**
- Simpler deployment
- No RLS complexity
- Frontend focuses on UI/UX
- Data safety (no accidental edits)
- Backend can prepare CRUD for Phase 2

**Phase 2 adds editing:**
- Full CRUD via Edge Functions
- Proper validation and business rules
- Audit logging and notifications
- Brand-based access control

---

**Document Version:** 1.0  
**Last Updated:** 2025-10-23  
**Decision Required:** Confirm Phase 1 stays read-only or add CRUD now?
