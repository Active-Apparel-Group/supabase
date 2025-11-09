# BeProduct Style Webhook Intake Plan

**Date:** 2025-10-26  
**Status:** ✍️ Draft for review  
**Owner:** Data Integration Guild

---

## Objectives

1. Stand up a dedicated `styles` schema in Supabase that captures all canonical BeProduct style attributes, nested colorways, and size structures delivered via webhook.
2. Define the Supabase Edge Function contract that accepts BeProduct `OnCopy` (create) and `OnChange` style events and persists them idempotently.
3. Recommend the mutation strategy (single vs. split functions) and supporting database routines required to keep the `styles` schema synchronized.

---

## Source Payload Recap

All examples are taken from the attached `event_data_create.json` (`OnCopy`) and `event_data_change.json` (`OnChange`) payloads.

- **Identifiers:** `headerId` (UUID), `headerNumber`, `headerName`, `folderId`, `folderName`.
- **Images:** `frontImage`, `sideImage`, `backImage` objects with `preview` (signed thumbnail) and `origin` (signed asset) URLs.
- **Audit:** `createdBy`, `createdAt`, `modifiedBy`, `modifiedAt`, `FolderModifiedAt`, `FolderModifiedBy`, `PageModified`, `version`.
- **Core attributes:** `brand_1`, `classification`, `status`, `delivery`, `gender`, `product_category`, `product_type`, `fabric_group`, `season_year`, `season`, `year`, `account_manager`, `senior_product_developer`, `designer`, `core_size_range`, `core_main_material`.
- **Colorways:** Array with `id`, `colorNumber`, `colorName`, `primaryColor`, `secondaryColor`, `comments`, `hideColorway`, nested `fields` (marketing name, comments, etc.).
- **Sizes:** Top-level `sizeRange` array plus `sizeClasses` array (each class has its own `sizeRange`).
- **Linkage:** `planIds` (future integration point), `copiedOrCarriedOverFrom` (lineage array), `isDeleted` flag.
- **Event metadata:** `eventType`, `objectType`, `invocationId`, `logicId`, `date`.

---

## Proposed `styles` Schema

The goal is to normalize repeatable structures (colorways, size data) while retaining a JSONB escape hatch for vendor-specific extensions.

### 1. `styles.style`

| Column | Type | Notes |
| --- | --- | --- |
| `style_id` | UUID PK | Maps to `headerId` (supplied by BeProduct).
| `header_number` | TEXT NOTULL | From `header_number.value`.
| `header_name` | TEXT NOT NULL | From `header_name.value`.
| `folder_id` | UUID | From `folderId`.
| `folder_name` | TEXT | From `folderName`.
| `version_number` | INTEGER | Parsed from `version.value`.
| `brand` | TEXT | `brand_1.value`.
| `status` | TEXT | `status.value`.
| `classification` | TEXT | `classification.value`.
| `product_type` | TEXT | `product_type.value`.
| `product_category` | TEXT | `product_category.value`.
| `delivery_month` | TEXT | `delivery.value`.
| `gender` | TEXT | `gender.value`.
| `fabric_group` | TEXT | `fabric_group.value`.
| `season_label` | TEXT | `season_year.value` (e.g. `Spring | 2026`).
| `season` | TEXT | `season.value`.
| `year` | TEXT | `year.value`.
| `core_size_range_label` | TEXT | `core_size_range.value`.
| `core_main_material_label` | TEXT | `core_main_material.value`.
| `account_manager` | TEXT | Dropdown display value.
| `senior_product_developer` | TEXT | Dropdown display value.
| `designer` | TEXT | Users field (string list if multiple).
| `created_by_id` | UUID | From `createdBy.id`.
| `created_by_name` | TEXT | From `createdBy.name`.
| `created_at_utc` | TIMESTAMPTZ | `createdAt`.
| `modified_by_id` | UUID | From `modifiedBy.id`.
| `modified_by_name` | TEXT | From `modifiedBy.name`.
| `modified_at_utc` | TIMESTAMPTZ | `modifiedAt`.
| `folder_modified_at_utc` | TIMESTAMPTZ | `FolderModifiedAt.value`.
| `folder_modified_by` | TEXT | `FolderModifiedBy.value`.
| `page_last_modified` | TEXT | `PageModified.value`.
| `front_image_preview_url` | TEXT | `frontImage.preview`.
| `front_image_origin_url` | TEXT | `frontImage.origin`.
| `side_image_preview_url` | TEXT | `sideImage.preview`.
| `side_image_origin_url` | TEXT | `sideImage.origin`.
| `back_image_preview_url` | TEXT | `backImage.preview`.
| `back_image_origin_url` | TEXT | `backImage.origin`.
| `available_artboards` | TEXT[] | Flattened list (strings); use separate table if structured later.
| `plan_ids` | UUID[] | Mirrors `planIds` if/when provided.
| `is_deleted` | BOOLEAN DEFAULT FALSE | Mirrors payload flag.
| `last_event_type` | TEXT | `eventType` from webhook.
| `last_event_date` | TIMESTAMPTZ | Envelope `date`.
| `copied_from_ids` | UUID[] | Optional array from `copiedOrCarriedOverFrom`.
| `payload_hash` | TEXT | SHA-256 of `after` payload to short-circuit no-op updates.
| `raw_payload` | JSONB | Latest `after` block for forensic diffing.
| `created_at` / `updated_at` | TIMESTAMPTZ DEFAULT NOW() | Supabase audit columns.

**Indexes:**
- `UNIQUE (style_id)` (PK).
- `UNIQUE (header_number)` (optional, enforce only if value is globally unique).
- `INDEX ON (folder_id)`, `INDEX ON (brand)`, `INDEX ON (status)` for query filters.

### 2. `styles.style_event`

Captures every webhook delivery for auditability and retry logic.

| Column | Type | Notes |
| --- | --- | --- |
| `event_id` | UUID PK | Use `invocationId`.
| `style_id` | UUID REFERENCES `styles.style(style_id)` | From payload.
| `event_type` | TEXT | `OnCopy`, `OnChange`, etc.
| `beproduct_logic_id` | UUID | `logicId`.
| `received_at` | TIMESTAMPTZ DEFAULT NOW() | Supabase timestamp.
| `processed_at` | TIMESTAMPTZ | Set after successful commit.
| `status` | TEXT | `pending`, `processed`, `failed`.
| `error_detail` | TEXT | Last failure message (if any).
| `payload_hash` | TEXT | Same SHA-256 as `styles.style.payload_hash`.
| `payload` | JSONB | Full envelope (including `before` & `after`).

**Indexes:**
- `UNIQUE (event_id)`.
- `INDEX ON (style_id, received_at DESC)`.

### 3. `styles.style_colorway`

| Column | Type | Notes |
| --- | --- | --- |
| `colorway_id` | UUID PK | `colorways[].id` from payload.
| `style_id` | UUID REFERENCES `styles.style` | Parent reference.
| `color_number` | TEXT | `colorNumber`.
| `color_name` | TEXT | `colorName`.
| `primary_color_hex` | TEXT | `primaryColor`.
| `secondary_color_hex` | TEXT | `secondaryColor`.
| `secondary_color_number` | TEXT | `fields.secondary_color_number`.
| `secondary_color_name` | TEXT | `fields.secondary_color_name`.
| `marketing_name` | TEXT | `fields.marketing_name`.
| `core_colorway_comments` | TEXT | `fields.core_colorway_comments`.
| `core_colorway_main_material` | TEXT | `fields.core_colorway_main_material`.
| `color_reference` | TEXT | `fields.color_reference`.
| `comments` | TEXT | `comments`.
| `hide_colorway` | BOOLEAN | `hideColorway`.
| `image_header_id` | UUID | `imageHeaderId`.
| `image_url` | TEXT | If future payloads add asset URL.
| `color_source_id` | UUID | `colorSourceId`.
| `raw_fields` | JSONB | Retains unknown nested properties.
| `created_at` / `updated_at` | TIMESTAMPTZ | Default audit columns.

**Indexes:** `INDEX ON (style_id)`, `UNIQUE (style_id, color_number)` for downstream joins.

### 4. `styles.style_size`

Stores the flattened `sizeRange` array (primary range currently displayed in BeProduct).

| Column | Type | Notes |
| --- | --- | --- |
| `style_size_id` | BIGINT GENERATED BY DEFAULT AS IDENTITY | PK.
| `style_id` | UUID REFERENCES `styles.style` | Parent reference.
| `size_name` | TEXT | `sizeRange[].name`.
| `price` | NUMERIC(12,2) | `price`.
| `currency` | TEXT | ISO currency code.
| `unit_of_measure` | TEXT | `unitOfMeasure`.
| `comments` | TEXT | `comments`.
| `is_sample_size` | BOOLEAN | `isSampleSize`.
| `size_index` | INTEGER | `sizeIndex`.
| `hide_size` | BOOLEAN | `hideSize`.
| `extra_fields` | JSONB | `fields` payload (currently empty but reserved).
| `source` | TEXT | Default `primary` to distinguish from size classes if merged later.

**Indexes:** `INDEX ON (style_id, size_index)`.

### 5. `styles.style_size_class`

| Column | Type | Notes |
| --- | --- | --- |
| `style_size_class_id` | BIGINT IDENTITY PK | |
| `style_id` | UUID REFERENCES `styles.style` | Parent reference.
| `class_name` | TEXT | `sizeClasses[].name`.
| `is_default` | BOOLEAN | `sizeClasses[].isDefault`.

### 6. `styles.style_size_class_entry`

| Column | Type | Notes |
| --- | --- | --- |
| `style_size_class_entry_id` | BIGINT IDENTITY PK | |
| `style_size_class_id` | BIGINT REFERENCES `styles.style_size_class` | Parent reference.
| `size_name` | TEXT | `sizeClasses[].sizeRange[].name`.
| `price` / `currency` / `unit_of_measure` / `comments` / `is_sample_size` / `size_index` / `hide_size` | Mirrors `style_size` columns.
| `extra_fields` | JSONB | Raw `fields` for future attributes.

### 7. `styles.style_artboard`

| Column | Type | Notes |
| --- | --- | --- |
| `style_artboard_id` | BIGINT IDENTITY PK | |
| `style_id` | UUID REFERENCES `styles.style` |
| `label` | TEXT | Element from `availableArtboards` array.

### 8. `styles.style_plan_link`

| Column | Type | Notes |
| --- | --- | --- |
| `style_id` | UUID REFERENCES `styles.style` | PK part.
| `plan_id` | UUID | PK part (future-proof when payload populates `planIds`).
| `linked_at` | TIMESTAMPTZ DEFAULT NOW() | |

### 9. `styles.style_origin_link`

| Column | Type | Notes |
| --- | --- | --- |
| `style_id` | UUID REFERENCES `styles.style` | Child style.
| `source_style_id` | UUID | From `copiedOrCarriedOverFrom` array.
| `relationship` | TEXT DEFAULT 'copied_from' | Allows future relationship types.

> ✅ **Escape hatch:** If BeProduct introduces additional structured nodes, extend with new tables following the same naming convention or attach to `raw_fields` / `extra_fields` JSONB columns without breaking ingestion.

---

## Edge Function Design (`styles-sync-webhook`)

### Invocation Contract

- **URL:** `https://<project>.functions.supabase.co/styles-sync-webhook`
- **Method:** `POST`
- **Headers:**
  - `Content-Type: application/json`
  - `X-BeProduct-Signature`: HMAC SHA-256 signature of request body using shared secret.
  - `X-BeProduct-Company`: Optional for multi-tenant telemetry.
- **Body:** Exact BeProduct webhook envelope (`eventType`, `objectType`, `data.before`, `data.after`, etc.).

### Flow

1. **Inbound validation**
   - Reject non-`POST` requests (`405`).
   - Verify `objectType === "Header"` and `data.after` presence.
   - Validate HMAC signature against `styles_webhook_secret` (Edge Function environment variable).
   - Parse JSON with size guard (reject > 512 KB).

2. **Idempotency guard**
   - Compute `payload_hash = SHA-256(JSON.stringify(data.after))`.
   - Attempt `INSERT` into `styles.style_event` using `invocationId` as `event_id`.
   - If duplicate key, short-circuit with `200` and `{"status":"duplicate"}` (ensures replays are safe).

3. **Database mutation**
   - Call SQL stored procedure `styles.fn_upsert_style(event_type TEXT, payload JSONB)` using the Supabase service-role client.
   - The SQL routine wraps all table writes in a single transaction to guarantee consistency across `style`, `style_colorway`, `style_size`, etc.
   - `fn_upsert_style` responsibilities:
     - Upsert `styles.style` (merge metadata, update `payload_hash`, `raw_payload`).
     - Replace child collections (`colorways`, `sizeRange`, `sizeClasses`) using `DELETE`+`INSERT` or `ON CONFLICT` semantics keyed by payload IDs.
     - Update linkage tables (`style_plan_link`, `style_origin_link`).
     - Return `{ style_id UUID, mutated BOOLEAN, version INTEGER }`.

4. **Event lifecycle update**
   - Upon success, update `styles.style_event.status = 'processed'`, set `processed_at = NOW()`.
   - If no data changed (`mutated = FALSE` because of identical hash), leave child tables untouched but still mark event processed.

5. **Response**
   - `200 OK` with `{ "style_id": "...", "mutated": true/false }`.
   - On validation failure → `400` with reason.
   - On signature mismatch → `401`.
   - On downstream errors → `500` and mark `styles.style_event.status = 'failed'` with `error_detail`.

### Supporting Pieces

- **Secrets:** Store `styles_webhook_secret` and `SERVICE_ROLE_KEY` in Supabase Edge Function configuration; never expose to client code.
- **Retries:** BeProduct retries on non-2xx status. Our idempotency guard + transaction-safe SQL ensures safe replays.
- **Metrics / logging:** Use `console.log` structured logs forwarded to Supabase Log Explorer. Consider adding optional Slack alert via Edge Function if `status = 'failed'` persists.
- **Testing:** Add Playwright-style HTTP tests in `scripts/` using recorded payloads to verify signature validation, idempotency, and DB writes.

---

## Mutation Strategy Recommendation

| Option | Description | Pros | Cons | Recommendation |
| --- | --- | --- | --- | --- |
| **Single function (`styles-sync-webhook`)** | One endpoint handles both `OnCopy` and `OnChange`, branching internally on `eventType`. | Simplest integration, shared validation, less infra, same SQL path enforces consistent upsert rules. | Requires SQL routine to differentiate between insert vs update (handled via `ON CONFLICT`). | ✅ **Adopt.** Payload shape is identical; branching is trivial. |
| Separate functions (`styles-create`, `styles-update`) | Distinct endpoints, each tuned for create vs change events. | Potentially simpler SQL for create-only path. | Doubles deployment surface, duplicates verification logic, complicates BeProduct webhook setup (two destinations). | ❌ Overkill for current payload; avoid. |
| Queue + worker | Edge Function only logs, background job processes events. | Smooths load spikes, allows retries independent of webhook. | Requires additional infrastructure (cron/queue), increases latency before data lands. | ⏳ Keep in backlog; re-evaluate if volume becomes problematic. |

Key enablers for the single-function approach:
- `styles.fn_upsert_style` handles both inserts and updates through `INSERT ... ON CONFLICT` and `DELETE/INSERT` patterns for children.
- `payload_hash` short-circuits duplicate `OnChange` events where no actual data changed (common in UI toggles).
- `styles.style_event` log preserves full history for auditing and replays, so even with a single function we retain traceability.

---

## Implementation Phases

1. **Phase 0 – Prep (0.5 day)**
   - Create `styles` schema and baseline tables (`style_event`, `style`).
   - Stub `styles.fn_upsert_style(payload JSONB)` returning `NULL` for smoke testing.
   - Load sample payloads into staging DB for schema validation.

2. **Phase 1 – Core ingestion (1 day)**
   - Flesh out full table set (`style_colorway`, `style_size`, `style_size_class`, link tables).
   - Implement SQL upsert routine with transaction semantics.
   - Write unit tests using `pgTAP` or SQL fixtures verifying idempotent upserts and child replacement behaviour.

3. **Phase 2 – Edge Function (0.5 day)**
   - Scaffold Supabase Edge Function (`styles-sync-webhook`).
   - Implement signature verification, event logging, SQL call, response contract.
   - Add automated tests invoking the Edge Function locally with Supabase CLI.

4. **Phase 3 – Observability & hardening (0.5 day)**
   - Add Supabase Logflare dashboards or Log Explorer saved queries for `styles` events.
   - Configure alerting on `status = 'failed'` in `styles.style_event` via Supabase SQL triggers or scheduled reports.
   - Document runbook in `supabase-tracking/docs`.

5. **Phase 4 – Optional enhancements**
   - Introduce diffing table (`styles.style_change`) to capture field-level deltas.
   - Backfill historical styles by replaying existing exports through the Edge Function.
   - Implement RLS policies once consumer roles are defined (e.g., scope by brand/folder).

---

## Open Questions / Next Decisions

1. **Plan linkage:** When `planIds` starts populating, do we derive relationships to `tracking.tracking_plan` automatically, or require manual mapping? (Default: insert into `styles.style_plan_link` and expose join view.)
2. **Image persistence:** Signed URLs expire; decide whether to cache assets in Supabase Storage (Edge Function could kick off background fetch).
3. **RLS strategy:** Should consumer apps read from `styles` schema directly, or via curated views enforcing brand-level scoping? (Recommend mirroring the `tracking` schema approach—views plus RLS-permissive policies initially.)
4. **Backfill window:** Determine how many historical style revisions need to be replayed so that `styles` schema starts with a full dataset.

---

## Next Actions

- [ ] Review and sign off on the proposed table definitions and JSON retention strategy.
- [ ] Decide on any additional derived columns needed for analytics (e.g., `season_year_numeric`).
- [ ] Draft the initial SQL migration set (`supabase-tracking/migrations/0110-0115`) implementing the schema.
- [ ] Prototype `styles.fn_upsert_style` in staging and validate against both sample payloads.
- [ ] Schedule pairing session to scaffold the Edge Function and automate local testing with Supabase CLI.

---

**Summary:** A single, idempotent Edge Function backed by a transactional SQL routine inside the new `styles` schema keeps BeProduct styles synchronized without duplicating webhook infrastructure. The schema normalizes nested structures so downstream reporting and joins remain straightforward, while JSONB columns preserve flexibility for future payload changes.
