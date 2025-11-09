# 07-supabase-rls-and-permissions.md

## Supabase RLS and Permissions Configuration

This document summarizes the Row Level Security (RLS) and permissions configuration for all tracking-related tables in the BeProduct MCP Supabase schema as of October 2025.

---

### 1. RLS Status
- **RLS is enabled** on all main tracking tables:
  - tracking_folder
  - tracking_folder_style_link
  - tracking_plan
  - tracking_plan_view
  - tracking_plan_style
  - tracking_plan_style_timeline
  - tracking_plan_style_dependency
  - tracking_plan_material
  - tracking_plan_material_timeline
  - tracking_plan_material_dependency
  - tracking_timeline_template
  - tracking_timeline_template_item
  - tracking_timeline_template_visibility
  - tracking_timeline_assignment
  - tracking_timeline_status_history

---

### 2. Default RLS Policies (Permissive)
For each table, the following policies are in place (unless otherwise noted):
- **SELECT:** `USING (true)`
- **INSERT:** `WITH CHECK (true)`
- **UPDATE:** `USING (true)`
- **DELETE:** `USING (true)`

This means all authenticated users (including those using the anon key) can read, insert, update, and delete rows in these tables.

---

### 3. Example Policy (tracking_timeline_template_item)
```sql
CREATE POLICY "temp_allow_all_template_item_select" ON tracking.tracking_timeline_template_item FOR SELECT USING (true);
CREATE POLICY "temp_allow_all_template_item_insert" ON tracking.tracking_timeline_template_item FOR INSERT WITH CHECK (true);
CREATE POLICY "temp_allow_all_template_item_update" ON tracking.tracking_timeline_template_item FOR UPDATE USING (true);
CREATE POLICY "temp_allow_all_template_item_delete" ON tracking.tracking_timeline_template_item FOR DELETE USING (true);
```

---

### 4. Permissions Grants
All main tracking tables have the following grant:
```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON tracking.<table> TO authenticated;
```

---

### 5. Exceptions & Notes
- Some internal tables (e.g., import_batches, import_errors, beproduct_sync_log) may not have RLS enabled.
- If more restrictive policies are needed (e.g., brand/user-scoped), these permissive policies should be replaced.
- If you encounter a 401 Unauthorized error, check:
  - The API key/token role (anon vs. service role)
  - That the RLS policy for the operation is present and correct
  - That the grant exists for the `authenticated` role

---

### 6. Schema Quick Reference
See `reference-schema-quick-reference.md` for a summary of table columns and relationships.

---

### 7. Change Management
- All RLS and permission changes should be documented in this file and in the relevant migration SQL files.
- For stricter access, update or replace the `USING (true)`/`WITH CHECK (true)` policies with appropriate logic.

---

_Last updated: October 25, 2025_
