---
name: 02a-Tracking API CRUD Enablement
about: Enable CRUD operations on tracking schema tables
title: '[02a-Tracking] Enable CRUD operations on tracking schema tables'
labels: ['phase-02a-tracking', 'database', 'api']
assignees: ''
---

## Context
Frontend needs to perform CRUD operations on tracking data. Phase 1 approach: Grant direct table access via PostgREST.

**Priority:** 🔴 CRITICAL - Blocks frontend development

## Required Changes

### 1. Create Migration for CRUD Permissions

Create file: `supabase/migrations/014_enable_tracking_crud.sql`

```sql
-- Enable CRUD operations on tracking schema tables
-- Purpose: Allow frontend to read/write tracking data via PostgREST
-- Date: 2025-11-09

BEGIN;

-- Grant CRUD permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_folder TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_style_timeline TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_assignment TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_plan_view TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_template TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_timeline_template_item TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.tracking_folder_style_link TO authenticated;

-- Grant sequence usage
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA tracking TO authenticated;

-- Enable RLS (required for PostgREST exposure)
ALTER TABLE tracking.tracking_folder ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_style ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_style_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_timeline_assignment ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_plan_view ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_timeline_template ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_timeline_template_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.tracking_folder_style_link ENABLE ROW LEVEL SECURITY;

-- Create permissive policies (temporary - refine in Phase 3)
CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_folder
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_plan
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_plan_style
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_plan_style_timeline
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_timeline_assignment
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_plan_view
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_timeline_template
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_timeline_template_item
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON tracking.tracking_folder_style_link
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Grant schema usage to anon role (public read access)
GRANT USAGE ON SCHEMA tracking TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA tracking TO anon;

COMMENT ON SCHEMA tracking IS 'Tracking schema with CRUD enabled for authenticated users. RLS policies are permissive in Phase 1; will be refined in Phase 3 for user/brand/supplier filtering.';

COMMIT;
```

### 2. Apply Migration

```bash
cd supabase
npx supabase db push
```

### 3. Verify Deployment

```sql
-- Check RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'tracking' 
  AND tablename LIKE 'tracking_%';

-- Check policies exist
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'tracking';

-- Check permissions
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'tracking' 
  AND grantee IN ('authenticated', 'anon');
```

## Testing

### Test SELECT (Read)
```bash
curl "https://[project-id].supabase.co/rest/v1/tracking_folder" \
  -H "apikey: [anon-key]" \
  -H "Authorization: Bearer [anon-key]"
```

### Test INSERT (Create)
```bash
curl -X POST "https://[project-id].supabase.co/rest/v1/tracking_plan" \
  -H "apikey: [service-key]" \
  -H "Authorization: Bearer [service-key]" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "folder_id": "82a698e1-9103-4bab-98af-a0ec423332a2",
    "name": "Test Plan API",
    "season": "2026 Fall",
    "brand": "GREYSON"
  }'
```

### Test UPDATE (Modify)
```bash
# Update milestone status
curl -X PATCH "https://[project-id].supabase.co/rest/v1/tracking_plan_style_timeline?id=eq.[timeline-uuid]" \
  -H "apikey: [service-key]" \
  -H "Authorization: Bearer [service-key]" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "status": "IN_PROGRESS",
    "rev_date": "2025-11-15"
  }'
```

### Test DELETE (Soft Delete Preferred)
```bash
# Soft delete a style (set active = false)
curl -X PATCH "https://[project-id].supabase.co/rest/v1/tracking_plan_style?id=eq.[style-uuid]" \
  -H "apikey: [service-key]" \
  -H "Authorization: Bearer [service-key]" \
  -H "Content-Type: application/json" \
  -d '{"active": false}'
```

### Test PostgREST Filtering
```bash
# Get late milestones
curl "https://[project-id].supabase.co/rest/v1/tracking_plan_style_timeline?late=eq.true&order=due_date.asc" \
  -H "apikey: [anon-key]" \
  -H "Authorization: Bearer [anon-key]"

# Get styles in specific plan
curl "https://[project-id].supabase.co/rest/v1/tracking_plan_style?plan_id=eq.[uuid]&active=eq.true" \
  -H "apikey: [anon-key]" \
  -H "Authorization: Bearer [anon-key]"
```

## Success Criteria
- [ ] Migration created and syntax validated
- [ ] Migration applied successfully (`npx supabase db push`)
- [ ] All tracking tables have RLS enabled
- [ ] All tracking tables have permissive policies
- [ ] Authenticated users can SELECT from all tables
- [ ] Authenticated users can INSERT into all tables
- [ ] Authenticated users can UPDATE all tables
- [ ] Authenticated users can DELETE (or soft delete) from all tables
- [ ] Anon users can SELECT (read-only)
- [ ] All test queries return correct JSON responses
- [ ] No SQL errors in any CRUD operation
- [ ] PostgREST filtering and sorting work correctly

## Security Note
⚠️ **Permissive RLS policies allow all authenticated users to access all data.**

This is acceptable for Phase 1 development. Phase 3 will add proper filtering:
- Users see only their assigned timelines
- Brand managers see only their brand data
- Suppliers see only shared timelines
- Admin users see all data

## Dependencies
- **Blocks:** Frontend migration work
- **Depends on:** Migration 009 (triggers disabled)

## Related Documentation
- [PostgREST API Reference](https://postgrest.org/en/stable/references/api.html)
- [Supabase RLS Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Endpoint Consolidation Plan](../../../ref/supabase-tracking/plans/endpoint-consolidation-and-naming-plan.md)
