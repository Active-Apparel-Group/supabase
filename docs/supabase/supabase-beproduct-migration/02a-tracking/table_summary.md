

Searched text for `\.from\(` (`**/supabase/functions/beproduct-tracking-webhook/index.ts`), 12 results

Searched text for `\.from\(` (`**/supabase/functions/lindy-dependency-webhook/index.ts`), 4 results

## Edge Function Tables Summary

### **beproduct-tracking-webhook** (Main Webhook)
1. `tracking_folder` - upsert folder metadata
2. `tracking_plan` - check/upsert plan, fetch plan details
3. `tracking_plan_style` - upsert style records, soft delete
4. `tracking_plan_style_timeline` - upsert milestones, update status/dates
5. `tracking_timeline_assignment` - sync assignedTo users
6. `beproduct_sync_log` - log all webhook events

### **lindy-dependency-webhook** (Async Callback)
1. `tracking_plan` - verify plan exists before storing dependencies
2. `tracking_plan_dependencies` - delete existing + insert new dependencies (with START/END bookends)
3. `beproduct_sync_log` - log dependency fetch completion

---

## Tracking Tables NOT in Edge Function Workflow

### 🔴 Not Used (Yet)
1. `tracking_folder_style_link` - many-to-many folder↔style_folder mapping
2. `tracking_plan_view` - custom view definitions (columns, filters, sorting)
3. `tracking_plan_material` - material tracking (Phase 2)
4. `tracking_plan_material_timeline` - material milestones (Phase 2)
5. `tracking_plan_material_dependency` - material dependencies (Phase 2)
6. `tracking_plan_style_dependency` - style milestone dependencies (has 200 rows but not used in webhook)
7. `tracking_timeline_template` - template definitions (used for plan creation, not webhooks)
8. `tracking_timeline_template_item` - template milestone definitions (has 27 rows)
9. `tracking_timeline_template_visibility` - template milestone visibility by view
10. `tracking_timeline_status_history` - audit log for status changes (not yet implemented)

### Summary
- **Edge functions use: 7 tables** (6 tracking_* + beproduct_sync_log)
- **Not used in webhooks: 10 tracking_* tables** (templates, views, materials, dependencies, history)