# Hybrid Timeline Schema Redesign

**Status:** Ready for Implementation  
**Date:** October 31, 2025  
**Context:** Migration from entity-specific timeline tables to unified hybrid graph architecture

---

## 📋 Executive Summary

This document outlines a comprehensive redesign of the timeline tracking system to support unified cross-entity dependency management while preserving entity-specific business logic. The new hybrid architecture addresses critical gaps in the current implementation and provides feature parity with BeProduct tracking APIs.

**Key Changes:**
- ✅ Unified timeline graph layer (`timeline_node`) supporting cross-entity dependencies
- ✅ Entity-specific detail tables (`timeline_style`, `timeline_material`) for business logic
- ✅ Normalized assignment and sharing tables for performance
- ✅ Automatic dependency recalculation via triggers
- ✅ Complete BeProduct API parity with enhanced features

**Impact:**
- 🔄 **Breaking Changes:** Yes - existing timeline tables restructured
- 📊 **Data Migration:** Required - transform existing data to new schema
- 🎯 **Frontend Changes:** API endpoints restructured (detailed mapping provided)
- ⚡ **Performance:** Improved - normalized storage and indexed queries

---

## 📚 Document Structure

This redesign is documented across multiple files organized by concern:

| Document | Purpose | Audience |
|----------|---------|----------|
| **[This Document]** | Overview, schema design, migration plan | All stakeholders |
| **[Schema DDL](./schema-ddl.md)** | Complete table definitions, indexes, constraints | Backend developers |
| **[Triggers & Functions](./triggers-functions.md)** | Dependency recalculation logic, automation | Backend developers |
| **[BeProduct API Mapping](./beproduct-api-mapping.md)** | Endpoint comparison, data structure mapping | Integration team |
| **[Endpoint Design](./endpoint-design.md)** | New unified API layer specification | Frontend & backend |
| **[Query Examples](./query-examples.md)** | SQL queries for common operations | Backend developers |
| **[Migration Plan](./migration-plan.md)** | Step-by-step migration guide with rollback | DevOps, backend |
| **[Testing Plan](./testing-plan-updated.md)** | Comprehensive test coverage for new schema | QA, backend |
| **[Frontend Change Guide](./frontend-change-guide.md)** | Breaking changes, migration steps for UI | Frontend developers |

---

## 🎯 Business Problem & Solution

### Current Limitations
1. ❌ **No Cross-Entity Dependencies:** Styles cannot depend on materials (common in production workflows)
2. ❌ **Duplicate Timeline Logic:** Same dependency rules duplicated across `tracking_plan_style_timeline` and `tracking_plan_material_timeline`
3. ❌ **No Revision Recalculation:** BeProduct gap - changing `rev_date` doesn't cascade to downstream milestones
4. ❌ **Missing Start Dates:** No Gantt chart support (only end dates tracked)
5. ❌ **Performance Issues:** JSONB arrays for assignments/sharing instead of normalized tables

### Hybrid Architecture Solution

```
┌──────────────────────────────────────────────────────────────────┐
│                    TIMELINE HIERARCHY                             │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │             ops.timeline_folder                          │    │
│  │  - Brand/Season organization                            │    │
│  │  - Top-level container                                  │    │
│  └─────────────────┬───────────────────────────────────────┘    │
│                    │ 1:N                                          │
│                    ▼                                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │             ops.timeline_plan                            │    │
│  │  - Tracking plan header                                 │    │
│  │  - Date ranges, template reference                      │    │
│  └─────────────────┬───────────────────────────────────────┘    │
│                    │ 1:N                                          │
│                    ▼                                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │             ops.timeline_node                            │    │
│  │  - Universal timeline records for ALL entities          │    │
│  │  - Cross-entity dependency support                      │    │
│  │  - Core date fields (plan/rev/due/final)               │    │
│  │  - Status tracking and late flags                       │    │
│  │  - Entity-agnostic (style/material/order/production)    │    │
│  └─────────────────┬───────────────────────────────────────┘    │
│                    │ 1:1                                          │
│       ┌────────────┼────────────┐                                │
│       │            │            │                                 │
└───────┼────────────┼────────────┼─────────────────────────────────┘
        │            │            │
        ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ STYLE DETAIL │ │MATERIAL DETA │ │ FUTURE: ORDER│
│              │ │              │ │   PRODUCTION  │
├──────────────┤ ├──────────────┤ ├──────────────┤
│ timeline_    │ │ timeline_    │ │ timeline_    │
│   style      │ │   material   │ │   order      │
│              │ │              │ │              │
│ - style_id   │ │ - material_id│ │ - order_id   │
│ - colorway_id│ │ - milestone  │ │ - milestone  │
│ - milestone  │ │ - phase (FK) │ │ - phase (FK) │
│ - phase (FK) │ │ - dept (FK)  │ │ - dept (FK)  │
│ - dept (FK)  │ │ - page refs  │ │ - page refs  │
│ - page refs  │ │ - visibility │ │ - visibility │
│ - visibility │ │              │ │              │
└──────────────┘ └──────────────┘ └──────────────┘

ref/ schema (Reference Data)
├── ref_timeline_status (status codes)
├── ref_timeline_entity_type (entity types)
├── ref_dependency_type (dependency relationships)
├── ref_risk_level (risk classifications)
├── ref_phase (project phases)
├── ref_department (departments)
└── ref_page_type (page types)
```

**Benefits:**
- ✅ Single source of truth for all timeline logic
- ✅ Entity-specific business rules preserved in detail tables
- ✅ Cross-entity dependencies enabled (e.g., style depends on material approval)
- ✅ Easy to extend (new entity types just add detail table)
- ✅ Query flexibility (join graph for dependencies, detail for business context)

---

## 🏗️ High-Level Schema Overview

### Core Tables (New/Modified)

```
ref.ref_timeline_entity_type               [NEW - Entity Type Reference]
├── code (PK): style, material, order, production
├── label, description, display_order, is_active
└── Standardized ref schema pattern

ref.ref_dependency_type                    [NEW - Dependency Type Reference]
├── code (PK): finish_to_start, start_to_start, etc.
├── label, description, display_order, is_active
└── Standardized ref schema pattern

ref.ref_risk_level                         [NEW - Risk Level Reference]
├── code (PK): low, medium, high, critical
├── label, description, display_order, is_active
└── Standardized ref schema pattern

ops.timeline_folder                        [NEW - Brand/Season Organization]
├── folder_id (PK)
├── name, brand, season, year
├── description, active
├── created_at, updated_at, created_by, updated_by
└── Indexes: brand, season, active

ops.timeline_plan                          [NEW - Tracking Plan Header]
├── plan_id (PK)
├── folder_id (FK → timeline_folder)
├── template_id (FK → timeline_template)
├── name, description
├── start_date, end_date, timezone
├── color_theme, suppliers (JSONB)
├── active
├── created_at, updated_at, created_by, updated_by
└── Indexes: folder, template, dates, active

ops.timeline_node                          [NEW - Universal Graph Layer]
├── node_id (PK)
├── entity_type (TEXT, FK → ref_timeline_entity_type)
├── entity_id (style_id, material_id, etc.)
├── plan_id (FK → timeline_plan)
├── milestone_id (FK → timeline_template_milestone)
├── status (TEXT, FK → ref_timeline_status)
├── plan_date, rev_date, due_date, final_date
├── start_date_plan, start_date_due         [ENHANCEMENT: Gantt support]
├── is_late (computed)
├── created_at, updated_at, created_by, updated_by
└── Indexes: entity lookups, plan queries, status filters

ops.timeline_style                         [NEW - Style Business Logic]
├── node_id (PK, FK → timeline_node)
├── style_id (FK → pim.styles)
├── colorway_id (FK → pim.style_colorways)
├── milestone_name
├── phase (TEXT, FK → ref_phase)
├── department (TEXT, FK → ref_department)
├── page_id, page_title
├── page_type (TEXT, FK → ref_page_type)
├── customer_visible, supplier_visible      [Visibility flags]
├── submits_quantity
└── Indexes: style/colorway lookups

ops.timeline_material                       [NEW - Material Business Logic]
├── node_id (PK, FK → timeline_node)
├── material_id (FK → pim.materials)
├── milestone_name
├── phase (TEXT, FK → ref_phase)
├── department (TEXT, FK → ref_department)
├── page_id, page_title
├── page_type (TEXT, FK → ref_page_type)
├── customer_visible, supplier_visible
├── submits_quantity
└── Indexes: material lookups

ops.timeline_dependency                     [ENHANCED - Unified Dependencies]
├── dependency_id (PK)
├── dependent_node_id (FK → timeline_node)
├── predecessor_node_id (FK → timeline_node)
├── dependency_type (TEXT, FK → ref_dependency_type)
├── lag_days
├── lag_type (TEXT, FK → ref_offset_unit)
└── Indexes: dependency traversal

ops.timeline_assignment                    [NEW - Normalized Assignments]
├── assignment_id (PK)
├── node_id (FK → timeline_node)
├── user_id (FK → users)
├── assigned_at, assigned_by
└── Indexes: user workload queries

ops.timeline_share                         [NEW - Normalized Sharing]
├── share_id (PK)
├── node_id (FK → timeline_node)
├── user_id (FK → users)
├── shared_at, shared_by
└── Indexes: user visibility queries

ops.timeline_audit_log                     [NEW - Change Tracking]
├── audit_id (PK)
├── node_id (FK → timeline_node)
├── changed_field, old_value, new_value
├── changed_at, changed_by, change_reason
└── Indexes: node, changed_at, changed_by

ops.timeline_setting_health                [NEW - Risk Thresholds]
├── setting_id (PK)
├── risk_level (TEXT, FK → ref_risk_level, UNIQUE)
├── threshold_days, definition, sort_order
├── created_at, updated_at, created_by, updated_by
└── Indexes: risk_level, sort_order
```

### Table Tree View

```
ops/
├── timeline_folder                        [NEW - Brand/Season Container]
│   └── timeline_plan                      [NEW - Plan Header]
│       └── timeline_node                  [NEW - Universal Graph]
│           ├── timeline_style             [NEW - Style Details]
│           ├── timeline_material          [NEW - Material Details]
│           ├── timeline_dependency        [NEW - Dependencies]
│           ├── timeline_assignment        [NEW - User Assignments]
│           └── timeline_share             [NEW - User Sharing]
│
├── timeline_template                      [EXISTING - unchanged]
│   └── timeline_template_milestone        [EXISTING - unchanged]
│
├── timeline_audit_log                     [NEW - Change Tracking]
└── timeline_setting_health                [NEW - Risk Configuration]

ref/
├── ref_timeline_status                    [EXISTING]
├── ref_timeline_entity_type               [NEW]
├── ref_dependency_type                    [NEW]
├── ref_risk_level                         [NEW]
├── ref_phase                              [EXISTING]
├── ref_department                         [EXISTING]
├── ref_page_type                          [EXISTING]
├── ref_node_type                          [EXISTING]
├── ref_offset_relation                    [EXISTING]
└── ref_offset_unit                        [EXISTING]
```

---

## 🔄 Changes to Existing Schema

### Complete Schema Rename & Restructure

**IMPORTANT:** This is a **complete rename** from `tracking_*` to `timeline_*` with full schema restructure.

#### Key Changes Overview

| Old Table | New Table(s) | Change Type | Notes |
|-----------|--------------|-------------|-------|
| `tracking_folder` | `timeline_folder` | RENAME + ENHANCE | Added year field |
| `tracking_plan` | `timeline_plan` | RENAME + ENHANCE | Added folder_id FK |
| `tracking_plan_style_timeline` | `timeline_node` + `timeline_style` | RESTRUCTURE | Split into graph + detail |
| `tracking_plan_material_timeline` | `timeline_node` + `timeline_material` | RESTRUCTURE | Split into graph + detail |
| N/A | `timeline_dependency` | NEW | Unified cross-entity deps |
| N/A | `timeline_assignment` | NEW | Normalized assignments |
| N/A | `timeline_share` | NEW | Normalized sharing |
| N/A | `timeline_audit_log` | NEW | Change tracking |
| N/A | `timeline_setting_health` | NEW | Risk configuration |

### Reference Data Migration

**All ENUMs → ref schema FK references**

| Old ENUM | New ref Table | Status |
|----------|---------------|--------|
| `ops.timeline_status` | `ref.ref_timeline_status` | EXISTING |
| `ops.timeline_entity_type` | `ref.ref_timeline_entity_type` | NEW |
| `ops.dependency_type` | `ref.ref_dependency_type` | NEW |
| `ops.lag_type` | `ref.ref_offset_unit` | EXISTING |
| `ops.risk_level_enum` | `ref.ref_risk_level` | NEW |

### Detailed Table Changes

#### 1. `tracking_folder` → `timeline_folder`
**Changes:**
- Renamed table to align with timeline_* convention
- Primary key: `id` → `folder_id`
- Added `year` TEXT column for explicit year tracking
- All foreign keys updated to reference `folder_id`

#### 2. `tracking_plan` → `timeline_plan`
**Changes:**
- Renamed table to align with timeline_* convention
- Primary key: `id` → `plan_id`
- Added `folder_id` UUID FK → `timeline_folder(folder_id)`
- Template FK updated: `template_id` → `timeline_template(template_id)`
- All foreign keys updated to reference `plan_id`

#### 3. `tracking_plan_style_timeline` → DEPRECATED
**Action:** Data migrated to `timeline_node` + `timeline_style`  
**Reason:** Unified graph architecture with entity-agnostic node layer  
**Migration:** Transform existing records, preserve all data  
**Rollback:** Backup table maintained for 30 days

#### 4. `tracking_plan_material_timeline` → DEPRECATED
**Action:** Data migrated to `timeline_node` + `timeline_material`  
**Reason:** Unified graph architecture with entity-agnostic node layer  
**Migration:** Transform existing records, preserve all data  
**Rollback:** Backup table maintained for 30 days

#### 5. New Unified Dependency System
**Old:** Separate dependencies for styles and materials  
**New:** `timeline_dependency` supports cross-entity dependencies  
**Key Feature:** Style milestones can depend on material milestones (and vice versa)

**Example:**
```sql
-- Style "Final Approval" depends on Material "Lab Dip Approved"
INSERT INTO ops.timeline_dependency (
  dependent_node_id,      -- style node
  predecessor_node_id,    -- material node
  dependency_type,        -- 'finish_to_start'
  lag_days               -- 7 days after material approved
) VALUES (
  '<style_final_approval_node_id>',
  '<material_lab_dip_node_id>',
  'finish_to_start',
  7
);
```

---

## 🔧 Dependent Triggers & Functions

### New Triggers

#### 1. `trigger_calculate_timeline_due_date`
**Table:** `ops.timeline_node`  
**Event:** INSERT, UPDATE (when plan_date, rev_date, final_date, or dependencies change)  
**Purpose:** Auto-calculate `due_date` based on latest available date and dependency chain  
**Logic:**
```sql
due_date = COALESCE(
  final_date,           -- Use actual completion if done
  rev_date,             -- Use revision if rescheduled
  plan_date             -- Use original plan otherwise
) + dependency_lag_days
```

#### 2. `trigger_calculate_is_late`
**Table:** `ops.timeline_node`  
**Event:** INSERT, UPDATE (when due_date, plan_date change), daily cron  
**Purpose:** Auto-calculate late flag  
**Logic:**
```sql
is_late = (due_date > plan_date) OR (CURRENT_DATE > due_date AND status != 'completed')
```

#### 3. `trigger_recalculate_downstream_timelines`
**Table:** `ops.timeline_node`  
**Event:** UPDATE (when rev_date or final_date changes)  
**Purpose:** Cascade date changes to all dependent milestones  
**Logic:**
```sql
-- Calculate delta
delta_days = (new_date - old_date);

-- Recursive CTE to find all downstream nodes
WITH RECURSIVE downstream AS (
  SELECT dependent_node_id, lag_days
  FROM timeline_dependency
  WHERE predecessor_node_id = updated_node_id
  UNION ALL
  SELECT td.dependent_node_id, td.lag_days
  FROM timeline_dependency td
  JOIN downstream d ON td.predecessor_node_id = d.dependent_node_id
)
-- Update all downstream due_dates
UPDATE timeline_node
SET due_date = due_date + delta_days
WHERE node_id IN (SELECT dependent_node_id FROM downstream);
```

**CRITICAL ENHANCEMENT:** This fixes the BeProduct gap where `rev_date` changes don't cascade!

#### 4. `trigger_audit_timeline_changes`
**Table:** `ops.timeline_node`  
**Event:** UPDATE (any field change)  
**Purpose:** Audit trail for all timeline changes  
**Target Table:** `ops.timeline_audit_log`

### Modified Functions

#### 1. `fn_instantiate_plan_timeline()` → UPDATED
**Changes:**
- Generate `timeline_node` records instead of entity-specific tables
- Create corresponding detail records (`timeline_style` or `timeline_material`)
- Preserve all existing business logic (date calculations, offsets, etc.)

#### 2. `fn_get_timeline_progress()` → UPDATED
**Changes:**
- Query `timeline_node` instead of separate entity tables
- Aggregate across all entity types for plan-level progress
- Return same output structure (backward compatible)

### New Functions

#### 1. `fn_get_timeline_critical_path(plan_id UUID)`
**Purpose:** Calculate critical path for Gantt chart rendering  
**Returns:** Array of node_ids representing longest dependency chain

#### 2. `fn_get_user_timeline_workload(user_id UUID)`
**Purpose:** Get all assigned milestones for a user across all plans  
**Returns:** Table with node_id, entity_type, entity_name, due_date, status, is_late

#### 3. `fn_bulk_update_timeline_status(node_ids UUID[], new_status TEXT)`
**Purpose:** Efficiently update multiple milestones (parallel to BeProduct `planUpdateStyleTimelines`)  
**Returns:** Array of updated node_ids

---

## 📊 BeProduct API Mapping Summary

*(Full details in [BeProduct API Mapping](./beproduct-api-mapping.md))*

### Tested Endpoints

| BeProduct Tool | Operation | Test Plan | Result |
|---------------|-----------|-----------|--------|
| `beproduct-tracking` | `planSearch` | GREYSON query | ✅ 11 plans found |
| `beproduct-tracking` | `planGet` | Plan 162eedf3 | ✅ 25 style + 9 material milestones |
| `beproduct-tracking` | `planStyleTimeline` | Plan 162eedf3 | ✅ 75 milestone instances (3 colorways) |
| `beproduct-tracking` | `planStyleProgress` | Plan 162eedf3 | ✅ 125 total, 110 late, 11 in_progress |

### Key Data Structures Retrieved

#### Plan Metadata (planGet)
```json
{
  "id": "162eedf3-0230-4e4c-88e1-6db332e3707b",
  "name": "GREYSON 2026 SPRING DROP 1",
  "startDate": "2025-05-01",
  "endDate": "2026-01-05",
  "styleTimeline": [
    {
      "id": "timeline-milestone-id",
      "name": "TECHPACKS PASS OFF",
      "phase": "DEVELOPMENT",
      "department": "DESIGN",
      "customerVisible": true,
      "supplierVisible": false,
      "pageName": "Techpack"
    }
    // ... 24 more style milestones
  ],
  "materialTimeline": [
    {
      "id": "timeline-milestone-id",
      "name": "MATERIAL SUBMITTED",
      "phase": "DEVELOPMENT",
      "department": "PRODUCT DEVELOPMENT"
    }
    // ... 8 more material milestones
  ]
}
```

#### Timeline Instance Data (planStyleTimeline)
```json
{
  "style": "MSP26B26",
  "styleName": "MONTAUK SHORT - 8\" INSEAM",
  "colorway": "220 - GROVE",
  "supplier": "NAGACO",
  "timeline": [
    {
      "id": "instance-record-id",
      "timelineId": "template-milestone-id",
      "status": "Approved",
      "plan": "2025-05-01",
      "rev": null,
      "due": "2025-05-01",
      "final": "2025-05-01",
      "late": false,
      "assignedTo": [],
      "shareWith": [],
      "page": {
        "id": "page-id",
        "title": "Techpack",
        "type": "techpack"
      },
      "submitsQuantity": 0
    }
    // ... 24 more milestones for this colorway
  ]
}
```

#### Progress Summary (planStyleProgress)
```json
{
  "not_started": 109,
  "in_progress": 11,
  "waiting_on": 0,
  "rejected": 0,
  "approved": 5,
  "approved_with_corrections": 0,
  "na": 0,
  "late": 110,
  "total": 125
}
```

---

## 🔗 New Unified API Endpoints

*(Full specification in [Endpoint Design](./endpoint-design.md))*

### Design Principles
1. **Domain-Based:** Endpoints grouped by domain (tracking, style, color, material)
2. **Entity-Agnostic:** Tracking endpoints work across all entity types
3. **BeProduct Parity:** Same operations, enhanced data structures
4. **RESTful:** Standard HTTP methods and resource paths
5. **Enriched Responses:** Additional fields for Gantt, critical path, etc.

### Tracking Domain Endpoints

#### 1. Get Timeline for Entity
```
GET /api/v1/tracking/timeline/{entity_type}/{entity_id}
```
**Entity Types:** `style`, `material`, `order`, `production`  
**Response:** Timeline nodes with assignments, sharing, dependencies  
**Equivalent BeProduct:** `planStyleTimeline`, `planMaterialTimeline`

**Example Response:**
```json
{
  "entity_type": "style",
  "entity_id": "style-uuid",
  "entity_name": "MONTAUK SHORT - 8\" INSEAM",
  "colorway": "220 - GROVE",
  "plan_id": "plan-uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "timeline": [
    {
      "node_id": "node-uuid",
      "milestone_name": "TECHPACKS PASS OFF",
      "phase": "DEVELOPMENT",
      "department": "DESIGN",
      "status": "approved",
      "plan_date": "2025-05-01",
      "rev_date": null,
      "due_date": "2025-05-01",
      "final_date": "2025-05-01",
      "start_date_plan": "2025-04-28",
      "start_date_due": "2025-04-28",
      "is_late": false,
      "assigned_to": [],
      "shared_with": [],
      "page": {
        "id": "page-id",
        "title": "Techpack",
        "type": "techpack"
      },
      "customer_visible": true,
      "supplier_visible": false,
      "dependencies": [
        {
          "predecessor_node_id": "other-node-uuid",
          "predecessor_milestone": "START DATE",
          "dependency_type": "finish_to_start",
          "lag_days": 5
        }
      ]
    }
    // ... more milestones
  ]
}
```

#### 2. Get Plan Progress
```
GET /api/v1/tracking/plans/{plan_id}/progress
```
**Query Params:** `entity_type` (optional filter)  
**Response:** Status summary across all entities  
**Equivalent BeProduct:** `planStyleProgress`, `planMaterialProgress`

**Example Response:**
```json
{
  "plan_id": "plan-uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "total_milestones": 125,
  "by_status": {
    "not_started": 109,
    "in_progress": 11,
    "waiting_on": 0,
    "rejected": 0,
    "approved": 5,
    "approved_with_corrections": 0,
    "na": 0
  },
  "late_count": 110,
  "on_time_count": 15,
  "completion_percentage": 4.0,
  "by_entity_type": {
    "style": {
      "total": 75,
      "late": 65,
      "completed": 5
    },
    "material": {
      "total": 50,
      "late": 45,
      "completed": 0
    }
  }
}
```

#### 3. Update Timeline Milestones (Bulk)
```
PATCH /api/v1/tracking/timeline/bulk
```
**Request Body:**
```json
{
  "updates": [
    {
      "node_id": "node-uuid-1",
      "status": "in_progress",
      "rev_date": "2025-11-15"
    },
    {
      "node_id": "node-uuid-2",
      "final_date": "2025-11-01",
      "status": "approved"
    }
  ]
}
```
**Response:** Updated node records with recalculated downstream dates  
**Equivalent BeProduct:** `planUpdateStyleTimelines`, `planUpdateMaterialTimelines`

#### 4. Get User Workload
```
GET /api/v1/tracking/users/{user_id}/assignments
```
**Response:** All assigned milestones across plans  
**Enhancement:** Not available in BeProduct (new capability)

### BeProduct Tool → Supabase Endpoint Mapping

| BeProduct Tool | Operation | New Supabase Endpoint | Notes |
|---------------|-----------|----------------------|-------|
| `beproduct-tracking` | `planSearch` | `GET /api/v1/tracking/plans?search={query}` | Same search capability |
| `beproduct-tracking` | `planGet` | `GET /api/v1/tracking/plans/{plan_id}` | Same metadata structure |
| `beproduct-tracking` | `planStyleTimeline` | `GET /api/v1/tracking/timeline/style/{style_id}` | Enhanced with start dates |
| `beproduct-tracking` | `planMaterialTimeline` | `GET /api/v1/tracking/timeline/material/{material_id}` | Enhanced with start dates |
| `beproduct-tracking` | `planStyleProgress` | `GET /api/v1/tracking/plans/{plan_id}/progress?entity_type=style` | Same output structure |
| `beproduct-tracking` | `planMaterialProgress` | `GET /api/v1/tracking/plans/{plan_id}/progress?entity_type=material` | Same output structure |
| `beproduct-tracking` | `planUpdateStyleTimelines` | `PATCH /api/v1/tracking/timeline/bulk` | Enhanced with auto-recalc |
| `beproduct-tracking` | `planUpdateMaterialTimelines` | `PATCH /api/v1/tracking/timeline/bulk` | Enhanced with auto-recalc |
| `beproduct-tracking` | `planStyleView` | `GET /api/v1/tracking/timeline/style/{style_id}/view` | Per-milestone detail view |
| `beproduct-tracking` | `planMaterialView` | `GET /api/v1/tracking/timeline/material/{material_id}/view` | Per-milestone detail view |
| (NEW) | N/A | `GET /api/v1/tracking/users/{user_id}/assignments` | User workload view |
| (NEW) | N/A | `GET /api/v1/tracking/plans/{plan_id}/critical-path` | Gantt chart support |

---

## 📝 Example Query Outputs

*(Full examples in [Query Examples](./query-examples.md))*

### Query 1: Timeline with Assignments/Sharing (Replicates planStyleTimeline)

```sql
SELECT 
  tn.node_id,
  ts.milestone_name,
  ts.phase,
  ts.department,
  tn.status,
  tn.plan_date,
  tn.rev_date,
  tn.due_date,
  tn.final_date,
  tn.start_date_plan,
  tn.start_date_due,
  tn.is_late,
  ts.page_id,
  ts.page_title,
  ts.page_type,
  ts.customer_visible,
  ts.supplier_visible,
  ts.submits_quantity,
  -- Aggregate assignments as array (matches BeProduct assignedTo)
  COALESCE(
    json_agg(
      DISTINCT jsonb_build_object(
        'user_id', ta.user_id,
        'user_name', u1.name,
        'assigned_at', ta.assigned_at
      )
    ) FILTER (WHERE ta.user_id IS NOT NULL),
    '[]'::json
  ) AS assigned_to,
  -- Aggregate sharing as array (matches BeProduct shareWith)
  COALESCE(
    json_agg(
      DISTINCT jsonb_build_object(
        'user_id', ts_share.user_id,
        'user_name', u2.name,
        'shared_at', ts_share.shared_at
      )
    ) FILTER (WHERE ts_share.user_id IS NOT NULL),
    '[]'::json
  ) AS shared_with
FROM ops.timeline_node tn
JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.tracking_timeline_assignment ta ON tn.node_id = ta.node_id
LEFT JOIN ops.tracking_timeline_share ts_share ON tn.node_id = ts_share.node_id
LEFT JOIN auth.users u1 ON ta.user_id = u1.id
LEFT JOIN auth.users u2 ON ts_share.user_id = u2.id
WHERE tn.entity_type = 'style'
  AND tn.entity_id = 'style-uuid'
  AND tn.plan_id = 'plan-uuid'
GROUP BY tn.node_id, ts.node_id
ORDER BY tn.plan_date;
```

**Example Output:**
```json
[
  {
    "node_id": "node-uuid-1",
    "milestone_name": "TECHPACKS PASS OFF",
    "phase": "DEVELOPMENT",
    "department": "DESIGN",
    "status": "approved",
    "plan_date": "2025-05-01",
    "rev_date": null,
    "due_date": "2025-05-01",
    "final_date": "2025-05-01",
    "start_date_plan": "2025-04-28",
    "start_date_due": "2025-04-28",
    "is_late": false,
    "page_id": "page-uuid",
    "page_title": "Techpack",
    "page_type": "techpack",
    "customer_visible": true,
    "supplier_visible": false,
    "submits_quantity": 0,
    "assigned_to": [],
    "shared_with": []
  },
  {
    "node_id": "node-uuid-2",
    "milestone_name": "PROTO PRODUCTION",
    "phase": "DEVELOPMENT",
    "department": "PRODUCT DEVELOPMENT",
    "status": "in_progress",
    "plan_date": "2025-05-05",
    "rev_date": "2025-09-16",
    "due_date": "2025-09-16",
    "final_date": null,
    "start_date_plan": "2025-05-02",
    "start_date_due": "2025-09-13",
    "is_late": true,
    "page_id": "page-uuid-2",
    "page_title": "Proto Sample",
    "page_type": "sample",
    "customer_visible": false,
    "supplier_visible": true,
    "submits_quantity": 1,
    "assigned_to": [
      {
        "user_id": "user-uuid",
        "user_name": "Natalie James",
        "assigned_at": "2025-05-02T10:00:00Z"
      }
    ],
    "shared_with": [
      {
        "user_id": "user-uuid-2",
        "user_name": "Chris K",
        "shared_at": "2025-05-03T14:30:00Z"
      }
    ]
  }
]
```

### Query 2: Progress Summary (Replicates planStyleProgress)

```sql
SELECT 
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE status = 'not_started') AS not_started,
  COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress,
  COUNT(*) FILTER (WHERE status = 'waiting_on') AS waiting_on,
  COUNT(*) FILTER (WHERE status = 'rejected') AS rejected,
  COUNT(*) FILTER (WHERE status = 'approved') AS approved,
  COUNT(*) FILTER (WHERE status = 'approved_with_corrections') AS approved_with_corrections,
  COUNT(*) FILTER (WHERE status = 'na') AS na,
  COUNT(*) FILTER (WHERE is_late = true) AS late
FROM ops.timeline_node
WHERE plan_id = 'plan-uuid'
  AND entity_type = 'style';
```

**Example Output:**
```json
{
  "total": 125,
  "not_started": 109,
  "in_progress": 11,
  "waiting_on": 0,
  "rejected": 0,
  "approved": 5,
  "approved_with_corrections": 0,
  "na": 0,
  "late": 110
}
```

---

## 🚀 Change Management Plan

*(Full details in [Migration Plan](./migration-plan.md) and [Frontend Change Guide](./frontend-change-guide.md))*

### Phase 1: Schema Migration (Backend)
**Duration:** 1 week  
**Risk:** Low (non-production data)

1. **Create new tables** (`timeline_node`, `timeline_style`, `timeline_material`, etc.)
2. **Migrate existing data** from deprecated tables
3. **Update triggers and functions**
4. **Run validation queries** to ensure data integrity
5. **Deploy new API endpoints** (backward compatible where possible)

### Phase 2: Frontend Migration (UI)
**Duration:** 2 weeks  
**Risk:** Medium (breaking changes)

#### Breaking Changes

| Component | Old Behavior | New Behavior | Migration Required |
|-----------|-------------|--------------|-------------------|
| **Timeline List** | Queries `tracking_plan_style_timeline` | Queries `timeline_node` + `timeline_style` | ✅ Update API calls |
| **Gantt Chart** | Only end dates available | Start + end dates available | ✅ Update chart rendering |
| **Progress Dashboard** | Separate style/material queries | Unified progress endpoint | ✅ Update API calls |
| **Assignment UI** | JSONB array in timeline record | Separate `tracking_timeline_assignment` table | ✅ Update save/fetch logic |
| **Dependency Editor** | Entity-specific dependencies | Cross-entity dependencies supported | ⚠️ Optional enhancement |

#### Migration Steps for Frontend

1. **Update API client** to use new endpoint structure
2. **Update timeline components** to handle new data shape
3. **Add Gantt chart enhancements** (start dates, critical path)
4. **Update assignment/sharing UI** to use normalized tables
5. **Test all timeline workflows** (view, edit, bulk update)

### Phase 3: Deprecation & Cleanup
**Duration:** 1 week (after 30-day grace period)  
**Risk:** Low

1. **Remove old API endpoints** (after frontend migration complete)
2. **Archive deprecated tables** (backup for 30 days)
3. **Drop deprecated tables** (after stakeholder approval)
4. **Update documentation** (mark old endpoints as deprecated)

### Rollback Plan

If critical issues arise:
1. **Restore backup tables** from pre-migration snapshot
2. **Revert API endpoints** to old implementation
3. **Frontend reverts to old API calls** (if already migrated)
4. **Investigate and fix issues** before retry

---

## ✅ Testing Plan Overview

*(Full testing plan in [Testing Plan Updated](./testing-plan-updated.md))*

### Test Categories

#### 1. Schema Validation Tests
- ✅ All tables created successfully
- ✅ All constraints and indexes in place
- ✅ Foreign key relationships valid
- ✅ Data types correct

#### 2. Data Migration Tests
- ✅ All records migrated from old tables
- ✅ No data loss during migration
- ✅ Relationships preserved (assignments, sharing, dependencies)
- ✅ Date calculations accurate

#### 3. Trigger & Function Tests
- ✅ `due_date` auto-calculation works
- ✅ `is_late` flag computed correctly
- ✅ Downstream recalculation cascades properly
- ✅ Audit trail captures all changes

#### 4. API Endpoint Tests
- ✅ All endpoints return expected data structure
- ✅ Query performance acceptable (< 500ms for timeline queries)
- ✅ Bulk update endpoints handle concurrent requests
- ✅ Error handling for invalid inputs

#### 5. Integration Tests
- ✅ BeProduct webhook sync works
- ✅ Timeline updates propagate correctly
- ✅ Cross-entity dependencies resolve
- ✅ User workload queries accurate

#### 6. Frontend Integration Tests
- ✅ Timeline list renders correctly
- ✅ Gantt chart displays start/end dates
- ✅ Progress dashboard shows accurate counts
- ✅ Assignment UI saves/fetches correctly
- ✅ Bulk status updates work

### Test Data

Using **GREYSON 2026 SPRING DROP 1** plan:
- **Plan ID:** `162eedf3-0230-4e4c-88e1-6db332e3707b`
- **Style:** MONTAUK SHORT - 8" INSEAM
- **Colorways:** 3 (220 - GROVE, 359 - PINK SKY, 947 - ZION)
- **Total Milestones:** 125 (75 style + 50 estimated material)
- **Current Status:** 11 in_progress, 5 approved, 109 not_started, 110 late

---

## 📅 Implementation Timeline

| Week | Phase | Tasks | Owner | Status |
|------|-------|-------|-------|--------|
| **Week 1** | Schema Migration | Create tables, migrate data, update triggers | Backend | ⏳ Pending |
| **Week 2** | API Development | Implement new endpoints, test with Postman | Backend | ⏳ Pending |
| **Week 3** | Frontend Updates (Part 1) | Update API client, timeline list component | Frontend | ⏳ Pending |
| **Week 4** | Frontend Updates (Part 2) | Gantt chart, assignment UI, progress dashboard | Frontend | ⏳ Pending |
| **Week 5** | Testing & QA | Full regression testing, performance testing | QA | ⏳ Pending |
| **Week 6** | Deployment & Monitoring | Deploy to production, monitor for issues | DevOps | ⏳ Pending |
| **Week 7-10** | Grace Period | Support old endpoints, monitor adoption | All | ⏳ Pending |
| **Week 11** | Cleanup | Deprecate old endpoints, archive old tables | Backend | ⏳ Pending |

---

## 🎯 Success Criteria

### Technical Metrics
- ✅ All existing timeline functionality preserved
- ✅ Query performance < 500ms for timeline lists
- ✅ Zero data loss during migration
- ✅ All triggers executing correctly
- ✅ API endpoints return correct data structure

### Business Metrics
- ✅ Frontend developers can complete migration in 2 weeks
- ✅ No production incidents related to timeline functionality
- ✅ Cross-entity dependencies enable new workflows (style→material)
- ✅ Gantt chart improvements deliver value (start dates visible)

### User Experience
- ✅ No visible disruption to end users
- ✅ Timeline UI loads faster (normalized queries)
- ✅ Assignment/sharing features more responsive
- ✅ Progress dashboards more accurate

---

## 📚 Related Documentation

- [Schema DDL](./schema-ddl.md) - Complete table definitions
- [Triggers & Functions](./triggers-functions.md) - Automation logic
- [BeProduct API Mapping](./beproduct-api-mapping.md) - Endpoint comparison
- [Endpoint Design](./endpoint-design.md) - New API specification
- [Query Examples](./query-examples.md) - SQL examples for common operations
- [Migration Plan](./migration-plan.md) - Step-by-step migration guide
- [Testing Plan](./testing-plan-updated.md) - Comprehensive test coverage
- [Frontend Change Guide](./frontend-change-guide.md) - UI migration guide

---

## ❓ Questions & Support

For questions about this redesign, contact:
- **Backend/Schema:** [Backend team lead]
- **API Design:** [Backend team lead]
- **Frontend Migration:** [Frontend team lead]
- **Testing:** [QA lead]
- **Project Management:** [PM/Product owner]

---

**Document Status:** ✅ Ready for Review  
**Last Updated:** October 31, 2025  
**Version:** 1.0
