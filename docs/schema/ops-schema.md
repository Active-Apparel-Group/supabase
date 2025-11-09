...existing code...
# OPS Schema Documentation

This document describes the `ops` schema tables for the Supabase operational tracking and timeline data model. It includes table/column descriptions, relationships, and business notes. This is a living document and will be updated as the schema evolves.

---

## Table: ops.tracking_plan
| Column         | Type    | Description / Business Note                       |
|----------------|---------|--------------------------------------------------|
| id             | uuid    | Primary key.                                     |
| name           | text    | Plan name.                                       |
| season         | text    | Season.                                          |
| brand          | text    | Brand.                                           |
| start_date     | date    | Plan start date.                                 |
| end_date       | date    | Plan end date.                                   |
| template_id    | uuid    | FK to `tracking_timeline_template`.              |
| active         | boolean | Is plan active?                                  |
| created_at     | timestamptz | Created timestamp.                             |
| updated_at     | timestamptz | Updated timestamp.                             |

**Relationships:**
- Referenced by `tracking_plan_style`, `tracking_plan_material`.
- FK to `tracking_timeline_template` via `template_id`.

---

## Table: ops.tracking_plan_style
| Column         | Type    | Description / Business Note                       |
|----------------|---------|--------------------------------------------------|
| id             | uuid    | Primary key.                                     |
| plan_id        | uuid    | FK to `tracking_plan`.                           |
| style_id       | uuid    | Style ID (from PIM).                             |
| color_id       | uuid    | Colorway ID (from PIM).                          |
| style_number   | text    | Style number.                                    |
| style_name     | text    | Style name.                                      |
| color_name     | text    | Colorway name.                                   |
| season         | text    | Season.                                          |
| brand          | text    | Brand.                                           |
| suppliers      | jsonb   | Array of supplier company IDs.                   |
| active         | boolean | Soft delete flag.                                |
| created_at     | timestamptz | Created timestamp.                             |
| updated_at     | timestamptz | Updated timestamp.                             |

**Relationships:**
- FK to `tracking_plan` via `plan_id`.
- Referenced by `tracking_plan_style_timeline`.

---

## Table: ops.tracking_plan_style_timeline
| Column             | Type    | Description / Business Note                       |
|--------------------|---------|--------------------------------------------------|
| id                 | uuid    | Primary key.                                     |
| plan_style_id      | uuid    | FK to `tracking_plan_style`.                     |
| template_item_id   | uuid    | FK to `tracking_timeline_template_item`.         |
| status             | enum    | Milestone status (NOT_STARTED, IN_PROGRESS, etc).|
| plan_date          | date    | Baseline planned date.                           |
| rev_date           | date    | Revised date (manual update).                    |
| final_date         | date    | Actual completion date.                          |
| due_date           | date    | Current working due date.                        |
| late               | boolean | Is milestone late?                               |
| notes              | text    | Notes.                                           |
| page_id            | uuid    | Linked page ID (if any).                         |
| page_type          | enum    | Page type (BOM, SAMPLE_REQUEST, etc).            |
| page_name          | text    | Page name.                                       |
| shared_with        | jsonb   | Array of company IDs with visibility.            |
| start_date_plan    | date    | Planned start date.                              |
| start_date_due     | date    | Committed/forecast start date.                   |
| duration_value     | int     | Task duration in days.                           |
| duration_unit      | enum    | Duration unit (DAYS, BUSINESS_DAYS).             |
| supplier_visible   | boolean | Is milestone visible to supplier users?           |
| customer_visible   | boolean | Is milestone visible to customer users?           |
| created_at         | timestamptz | Created timestamp.                             |
| updated_at         | timestamptz | Updated timestamp.                             |

**Relationships:**
- FK to `tracking_plan_style` via `plan_style_id`.
- FK to `tracking_timeline_template_item` via `template_item_id`.
- Referenced by `tracking_plan_style_dependency`.

---

## Table: ops.tracking_plan_style_dependency
| Column           | Type    | Description / Business Note                       |
|------------------|---------|--------------------------------------------------|
| successor_id     | uuid    | FK to `tracking_plan_style_timeline` (dependent).|
| predecessor_id   | uuid    | FK to `tracking_plan_style_timeline` (dependency).|
| offset_relation  | enum    | AFTER/BEFORE.                                    |
| offset_value     | int     | Offset value (days).                             |
| offset_unit      | enum    | Offset unit (DAYS, BUSINESS_DAYS).               |

**Relationships:**
- Both FKs to `tracking_plan_style_timeline`.

---

## Table: ops.tracking_timeline_template
| Column         | Type    | Description / Business Note                       |
|----------------|---------|--------------------------------------------------|
| id             | uuid    | Primary key.                                     |
| name           | text    | Template name.                                   |
| brand          | text    | Brand.                                           |
| season         | text    | Season.                                          |
| version        | int     | Template version.                                |
| is_active      | boolean | Is template active?                              |
| created_at     | timestamptz | Created timestamp.                             |
| updated_at     | timestamptz | Updated timestamp.                             |

**Relationships:**
- Referenced by `tracking_plan` and `tracking_timeline_template_item`.

---

## Table: ops.tracking_timeline_template_item
| Column                   | Type    | Description / Business Note                       |
|--------------------------|---------|--------------------------------------------------|
| id                       | uuid    | Primary key.                                     |
| template_id              | uuid    | FK to `tracking_timeline_template`.              |
| node_type                | enum    | ANCHOR/TASK.                                     |
| name                     | text    | Milestone name.                                  |
| phase                    | text    | Phase (DEV, SMS, etc).                           |
| display_order            | int     | Display order.                                   |
| depends_on_template_item_id | uuid | FK to another template item (dependency).        |
| offset_relation          | enum    | AFTER/BEFORE.                                    |
| offset_value             | int     | Offset value (days).                             |
| offset_unit              | enum    | Offset unit (DAYS, BUSINESS_DAYS).               |
| page_type                | enum    | Page type (BOM, SAMPLE_REQUEST, etc).            |
| applies_to_style         | boolean | Applies to style timelines.                      |
| applies_to_material      | boolean | Applies to material timelines.                   |
| required                 | boolean | Is milestone required?                           |
| duration_value           | int     | Default duration.                                |
| duration_unit            | enum    | Duration unit (DAYS, BUSINESS_DAYS).             |
| supplier_visible         | boolean | Is milestone visible to supplier users?           |
| customer_visible         | boolean | Is milestone visible to customer users?           |
| created_at               | timestamptz | Created timestamp.                             |
| updated_at               | timestamptz | Updated timestamp.                             |

**Relationships:**
- FK to `tracking_timeline_template` via `template_id`.
- FK to self via `depends_on_template_item_id`.
- Referenced by `tracking_plan_style_timeline`.

---

## Table: ops.tracking_timeline_assignment
| Column         | Type    | Description / Business Note                       |
|----------------|---------|--------------------------------------------------|
| id             | bigint  | Primary key.                                     |
| timeline_id    | uuid    | FK to timeline milestone (style/material).        |
| assignee_id    | uuid    | FK to user.                                      |
| role_name      | text    | Role assigned.                                   |
| assigned_at    | timestamptz | Assignment timestamp.                          |

**Relationships:**
- FK to timeline milestone (style/material).

---

## Table: ops.tracking_plan_material
| Column         | Type    | Description / Business Note                       |
|----------------|---------|--------------------------------------------------|
| id             | uuid    | Primary key.                                     |
| plan_id        | uuid    | FK to `tracking_plan`.                           |
| material_id    | uuid    | Material ID (from PIM).                          |
| color_id       | uuid    | Colorway ID (from PIM).                          |
| material_name  | text    | Material name.                                   |
| color_name     | text    | Colorway name.                                   |
| suppliers      | jsonb   | Array of supplier company IDs.                   |
| active         | boolean | Soft delete flag.                                |
| created_at     | timestamptz | Created timestamp.                             |
| updated_at     | timestamptz | Updated timestamp.                             |

**Relationships:**
- FK to `tracking_plan` via `plan_id`.
- Referenced by `tracking_plan_material_timeline`.

---

## Table: ops.tracking_plan_material_timeline
| Column             | Type    | Description / Business Note                       |
|--------------------|---------|--------------------------------------------------|
| id                 | uuid    | Primary key.                                     |
| plan_material_id   | uuid    | FK to `tracking_plan_material`.                  |
| template_item_id   | uuid    | FK to `tracking_timeline_template_item`.         |
| status             | enum    | Milestone status.                                |
| plan_date          | date    | Baseline planned date.                           |
| rev_date           | date    | Revised date (manual update).                    |
| final_date         | date    | Actual completion date.                          |
| due_date           | date    | Current working due date.                        |
| late               | boolean | Is milestone late?                               |
| notes              | text    | Notes.                                           |
| page_id            | uuid    | Linked page ID (if any).                         |
| page_type          | enum    | Page type.                                       |
| page_name          | text    | Page name.                                       |
| shared_with        | jsonb   | Array of company IDs with visibility.            |
| start_date_plan    | date    | Planned start date.                              |
| start_date_due     | date    | Committed/forecast start date.                   |
| duration_value     | int     | Task duration in days.                           |
| duration_unit      | enum    | Duration unit (DAYS, BUSINESS_DAYS).             |
| supplier_visible   | boolean | Is milestone visible to supplier users?           |
| customer_visible   | boolean | Is milestone visible to customer users?           |
| created_at         | timestamptz | Created timestamp.                             |
| updated_at         | timestamptz | Updated timestamp.                             |

**Relationships:**
- FK to `tracking_plan_material` via `plan_material_id`.
- FK to `tracking_timeline_template_item` via `template_item_id`.
- Referenced by `tracking_plan_material_dependency`.

---

## Table: ops.tracking_plan_material_dependency
| Column           | Type    | Description / Business Note                       |
|------------------|---------|--------------------------------------------------|
| successor_id     | uuid    | FK to `tracking_plan_material_timeline` (dependent).|
| predecessor_id   | uuid    | FK to `tracking_plan_material_timeline` (dependency).|
| offset_relation  | enum    | AFTER/BEFORE.                                    |
| offset_value     | int     | Offset value (days).                             |
| offset_unit      | enum    | Offset unit (DAYS, BUSINESS_DAYS).               |

**Relationships:**
- Both FKs to `tracking_plan_material_timeline`.

---

## Table: ops.tracking_timeline_template_visibility
| Column            | Type    | Description / Business Note                                 |
|-------------------|---------|------------------------------------------------------------|
| template_item_id  | uuid    | FK to `tracking_timeline_template_item`.                   |
| view_type         | enum    | View type (STYLE, MATERIAL).                               |
| is_visible        | boolean | Is this milestone visible in the given view? (default true)|

**Relationships:**
- FK to `tracking_timeline_template_item` via `template_item_id`.

---

## Foreign Key Cascade Update (2025-10-30)

**Change:**
- The foreign key from `tracking_plan_style_timeline.plan_style_id` to `tracking_plan_style.id` is now defined as `ON DELETE CASCADE`.

**Operational Impact:**
- Deleting a `tracking_plan_style` record will automatically delete all related `tracking_plan_style_timeline` and `tracking_plan_style_dependency` records.
- This ensures no orphaned milestones or dependencies remain when a style is removed from a plan.
- The workflow for re-assigning a style to a plan is now:
  1. Delete the `tracking_plan_style` record for the style/plan (all related milestones and dependencies are auto-removed).
  2. Insert a new `tracking_plan_style` record to re-assign the style (milestones and dependencies are freshly instantiated from the template).

---

## Example: Milestone Instantiation & Dependencies (Test Style/Plan)

**Plan:** GREYSON 2026 SPRING DROP 1  
**Style:** MONTAUK SHORT - 8" INSEAM (testing)

### Milestone Instantiation Table

| Display Order | Milestone Name                              | Status       | Plan Date   | Due Date   | Duration | Unit         | Customer Visible | Supplier Visible | Dependency (Predecessor → Successor, Offset) |
|--------------|---------------------------------------------|--------------|-------------|------------|----------|--------------|------------------|------------------|----------------------------------------------|
| 0            | START DATE                                  | NOT_STARTED  | 2025-05-01  | 2025-05-01 |           | DAYS         | TRUE             | TRUE             |                                          |
| 1            | TECHPACKS PASS OFF                          | NOT_STARTED  | 2025-05-01  | 2025-05-01 |           | DAYS         | TRUE             | TRUE             | START DATE → TECHPACKS PASS OFF (0 DAYS)    |
| 2            | PROTO PRODUCTION                            | NOT_STARTED  | 2025-05-09  | 2025-05-05 | 4        | DAYS         | TRUE             | TRUE             | TECHPACKS PASS OFF → PROTO PRODUCTION (4 DAYS) |
| 3            | PROTO EX-FCTY                               | NOT_STARTED  | 2025-06-02  | 2025-05-19 | 14       | DAYS         | TRUE             | TRUE             | PROTO PRODUCTION → PROTO EX-FCTY (14 DAYS)  |
| 4            | PROTO COSTING DUE                           | NOT_STARTED  | 2025-05-23  | 2025-05-21 | 2        | DAYS         | TRUE             | TRUE             | PROTO EX-FCTY → PROTO COSTING DUE (2 DAYS)  |
| 5            | PROTO FIT COMMENTS DUE                      | NOT_STARTED  | 2025-06-30  | 2025-06-09 | 21       | DAYS         | TRUE             | TRUE             | PROTO EX-FCTY → PROTO FIT COMMENTS DUE (21 DAYS) |
| 6            | 2nd PROTO PRODUCTION                        | NOT_STARTED  | 2025-06-17  | 2025-06-13 | 4        | DAYS         | TRUE             | TRUE             | PROTO FIT COMMENTS DUE → 2nd PROTO PRODUCTION (4 DAYS) |
| 7            | 2nd PROTO EX-FCTY                           | NOT_STARTED  | 2025-07-11  | 2025-06-27 | 14       | DAYS         | TRUE             | TRUE             | 2nd PROTO PRODUCTION → 2nd PROTO EX-FCTY (14 DAYS) |
| 8            | 2nd PROTO FIT COMMENTS DUE                  | NOT_STARTED  | 2025-08-08  | 2025-07-18 | 21       | DAYS         | TRUE             | TRUE             | 2nd PROTO EX-FCTY → 2nd PROTO FIT COMMENTS DUE (21 DAYS) |
| 9            | SMS POs PLACED                              | NOT_STARTED  | 2025-05-07  | 2025-05-04 | 3        | DAYS         | TRUE             | TRUE             | TECHPACKS PASS OFF → SMS POs PLACED (3 DAYS) |
| ...          | ...                                         | ...          | ...         | ...        | ...      | ...          | ...              | ...              | ...                                          |

*Note: Table truncated for brevity. See database for full milestone and dependency mapping.*

---

*This document is a living artifact. Update as your workflow, schema, and test data evolve.*
