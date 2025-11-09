# Supabase Tracking Schema Blueprint (GREYSON Pilot)

**Document version:** 1.2 • **Last updated:** 2025-10-26 • **Author:** GitHub Copilot (GPT-5-Codex Preview)

This blueprint is aligned with the live Supabase project `wjpbryjgtmmaqjbhjgap`. All metadata below was validated on 2025-10-26 after migration 0105 via Supabase MCP tooling (`list_tables`, `pg_views`, `pg_proc`, and `information_schema.triggers`). Use this document as the single source of truth for the tracking schema, supporting reference data, and associated REST endpoints until the next refresh.

## 1. Schema overview

### 1.1 `tracking` schema — tables

- `tracking_folder`
- `tracking_folder_style_link`
- `tracking_plan`
- `tracking_plan_view`
- `tracking_plan_style`
- `tracking_plan_style_timeline`
- `tracking_plan_style_dependency`
- `tracking_plan_material`
- `tracking_plan_material_timeline`
- `tracking_plan_material_dependency`
- `tracking_timeline_template`
- `tracking_timeline_template_item`
- `tracking_timeline_template_visibility`
- `tracking_timeline_assignment`
- `tracking_timeline_status_history`
- `import_batches`
- `import_errors`
- `beproduct_sync_log`

> All tracking tables except the import log trio have RLS enabled. `import_batches`, `import_errors`, and `beproduct_sync_log` remain RLS-disabled to simplify service-role ETL operations.

### 1.2 `tracking` schema — views

- `tracking_folder_summary`
- `tracking_plan_summary`
- `tracking_plan_style_summary`
- `tracking_plan_style_timeline_detail`
- `tracking_plan_material_summary`
- `tracking_plan_material_timeline_detail`
- `tracking_timeline_template_detail`

These views are exposed verbatim through PostgREST at `/rest/v1/{view_name}` (validated via GET requests on 2025-10-25).

### 1.3 `tracking` schema — functions & triggers

**Functions**

- `calculate_material_timeline_dates()`
- `calculate_timeline_dates()`
- `calculate_timeline_dates(p_plan_style_id uuid)`
- `cascade_material_timeline_updates()`
- `cascade_timeline_updates()`
- `instantiate_timeline_from_template()`
- `recalculate_plan_timelines()`

**Triggers**

| Trigger | Table | Timing | Event | Function |
| --- | --- | --- | --- | --- |
| `recalculate_plan_timelines_trigger` | `tracking_plan` | AFTER | UPDATE | `tracking.recalculate_plan_timelines()` |
| `trg_instantiate_style_timeline` | `tracking_plan_style` | AFTER | INSERT | `tracking.instantiate_timeline_from_template()` |
| `calculate_timeline_dates_trigger` | `tracking_plan_style_timeline` | BEFORE | INSERT / UPDATE | `tracking.calculate_timeline_dates()` |
| `cascade_timeline_updates_trigger` | `tracking_plan_style_timeline` | AFTER | UPDATE | `tracking.cascade_timeline_updates()` |
| `calculate_material_timeline_dates_trigger` | `tracking_plan_material_timeline` | BEFORE | INSERT / UPDATE | `tracking.calculate_material_timeline_dates()` |
| `cascade_material_timeline_updates_trigger` | `tracking_plan_material_timeline` | AFTER | UPDATE | `tracking.cascade_material_timeline_updates()` |

### 1.4 `ref` schema — lookup tables

- `ref_timeline_status`
- `ref_timeline_type`
- `ref_view_type`
- `ref_page_type`
- `ref_node_type`
- `ref_offset_relation`
- `ref_offset_unit`
- `ref_phase`
- `ref_department`

Each reference table stores `code`, `label`, `description`, ordering metadata, and `is_active` flags. They supplement the `tracking` enum values with UI-friendly labels and colour metadata.

### 1.5 `public` schema — tracking exposures

The `public` schema currently exposes PostGIS helper views only. Tracking views are served directly from the `tracking` schema, so no public synonyms exist as of 2025-10-25. REST consumers should call `/rest/v1/tracking_{view}`.

## 2. Enumerations

Enum definitions confirmed via `pg_enum`:

| Enum | Values | Notes |
| --- | --- | --- |
| `tracking.timeline_status_enum` | `NOT_STARTED`, `IN_PROGRESS`, `APPROVED`, `REJECTED`, `COMPLETE`, `BLOCKED` | Mirrors BeProduct milestone statuses. |
| `tracking.timeline_type_enum` | `MASTER`, `STYLE`, `MATERIAL` | Used on template items and timeline rows. |
| `tracking.view_type_enum` | `STYLE`, `MATERIAL` | Plan view categorisation. |
| `tracking.page_type_enum` | `BOM`, `SAMPLE_REQUEST_MULTI`, `SAMPLE_REQUEST`, `FORM`, `TECHPACK`, `NONE` | Linked MCP page types. |
| `tracking.node_type_enum` | `ANCHOR`, `TASK` | Distinguishes bookend nodes vs actionable tasks. |
| `tracking.offset_relation_enum` | `AFTER`, `BEFORE` | Dependency direction. |
| `tracking.offset_unit_enum` | `DAYS`, `BUSINESS_DAYS` | Offset unit for dependency maths. |

`ref_*` tables duplicate the values above with descriptive labels.

## 3. Table reference

### 3.1 Folders & plan metadata

#### `tracking.tracking_folder`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | `gen_random_uuid()` | Primary key (mirrors BeProduct folder UID when imported). |
| `name` | `text` | — | Folder display name. |
| `brand` | `text` | — | Optional brand tag. |
| `style_folder_id` | `uuid` | — | Upstream BeProduct style folder id. |
| `style_folder_name` | `text` | — | Cached BeProduct folder name. |
| `active` | `boolean` | `true` | Soft-delete flag. |
| `created_at` | `timestamptz` | `timezone('utc', now())` | Ingest timestamp. |
| `updated_at` | `timestamptz` | `timezone('utc', now())` | Last sync timestamp. |
| `raw_payload` | `jsonb` | — | Optional raw API payload snapshot. |

#### `tracking.tracking_folder_style_link`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `folder_id` | `uuid` | — | FK → `tracking_folder.id`. |
| `style_folder_id` | `uuid` | — | BeProduct style folder id. |
| `is_primary` | `boolean` | `false` | Marks the default style folder. |
| `linked_at` | `timestamptz` | `timezone('utc', now())` | Link creation time. |

PK: `(folder_id, style_folder_id)`

#### `tracking.tracking_plan`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | `gen_random_uuid()` | Primary key (map to BeProduct plan id). |
| `folder_id` | `uuid` | — | FK → `tracking_folder.id`. |
| `name` | `text` | — | Plan name. |
| `active` | `boolean` | `true` | Soft-delete flag. |
| `season` | `text` | — | Season string (e.g. `2026 Spring`). |
| `brand` | `text` | — | Brand override. |
| `start_date` | `date` | — | Plan start. |
| `end_date` | `date` | — | Plan end. |
| `description` | `text` | — | Optional description. |
| `default_view_id` | `uuid` | — | FK → `tracking_plan_view.id`. |
| `template_id` | `uuid` | — | FK → `tracking_timeline_template.id`. |
| `timezone` | `text` | — | Plan timezone. |
| `color_theme` | `text` | — | Optional UI theme. |
| `created_at` | `timestamptz` | `timezone('utc', now())` | Sync timestamp. |
| `created_by` | `text` | — | Upstream user label. |
| `updated_at` | `timestamptz` | `timezone('utc', now())` | Sync timestamp. |
| `updated_by` | `text` | — | Upstream user label. |
| `raw_payload` | `jsonb` | — | Original BeProduct payload. |
| `suppliers` | `jsonb` | `'[]'::jsonb` | Supplier access control block per plan. |

#### `tracking.tracking_plan_view`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | `gen_random_uuid()` | Primary key (view id). |
| `plan_id` | `uuid` | — | FK → `tracking_plan.id`. |
| `name` | `text` | — | View label. |
| `view_type` | `tracking.view_type_enum` | — | STYLE or MATERIAL. |
| `active` | `boolean` | `true` | Soft-delete flag. |
| `sort_order` | `integer` | — | Order on plan UI. |
| `template_id` | `uuid` | — | FK → `tracking_timeline_template.id`. |
| `created_at` | `timestamptz` | `timezone('utc', now())` | Sync timestamp. |
| `description` | `text` | — | Optional description. |
| `column_config` | `jsonb` | `'[]'::jsonb` | Column metadata array. |
| `updated_at` | `timestamptz` | `timezone('utc', now())` | Sync timestamp. |

### 3.2 Style tracking entities

#### `tracking.tracking_plan_style`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | `gen_random_uuid()` | Primary key. |
| `plan_id` | `uuid` | — | FK → `tracking_plan.id`. |
| `view_id` | `uuid` | — | FK → `tracking_plan_view.id`. |
| `style_id` | `uuid` | — | BeProduct style id. |
| `style_header_id` | `uuid` | — | Header id for style. |
| `color_id` | `uuid` | — | Colourway id. |
| `style_number` | `text` | — | Style number. |
| `style_name` | `text` | — | Style description. |
| `color_name` | `text` | — | Colour description. |
| `season` | `text` | — | Season metadata. |
| `delivery` | `text` | — | Delivery window. |
| `factory` | `text` | — | Factory name. |
| `supplier_id` | `uuid` | — | Supplier id. |
| `supplier_name` | `text` | — | Supplier name. |
| `brand` | `text` | — | Brand tag. |
| `status_summary` | `jsonb` | — | Aggregated status stats from BeProduct. |
| `created_at` | `timestamptz` | `timezone('utc', now())` | Sync timestamp. |
| `updated_at` | `timestamptz` | `timezone('utc', now())` | Sync timestamp. |
| `suppliers` | `jsonb` | `'[]'::jsonb` | Supplier access control per style. |
| `active` | `boolean` | `true` | Soft-delete flag. |

#### `tracking.tracking_plan_style_timeline`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | `gen_random_uuid()` | Primary key. |
| `plan_style_id` | `uuid` | — | FK → `tracking_plan_style.id`. |
| `template_item_id` | `uuid` | — | FK → `tracking_timeline_template_item.id`. |
| `status` | `tracking.timeline_status_enum` | `'NOT_STARTED'` | Current milestone status. |
| `plan_date` | `date` | — | Planned due date. |
| `rev_date` | `date` | — | Revision date. |
| `final_date` | `date` | — | Final due date. |
| `due_date` | `date` | — | Primary due date (synced from plan). |
| `completed_date` | `date` | — | Completion timestamp. |
| `start_date_plan` | `date` | — | Calculated planned start (trigger managed). |
| `start_date_due` | `date` | — | Forecast start (trigger managed). |
| `duration_value` | `integer` | — | Task duration magnitude. |
| `duration_unit` | `tracking.offset_unit_enum` | `'DAYS'` | Duration unit. |
| `late` | `boolean` | `false` | Marked overdue flag. |
| `notes` | `text` | — | Timeline notes. |
| `page_id` | `uuid` | — | Linked MCP page id. |
| `page_type` | `tracking.page_type_enum` | — | Page type. |
| `page_name` | `text` | — | Page label. |
| `request_id` | `uuid` | — | Linked MCP request id. |
| `request_code` | `text` | — | Request reference. |
| `request_status` | `text` | — | Request status. |
| `timeline_type` | `tracking.timeline_type_enum` | `'STYLE'` | Scope marker. |
| `created_at` | `timestamptz` | `timezone('utc', now())` | Insert timestamp. |
| `updated_at` | `timestamptz` | `timezone('utc', now())` | Update timestamp. |
| `shared_with` | `jsonb` | `'[]'::jsonb` | Supplier visibility overrides. |

#### `tracking.tracking_plan_style_dependency`

| Column | Type | Notes |
| --- | --- | --- |
| `successor_id` | `uuid` | FK → `tracking_plan_style_timeline.id`. |
| `predecessor_id` | `uuid` | FK → `tracking_plan_style_timeline.id`. |
| `offset_relation` | `tracking.offset_relation_enum` | BEFORE / AFTER. |
| `offset_value` | `integer` | Offset magnitude. |
| `offset_unit` | `tracking.offset_unit_enum` | DAYS / BUSINESS_DAYS. |

PK: `(successor_id, predecessor_id)`

### 3.3 Material tracking entities

#### `tracking.tracking_plan_material`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | `gen_random_uuid()` | Primary key. |
| `plan_id` | `uuid` | — | FK → `tracking_plan.id`. |
| `view_id` | `uuid` | — | FK → `tracking_plan_view.id`. |
| `material_id` | `uuid` | — | BeProduct material id. |
| `material_header_id` | `uuid` | — | Header id. |
| `color_id` | `uuid` | — | Colour id. |
| `material_number` | `text` | — | Material number. |
| `material_name` | `text` | — | Material description. |
| `color_name` | `text` | — | Colour description. |
| `supplier_id` | `uuid` | — | Supplier id. |
| `supplier_name` | `text` | — | Supplier name. |
| `bom_item_id` | `uuid` | — | Linked production BOM item. |
| `style_links` | `jsonb` | — | List of style associations. |
| `created_at` | `timestamptz` | `timezone('utc', now())` | Sync timestamp. |
| `updated_at` | `timestamptz` | `timezone('utc', now())` | Sync timestamp. |
| `suppliers` | `jsonb` | `'[]'::jsonb` | Supplier access overrides. |
| `active` | `boolean` | `true` | Soft-delete flag. |
| `bom_references` | `jsonb` | `'[]'::jsonb` | Linked BOM metadata. |

#### `tracking.tracking_plan_material_timeline`

Structure mirrors `tracking_plan_style_timeline` with `timeline_type` defaulting to `'MATERIAL'` and identical trigger-driven date calculations.

#### `tracking.tracking_plan_material_dependency`

Identical shape to the style dependency table; PK `(successor_id, predecessor_id)`.

### 3.4 Template subsystem

#### `tracking.tracking_timeline_template`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | `gen_random_uuid()` | Primary key. |
| `name` | `text` | — | Template label. |
| `brand` | `text` | — | Brand scope. |
| `season` | `text` | — | Optional season tag. |
| `version` | `integer` | `1` | Template revision. |
| `is_active` | `boolean` | `true` | Template availability. |
| `timezone` | `text` | — | Default timezone. |
| `anchor_strategy` | `text` | — | Scheduling strategy label. |
| `conflict_policy` | `text` | — | Conflict resolution policy. |
| `business_days_calendar` | `jsonb` | — | Business day map (optional). |
| `created_at` | `timestamptz` | `timezone('utc', now())` | Audit timestamp. |
| `created_by` | `uuid` | — | Creator uid. |
| `updated_at` | `timestamptz` | `timezone('utc', now())` | Audit timestamp. |
| `updated_by` | `uuid` | — | Updater uid. |

#### `tracking.tracking_timeline_template_item`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `uuid` | `gen_random_uuid()` | Primary key. |
| `template_id` | `uuid` | — | FK → `tracking_timeline_template.id`. |
| `node_type` | `tracking.node_type_enum` | — | ANCHOR / TASK. |
| `name` | `text` | — | Milestone label. |
| `short_name` | `text` | — | Optional short label. |
| `phase` | `text` | — | Phase grouping. |
| `department` | `text` | — | Owning department. |
| `display_order` | `integer` | — | Ordering key. |
| `depends_on_template_item_id` | `uuid` | — | Self-referential dependency. |
| `depends_on_action` | `text` | — | Dependency text label. |
| `offset_relation` | `tracking.offset_relation_enum` | — | BEFORE / AFTER. |
| `offset_value` | `integer` | — | Offset magnitude. |
| `offset_unit` | `tracking.offset_unit_enum` | — | DAYS / BUSINESS_DAYS. |
| `page_type` | `tracking.page_type_enum` | — | Linked page type. |
| `page_label` | `text` | — | Page label. |
| `applies_to_style` | `boolean` | `true` | Style visibility. |
| `applies_to_material` | `boolean` | `false` | Material visibility. |
| `timeline_type` | `tracking.timeline_type_enum` | `'MASTER'` | Scope override. |
| `required` | `boolean` | `true` | Required flag. |
| `notes` | `text` | — | Guidance copy. |
| `supplier_visible` | `boolean` | `false` | Supplier default visibility toggle. |
| `default_assigned_to` | `jsonb` | `'[]'::jsonb` | Default assignee ids. |
| `default_shared_with` | `jsonb` | `'[]'::jsonb` | Default sharing company ids. |
| `duration_value` | `integer` | — | Default task duration. |
| `duration_unit` | `tracking.offset_unit_enum` | `'DAYS'` | Duration unit default. |

#### `tracking.tracking_timeline_template_visibility`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `template_item_id` | `uuid` | — | FK → `tracking_timeline_template_item.id`. |
| `view_type` | `tracking.view_type_enum` | — | STYLE / MATERIAL. |
| `is_visible` | `boolean` | `true` | Visibility flag. |

PK: `(template_item_id, view_type)`

### 3.5 Assignments & audit tables

#### `tracking.tracking_timeline_assignment`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `bigint` | `nextval('tracking.tracking_timeline_assignment_id_seq')` | **Primary key** (auto-increment). |
| `timeline_id` | `uuid` | — | FK to style/material timeline row. |
| `assignee_id` | `uuid` | — | Supabase profile id (nullable). |
| `source_user_id` | `uuid` | — | Upstream BeProduct user id. |
| `role_name` | `text` | — | Descriptive role. |
| `role_id` | `uuid` | — | Optional role id. |
| `assigned_at` | `timestamptz` | `timezone('utc', now())` | Assignment timestamp. |

**Changed in Migration 0105 (2025-10-26):**
- ✅ Added `id` column as new primary key (auto-increment)
- ✅ Removed `timeline_type` column (redundant - can infer from `timeline_id`)
- ✅ Made `assignee_id` nullable (assignments created after timelines)
- ✅ Removed composite PK `(timeline_id, timeline_type, assignee_id)` (too restrictive)
- ✅ Added index on `timeline_id` for fast lookups

#### `tracking.tracking_timeline_status_history`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `bigint` | `nextval('tracking.timeline_status_history_id_seq')` | Primary key. |
| `timeline_id` | `uuid` | — | Timeline FK. |
| `timeline_type` | `tracking.timeline_type_enum` | — | Scope marker. |
| `previous_status` | `tracking.timeline_status_enum` | — | Prior state. |
| `new_status` | `tracking.timeline_status_enum` | — | New state. |
| `changed_at` | `timestamptz` | `timezone('utc', now())` | Change timestamp. |
| `changed_by` | `uuid` | — | Supabase user id. |
| `source` | `text` | `'import'` | Origin of change. |

### 3.6 Import logging tables

#### `tracking.import_batches`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `bigint` | `nextval('tracking.import_batches_id_seq')` | Primary key. |
| `source` | `text` | — | Import source label. |
| `source_folder_id` | `uuid` | — | Optional folder id. |
| `hash` | `text` | — | Payload checksum. |
| `started_at` | `timestamptz` | `timezone('utc', now())` | Start time. |
| `completed_at` | `timestamptz` | — | Completion time. |
| `status` | `text` | — | `success`/`partial`/`failed`. |
| `error_count` | `integer` | `0` | Count of errors. |
| `payload` | `jsonb` | — | Optional metadata. |

#### `tracking.import_errors`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `bigint` | `nextval('tracking.import_errors_id_seq')` | Primary key. |
| `batch_id` | `bigint` | — | FK → `tracking.import_batches.id`. |
| `entity_type` | `text` | — | Entity label. |
| `entity_id` | `uuid` | — | Offending entity id. |
| `error_code` | `text` | — | Error code. |
| `error_message` | `text` | — | Human readable message. |
| `payload` | `jsonb` | — | Snapshot of failing row. |
| `created_at` | `timestamptz` | `timezone('utc', now())` | Logged at. |

#### `tracking.beproduct_sync_log`

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `id` | `bigint` | `nextval('tracking.beproduct_sync_log_id_seq')` | Primary key. |
| `batch_id` | `bigint` | — | FK → `tracking.import_batches.id`. |
| `entity_type` | `text` | — | Entity label. |
| `entity_id` | `uuid` | — | Entity id. |
| `action` | `text` | — | Action performed. |
| `processed_at` | `timestamptz` | `timezone('utc', now())` | Timestamp. |
| `payload` | `jsonb` | — | Optional details. |

## 4. View reference

| View | Purpose | Key fields |
| --- | --- | --- |
| `tracking_folder_summary` | Folder roll-up with active/total plan counts. | `id`, `name`, `brand`, `active_plan_count`, `total_plan_count`. |
| `tracking_plan_summary` | Plan overview with style/material/view counts & template. | `id`, `name`, `folder_id`, `template_id`, aggregated counts. |
| `tracking_plan_style_summary` | Style roster with milestone aggregates. | `id`, `plan_id`, `style_number`, `milestones_total`, `status_breakdown`. |
| `tracking_plan_style_timeline_detail` | Enriched style timeline rows with template metadata & assignments. | `id`, `plan_style_id`, `status`, `milestone_name`, `assignments`. |
| `tracking_plan_material_summary` | Material roster with milestone aggregates (currently empty). | `id`, `plan_id`, `milestones_total`, `status_breakdown`. |
| `tracking_plan_material_timeline_detail` | Enriched material timeline rows (awaiting data). | `id`, `plan_material_id`, `status`, `milestone_name`, `assignments`. |
| `tracking_timeline_template_detail` | Template inventory with counts by node type & applicability. | `id`, `name`, `total_items`, `style_items`, `material_items`. |

## 5. Trigger automation notes

- Style timelines are auto-instantiated via `trg_instantiate_style_timeline` whenever a new `tracking_plan_style` row is inserted.
- Date recalculations are centralised in `calculate_timeline_dates`/`calculate_material_timeline_dates` triggers; manual updates should respect these triggers.
- Cascade triggers propagate milestone changes to dependent rows (style and material variants respectively).
- Updating plan metadata runs `recalculate_plan_timelines`, ensuring anchor recalculations propagate downstream.

## 6. Reference data tables (`ref` schema)

Each `ref_*` table stores authoritative label metadata for enums. Common columns include `code`, `label`, `description`, `display_order`, `is_active`, `created_at`, and `updated_at`. Colour-dependent tables (`ref_timeline_status`, `ref_phase`) also include `color_hex` for UI styling. Row counts captured on 2025-10-25: timeline statuses (6), node types (2), offset relations (2), offset units (2), page types (6), timeline types (3), phases (7), departments (10).

## 7. Security & access

- RLS is enabled on all operational tracking tables, inheriting folder/plan scoping.
- Import audit tables remain RLS-disabled; restrict access via Supabase policies on the service role.
- REST clients should authenticate with Supabase anon/service keys; GraphQL exposes both tables and views with identical naming (e.g., `tracking_plan_style_timeline`).

## 8. Data snapshot (2025-10-26, after migration 0105)

| Entity | Rows |
| --- | --- |
| Folders (`tracking_folder`) | 1 |
| Plans (`tracking_plan`) | 3 |
| Timeline templates (`tracking_timeline_template`) | 1 |
| Template items (`tracking_timeline_template_item`) | 27 |
| Plan styles (`tracking_plan_style`) | 4 |
| Style timeline rows (`tracking_plan_style_timeline`) | 108 |
| Plan materials (`tracking_plan_material`) | 0 |
| Material timeline rows (`tracking_plan_material_timeline`) | 0 |
| Timeline assignments (`tracking_timeline_assignment`) | 0 |

**Migration 0105 Impact:**
- `tracking_timeline_assignment` schema simplified (see section 3.5)
- Both detail views (`tracking_plan_style_timeline_detail`, `tracking_plan_material_timeline_detail`) updated to remove `timeline_type` filter

## 9. Gaps & follow-ups

1. **Staging tables missing** — `tracking.import_plans`, `tracking.import_styles`, `tracking.import_materials`, and `tracking.import_timelines` described in earlier drafts do not exist yet. Decide whether to create them or adjust the ETL approach.
2. **Upsert functions pending** — No `fn_upsert_*` routines are currently present. Consider adding service-layer RPCs or edge functions to encapsulate imports.
3. **Public synonyms** — If external consumers require shorter REST paths (e.g., `/rest/v1/v_plan_styles`), create `public` synonyms; currently all endpoints live under `/rest/v1/tracking_*`.
4. **Material data** — Tracking tables for materials are empty; validate importer once trims data becomes available.
5. **RLS policies** — Confirm final brand-scoped policies across tracking tables before production rollout.

## 10. Sample queries

### 10.1 Enriched style timeline rows

```sql
select
	pst.id as timeline_id,
	pst.plan_style_id,
	ps.style_number,
	pst.status,
	pst.due_date,
	v.milestone_name,
	v.phase,
	v.assignments
from tracking.tracking_plan_style_timeline pst
join tracking.tracking_plan_style ps on ps.id = pst.plan_style_id
join tracking.tracking_plan_style_timeline_detail v on v.id = pst.id
where ps.plan_id = '1305c5e9-39d5-4686-926c-c88c620d4f8a'
order by ps.style_number, v.display_order;
```

### 10.2 Folder dashboard summary

```sql
select name, brand, active_plan_count, total_plan_count
from tracking.tracking_folder_summary
order by name;
```

## 11. Next steps

1. Decide on staging-table strategy or confirm direct streaming into operational tables.
2. Implement RPC/Edge Function layer for deterministic imports (`tracking-import-beproduct` etc.).
3. Add observability (Slack/webhook) tied to `import_batches.status` changes.
4. Finalise RLS rules using JWT `brand_ids` claim once auth integration is ready.
5. Schedule regular schema blueprint refresh alongside Supabase migrations.
