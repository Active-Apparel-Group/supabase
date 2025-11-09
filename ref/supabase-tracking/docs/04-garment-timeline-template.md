# Garment Tracking Timeline Template Mapping

**Document version:** 0.1 • **Last updated:** 2025-10-22

Source assets:
- `ref/timeline_extract_beproduct.json` — canonical export of the GREYSON “Garment Tracking Timeline” template.
- `ref/timeline_config.html` — raw HTML capture of the BeProduct setup page (screenshot attached in repo).

## 1. Template metadata

- `timezone`: `Australia/Brisbane`
- `anchor_strategy`: `bookend` — template expects explicit START/END anchors.
- `conflict_policy`: `report`
- `business_day_calendar`: weekends = Saturday/Sunday, no holidays defined.

These attributes will map to `tracking.timeline_templates` columns (`timezone`, `anchor_strategy`, `conflict_policy`, `business_days_calendar`). The offsets below assume plan `start_date` and `end_date` are populated.

## 2. Anchor nodes

| Legacy ID | Action | Relation | Offset | Notes |
| --- | --- | --- | --- | --- |
| 0 | START DATE | — | 0 DAYS | Drives `node_type = ANCHOR`, `offset_value = 0`, root dependency. |
| 99 | END DATE | — | 0 DAYS | Terminal anchor; other tasks can reference via `BEFORE` relations. |

## 3. Task nodes

| # | Phase | Department | Action | Page label | Depends on | Relation | Offset | Offset unit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | DEVELOPMENT | CUSTOMER | TECHPACKS PASS OFF | Production BoM | START DATE | AFTER | 0 | DAYS |
| 2 | DEVELOPMENT | PD | PROTO PRODUCTION | — | TECHPACKS PASS OFF | AFTER | 4 | DAYS |
| 3 | DEVELOPMENT | PD | PROTO EX-FCTY | Proto Sample | PROTO PRODUCTION | AFTER | 14 | DAYS |
| 4 | DEVELOPMENT | ACCOUNT MANAGER | PROTO COSTING DUE | Production BoM | PROTO EX-FCTY | AFTER | 2 | DAYS |
| 5 | DEVELOPMENT | CUSTOMER | PROTO FIT COMMENTS DUE | Proto Sample | PROTO EX-FCTY | AFTER | 21 | DAYS |
| 6 | DEVELOPMENT | PD | 2nd PROTO PRODUCTION | — | PROTO FIT COMMENTS DUE | AFTER | 4 | DAYS |
| 7 | DEVELOPMENT | PD | 2nd PROTO EX-FCTY | Fit Sample | 2nd PROTO PRODUCTION | AFTER | 14 | DAYS |
| 8 | DEVELOPMENT | CUSTOMER | 2nd PROTO FIT COMMENTS DUE | Fit Sample | 2nd PROTO EX-FCTY | AFTER | 21 | DAYS |
| 9 | SMS | CUSTOMER | SMS POs PLACED | — | TECHPACKS PASS OFF | AFTER | 3 | DAYS |
| 10 | SMS | PD | SMS EX-FCTY | Fit Sample | SMS POs PLACED | AFTER | 106 | DAYS |
| 11 | PRODUCTION | CUSTOMER | BULK PO | — | PLAYERS CLUB… FINAL UPCS DUE | BEFORE | -74 | DAYS |
| 12 | ALLOCATION | CFT | Issue partner allocations | Sourcing and Delivery | BULK PO | AFTER | 2 | DAYS |
| 13 | ALLOCATION | FACTORY | Download Tech Packs | Tech Pack | BULK PO | AFTER | 4 | DAYS |
| 14 | ALLOCATION | CFT | Physical Reference Samples | Sourcing and Delivery | BULK PO | AFTER | 4 | DAYS |
| 15 | ALLOCATION | FINANCE | Confirm target CMP price | Sourcing and Delivery | BULK PO | AFTER | 4 | DAYS |
| 16 | ALLOCATION | FACTORY | Submit confirmed pricing and ex-factory date | Sourcing and Delivery | Download Tech Packs | AFTER | 8 | DAYS |
| 17 | ALLOCATION | ACCOUNT MANAGER | Approve terms and price | — | Submit confirmed pricing… | AFTER | 3 | DAYS |
| 18 | ALLOCATION | CFT | Issue purchase contract to factory | — | Approve terms and price | AFTER | 2 | BUSINESS_DAYS |
| 19 | ALLOCATION | FACTORY | Countersign Purchase Contract | — | Issue purchase contract to factory | AFTER | 6 | BUSINESS_DAYS |
| 20 | PRODUCTION | CUSTOMER | PLAYERS CLUB, RESIDED ORDERS, FINAL UPCS DUE | — | CUT DATE | BEFORE | -60 | DAYS |
| 21 | PRODUCTION | PURCHASING | BULK FABRIC & TRIM IN-HOUSE | — | CUT DATE | BEFORE | -30 | DAYS |
| 22 | PRODUCTION | CUSTOMER | PPS APPROVAL | PP Sample | CUT DATE | BEFORE | -10 | DAYS |
| 23 | PRODUCTION | FACTORY | CUT DATE | — | EX-FTY DATE | BEFORE | -60 | DAYS |
| 24 | PRODUCTION | FACTORY | EX-FTY DATE | — | END DATE | BEFORE | -30 | DAYS |
| 25 | PRODUCTION | LOGISTICS | IN WAREHOUSE | — | END DATE | AFTER | 0 | DAYS |

> Actions 11 and 20 use `BEFORE` relationships with negative offsets but maintain positive `offset_value` in the JSON. During normalization we will store signed integers (`offset_relation = BEFORE`, `offset_value = 60`, `offset_unit = DAYS`) to preserve meaning while avoiding double negatives.

## 4. Mapping notes

- `phase` and `department` fields become free-form text columns on `timeline_template_items` to preserve the original taxonomy.
- `page` values map to `page_type` via heuristic (e.g., `Production BoM` → `BOM`, `Fit Sample` → `SAMPLE_REQUEST_MULTI`); ambiguous cases should default to `NONE` while retaining `page_label`.
- Anchor nodes (`START DATE`, `END DATE`) must be seeded first, with deterministic UUIDs referenced by downstream tasks through `depends_on_template_item_id`.
- The template currently applies to style timelines. Visibility flags will default to `applies_to_style = true`, `applies_to_material = false` until material mapping is defined.
- Use the JSON’s `id` ordering as `display_order`; future edits should version the template to avoid breaking plan clones.

## 5. Next actions

1. Convert JSON extract into migration seed data inserting records into `tracking.timeline_template_items`.
2. Define page-type mapping table to convert `page_label` strings into enum-friendly values.
3. Tag each template item with visibility defaults for material timelines once corresponding material template is available.
4. Build validation script ensuring Supabase copy matches the BeProduct HTML grid screenshot (row counts, ordering, offsets).