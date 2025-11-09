# BeProduct ↔ Supabase Tracking Import & API Plan

**Document version:** 1.1 • **Last updated:** 2025-10-25

This plan reflects the current Supabase project `wjpbryjgtmmaqjbhjgap` as of 2025-10-25. The live schema and REST surface were verified via MCP Supabase tooling alongside manual PostgREST calls. Use this document to guide data imports, service automation, and client integrations for the GREYSON pilot.

## 1. Objectives

- Mirror BeProduct tracking data into Supabase with deterministic identifiers and auditable history.
- Define the Supabase API surface (GraphQL + REST + Edge Functions) required for the tracking portal and automation.
- Capture open gaps (staging tables, upsert RPCs, RLS) and outline follow-up work.

## 2. Data acquisition workflow (MCP tooling)

| Step | Tool call | Purpose | Notes |
| --- | --- | --- | --- |
| 1 | `beproduct-tracking.folderList` | Enumerate tracking folders | Filter by brand; capture BeProduct `styleFolder` mapping. |
| 2 | `beproduct-tracking.planSearch` | Fetch plans per folder | Persist plan IDs, template linkage, default view info. |
| 3 | `beproduct-tracking.planStyleTimeline` | Pull detailed style timelines | Required for milestone → template mapping. |
| 4 | `beproduct-tracking.planMaterialTimeline` | Pull material timelines | Keeps material milestones in sync. |
| 5 | `beproduct-tracking.planStyleView` | Capture style column configuration | Needed for UI parity. |
| 6 | `beproduct-tracking.planMaterialView` | Capture material column configuration | Needed for UI parity. |
| 7 | `beproduct-masterdata.get` | Fetch enumerations (statuses, departments, roles) | Prevent enum drift. |
| 8 | `beproduct-tracking.planStyleProgress` | QA aggregates | Optional; validates milestone counts. |
| 9 | `beproduct-tracking.planMaterialProgress` | QA aggregates | Optional. |
| 10 | *(manual export)* timeline template HTML/JSON | Seed timeline templates | Normalize into `supabase-tracking/raw/timeline_template_{brand}.json`. |

Persist raw responses in `supabase-tracking/raw/` for reproducibility and regression testing.

## 3. Import architecture

### 3.1 Current Supabase structures

Operational tables already present in the `tracking` schema (see `02-supabase-schema-blueprint.md`):

- `tracking_folder` / `tracking_folder_style_link`
- `tracking_plan`, `tracking_plan_view`
- `tracking_plan_style`, `tracking_plan_style_timeline`, `tracking_plan_style_dependency`
- `tracking_plan_material`, `tracking_plan_material_timeline`, `tracking_plan_material_dependency`
- `tracking_timeline_template`, `tracking_timeline_template_item`, `tracking_timeline_template_visibility`
- `tracking_timeline_assignment`, `tracking_timeline_status_history`
- Import logs: `import_batches`, `import_errors`, `beproduct_sync_log`

Triggers automatically instantiate timelines (`trg_instantiate_style_timeline`) and cascade date recalculations. No staging tables or ETL-specific functions exist yet.

### 3.2 Staging layer (not yet created)

To support idempotent imports and rollbacks we still intend to add:

- `tracking.import_plans`
- `tracking.import_styles`
- `tracking.import_materials`
- `tracking.import_timelines`

These tables are **not** present in the live database. They remain a TODO item and are tracked in the “Gaps & follow-ups” sections of both this plan and the schema blueprint.

### 3.3 Upsert routines (planned)

No `fn_upsert_*` functions currently exist. The accepted pattern is to encapsulate operations in SQL (or Edge Functions) that perform the following:

| Proposed function | Responsibility | Status |
| --- | --- | --- |
| `tracking.fn_upsert_folder(payload jsonb)` | Upsert `tracking_folder` + `tracking_folder_style_link` | Pending |
| `tracking.fn_upsert_plan(payload jsonb)` | Upsert plan metadata + default view | Pending |
| `tracking.fn_upsert_plan_style(payload jsonb)` | Upsert styles & supplier access | Pending |
| `tracking.fn_upsert_plan_material(payload jsonb)` | Upsert trims | Pending |
| `tracking.fn_upsert_timeline(payload jsonb)` | Upsert milestone rows & dependencies | Pending |

All functions will log to `beproduct_sync_log` and write batch context to `import_batches` / `import_errors`.

### 3.4 Edge Function flow (`tracking-import-beproduct`)

Edge Functions are not yet deployed. The proposed flagship function should:

1. Accept `{ folderId, planIds?, includeMaterialTimelines?, dryRun? }`.
2. Call BeProduct tracking endpoints (Section 2) using the MCP service credentials.
3. Persist raw payloads to staging tables (once created).
4. Invoke the upsert SQL routines inside a transaction.
5. Write batch summaries to `import_batches` and `beproduct_sync_log`.
6. When `dryRun=true`, bypass SQL writes and return object diffs.

Secondary Edge Functions (`tracking-template-apply`, `tracking-timeline-action`, etc.) remain on the roadmap; none exist in the live project today.

### 3.5 Scheduling & cadence

- **Initial load:** manual invocation with service role key per folder/plan to verify templates.
- **Nightly sync (target):** Supabase cron hitting `tracking-import-beproduct` for GREYSON brands.
- **Spot refresh:** Admin panel button (service role) once Edge Function is live.
- **Future:** Webhook-driven incremental updates as BeProduct surfaces events.

## 4. Supabase API surface (current state)

### 4.1 GraphQL

Supabase GraphQL exposes tables and views with the exact identifiers listed below. Queries originate from the `tracking` schema; there are no `public` synonyms.

| Node | Type | Source | Purpose |
| --- | --- | --- | --- |
| `tracking_folder` | table | `tracking.tracking_folder` | Folder directory with brand + active flag. |
| `tracking_plan` | table | `tracking.tracking_plan` | Plan metadata (season, template, default view). |
| `tracking_plan_view` | table | `tracking.tracking_plan_view` | View metadata + `column_config` JSON. |
| `tracking_plan_style` | table | `tracking.tracking_plan_style` | Style/color/supplier rows. |
| `tracking_plan_style_timeline` | table | `tracking.tracking_plan_style_timeline` | Style milestone rows with trigger-managed dates. |
| `tracking_plan_material` | table | `tracking.tracking_plan_material` | Material roster (empty as of 2025-10-25). |
| `tracking_plan_material_timeline` | table | `tracking.tracking_plan_material_timeline` | Material milestones (empty). |
| `tracking_timeline_template` | table | `tracking.tracking_timeline_template` | Template headers. |
| `tracking_timeline_template_item` | table | `tracking.tracking_timeline_template_item` | Template nodes + offsets. |
| `tracking_timeline_template_visibility` | table | `tracking.tracking_timeline_template_visibility` | Template visibility flags. |
| `tracking_timeline_assignment` | table | `tracking.tracking_timeline_assignment` | Timeline assignee links. |
| `tracking_timeline_status_history` | table | `tracking.tracking_timeline_status_history` | Milestone status audit log. |
| `tracking_folder_summary` | view | `tracking.tracking_folder_summary` | Folder roll-up counts. |
| `tracking_plan_summary` | view | `tracking.tracking_plan_summary` | Plan-level counts + default view/template metadata. |
| `tracking_plan_style_summary` | view | `tracking.tracking_plan_style_summary` | Style-level aggregates. |
| `tracking_plan_style_timeline_detail` | view | `tracking.tracking_plan_style_timeline_detail` | Enriched style milestone payload. |
| `tracking_plan_material_summary` | view | `tracking.tracking_plan_material_summary` | Material-level aggregates (no rows yet). |
| `tracking_plan_material_timeline_detail` | view | `tracking.tracking_plan_material_timeline_detail` | Enriched material milestone payload (no rows yet). |
| `tracking_timeline_template_detail` | view | `tracking.tracking_timeline_template_detail` | Template node counts by applicability. |

**Interaction notes**

- Include UUID identifiers and timestamps in projections so the UI can compute diffs locally.
- Apply `order_by: {display_order: asc}` when querying timeline detail views to keep milestone ordering consistent.
- GraphQL returns nested JSON fields (e.g., `column_config`, `status_breakdown`) as scalars—clients should parse manually.
- Mutations against base tables are technically available but should be restricted via RLS; production writes will flow through Edge Functions or RPCs.
- Realtime subscriptions work on base tables (`tracking_plan_style_timeline` etc.), not views. Refresh derived data post-change.

### 4.2 REST (PostgREST)

Seven read-only endpoints are currently exposed under `/rest/v1/` with the Supabase anon/service role key. All have been confirmed via GET requests on 2025-10-25.

| # | Endpoint | Object | Purpose | Status |
| --- | --- | --- | --- | --- |
| 1 | `/rest/v1/tracking_folder_summary` | View | Folder counts (active vs total plans). | ✅ data present |
| 2 | `/rest/v1/tracking_plan_summary` | View | Plan overview with style/material metrics & template references. | ✅ data present |
| 3 | `/rest/v1/tracking_plan_style_summary` | View | Style roster with milestone aggregates. | ✅ data present |
| 4 | `/rest/v1/tracking_plan_style_timeline_detail` | View | Enriched style milestones (108 rows seeded). | ✅ data present |
| 5 | `/rest/v1/tracking_plan_material_summary` | View | Material roster aggregates. | ⚠️ empty (awaiting imports) |
| 6 | `/rest/v1/tracking_plan_material_timeline_detail` | View | Enriched material milestones. | ⚠️ empty |
| 7 | `/rest/v1/tracking_timeline_template_detail` | View | Template catalog (27 nodes). | ✅ data present |

**Usage tips**

- Authenticate using `apikey` + `Authorization: Bearer {SUPABASE_KEY}` headers.
- Filtering uses standard PostgREST syntax (e.g., `?plan_id=eq.{uuid}`).
- Apply `Prefer: count=exact` for pagination totals and `Range: 0-49` style headers for page slices.
- RLS mirrors the base tables; current GREYSON pilot data is accessible to anon/service roles. Brand-scoped policies remain outstanding.
- No write endpoints are enabled yet.

### 4.3 Future REST/RPC surface

Once upsert routines are implemented we will expose RPC endpoints such as:

- `tracking.get_plan_progress_delta`
- `tracking.apply_template_to_plan`
- `tracking.sync_style(plan_id uuid, style_header_id uuid)`

All will run under the service role and enforce custom authorization logic.

## 5. Observability & error handling

- **Retries:** Planned Edge Function wrapper should retry BeProduct calls (500 ms → 2 s → 5 s backoff).
- **Partial failures:** Commit successes, log failures to `import_errors`, and return payload-level diagnostics in the Edge Function response.
- **Monitoring:** Use Supabase logs plus a webhook that fires when `import_batches.status` transitions to `failed`.
- **Checksum:** Store SHA-256 hashes in `import_batches.hash` to skip duplicate payloads.
- **Status history:** `tracking_timeline_status_history` captures milestone transitions for audit. Consider surfacing this in UI v2.

## 6. Rollback strategy

- **Short-term:** Use Supabase point-in-time recovery (PITR) if catastrophic failure occurs prior to staging tables.
- **Post-staging:** Implement `tracking.fn_revert_to_batch(batch_id bigint)` to replay the last known-good snapshot from `import_*` tables (once created).
- **Dry runs:** Support `dryRun=true` in the Edge Function to validate payload diffs without committing new data.

## 7. Authorization matrix (target state)

| Role | GraphQL | REST | Edge Functions | Notes |
| --- | --- | --- | --- | --- |
| `admin` | Full CRUD | Full | All functions | Internal tech ops. |
| `manager` | Read + mutate timelines in permitted folders | Read-only | `tracking-timeline-action`, `tracking-plan-analytics` | No import capability. |
| `importer` | Read-only | Read-only | `tracking-import-beproduct`, `tracking-sync-*` | Service account. |
| `viewer` | Read-only | Read-only | None | Portal users. |

JWT tokens must include `brand_ids` used in folder/plan RLS policies. Implement RLS policies on base tables prior to production.

## 8. Naming conventions

- **Tables:** `tracking_{entity}` (singular). Example: `tracking_plan_style_timeline`.
- **Views:** `tracking_{context}_{suffix}` with `_summary` or `_detail` to indicate aggregation depth. Example: `tracking_plan_style_timeline_detail`.
- **Functions (mutating):** `fn_{verb}_{noun}`. Example: `fn_upsert_plan_style` (planned).
- **RPC exposers:** Imperative verbs (e.g., `get_plan_progress_delta`).
- **Indexes:** `idx_{table}_{columns}`. Example: `idx_tracking_plan_style_plan_id`.
- **FK constraints:** `fk_{child}_{parent}`. Example: `fk_tracking_plan_style_plan`.

## 9. Implementation status (2025-10-25)

### ✅ Completed
1. Baseline tracking tables, triggers, and reference data deployed (see schema blueprint).
2. Analytical views (`tracking_plan_*_summary`, `tracking_plan_*_timeline_detail`, `tracking_timeline_template_detail`) online and tested via REST.
3. REST surface confirmed (7 endpoints operational).
4. Enumerations synced via Postgres enums + `ref_*` tables.

### ⏳ Pending
1. Create staging tables (`tracking.import_*`).
2. Implement upsert SQL functions and expose RPC wrappers.
3. Deploy `tracking-import-beproduct` Edge Function with retry + batch logging.
4. Finalize RLS policies using JWT `brand_ids` for folder/plan scoping.
5. Add observability (Slack/webhook) for failed import batches.
6. Seed material data once BeProduct trims import is ready.

## 10. Try it

### 10.1 REST smoke tests

```powershell
$headers = @{ "apikey" = $env:SUPABASE_ANON_KEY; "Authorization" = "Bearer $($env:SUPABASE_ANON_KEY)" }
Invoke-RestMethod -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/tracking_plan_summary?limit=10" -Headers $headers
Invoke-RestMethod -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/tracking_plan_style_timeline_detail?plan_id=eq.1305c5e9-39d5-4686-926c-c88c620d4f8a&order=display_order.asc" -Headers $headers
```

### 10.2 GraphQL folder/plan overview

```graphql
query FolderPlanOverview($limit: Int = 20) {
  tracking_plan_summary(limit: $limit, order_by: {folder_name: asc, plan_name: asc}) {
    folder_id
    folder_name
    plan_id
    plan_name
    template_name
    style_count
    material_count
    updated_at
  }
}
```

### 10.3 Timeline detail for a single style

```graphql
query StyleTimeline($planStyleId: uuid!) {
  tracking_plan_style_timeline_detail(where: {plan_style_id: {_eq: $planStyleId}}, order_by: {display_order: asc}) {
    id
    milestone_name
    status
    due_date
    start_date_plan
    assignments
  }
}
```

## 11. Next steps

1. Design and migrate staging tables + upsert routines (ownership: data engineering).
2. Package Edge Function(s) with MCP credential management and deploy via Supabase CLI.
3. Implement RLS policies (brand filtering) and verify PostgREST/GraphQL adherence.
4. Populate material tables to validate dual-scope timelines before supplier pilot.
5. Automate nightly import and set up Slack alerts for failed batches.
# BeProduct ↔ Supabase Tracking Import & API Plan

**Document version:** 1.1 • **Last updated:** 2025-10-24

## 1. Objectives

- Provide a deterministic import pipeline that mirrors BeProduct tracking data into Supabase while preserving identifiers.
- Outline Supabase API surface (GraphQL + Edge Functions) required for front-end and automation use cases.
- Define ongoing sync cadence, error handling, and rollback strategies.

## 2. Data acquisition workflow (MCP tooling)

| Step | Tool call | Purpose | Notes |
| --- | --- | --- | --- |
| 1 | `beproduct-tracking.folderList` | Enumerate tracking folders | Scope by brand; capture `styleFolder` mapping |
| 2 | `beproduct-tracking.planSearch` | Fetch plans per folder | Save plan IDs, view templates |
| 3 | `beproduct-tracking.planStyleTimeline` | Pull detailed style timelines | Required for milestone + template mapping |
| 4 | `beproduct-tracking.planMaterialTimeline` | Pull material timelines | Mirrors style timeline to validate template toggles |
| 5 | `beproduct-tracking.planStyleView` | Capture column configuration | Needed for UI parity |
| 6 | `beproduct-tracking.planMaterialView` | Capture column configuration | Needed for UI parity |
| 7 | `beproduct-masterdata.get` | Fetch enumerations (statuses, departments, roles) | Prevent enum drift |
| 8 | `beproduct-tracking.planStyleProgress` | Gather aggregate stats for QA | Optional |
| 9 | `beproduct-tracking.planMaterialProgress` | Gather aggregate stats for QA | Optional |
| 10 | *(manual export)* timeline template HTML/JSON | Capture raw template definition for seeding | Normalize into `ref/timeline_extract_beproduct.json` |

All responses should be versioned and stored under `supabase-tracking/raw/` during development for reproducibility.

## 3. Import architecture

### 3.1 Staging tables

- `tracking.import_plans` — raw plan JSON payloads.
- `tracking.import_styles` / `tracking.import_materials` — flattened entries per style/material.
- `tracking.import_timelines` — milestone rows joined with template metadata (node type, phase, dependency, offsets).

### 3.2 SQL upsert functions

| Function | Responsibility |
| --- | --- |
| `tracking.fn_upsert_folder(payload jsonb)` | Insert/update `folders` & style links |
| `tracking.fn_upsert_plan(payload jsonb)` | Upsert plan metadata, views |
| `tracking.fn_upsert_plan_style(payload jsonb)` | Upsert style records, assignments |
| `tracking.fn_upsert_plan_material(payload jsonb)` | Upsert material records |
| `tracking.fn_upsert_timeline(payload jsonb)` | Upsert milestone rows & dependencies |

Seed routines will parse `ref/timeline_extract_beproduct.json` to populate `timeline_template_items`, hydrate `timeline_template_visibility`, and ensure anchor nodes exist before plan imports run.

Each function logs activity in `tracking.beproduct_sync_log` with counts and timestamps.

### 3.3 Edge Function flow (`tracking-import-beproduct`)

1. Receive request `{ folderId, planIds?, includeMaterialTimelines?, dryRun? }`.
2. Fetch folder metadata and plan list.
3. For each plan:
   - Call `planStyleTimeline`; on request call `planMaterialTimeline`.
   - Persist payloads to staging tables.
   - Invoke upsert functions inside a transaction.
4. Record batch summary in `import_batches` / `beproduct_sync_log`.
5. Return `{ batchId, counts: { plans, styles, materials, milestones }, warnings }`.
6. When `dryRun=true`, skip upserts and produce diff summary (new vs existing timestamps/statuses).

### 3.4 Scheduling & cadence

- **Initial load:** manual trigger per plan to validate data and templates.
- **Nightly sync:** Supabase cron job invoking Edge Function with `includeMaterialTimelines=true`.
- **Spot refresh:** On-demand run from admin UI (with service role key).
- **Future enhancements:** Webhook from BeProduct to trigger incremental sync when milestones change.

## 4. Supabase API surface

### 4.1 GraphQL (auto-generated)

Supabase's GraphQL endpoint will expose both the base tables and analytics views we create under `tracking`. Queries are organized to mirror the `beproduct-tracking` tool surface:

#### Folder & plan discovery

| GraphQL object/view | BeProduct analog | Description | Notes |
| --- | --- | --- | --- |
| `tracking_folders` → `tracking_plans` → `tracking_plan_views` | `folderList`, `planSearch`, `planGet` | Lists folders scoped by brand/season along with plan headers and the default view metadata. | Supports filters on `brand`, `season`, `active`; ordering by `updated_at`. |
| `tracking_v_folder_plan` (view) | `planSearch` | Combined folder + plan summary with template metadata, counts, and default view reference. | Designed for the folder/plan landing experience; filter via `folder_id`, `plan_active`. |
| `tracking_v_folder_plan_columns` (view) | `planStyleView`, `planMaterialView` | Column configuration derived from `plan_views.column_config` (pinned, visibility, labels, widths). | Returns a row per column; front-end uses it to render grid headers without hand parsing JSON. |

#### Timeline hydration

| GraphQL object/view | BeProduct analog | Description | Notes |
| --- | --- | --- | --- |
| `tracking_plan_styles` → `tracking_plan_style_timelines` | `planStyleTimeline` | Returns style timelines with milestone metadata, dependencies, assignments, and attachment counts. | View enforces ordering by template `display_order` and adds `is_overdue` + `is_anchor` flags. |
| `tracking_plan_materials` → `tracking_plan_material_timelines` | `planMaterialTimeline` | Mirrors style timelines for materials (including Production BoM references and style link summaries). | Filters include `material_header_id`, `supplier_id`, and `status`. |
| `tracking_timeline_templates` → `tracking_timeline_template_items` → `tracking_timeline_template_visibility` | Template metadata bundled in timeline calls | Exposes the master template catalog for editor tooling and import sanity checks. | Includes offsets, dependency info, `applies_to_style/material`, and `node_type`. |
| `tracking_timeline_assignments` (view) | Timeline assignment arrays | Flattens assignee chips by milestone with `role_name`, `source_user_id`, and Supabase `assignee_id`. | Drives mentions/notifications; filterable by `plan_id` + `assignee_id`. |

#### Progress & analytics

| GraphQL view | BeProduct analog | Description | Key fields |
| --- | --- | --- | --- |
| `tracking_plan_progress_summary` | `planStyleProgress`, `planMaterialProgress` (plan level) | Aggregates milestone counts per plan across style + material timelines. | `plan_id`, `plan_name`, `milestones_total`, `milestones_complete`, `milestones_late`, `status_breakdown jsonb`, `last_synced_at`. |
| `tracking_plan_style_progress` | `planStyleProgress` (style level) | Aggregates progress per `plan_style_id` (style + color + supplier). | `plan_style_id`, `style_number`, `color_name`, `supplier_name`, `status_breakdown`, `late_count`, `completion_pct`. |
| `tracking_plan_style_color_progress` | Style + color rollup (new) | Collapses progress per unique `style_header_id` + `color_id` across suppliers. | `plan_id`, `style_header_id`, `color_id`, `style_number`, `color_name`, `status_breakdown`, `variance_from_plan`. |
| `tracking_plan_material_progress` | `planMaterialProgress` (material level) | Aggregates milestone state for each `plan_material_id` and `material_header_id`. | `plan_material_id`, `material_number`, `supplier_name`, `status_breakdown`, `late_count`, `bom_linked`. |
| `tracking_plan_progress_timeseries` | Analytics extension | Stores daily snapshots for trend lines and burndown charts. | `plan_id`, `captured_at`, `open_milestones`, `closed_milestones`, `on_time_pct`. |

#### Mutation gateways

GraphQL insert/update mutations for `tracking.plan_styles`, `tracking.plan_materials`, and timeline tables remain available but will be locked down via RLS. Bulk timeline edits, template application, and audit logging continue to route through the `tracking-timeline-action` Edge Function to guarantee policy enforcement.

#### 4.1.1 GraphQL interaction contract

- **Query selection:** Front-end clients request fields by view, aligning with Supabase's [GraphQL preview documentation](https://supabase.com/docs/guides/graphql). Default projections should include identifiers + timestamps so deltas can be computed client side. Composite views (for example, `tracking_plan_progress_summary`) expose nested JSON fields that GraphQL will surface as raw JSON scalars; normalize these in consuming code.
- **Pagination:** Use `order_by` + `limit`/`offset` on collection queries. For timeline grids, prefer deterministic ordering on `display_order` to ensure consistent renders between GraphQL and REST responses.
- **Mutations:** Direct mutations against base tables (`tracking_plan_style_timelines`, `tracking_plan_material_timelines`) stay limited to service accounts. User-facing edits invoke Edge Functions or RPCs that encapsulate validation, then refresh reads via GraphQL queries.
- **Realtime:** Subscriptions are scoped to base tables only. For analytics dashboards, subscribe to `tracking.plan_style_timelines` / `tracking.plan_material_timelines` and re-hydrate views client-side rather than relying on view-level subscriptions (views do not emit realtime changefeeds).

### 4.2 REST (PostgREST)

Phase 1 exposes **nine read-only PostgREST endpoints**. They map directly to the public views created through migrations 0007–0016 and are already verified against the GREYSON seed data.

| # | Endpoint | Source object | Migration | Purpose |
| --- | --- | --- | --- | --- |
| 1 | `/rest/v1/v_folder` | `public.v_folder` | 0008 | Folder directory with active/total plan counts for each brand. |
| 2 | `/rest/v1/v_folder_plan` | `public.v_folder_plan` | 0007 | Plan roster with template linkage, count aggregates, and default view metadata. |
| 3 | `/rest/v1/v_folder_plan_columns` | `public.v_folder_plan_columns` | 0007 | Flattens `plan_views.column_config` for front-end grids. |
| 4 | `/rest/v1/v_timeline_template` | `public.v_timeline_template` | 0011 | Timeline template catalog with milestone counts and usage metrics. |
| 5 | `/rest/v1/v_timeline_template_item` | `public.v_timeline_template_item` | 0011 | Template item detail including dependency offsets and applicability flags. |
| 6 | `/rest/v1/v_plan_styles` | `public.v_plan_styles` | 0015 | Styles in a plan with milestone progress aggregates and supplier snapshots. |
| 7 | `/rest/v1/v_plan_style_timelines_enriched` | `public.v_plan_style_timelines_enriched` | 0015 | Full milestone payload per style (27× rows for GREYSON test data). |
| 8 | `/rest/v1/v_plan_materials` | `public.v_plan_materials` | 0015 | Material roster (currently empty until material imports run). |
| 9 | `/rest/v1/v_plan_material_timelines_enriched` | `public.v_plan_material_timelines_enriched` | 0015 | Material milestone payload (empty until materials import). |

**Characteristics**

- Methods: `GET` only. Phase 1 intentionally ships as **view-only**; CRUD will arrive in a later milestone via Edge Functions.
- Authentication: use the Supabase `anon` or `service_role` key with the standard headers.

```javascript
const headers = {
  apikey: SUPABASE_ANON_KEY,
  Authorization: `Bearer ${SUPABASE_ANON_KEY}`
};
```

- Filtering & ordering: standard PostgREST syntax works on every endpoint (e.g. `?plan_id=eq.{uuid}`, `?order=style_number.asc`). `Prefer: count=exact` enables accurate pagination.
- Row Level Security: views inherit policies from the base tracking tables. Current seed data is accessible to the anon role; production rollout will scope visibility by brand once the portal auth path lands.
- Data freshness: nightly import hydrates GREYSON folders/plans/templates/styles. Material tables are provisioned but empty until the importer enables trims.

**Future expansion**

- Expose RPCs (e.g. `get_plan_progress_delta`) once analytics views are finalized.
- Attach write policies and Edge Functions for CRUD operations post-Phase 1.
- Publish synonyms under an `api` schema if we want shorter endpoint names for external consumers.

### 4.3 Edge Functions

| Function | Input | Output | Purpose |
| --- | --- | --- | --- |
| `tracking-import-beproduct` | `{ folderId, planIds?, includeMaterialTimelines?, dryRun? }` | Import summary | ETL from BeProduct |
| `tracking-template-apply` | `{ planId, templateId, includeMaterial }` | `{ inserted, skipped }` | Clone template milestones |
| `tracking-timeline-action` | `{ timelineId, action, payload }` | Updated milestone | Controlled writes with audit |
| `tracking-sync-style` | `{ planId, styleHeaderId }` | Upsert result | On-demand style refresh |
| `tracking-sync-material` | `{ planId, materialHeaderId }` | Upsert result | Material refresh |
| `tracking-plan-analytics` | `{ planId }` | Metrics payload | Aggregated stats for dashboards, including plan/style/style+color progress + late milestone breakdown |

Each function runs with service role credentials and enforces custom authorization logic.

### 4.4 Seed data snapshot (Oct 24, 2025)

| Entity | Source | Count | Notes |
| --- | --- | --- | --- |
| Folders | `public.v_folder` | 1 | `GREYSON MENS` with three active plans. |
| Plans | `public.v_folder_plan` | 3 | Spring Drop 1–3; template names populated after GREYSON seed import. |
| Templates | `public.v_timeline_template` | 1 | “Garment Tracking Timeline” (27 milestones, 5 phases). |
| Template items | `public.v_timeline_template_item` | 27 | Includes anchor (`START DATE`/`END DATE`) and 25 task nodes. |
| Styles | `public.v_plan_styles` | 4 | MSP26B26 (three colourways) plus one test style. |
| Style milestones | `public.v_plan_style_timelines_enriched` | 108 | 27 milestones × 4 styles with calculated plan/rev/final dates. |
| Materials | `public.v_plan_materials` | 0 | Ready for Phase 2 imports; UI should show empty state gracefully. |
| Material milestones | `public.v_plan_material_timelines_enriched` | 0 | Provisioned; remains empty until trims import. |

## 5. Error handling & observability

- **Retries:** Edge Functions retry failed BeProduct requests up to 3 times with exponential backoff (500ms → 2s → 5s).
- **Partial failures:** When an import batch encounters errors, successful milestones still commit; failed rows are logged in `import_errors` and surfaced in the response.
- **Monitoring:** Supabase logs + custom `import_batches.status` field (`success`, `partial`, `failed`). Connect to Slack alert via webhook for `failed` batches.
- **Checksum:** Store SHA-256 hash of raw payload in `import_batches` to short-circuit identical re-runs.

## 6. Rollback strategy

- For catastrophic imports, call SQL procedure `tracking.fn_revert_to_batch(batch_id)` which reads previous snapshot from `import_*` tables and replays last known-good state.
- Maintain nightly backups at the database level (Supabase PITR) for additional safety.

## 7. Authorization matrix

| Role | GraphQL access | Edge function access | Notes |
| --- | --- | --- | --- |
| `admin` | Full CRUD on tracking schema | All functions | Limited to tech ops |
| `manager` | Read + update timelines within permitted folders | `tracking-timeline-action`, `tracking-plan-analytics` | No import rights |
| `importer` | Read | `tracking-import-beproduct`, `tracking-sync-*` | Service account |
| `viewer` | Read-only | None | Default user role |

JWT claims include `brand_ids` array used in RLS filters.

## 8. Naming conventions & SQL objects

### 8.1 Naming convention rules

**Tables:** Snake case, plural nouns describing entities
- Examples: `folders`, `plans`, `plan_styles`, `plan_style_timelines`

**Views:** Prefix with `v_`, describe the aggregation or transformation
- Examples: `v_folder_plan`, `v_plan_progress_summary`, `v_plan_style_timelines_enriched`

**Functions (data manipulation):** Prefix with `fn_`, verb describing action
- Examples: `fn_upsert_folder`, `fn_plan_progress_delta`, `fn_revert_to_batch`

**Functions (RPC endpoints):** Use imperative verbs for REST calls
- Examples: `get_plan_progress`, `update_timeline_status`, `apply_template`

**Indexes:** `idx_{table}_{columns}` or `idx_{table}_{purpose}`
- Examples: `idx_plans_folder_active`, `idx_timelines_status_target_date`

**Foreign keys:** `fk_{child_table}_{parent_table}` or `fk_{child_table}_{column}`
- Examples: `fk_plans_folder`, `fk_plan_styles_plan`

**Check constraints:** `ck_{table}_{column}_{condition}`
- Examples: `ck_plans_dates_valid`, `ck_timelines_status_enum`

### 8.2 Required views for frontend

#### Core data views

```sql
-- View: v_folder_plan
-- Purpose: Folder + plan list with counts and metadata
-- Endpoint: /rest/v1/tracking_v_folder_plan
CREATE OR REPLACE VIEW tracking.v_folder_plan AS
SELECT 
  f.id AS folder_id,
  f.name AS folder_name,
  f.brand,
  f.active AS folder_active,
  p.id AS plan_id,
  p.name AS plan_name,
  p.season,
  p.start_date,
  p.end_date,
  p.active AS plan_active,
  p.template_id,
  p.default_view_id,
  t.name AS template_name,
  pv.name AS default_view_name,
  pv.view_type AS default_view_type,
  (SELECT COUNT(*) FROM tracking.plan_styles ps WHERE ps.plan_id = p.id) AS style_count,
  (SELECT COUNT(*) FROM tracking.plan_materials pm WHERE pm.plan_id = p.id) AS material_count,
  p.updated_at,
  p.created_at
FROM tracking.folders f
LEFT JOIN tracking.plans p ON p.folder_id = f.id
LEFT JOIN tracking.timeline_templates t ON t.id = p.template_id
LEFT JOIN tracking.plan_views pv ON pv.id = p.default_view_id
WHERE f.active = true
ORDER BY f.name, p.start_date DESC;

-- View: v_folder_plan_columns
-- Purpose: Denormalized column configuration per plan view
-- Endpoint: /rest/v1/tracking_v_folder_plan_columns
CREATE OR REPLACE VIEW tracking.v_folder_plan_columns AS
SELECT 
  pv.id AS view_id,
  pv.plan_id,
  pv.view_type,
  pv.name AS view_name,
  col.field_key,
  col.label,
  col.visible,
  col.pinned,
  col.width_px,
  col.sort_order,
  col.data_type,
  col.format_config
FROM tracking.plan_views pv,
LATERAL jsonb_to_recordset(pv.column_config) AS col(
  field_key text,
  label text,
  visible boolean,
  pinned boolean,
  width_px integer,
  sort_order integer,
  data_type text,
  format_config jsonb
)
ORDER BY pv.id, col.sort_order;
```

`v_folder_plan` returns one row per plan (scoped by folder) and is the primary feed for the landing screen. `v_folder_plan_columns` expands the JSON column metadata that lives on `plan_views.column_config` into a consumable list—effectively a schema/column catalog for the grid. Because the column records already include field keys, labels, pinning state, visibility, widths, and data types, a separate "schema endpoint" is unnecessary; however, if the UI ever needs raw JSON we can expose `plan_views` directly or add an `api.folder_plan_schema` synonym that simply re-selects `plan_views.column_config`.

#### Timeline views

```sql
-- View: v_plan_style_timelines_enriched
-- Purpose: Style timelines with computed flags and template metadata
-- Endpoint: /rest/v1/v_plan_style_timelines_enriched
CREATE OR REPLACE VIEW tracking.v_plan_style_timelines_enriched AS
SELECT 
  pst.id AS timeline_id,
  pst.plan_style_id,
  ps.plan_id,
  ps.style_id,
  ps.style_code,
  ps.style_name,
  ps.color_name,
  ps.supplier_name,
  pst.template_item_id,
  tti.milestone_name,
  tti.node_type,
  tti.phase,
  tti.display_order,
  tti.offset_days,
  tti.dependency_ids,
  pst.target_date,
  pst.actual_date,
  pst.status,
  pst.notes,
  pst.assigned_to,
  pst.completed_by,
  pst.completed_at,
  -- Computed flags
  CASE 
    WHEN pst.actual_date IS NOT NULL THEN false
    WHEN pst.target_date < CURRENT_DATE THEN true
    ELSE false
  END AS is_overdue,
  tti.is_anchor,
  -- Attachment count (placeholder for future)
  0 AS attachment_count,
  pst.created_at,
  pst.updated_at
FROM tracking.plan_style_timelines pst
JOIN tracking.plan_styles ps ON ps.id = pst.plan_style_id
JOIN tracking.timeline_template_items tti ON tti.id = pst.template_item_id
WHERE ps.active = true
ORDER BY ps.plan_id, ps.style_code, tti.display_order;

-- View: v_plan_material_timelines_enriched
-- Purpose: Material timelines with computed flags and template metadata
-- Endpoint: /rest/v1/v_plan_material_timelines_enriched
CREATE OR REPLACE VIEW tracking.v_plan_material_timelines_enriched AS
SELECT 
  pmt.id AS timeline_id,
  pmt.plan_material_id,
  pm.plan_id,
  pm.material_id,
  pm.material_code,
  pm.material_name,
  pm.supplier_name,
  pm.bom_references,
  pmt.template_item_id,
  tti.milestone_name,
  tti.node_type,
  tti.phase,
  tti.display_order,
  tti.offset_days,
  tti.dependency_ids,
  pmt.target_date,
  pmt.actual_date,
  pmt.status,
  pmt.notes,
  pmt.assigned_to,
  pmt.completed_by,
  pmt.completed_at,
  -- Computed flags
  CASE 
    WHEN pmt.actual_date IS NOT NULL THEN false
    WHEN pmt.target_date < CURRENT_DATE THEN true
    ELSE false
  END AS is_overdue,
  tti.is_anchor,
  pmt.created_at,
  pmt.updated_at
FROM tracking.plan_material_timelines pmt
JOIN tracking.plan_materials pm ON pm.id = pmt.plan_material_id
JOIN tracking.timeline_template_items tti ON tti.id = pmt.template_item_id
WHERE pm.active = true
ORDER BY pm.plan_id, pm.material_code, tti.display_order;

-- View: v_timeline_assignments_flattened
-- Purpose: Flattened assignee list for mention/notification features
-- Endpoint: /rest/v1/v_timeline_assignments_flattened
CREATE OR REPLACE VIEW tracking.v_timeline_assignments_flattened AS
SELECT 
  ta.id AS assignment_id,
  ta.timeline_id,
  ta.timeline_type,
  ta.assignee_id,
  ta.role_name,
  ta.assigned_by,
  ta.assigned_at,
  u.email AS assignee_email,
  u.full_name AS assignee_name,
  -- Link to parent objects
  CASE 
    WHEN ta.timeline_type = 'style' THEN (
      SELECT ps.plan_id 
      FROM tracking.plan_style_timelines pst 
      JOIN tracking.plan_styles ps ON ps.id = pst.plan_style_id 
      WHERE pst.id = ta.timeline_id
    )
    WHEN ta.timeline_type = 'material' THEN (
      SELECT pm.plan_id 
      FROM tracking.plan_material_timelines pmt 
      JOIN tracking.plan_materials pm ON pm.id = pmt.plan_material_id 
      WHERE pmt.id = ta.timeline_id
    )
  END AS plan_id
FROM tracking.timeline_assignments ta
LEFT JOIN auth.users u ON u.id = ta.assignee_id;
```

#### Progress & analytics views

```sql
-- View: v_plan_progress_summary
-- Purpose: Aggregated plan-level progress
-- Endpoint: /rest/v1/v_plan_progress_summary
CREATE OR REPLACE VIEW tracking.v_plan_progress_summary AS
SELECT 
  p.id AS plan_id,
  p.name AS plan_name,
  p.folder_id,
  f.name AS folder_name,
  p.season,
  -- Style timeline counts
  COUNT(DISTINCT pst.id) FILTER (WHERE pst.id IS NOT NULL) AS style_milestones_total,
  COUNT(DISTINCT pst.id) FILTER (WHERE pst.status = 'Completed') AS style_milestones_complete,
  COUNT(DISTINCT pst.id) FILTER (WHERE pst.target_date < CURRENT_DATE AND pst.actual_date IS NULL) AS style_milestones_late,
  -- Material timeline counts
  COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.id IS NOT NULL) AS material_milestones_total,
  COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.status = 'Completed') AS material_milestones_complete,
  COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.target_date < CURRENT_DATE AND pmt.actual_date IS NULL) AS material_milestones_late,
  -- Combined totals
  COUNT(DISTINCT pst.id) + COUNT(DISTINCT pmt.id) AS milestones_total,
  COUNT(DISTINCT pst.id) FILTER (WHERE pst.status = 'Completed') + 
    COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.status = 'Completed') AS milestones_complete,
  COUNT(DISTINCT pst.id) FILTER (WHERE pst.target_date < CURRENT_DATE AND pst.actual_date IS NULL) + 
    COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.target_date < CURRENT_DATE AND pmt.actual_date IS NULL) AS milestones_late,
  -- Status breakdown (JSONB)
  jsonb_build_object(
    'style', jsonb_build_object(
      'Not Started', COUNT(DISTINCT pst.id) FILTER (WHERE pst.status = 'Not Started'),
      'In Progress', COUNT(DISTINCT pst.id) FILTER (WHERE pst.status = 'In Progress'),
      'Completed', COUNT(DISTINCT pst.id) FILTER (WHERE pst.status = 'Completed'),
      'Blocked', COUNT(DISTINCT pst.id) FILTER (WHERE pst.status = 'Blocked')
    ),
    'material', jsonb_build_object(
      'Not Started', COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.status = 'Not Started'),
      'In Progress', COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.status = 'In Progress'),
      'Completed', COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.status = 'Completed'),
      'Blocked', COUNT(DISTINCT pmt.id) FILTER (WHERE pmt.status = 'Blocked')
    )
  ) AS status_breakdown,
  MAX(GREATEST(pst.updated_at, pmt.updated_at)) AS last_synced_at,
  p.updated_at AS plan_updated_at
FROM tracking.plans p
JOIN tracking.folders f ON f.id = p.folder_id
LEFT JOIN tracking.plan_styles ps ON ps.plan_id = p.id AND ps.active = true
LEFT JOIN tracking.plan_style_timelines pst ON pst.plan_style_id = ps.id
LEFT JOIN tracking.plan_materials pm ON pm.plan_id = p.id AND pm.active = true
LEFT JOIN tracking.plan_material_timelines pmt ON pmt.plan_material_id = pm.id
WHERE p.active = true
GROUP BY p.id, p.name, p.folder_id, f.name, p.season, p.updated_at;

-- View: v_plan_style_progress
-- Purpose: Style-level progress by plan_style_id
-- Endpoint: /rest/v1/v_plan_style_progress
CREATE OR REPLACE VIEW tracking.v_plan_style_progress AS
SELECT 
  ps.id AS plan_style_id,
  ps.plan_id,
  ps.style_id,
  ps.style_code AS style_number,
  ps.style_name,
  ps.color_name,
  ps.supplier_name,
  COUNT(pst.id) AS milestones_total,
  COUNT(pst.id) FILTER (WHERE pst.status = 'Completed') AS milestones_complete,
  COUNT(pst.id) FILTER (WHERE pst.target_date < CURRENT_DATE AND pst.actual_date IS NULL) AS late_count,
  COUNT(pst.id) FILTER (WHERE pst.target_date >= CURRENT_DATE OR pst.actual_date IS NOT NULL) AS on_track_count,
  ROUND(
    COUNT(pst.id) FILTER (WHERE pst.status = 'Completed')::numeric / 
    NULLIF(COUNT(pst.id), 0) * 100, 
    1
  ) AS completion_pct,
  jsonb_object_agg(
    pst.status, 
    COUNT(pst.id)
  ) FILTER (WHERE pst.status IS NOT NULL) AS status_breakdown,
  MAX(pst.updated_at) AS last_updated_at
FROM tracking.plan_styles ps
LEFT JOIN tracking.plan_style_timelines pst ON pst.plan_style_id = ps.id
WHERE ps.active = true
GROUP BY ps.id, ps.plan_id, ps.style_id, ps.style_code, ps.style_name, ps.color_name, ps.supplier_name;

-- View: v_plan_style_color_progress
-- Purpose: Style + color rollup across suppliers
-- Endpoint: /rest/v1/v_plan_style_color_progress
CREATE OR REPLACE VIEW tracking.v_plan_style_color_progress AS
SELECT 
  ps.plan_id,
  ps.style_id AS style_header_id,
  ps.color_id,
  ps.style_code AS style_number,
  ps.style_name,
  ps.color_name,
  COUNT(DISTINCT ps.id) AS supplier_count,
  STRING_AGG(DISTINCT ps.supplier_name, ', ' ORDER BY ps.supplier_name) AS suppliers,
  COUNT(pst.id) AS milestones_total,
  COUNT(pst.id) FILTER (WHERE pst.status = 'Completed') AS milestones_complete,
  COUNT(pst.id) FILTER (WHERE pst.target_date < CURRENT_DATE AND pst.actual_date IS NULL) AS late_count,
  ROUND(
    COUNT(pst.id) FILTER (WHERE pst.status = 'Completed')::numeric / 
    NULLIF(COUNT(pst.id), 0) * 100, 
    1
  ) AS completion_pct,
  jsonb_object_agg(
    pst.status, 
    COUNT(pst.id)
  ) FILTER (WHERE pst.status IS NOT NULL) AS status_breakdown,
  -- Variance: difference between earliest and latest target dates across suppliers
  EXTRACT(DAY FROM (MAX(pst.target_date) - MIN(pst.target_date)))::integer AS variance_days,
  MAX(pst.updated_at) AS last_updated_at
FROM tracking.plan_styles ps
LEFT JOIN tracking.plan_style_timelines pst ON pst.plan_style_id = ps.id
WHERE ps.active = true
GROUP BY ps.plan_id, ps.style_id, ps.color_id, ps.style_code, ps.style_name, ps.color_name;

-- View: v_plan_material_progress
-- Purpose: Material-level progress
-- Endpoint: /rest/v1/v_plan_material_progress
CREATE OR REPLACE VIEW tracking.v_plan_material_progress AS
SELECT 
  pm.id AS plan_material_id,
  pm.plan_id,
  pm.material_id AS material_header_id,
  pm.material_code AS material_number,
  pm.material_name,
  pm.supplier_name,
  COUNT(pmt.id) AS milestones_total,
  COUNT(pmt.id) FILTER (WHERE pmt.status = 'Completed') AS milestones_complete,
  COUNT(pmt.id) FILTER (WHERE pmt.target_date < CURRENT_DATE AND pmt.actual_date IS NULL) AS late_count,
  ROUND(
    COUNT(pmt.id) FILTER (WHERE pmt.status = 'Completed')::numeric / 
    NULLIF(COUNT(pmt.id), 0) * 100, 
    1
  ) AS completion_pct,
  jsonb_object_agg(
    pmt.status, 
    COUNT(pmt.id)
  ) FILTER (WHERE pmt.status IS NOT NULL) AS status_breakdown,
  -- Check if material has BOM linkages
  CASE WHEN jsonb_array_length(pm.bom_references) > 0 THEN true ELSE false END AS bom_linked,
  -- Check if any milestone is on critical path
  bool_or(tti.is_anchor) AS on_critical_path,
  MAX(pmt.updated_at) AS last_updated_at
FROM tracking.plan_materials pm
LEFT JOIN tracking.plan_material_timelines pmt ON pmt.plan_material_id = pm.id
LEFT JOIN tracking.timeline_template_items tti ON tti.id = pmt.template_item_id
WHERE pm.active = true
GROUP BY pm.id, pm.plan_id, pm.material_id, pm.material_code, pm.material_name, pm.supplier_name, pm.bom_references;
```

### 8.3 Required RPC functions

```sql
-- Function: get_plan_progress_delta
-- Purpose: Return progress changes since a timestamp
-- Endpoint: POST /rest/v1/rpc/get_plan_progress_delta
CREATE OR REPLACE FUNCTION tracking.get_plan_progress_delta(
  p_plan_id uuid,
  p_since timestamptz DEFAULT NOW() - INTERVAL '24 hours'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'plan_id', p_plan_id,
    'since', p_since,
    'newly_completed', (
      SELECT jsonb_agg(jsonb_build_object(
        'timeline_id', id,
        'timeline_type', 'style',
        'milestone_name', (SELECT milestone_name FROM tracking.timeline_template_items WHERE id = template_item_id),
        'completed_at', completed_at,
        'completed_by', completed_by
      ))
      FROM tracking.plan_style_timelines pst
      JOIN tracking.plan_styles ps ON ps.id = pst.plan_style_id
      WHERE ps.plan_id = p_plan_id 
        AND pst.status = 'Completed'
        AND pst.completed_at >= p_since
    ),
    'newly_late', (
      SELECT jsonb_agg(jsonb_build_object(
        'timeline_id', id,
        'timeline_type', 'style',
        'milestone_name', (SELECT milestone_name FROM tracking.timeline_template_items WHERE id = template_item_id),
        'target_date', target_date,
        'days_overdue', EXTRACT(DAY FROM (CURRENT_DATE - target_date))::integer
      ))
      FROM tracking.plan_style_timelines pst
      JOIN tracking.plan_styles ps ON ps.id = pst.plan_style_id
      WHERE ps.plan_id = p_plan_id 
        AND pst.actual_date IS NULL
        AND pst.target_date < CURRENT_DATE
        AND pst.target_date >= p_since
    ),
    'status_changes', (
      SELECT jsonb_agg(jsonb_build_object(
        'timeline_id', tsh.timeline_id,
        'timeline_type', tsh.timeline_type,
        'old_status', tsh.old_status,
        'new_status', tsh.new_status,
        'changed_at', tsh.changed_at,
        'changed_by', tsh.changed_by
      ))
      FROM tracking.timeline_status_history tsh
      WHERE tsh.changed_at >= p_since
        AND EXISTS (
          SELECT 1 FROM tracking.plan_style_timelines pst
          JOIN tracking.plan_styles ps ON ps.id = pst.plan_style_id
          WHERE ps.plan_id = p_plan_id AND pst.id = tsh.timeline_id
        )
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- Function: apply_template_to_plan
-- Purpose: Clone template milestones to a plan's styles/materials
-- Endpoint: POST /rest/v1/rpc/apply_template_to_plan
CREATE OR REPLACE FUNCTION tracking.apply_template_to_plan(
  p_plan_id uuid,
  p_template_id uuid,
  p_include_materials boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted_count integer := 0;
  v_skipped_count integer := 0;
BEGIN
  -- Insert style timelines
  WITH inserted AS (
    INSERT INTO tracking.plan_style_timelines (
      plan_style_id,
      template_item_id,
      target_date,
      status
    )
    SELECT 
      ps.id,
      tti.id,
      p.start_date + (tti.offset_days || ' days')::interval,
      'Not Started'
    FROM tracking.plan_styles ps
    JOIN tracking.plans p ON p.id = ps.plan_id
    CROSS JOIN tracking.timeline_template_items tti
    LEFT JOIN tracking.timeline_template_visibility ttv 
      ON ttv.template_id = tti.template_id 
      AND ttv.item_id = tti.id
    WHERE ps.plan_id = p_plan_id
      AND tti.template_id = p_template_id
      AND tti.applies_to_style = true
      AND (ttv.visible_to_style = true OR ttv.id IS NULL)
      AND NOT EXISTS (
        SELECT 1 FROM tracking.plan_style_timelines existing
        WHERE existing.plan_style_id = ps.id
          AND existing.template_item_id = tti.id
      )
    RETURNING id
  )
  SELECT COUNT(*) INTO v_inserted_count FROM inserted;
  
  -- Insert material timelines if requested
  IF p_include_materials THEN
    WITH inserted_materials AS (
      INSERT INTO tracking.plan_material_timelines (
        plan_material_id,
        template_item_id,
        target_date,
        status
      )
      SELECT 
        pm.id,
        tti.id,
        p.start_date + (tti.offset_days || ' days')::interval,
        'Not Started'
      FROM tracking.plan_materials pm
      JOIN tracking.plans p ON p.id = pm.plan_id
      CROSS JOIN tracking.timeline_template_items tti
      LEFT JOIN tracking.timeline_template_visibility ttv 
        ON ttv.template_id = tti.template_id 
        AND ttv.item_id = tti.id
      WHERE pm.plan_id = p_plan_id
        AND tti.template_id = p_template_id
        AND tti.applies_to_material = true
        AND (ttv.visible_to_material = true OR ttv.id IS NULL)
        AND NOT EXISTS (
          SELECT 1 FROM tracking.plan_material_timelines existing
          WHERE existing.plan_material_id = pm.id
            AND existing.template_item_id = tti.id
        )
      RETURNING id
    )
    SELECT v_inserted_count + COUNT(*) INTO v_inserted_count FROM inserted_materials;
  END IF;
  
  RETURN jsonb_build_object(
    'inserted', v_inserted_count,
    'skipped', v_skipped_count
  );
END;
$$;
```

### 8.4 Migration placement

| Migration | Purpose |
| --- | --- |
| **0007_create_folder_plan_views.sql** | Introduces `tracking.v_folder_plan` and `tracking.v_folder_plan_columns`, the foundation for plan and view summaries. |
| **0008_create_folders_view.sql** | Publishes `tracking.v_folder` and its public synonym to support folder grids. |
| **0009_expose_tracking_views_to_public.sql** / **0010_public_views_consistent_naming.sql** | Grants `anon`/`authenticated` roles SELECT permissions and unifies naming so PostgREST exposes `/rest/v1/v_*`. |
| **0011_create_template_views.sql** | Adds `tracking.v_timeline_template` and `tracking.v_timeline_template_item` plus permissions. |
| **0012_import_garment_timeline_template.sql** | Seeds the “Garment Tracking Timeline” template used in GREYSON QA (safe to replace with real templates later). |
| **0013_create_timeline_instantiation_trigger.sql** | Ensures styles dropped into a plan automatically receive timeline rows. |
| **0014_create_timeline_date_calculation.sql** | Calculates plan/forecast dates when the trigger runs or when milestones adjust. |
| **0015_create_plan_entity_views.sql** | Publishes `v_plan_styles`, `v_plan_style_timelines_enriched`, `v_plan_materials`, and `v_plan_material_timelines_enriched`. |

## 9. Implementation Status (Updated Oct 24, 2025)

### ✅ Completed
1. ~~Define DDL for progress analytics views~~ **→ COMPLETED in Section 8.2**
2. ~~Spec the `tracking.fn_plan_progress_delta` RPC contract~~ **→ COMPLETED in Section 8.3**
3. ~~Create migrations 0007-0015 with view and function definitions~~ **→ APPLIED**
4. ~~Add template system (migration 0011)~~ **→ OPERATIONAL**
5. ~~Add style/material views (migration 0015)~~ **→ 4 NEW VIEWS CREATED**
6. ~~Add auto date calculation (migration 0014)~~ **→ TRIGGER UPDATED**
7. ~~All 9 public views exposed via REST~~ **→ TESTED AND OPERATIONAL**

### ⏳ Pending
1. Confirm final shape of BeProduct master data responses for statuses/roles.
2. Wire Edge Functions into CI pipeline with integration tests using captured raw payloads.
3. Decide on storage strategy for attachments (proxy vs download + store in Supabase Storage).
4. Align with front-end on analytics payload schema returned by `tracking-plan-analytics`.
5. Add RLS policies for all new views.

## 10. Phased deployment milestones

### Phase 1 — Folder, plan, and timeline read surfaces

**Objective:** Deliver the read-only Supabase payloads required for the initial folder/plan UI, template manager, and timeline preview tiles. CRUD, analytics deltas, and supplier actions land in later phases.

| View | Migration | REST endpoint | Sample usage |
| --- | --- | --- | --- |
| `public.v_folder` | 0008 | `/rest/v1/v_folder` | `?order=folder_name.asc` — Folder directory with plan counts. |
| `public.v_folder_plan` | 0007 | `/rest/v1/v_folder_plan` | `?folder_id=eq.{uuid}` — Plan cards with template names & counts. |
| `public.v_folder_plan_columns` | 0007 | `/rest/v1/v_folder_plan_columns` | `?plan_id=eq.{uuid}` — Column config for grid headers. |
| `public.v_timeline_template` | 0011 | `/rest/v1/v_timeline_template` | `?is_active=eq.true` — Template catalog (27 items in GREYSON seed). |
| `public.v_timeline_template_item` | 0011 | `/rest/v1/v_timeline_template_item` | `?template_id=eq.{uuid}&order=display_order.asc` — Template milestone list. |
| `public.v_plan_styles` | 0015 | `/rest/v1/v_plan_styles` | `?plan_id=eq.{uuid}` — Style roster with milestone aggregates. |
| `public.v_plan_style_timelines_enriched` | 0015 | `/rest/v1/v_plan_style_timelines_enriched` | `?style_number=eq.MSP26B26&order=display_order.asc` — 27 milestone rows/sample data. |
| `public.v_plan_materials` | 0015 | `/rest/v1/v_plan_materials` | Currently empty until trims import; front-end should handle gracefully. |
| `public.v_plan_material_timelines_enriched` | 0015 | `/rest/v1/v_plan_material_timelines_enriched` | Mirrors style endpoint; empty until trims import. |

**Supporting functions / RPCs:** None for Phase 1. All mutations flow through future Edge Functions once CRUD work begins.

**Security considerations:**

- Ensure RLS on `tracking.folders`, `tracking.plans`, and `tracking.plan_views` checks JWT `brand_ids` array to limit folder visibility. Reference Supabase GraphQL documentation for query filters and enforce identical logic on PostgREST (`?brand=in.(...)`).
- Views must inherit the same security posture by selecting only rows permitted under base-table policies. Use `security_invoker = true` for view creation or rely on default invoker semantics.

**Edge Function impact:** None. All interactions served via PostgREST/GraphQL.

**Testing checklist:**

1. After running migrations 0007–0015, verify `select * from public.v_folder limit 5;` and `select * from public.v_plan_styles limit 5;` return GREYSON seed data.
2. Call each REST endpoint (`/rest/v1/v_folder`, `/rest/v1/v_folder_plan`, `/rest/v1/v_plan_style_timelines_enriched`, etc.) with the Supabase `anon` key to confirm permissions.
3. Optional GraphQL parity check:
   ```graphql
   query FolderPlanOverview {
     public_v_folder_plan(limit: 20, order_by: {folder_name: asc}) {
       folder_id
       folder_name
       plan_id
       plan_name
       template_name
       style_count
       material_count
     }
   }
   ```
4. Confirm PostgREST pagination via `Range: 0-49` on `/rest/v1/v_folder_plan` and verify `Prefer: count=exact` yields totals.

### Phase 2 — Timeline grids & assignments *(next)*

Will enable enriched timeline views (`v_plan_style_timelines_enriched`, `v_plan_material_timelines_enriched`), assignment flattening, and supporting RPCs. See Sections 8.2–8.3 for definitions; schedule after Phase 1 UI hardening.