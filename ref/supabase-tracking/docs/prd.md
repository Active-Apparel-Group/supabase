# Supabase Tracking Migration — Product Requirements Document

**Document version:** 0.1 • **Last updated:** 2025-10-22 • **Author:** GitHub Copilot (GPT-5-Codex Preview)

## 1. Why we are doing this
Active Apparel Group’s tracking workflows currently live exclusively inside BeProduct. While that platform already houses rich style and material data, it limits how quickly we can extend functionality, scale concurrent usage, or integrate with modern tooling. By migrating tracking folders, plans, and timelines into Supabase, we unlock:

- Faster iteration velocity with first-class SQL, GraphQL, and Edge Function support.
- A path to richer analytics and automations (e.g., alerts, dashboards, cross-plan views).
- Fine-grained control over schema evolution and API surface area without depending on vendor feature releases.
- A future-proof way to cross-link BeProduct style data with new experiences (front-end UI, PLM integrations, workflow bots).

We will keep authoritative style/color master data inside BeProduct and federate it into Supabase timelines. Supabase becomes the system of engagement for tracking, with APIs and UI/UX custom-tailored for AAG.

## 2. Primary goals
1. Recreate BeProduct tracking folders, plans, and timelines in Supabase for the GREYSON brand, starting with folder **`GREYSON MENS`** (`136625d5-d9cc-4139-8747-d98b85314676`).
2. Maintain schema/key parity with BeProduct where feasible so that migrations are data-loss safe and bi-directional.
3. Introduce a master timeline template model that can derive style and material sub-views from a single milestone catalogue.
4. Deliver performant APIs (GraphQL-first, backed by Edge Functions where business rules apply) that cover all existing operations plus new template tooling absent in BeProduct.
5. Provide a staged web UI plan that lets teams create folders/plans, manage templates, add styles/materials, and monitor progress.

## 3. Explicit non-goals (v0)
- Rebuilding core style management pages from BeProduct.
- Handling brands beyond GREYSON before the pilot succeeds.
- Automating two-way writebacks into BeProduct (read-only integrations unless noted).
- Implementing advanced analytics dashboards (nice-to-have post-MVP).

## 4. Scope & success metrics
**In scope**
- Tracking folders ↔ style folder linkage
- Tracking plans (style + material views, timeline entries, metadata)
- Timeline templates (master/style/material) with toggles per milestone
- Supabase schema, migrations, and API orchestration
- Front-end orchestration for CRUD and lookups

**Success looks like**
- 🎯 100% of GREYSON’s tracking plans hydrated in Supabase with idempotent import scripts.
- ⚡️ <300 ms median response for primary timeline reads (plan-level with hydrated milestones).
- 🧩 Template toggles allow hiding/showing style or material milestones without data duplication.
- ✅ UI allows sourcing styles from BeProduct folder `TEST-GREYSON` (`66f377be-d3d6-4e42-b50a-b46f4e156191`) and attaching them (per style + colorway) to Supabase plans.

## 5. Users & use cases
| Persona | Needs | Pain today |
| --- | --- | --- |
| Production Manager | Track milestone status across style & material timelines | Slow load times, limited filtering/export options |
| Materials Manager | Monitor component-specific timelines derived from Production BoM | No template tooling, manual toggles |
| Account/Brand Manager | Configure plan scopes, folders, deadlines | Disconnected tooling, no cross-plan insights |
| Process/Tech Ops | Automate notifications, integrate with other systems | Limited API surface, difficult to extend |

## 6. Current-state snapshot (BeProduct)
We captured BeProduct state using the MCP tracking tool:

- **folderList** → identified `GREYSON MENS` tracking folder (`1366…`), plus other folders for context.
- **planSearch** (`folderId=1366…`) → plans include:
  - `GREYSON 2026 SPRING DROP 1` (`162eedf3-0230-4e4c-88e1-6db332e3707b`)
  - `GREYSON 2026 SPRING DROP 2` (`ece9be3a-9c60-47d7-923c-a0af83e77a98`)
  - `GREYSON 2026 SPRING DROP 3` (`35d05905-fce7-424f-916b-2348c2d4c77f`)
  - `GREYSON W/ SAMPLE TRACKET` (`85602834-cc81-4cb2-8d0d-72776db81fee`)
  - `xxSPRING 2026` (`03accce8-ce7d-4c12-8791-ec211dd2f02e`)
- **planStyleTimeline** and **planMaterialTimeline** for `GREYSON 2026 SPRING DROP 1` surfaced:
  - Style timelines per style-color supplier combination, each with ~30 milestones.
  - Material timelines per material colorway, each with 10+ milestones, linked to Production BoM forms.
  - Key fields: `status`, `plan/rev/final/due` dates, `assignedTo` arrays, `late` boolean, `page` metadata, `request` references.
  - Status values observed: `Not Started`, `In Progress`, `Approved`, `Rejected`.
  - Department descriptors (e.g., `DEVELOPMENT | PD`, `PRODUCTION | FACTORY`) and page types (`BOM`, `SampleRequestMulti`, `Form`, `TechPack`).

Supabase currently holds unrelated PO/order tables only; no conflicting names.

## 7. Target architecture (phase 1)
- **Database**: Supabase Postgres schemas `public` (existing) + new schema `tracking` for isolation.
- **APIs**:
  - Supabase auto-generated GraphQL for straightforward CRUD on `tracking.*` tables.
  - Edge Functions (`/functions/tracking-*`) for composed operations (e.g., import from BeProduct, timeline instantiation, permission checks).
- **Integrations**:
  - BeProduct REST via MCP tooling (read-only for import, potential webhooks later).
  - Supabase Auth for user access, mapping to AAG personnel/roles.
- **Front-end**: Next.js (existing repo) will point to Supabase GraphQL / Edge functions.

## 8. Data model strategy
We will mirror BeProduct identifiers to keep referential integrity during migration.

| Table (schema `tracking`) | Primary key | Purpose |
| --- | --- | --- |
| `folders` | `id` (UUID from BeProduct) | Tracking folders with linkage to style folders.
| `folder_style_links` | composite (`folder_id`, `style_folder_id`) | Maps tracking folders to BeProduct style folder IDs for lookup queries.
| `plans` | `id` (UUID from BeProduct) | Plan header info, date ranges, active flag.
| `plan_views` | serial | Stores style/material view metadata (name, description, active, `view_type_enum`).
| `plan_styles` | `id` (UUID) | Style-color entries added to a plan; stores header + color metadata.
| `plan_style_timelines` | `id` (UUID) | Timeline rows per style entry, linked to template milestones.
| `plan_materials` | `id` (UUID) | Material-color entries added to a plan.
| `plan_material_timelines` | `id` (UUID) | Timeline rows per material entry.
| `timeline_templates` | `id` (UUID) | Master catalog of milestones, tagged by `template_type_enum` (`master`, `style`, `material`).
| `timeline_template_items` | `id` (UUID) | Individual milestones with ordering, default offsets, required flags.
| `timeline_template_visibility` | composite | Connects template items to `style`/`material` subsets (mirrors BeProduct toggles).
| `timeline_status_history` | serial | Audit table for status changes (for analytics & notifications).
| `beproduct_sync_log` | serial | Tracks import batches, hash checks, error payloads.

**Enumerations & supporting tables**
- `timeline_status_enum`: `NOT_STARTED`, `IN_PROGRESS`, `APPROVED`, `REJECTED`, `COMPLETE` (reserved for future), `BLOCKED` (optional if discovered). Derived from observed values; we will confirm via BeProduct master data before finalizing migrations.
- `timeline_type_enum`: `MASTER`, `STYLE`, `MATERIAL`.
- `view_type_enum`: `STYLE`, `MATERIAL`.
- `page_type_enum`: `BOM`, `SAMPLE_REQUEST_MULTI`, `SAMPLE_REQUEST`, `FORM`, `TECHPACK`, `NONE`.
- `department_roles` table capturing unique strings such as `DEVELOPMENT | PD`, mapped to friendlier labels.
- `assignment_roles` table to normalize `assignedTo` user IDs (Supabase `person` table integration later).

**Key relational notes**
- `plan_styles` stores `style_header_id` and `color_id` (UUIDs from BeProduct) plus denormalized attributes (style number, description, supplier, season, etc.).
- `plan_materials` stores `material_header_id`, `material_color_id`, supplier data, BoM references.
- `plan_*_timelines` reference both the corresponding `plan_*` row and a `timeline_template_items` row to guarantee consistent milestone metadata.
- `plan_*_timelines` hold live status/dates; template items hold defaults and descriptive info.
- `timeline_templates` include brand + season filters (e.g., GREYSON Spring) and flags for master vs derived usage.

Migrations will create schema `tracking`, enumerations, and tables in dependency order (enums → base tables → junction tables → audit tables).

## 9. Tooling & data acquisition plan
| Purpose | MCP tool & operation | Notes |
| --- | --- | --- |
| List tracking folders | `beproduct-tracking` `folderList` | Already executed; used to select GREYSON folder.
| Enumerate plans | `beproduct-tracking` `planSearch` | Provided plan IDs, views, timeline template references.
| Capture style timelines | `beproduct-tracking` `planStyleTimeline` | Used to map fields, statuses, assignments.
| Capture material timelines | `beproduct-tracking` `planMaterialTimeline` | Validated material-specific milestones & form links.
| Master data enums | `beproduct-masterdata` `get` (targeting timeline status & department fields) | To be run before finalizing enum migrations.
| Supabase schema introspection | `supabase` `list_tables` | Confirmed there is no name collision.

Future data pulls: `planStyleView`, `planMaterialView`, `planStyleProgress`, `planMaterialProgress` to fill analytics tables; `planAdd*` endpoints will inform mutation payloads.

## 10. API surface (Supabase)
- **GraphQL-first CRUD & analytics** covering base tables (`folders`, `plans`, `plan_styles`, `plan_materials`, `timeline_templates`, etc.) plus derived views (`tracking_plan_progress_summary`, `tracking_plan_style_progress`, `tracking_plan_style_color_progress`, `tracking_plan_material_progress`, `tracking_plan_progress_timeseries`).
- **Vendor snapshot views** exposed via GraphQL/PostgREST: `tracking.v_vendor_plan_summary`, `tracking.v_vendor_milestone_feed`, `tracking.v_vendor_task_digest` (all supplier-scoped through RLS).
- **Edge Functions**
  1. `tracking-import-beproduct`: pulls BeProduct plans by folder, upserts into Supabase, logs batches.
  2. `tracking-sync-style`: adds/updates individual styles (triggered via UI or webhook).
  3. `tracking-sync-material`: similar for material updates & Production BoM integration.
  4. `tracking-timeline-action`: orchestrates status/due date updates with permission checks and audit logging.
  5. `tracking-template-apply`: applies master template to a plan (style+material) while respecting opt-in toggles.
  6. `tracking-vendor-portal`: returns supplier-scoped snapshot `{ plans[], milestones[], tasks[] }` from the cached views above; includes optional `since` and `planId` parameters for deltas/light payloads.
- **Security**: Row Level Security policies scope data by brand/folder and supplier; Edge Functions run with service role credentials and enforce supplier/company checks before returning data.

## 11. Timeline template strategy
We will maintain a **master timeline** per brand/season containing the full milestone catalogue. Templates have flags `applies_to_style` / `applies_to_material`. Front-end filtering simply toggles columns; data remains single-sourced. Template builder requirements:
- Drag/drop milestone ordering (persisted in `timeline_template_items.display_order`).
- Toggle inclusion for style vs material views (writes to `timeline_template_visibility`).
- Support explicit anchor nodes (e.g., `START DATE`, `END DATE`) stored as `node_type = 'ANCHOR'` that act as bookends for all offsets.
- Configure dependencies with `offset_relation` (`AFTER`/`BEFORE`), `offset_value`, and `offset_unit` (`DAYS`/`BUSINESS_DAYS`), mirroring BeProduct’s template JSON.
- Allow editing of auxiliary metadata captured in the extract (phase, department, page label, short description).
- Ability to create “material only” template anchored to Production BoM events by toggling visibility flags.

## 12. Front-end roadmap (staged)
0. **Supplier portal (Vercel)**
  - Implement vendor login flow (NextAuth/Supabase Auth) embedding `supplier_company_id` claim.
  - Consume `tracking-vendor-portal` snapshot (ISR/SWR) for dashboard load; wire to `tracking-timeline-action` for edits.
  - Ship fallback toggle hitting legacy BeProduct flow for QA until snapshot parity is verified.
1. **Foundation**
  - Basic folder list with brand filter (reads Supabase `tracking.folders`).
  - Plan detail view pulling GraphQL `plans → plan_styles → plan_style_timelines`.
2. **Configuration tooling**
  - Folder creation wizard with BeProduct style folder lookup (ad-hoc search via MCP + Supabase caching table `folder_style_links`).
  - Timeline template manager (CRUD + milestone toggles).
3. **Plan assembly**
  - Add styles by searching BeProduct folder (style headers & colorways), bulk add with default timeline instantiation.
  - Material linking: fetch Production BoM (existing integration) and attach materials with timeline clones.
4. **Operations & monitoring**
  - Timeline board/table with status updates, assignment chips, due-date editing.
  - Notifications & exports (CSV, ICS) leveraging Edge Functions + Supabase storage.
5. **Enhancements** (post-MVP)
  - Cross-plan dashboards, analytics, automation hooks, and eventual supplier self-service tooling (e.g., vendor analytics views on top of `tracking_plan_progress_timeseries`).

## 13. Migration & DevOps plan
- **Mini-repo**: live inside `supabase-tracking/` to keep assets isolated; eventual GitHub MCP export to a dedicated repo.
- **Branching**: Use Supabase CLI branches (e.g., `tracking-dev`) for iterative schema work. Migrations applied via `#mcp_supabase_apply_migration` once vetted.
- **ETL**: Scripted importer using Edge Function or standalone worker that:
  1. Fetches BeProduct data (folder → plans → timelines).
  2. Normalizes payload into staging tables (`tracking.import_*`).
  3. Upserts into target tables ensuring deterministic IDs.
  4. Logs batches in `beproduct_sync_log` with checksums to avoid duplicates.
- **Testing**: Unit tests for template logic, integration tests hitting Supabase GraphQL/Edge functions. Use `scripts/test-mcp-schema.mjs` style harness as template.
- **Environment**: `.env.supabase-tracking` for API keys, service role; secrets managed via Supabase secrets or GitHub Actions at deploy time.

## 14. Risks & mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| BeProduct API rate limits | Slow or failed imports | Batch requests, incremental sync, retry with exponential backoff. |
| Enum drift (statuses, departments) | Data rejects in Supabase | Fetch master data, maintain mapping tables, run validation pre-import. |
| Timeline template mismatch | Users see incorrect milestones | Introduce template versioning and audit logs; allow quick rollback. |
| Permission misconfiguration | Data exposure | Strict RLS policies per brand, role-based Edge Function guards. |
| Supabase GraphQL limitations | Missing resolver features | Supplement with Edge Functions and PostgREST when needed. |

## 15. Open questions & next steps
1. Confirm full enumeration list for timeline status/department/type via `beproduct-masterdata` calls.
2. Decide whether to include historical timeline revisions (store `rev` date separately?).
3. Align on Supabase GraphQL vs PostgREST coverage for complex filters (e.g., late milestones only).
4. Determine user identity mapping between BeProduct and Supabase Auth (email, SSO?).
5. Finalize supplier snapshot RLS policies + Edge Function auth handshake (`supplier_company_id` claim) before portal rollout.

**Immediate next actions**
- Finalize schema blueprint (see `01-beproduct-schema-research.md` for raw mappings and `04-garment-timeline-template.md` for template seed specification).
- Draft migrations in Supabase branch and validate with sample imports.
- Implement template data seeding for GREYSON master timeline.
- Kick off front-end spike for folder/plan list page and style lookup flow.