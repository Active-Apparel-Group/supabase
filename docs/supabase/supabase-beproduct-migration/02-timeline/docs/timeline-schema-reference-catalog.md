# Timeline Schema Reference Catalog

**Purpose:** Comprehensive reference catalog for all timeline schema components  
**Status:** Living Document  
**Date:** November 2, 2025  
**Version:** 1.0

---

## 📋 Document Purpose

This document serves as a **single source of truth** for all timeline schema components. Use this as your quick reference guide when:
- Looking up table structures and relationships
- Finding specific endpoints or views
- Understanding the complete schema hierarchy
- Navigating the timeline system architecture

**For detailed implementation:** See individual documentation files listed in [README.md](./README.md)

---

## Table of Contents

1. [Complete Table Hierarchy](#complete-table-hierarchy)
2. [Table Catalog](#table-catalog)
3. [View Catalog](#view-catalog)
4. [Function Catalog](#function-catalog)
5. [Endpoint Catalog](#endpoint-catalog)
6. [Reference Data Catalog](#reference-data-catalog)
7. [Entity Relationship Diagrams](#entity-relationship-diagrams)
8. [System Architecture](#system-architecture)

---

## Complete Table Hierarchy

### Tree View

```
ops/
├── timeline_folder                        [NEW - Brand/Season Organization]
│   └── timeline_plan                      [NEW - Tracking Plan Header]
│       └── timeline_node                  [NEW - Universal Milestone Graph]
│           ├── timeline_style             [NEW - Style Business Logic]
│           ├── timeline_material          [NEW - Material Business Logic]
│           ├── timeline_dependency        [NEW - Cross-Entity Dependencies]
│           ├── timeline_assignment        [NEW - User Assignments]
│           └── timeline_share             [NEW - User Sharing/Visibility]
│
├── timeline_template                      [NEW - Timeline Template Header]
│   └── timeline_template_milestone        [NEW - Template Milestone Definitions]
│
├── timeline_audit_log                     [NEW - Change Tracking]
└── timeline_setting_health                [NEW - Risk Threshold Configuration]

ref/
├── ref_timeline_status                    [EXISTING - Status values]
├── ref_timeline_entity_type               [NEW - Entity types]
├── ref_dependency_type                    [NEW - Dependency relationships]
├── ref_risk_level                         [NEW - Risk levels]
├── ref_phase                              [EXISTING - Phase values]
├── ref_department                         [EXISTING - Department values]
├── ref_page_type                          [EXISTING - Page types]
├── ref_node_type                          [EXISTING - Node types]
├── ref_offset_relation                    [EXISTING - Offset relations]
└── ref_offset_unit                        [EXISTING - Offset units]
```

### Flat Alphabetical View

| Schema | Table Name | Type | Purpose |
|--------|-----------|------|---------|
| `ops` | `timeline_assignment` | Transaction | User-to-milestone assignments |
| `ops` | `timeline_audit_log` | Transaction | Change tracking/audit trail |
| `ops` | `timeline_dependency` | Transaction | Milestone dependencies |
| `ops` | `timeline_folder` | Master | Brand/season folder organization |
| `ops` | `timeline_material` | Detail | Material-specific milestone data |
| `ops` | `timeline_node` | Graph | Universal milestone records |
| `ops` | `timeline_plan` | Master | Tracking plan header |
| `ops` | `timeline_setting_health` | Config | Risk level thresholds |
| `ops` | `timeline_share` | Transaction | User visibility sharing |
| `ops` | `timeline_style` | Detail | Style-specific milestone data |
| `ops` | `timeline_template` | Master | Timeline template header |
| `ops` | `timeline_template_milestone` | Detail | Template milestone definitions |
| `ref` | `ref_dependency_type` | Reference | Dependency type lookup |
| `ref` | `ref_department` | Reference | Department lookup |
| `ref` | `ref_node_type` | Reference | Node type lookup |
| `ref` | `ref_offset_relation` | Reference | Offset relation lookup |
| `ref` | `ref_offset_unit` | Reference | Offset unit lookup |
| `ref` | `ref_page_type` | Reference | Page type lookup |
| `ref` | `ref_phase` | Reference | Phase lookup |
| `ref` | `ref_risk_level` | Reference | Risk level lookup |
| `ref` | `ref_timeline_entity_type` | Reference | Entity type lookup |
| `ref` | `ref_timeline_status` | Reference | Status lookup |

---

## Table Catalog

### 1. timeline_folder
**Schema:** `ops`  
**Purpose:** Top-level organization by brand/season  
**Relationships:** Parent of `timeline_plan`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `folder_id` | UUID | NO | Primary key |
| `name` | TEXT | NO | Folder name (e.g., "GREYSON 2026 SPRING") |
| `brand` | TEXT | YES | Brand name |
| `season` | TEXT | YES | Season designation |
| `year` | TEXT | YES | Year |
| `description` | TEXT | YES | Folder description |
| `active` | BOOLEAN | NO | Soft delete flag |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |
| `created_by` | UUID | YES | FK to auth.users |
| `updated_by` | UUID | YES | FK to auth.users |

**Indexes:**
- `PK: folder_id`
- `idx_timeline_folder_brand`
- `idx_timeline_folder_season`
- `idx_timeline_folder_active`

---

### 2. timeline_plan
**Schema:** `ops`  
**Purpose:** Tracking plan header with dates and template reference  
**Relationships:** Child of `timeline_folder`, parent of `timeline_node`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `plan_id` | UUID | NO | Primary key |
| `folder_id` | UUID | YES | FK to timeline_folder |
| `name` | TEXT | NO | Plan name (e.g., "DROP 1") |
| `description` | TEXT | YES | Plan description |
| `template_id` | UUID | YES | FK to timeline_template |
| `start_date` | DATE | YES | Plan start date |
| `end_date` | DATE | YES | Plan end date |
| `timezone` | TEXT | YES | Timezone (e.g., "America/New_York") |
| `color_theme` | TEXT | YES | UI color theme |
| `suppliers` | JSONB | YES | Array of supplier company IDs with access |
| `active` | BOOLEAN | NO | Soft delete flag |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |
| `created_by` | UUID | YES | FK to auth.users |
| `updated_by` | UUID | YES | FK to auth.users |

**Indexes:**
- `PK: plan_id`
- `idx_timeline_plan_folder`
- `idx_timeline_plan_template`
- `idx_timeline_plan_dates`
- `idx_timeline_plan_active`

**Constraints:**
- `FK: folder_id → timeline_folder(folder_id)`
- `FK: template_id → timeline_template(template_id)`
- `CHECK: end_date IS NULL OR end_date >= start_date`

---

### 3. timeline_node
**Schema:** `ops`  
**Purpose:** Universal milestone graph supporting all entity types  
**Relationships:** Child of `timeline_plan`, parent of detail tables

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `node_id` | UUID | NO | Primary key |
| `plan_id` | UUID | NO | FK to timeline_plan |
| `entity_type` | TEXT | NO | FK to ref_timeline_entity_type (style/material/order/production) |
| `entity_id` | UUID | NO | Polymorphic FK to entity-specific table |
| `milestone_id` | UUID | NO | FK to timeline_template_milestone |
| `status` | TEXT | NO | FK to ref_timeline_status |
| `plan_date` | DATE | NO | Original baseline date |
| `rev_date` | DATE | YES | Revised/rescheduled date |
| `due_date` | DATE | NO | Current working due date (computed) |
| `final_date` | DATE | YES | Actual completion date |
| `start_date_plan` | DATE | YES | Planned start date (for Gantt) |
| `start_date_due` | DATE | YES | Current start date (for Gantt) |
| `is_late` | BOOLEAN | NO | Computed late flag |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |
| `created_by` | UUID | YES | FK to auth.users |
| `updated_by` | UUID | YES | FK to auth.users |

**Indexes:**
- `PK: node_id`
- `idx_timeline_node_plan`
- `idx_timeline_node_entity`
- `idx_timeline_node_milestone`
- `idx_timeline_node_status`
- `idx_timeline_node_late` (WHERE is_late = true)
- `idx_timeline_node_due_date`
- `idx_timeline_node_plan_entity` (composite)

**Constraints:**
- `FK: plan_id → timeline_plan(plan_id)`
- `FK: entity_type → ref_timeline_entity_type(code)`
- `FK: milestone_id → timeline_template_milestone(milestone_id)`
- `FK: status → ref_timeline_status(code)`
- `CHECK: due_date = COALESCE(final_date, rev_date, plan_date)`
- `CHECK: entity_id IS NOT NULL`

---

### 4. timeline_style
**Schema:** `ops`  
**Purpose:** Style-specific milestone business logic  
**Relationships:** 1-to-1 child of `timeline_node`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `node_id` | UUID | NO | PK & FK to timeline_node |
| `style_id` | UUID | NO | FK to pim.styles |
| `colorway_id` | UUID | YES | FK to pim.style_colorways |
| `milestone_name` | TEXT | NO | Milestone display name |
| `phase` | TEXT | YES | FK to ref_phase |
| `department` | TEXT | YES | FK to ref_department |
| `page_id` | UUID | YES | BeProduct page reference |
| `page_title` | TEXT | YES | Page display title |
| `page_type` | TEXT | YES | FK to ref_page_type |
| `customer_visible` | BOOLEAN | NO | Customer visibility flag |
| `supplier_visible` | BOOLEAN | NO | Supplier visibility flag |
| `submits_quantity` | INTEGER | NO | Number of submissions |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |

**Indexes:**
- `PK: node_id`
- `idx_timeline_style_style`
- `idx_timeline_style_colorway`
- `idx_timeline_style_page`
- `idx_timeline_style_phase`

**Constraints:**
- `FK: node_id → timeline_node(node_id) CASCADE`
- `FK: style_id → pim.styles(id) CASCADE`
- `FK: colorway_id → pim.style_colorways(id) CASCADE`
- `FK: phase → ref_phase(code)`
- `FK: department → ref_department(code)`
- `FK: page_type → ref_page_type(code)`
- `CHECK: Entity type must be 'style'`

---

### 5. timeline_material
**Schema:** `ops`  
**Purpose:** Material-specific milestone business logic  
**Relationships:** 1-to-1 child of `timeline_node`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `node_id` | UUID | NO | PK & FK to timeline_node |
| `material_id` | UUID | NO | FK to pim.materials |
| `milestone_name` | TEXT | NO | Milestone display name |
| `phase` | TEXT | YES | FK to ref_phase |
| `department` | TEXT | YES | FK to ref_department |
| `page_id` | UUID | YES | BeProduct page reference |
| `page_title` | TEXT | YES | Page display title |
| `page_type` | TEXT | YES | FK to ref_page_type |
| `customer_visible` | BOOLEAN | NO | Customer visibility flag |
| `supplier_visible` | BOOLEAN | NO | Supplier visibility flag |
| `submits_quantity` | INTEGER | NO | Number of submissions |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |

**Indexes:**
- `PK: node_id`
- `idx_timeline_material_material`
- `idx_timeline_material_page`
- `idx_timeline_material_phase`

**Constraints:**
- `FK: node_id → timeline_node(node_id) CASCADE`
- `FK: material_id → pim.materials(id) CASCADE`
- `FK: phase → ref_phase(code)`
- `FK: department → ref_department(code)`
- `FK: page_type → ref_page_type(code)`
- `CHECK: Entity type must be 'material'`

---

### 6. timeline_dependency
**Schema:** `ops`  
**Purpose:** Cross-entity milestone dependencies  
**Relationships:** References `timeline_node` (both sides)

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `dependency_id` | UUID | NO | Primary key |
| `dependent_node_id` | UUID | NO | FK to timeline_node (successor) |
| `predecessor_node_id` | UUID | NO | FK to timeline_node (predecessor) |
| `dependency_type` | TEXT | NO | FK to ref_dependency_type |
| `lag_days` | INTEGER | NO | Offset days (positive/negative) |
| `lag_type` | TEXT | NO | FK to ref_offset_unit |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |

**Indexes:**
- `PK: dependency_id`
- `idx_timeline_dependency_dependent`
- `idx_timeline_dependency_predecessor`
- `idx_timeline_dependency_both` (composite)

**Constraints:**
- `FK: dependent_node_id → timeline_node(node_id) CASCADE`
- `FK: predecessor_node_id → timeline_node(node_id) CASCADE`
- `FK: dependency_type → ref_dependency_type(code)`
- `FK: lag_type → ref_offset_unit(code)`
- `CHECK: dependent_node_id != predecessor_node_id`
- `CHECK: Same plan (both nodes in same plan_id)`
- `UNIQUE: (dependent_node_id, predecessor_node_id)`

---

### 7. timeline_assignment
**Schema:** `ops`  
**Purpose:** Many-to-many user assignments to milestones  
**Relationships:** References `timeline_node` and `auth.users`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `assignment_id` | UUID | NO | Primary key |
| `node_id` | UUID | NO | FK to timeline_node |
| `user_id` | UUID | NO | FK to auth.users |
| `assigned_at` | TIMESTAMPTZ | NO | Assignment timestamp |
| `assigned_by` | UUID | YES | FK to auth.users (who assigned) |

**Indexes:**
- `PK: assignment_id`
- `idx_timeline_assignment_node`
- `idx_timeline_assignment_user`
- `UNIQUE: (node_id, user_id)`

**Constraints:**
- `FK: node_id → timeline_node(node_id) CASCADE`
- `FK: user_id → auth.users(id) CASCADE`
- `FK: assigned_by → auth.users(id)`

---

### 8. timeline_share
**Schema:** `ops`  
**Purpose:** Many-to-many user sharing for milestone visibility  
**Relationships:** References `timeline_node` and `auth.users`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `share_id` | UUID | NO | Primary key |
| `node_id` | UUID | NO | FK to timeline_node |
| `user_id` | UUID | NO | FK to auth.users |
| `shared_at` | TIMESTAMPTZ | NO | Sharing timestamp |
| `shared_by` | UUID | YES | FK to auth.users (who shared) |

**Indexes:**
- `PK: share_id`
- `idx_timeline_share_node`
- `idx_timeline_share_user`
- `UNIQUE: (node_id, user_id)`

**Constraints:**
- `FK: node_id → timeline_node(node_id) CASCADE`
- `FK: user_id → auth.users(id) CASCADE`
- `FK: shared_by → auth.users(id)`

---

### 9. timeline_template
**Schema:** `ops`  
**Purpose:** Timeline template header  
**Relationships:** Parent of `timeline_template_milestone`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `template_id` | UUID | NO | Primary key |
| `name` | TEXT | NO | Template name |
| `brand` | TEXT | YES | Target brand |
| `season` | TEXT | YES | Target season |
| `version` | INTEGER | NO | Version number |
| `is_active` | BOOLEAN | NO | Active flag |
| `timezone` | TEXT | YES | Default timezone |
| `anchor_strategy` | TEXT | YES | Date calculation strategy |
| `business_days_calendar` | JSONB | YES | Holiday calendar |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |
| `created_by` | UUID | YES | FK to auth.users |
| `updated_by` | UUID | YES | FK to auth.users |

**Indexes:**
- `PK: template_id`
- `idx_timeline_template_brand`
- `idx_timeline_template_active`

---

### 10. timeline_template_milestone
**Schema:** `ops`  
**Purpose:** Template milestone definitions  
**Relationships:** Child of `timeline_template`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `milestone_id` | UUID | NO | Primary key |
| `template_id` | UUID | NO | FK to timeline_template |
| `node_type` | TEXT | NO | FK to ref_node_type |
| `name` | TEXT | NO | Milestone name |
| `short_name` | TEXT | YES | Abbreviated name |
| `phase` | TEXT | YES | FK to ref_phase |
| `department` | TEXT | YES | FK to ref_department |
| `display_order` | INTEGER | NO | Sort order |
| `predecessor_milestone_id` | UUID | YES | FK to self (dependency) |
| `offset_relation` | TEXT | YES | FK to ref_offset_relation |
| `offset_value` | INTEGER | YES | Offset days |
| `offset_unit` | TEXT | YES | FK to ref_offset_unit |
| `duration_value` | INTEGER | YES | Task duration |
| `duration_unit` | TEXT | YES | FK to ref_offset_unit |
| `page_type` | TEXT | YES | FK to ref_page_type |
| `applies_to_style` | BOOLEAN | NO | Applies to styles |
| `applies_to_material` | BOOLEAN | NO | Applies to materials |
| `customer_visible` | BOOLEAN | NO | Default customer visibility |
| `supplier_visible` | BOOLEAN | NO | Default supplier visibility |
| `required` | BOOLEAN | NO | Required milestone |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |

**Indexes:**
- `PK: milestone_id`
- `idx_timeline_template_milestone_template`
- `idx_timeline_template_milestone_order`

**Constraints:**
- `FK: template_id → timeline_template(template_id) CASCADE`
- `FK: node_type → ref_node_type(code)`
- `FK: phase → ref_phase(code)`
- `FK: department → ref_department(code)`
- `FK: predecessor_milestone_id → timeline_template_milestone(milestone_id)`
- `FK: offset_relation → ref_offset_relation(code)`
- `FK: offset_unit → ref_offset_unit(code)`
- `FK: page_type → ref_page_type(code)`

---

### 11. timeline_audit_log
**Schema:** `ops`  
**Purpose:** Audit trail for timeline changes  
**Relationships:** References `timeline_node`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `audit_id` | UUID | NO | Primary key |
| `node_id` | UUID | NO | FK to timeline_node |
| `changed_field` | TEXT | NO | Field that changed |
| `old_value` | TEXT | YES | Previous value (JSON string) |
| `new_value` | TEXT | YES | New value (JSON string) |
| `changed_at` | TIMESTAMPTZ | NO | Change timestamp |
| `changed_by` | UUID | YES | FK to auth.users |
| `change_reason` | TEXT | YES | Reason for change |

**Indexes:**
- `PK: audit_id`
- `idx_timeline_audit_node`
- `idx_timeline_audit_changed_at` (DESC)
- `idx_timeline_audit_changed_by`

**Constraints:**
- `FK: node_id → timeline_node(node_id) CASCADE`
- `FK: changed_by → auth.users(id)`

---

### 12. timeline_setting_health
**Schema:** `ops`  
**Purpose:** Configurable risk level thresholds  
**Relationships:** None (configuration table)

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `setting_id` | UUID | NO | Primary key |
| `risk_level` | TEXT | NO | FK to ref_risk_level (UNIQUE) |
| `threshold_days` | INTEGER | NO | Days late threshold |
| `definition` | TEXT | YES | User-editable description |
| `sort_order` | INTEGER | NO | Display order |
| `created_at` | TIMESTAMPTZ | NO | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NO | Last update timestamp |
| `created_by` | UUID | YES | FK to auth.users |
| `updated_by` | UUID | YES | FK to auth.users |

**Indexes:**
- `PK: setting_id`
- `UNIQUE: risk_level`
- `idx_timeline_setting_health_sort`

**Constraints:**
- `FK: risk_level → ref_risk_level(code)`
- `CHECK: threshold_days >= 0`

---

## View Catalog

### 1. view_timeline_with_details
**Schema:** `ops`  
**Purpose:** Denormalized timeline view joining node with detail tables  
**Base Tables:** `timeline_node`, `timeline_style`, `timeline_material`

**Key Columns:**
- All columns from `timeline_node`
- Entity-specific columns (style_id, material_id, milestone_name, phase, etc.)
- Unified columns using COALESCE across entity types

**Use Cases:**
- UI timeline list display
- Export/reporting
- Quick queries without complex joins

---

### 2. view_timeline_progress
**Schema:** `ops`  
**Purpose:** Progress summary by plan and entity type  
**Base Tables:** `timeline_node`

**Columns:**
- `plan_id`
- `entity_type`
- `total` - Total milestones
- `not_started` - Count by status
- `in_progress` - Count by status
- `waiting_on` - Count by status
- `rejected` - Count by status
- `approved` - Count by status
- `approved_with_corrections` - Count by status
- `na` - Count by status
- `late` - Count of late milestones
- `completion_percentage` - % approved

**Use Cases:**
- Dashboard metrics
- Plan progress tracking
- BeProduct parity (planStyleProgress/planMaterialProgress)

---

### 3. view_user_workload
**Schema:** `ops`  
**Purpose:** Active milestone assignments per user  
**Base Tables:** `timeline_assignment`, `timeline_node`, `timeline_style`, `timeline_material`, `timeline_plan`, `auth.users`

**Columns:**
- `user_id`, `user_email`, `user_name`
- `node_id`, `entity_type`, `entity_id`
- `plan_id`, `plan_name`
- `status`, `due_date`, `is_late`
- `milestone_name`, `phase`
- `assigned_at`

**Use Cases:**
- User workload dashboard
- My assignments view
- Capacity planning

---

### 4. view_timeline_folder_summary
**Schema:** `ops`  
**Purpose:** Folder-level summary with plan counts  
**Base Tables:** `timeline_folder`, `timeline_plan`

**Columns:**
- `folder_id`, `name`, `brand`, `season`, `year`
- `active_plan_count`
- `total_plan_count`
- `created_at`, `updated_at`

**Use Cases:**
- Folder navigation
- Brand/season overview

---

### 5. view_timeline_plan_summary
**Schema:** `ops`  
**Purpose:** Plan-level summary with milestone counts  
**Base Tables:** `timeline_plan`, `timeline_folder`, `timeline_template`, `timeline_node`

**Columns:**
- `plan_id`, `name`, `folder_name`, `template_name`
- `start_date`, `end_date`
- `style_milestone_count`
- `material_milestone_count`
- `total_milestone_count`
- `late_milestone_count`
- `completion_percentage`

**Use Cases:**
- Plan dashboard
- Timeline health monitoring

---

## Function Catalog

### 1. fn_instantiate_plan_timeline
**Schema:** `ops`  
**Purpose:** Create timeline nodes from template  
**Parameters:**
- `p_plan_id` UUID - Target plan
- `p_entity_type` TEXT - Entity type (style/material)
- `p_entity_id` UUID - Entity identifier
- `p_start_date` DATE - Plan start date

**Returns:** `TABLE(node_id UUID, milestone_name TEXT, due_date DATE)`

**Logic:**
1. Fetch template milestones for entity type
2. Calculate plan_date based on start_date + offsets
3. Create timeline_node records
4. Create entity-specific detail records (timeline_style or timeline_material)
5. Create dependencies between nodes
6. Return created node list

---

### 2. fn_calculate_due_date
**Schema:** `ops`  
**Purpose:** Auto-calculate due_date from plan/rev/final dates  
**Parameters:**
- `p_node_id` UUID

**Returns:** `DATE`

**Logic:**
```sql
due_date = COALESCE(final_date, rev_date, plan_date)
```

---

### 3. fn_calculate_is_late
**Schema:** `ops`  
**Purpose:** Determine if milestone is late  
**Parameters:**
- `p_node_id` UUID

**Returns:** `BOOLEAN`

**Logic:**
```sql
is_late = (due_date > plan_date) OR 
          (CURRENT_DATE > due_date AND status NOT IN ('approved', 'na'))
```

---

### 4. fn_recalculate_downstream_timelines
**Schema:** `ops`  
**Purpose:** Cascade date changes to dependent milestones  
**Parameters:**
- `p_node_id` UUID - Changed node
- `p_delta_days` INTEGER - Days to shift

**Returns:** `INTEGER` (count of updated nodes)

**Logic:**
1. Find all downstream dependent nodes (recursive CTE)
2. Update due_date for each dependent node
3. Trigger recalculation for each updated node
4. Return count of affected nodes

---

### 5. fn_get_timeline_critical_path
**Schema:** `ops`  
**Purpose:** Calculate critical path for Gantt chart  
**Parameters:**
- `p_plan_id` UUID

**Returns:** `TABLE(node_id UUID, path_length INTEGER, is_critical BOOLEAN)`

**Logic:**
1. Build dependency graph
2. Calculate longest path from start to each node
3. Identify critical path (longest duration)
4. Return nodes with path lengths and critical flag

---

### 6. fn_get_user_timeline_workload
**Schema:** `ops`  
**Purpose:** Get all assigned milestones for user  
**Parameters:**
- `p_user_id` UUID
- `p_include_completed` BOOLEAN (default: false)

**Returns:** `TABLE(node_id UUID, plan_name TEXT, milestone_name TEXT, due_date DATE, is_late BOOLEAN)`

**Use Cases:**
- User dashboard
- "My Tasks" view
- Capacity planning

---

### 7. fn_bulk_update_timeline_status
**Schema:** `ops`  
**Purpose:** Efficiently update multiple milestone statuses  
**Parameters:**
- `p_node_ids` UUID[] - Array of node IDs
- `p_new_status` TEXT - New status code
- `p_updated_by` UUID - User making change

**Returns:** `INTEGER` (count of updated nodes)

**Logic:**
1. Validate status code exists in ref_timeline_status
2. Update status for all nodes in array
3. Trigger audit log entries
4. Return count of updated records

---

## Endpoint Catalog

### Base URL
```
https://<project-id>.supabase.co/rest/v1
```

### Timeline Folder Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `GET` | `/timeline_folder` | List all folders | Required |
| `GET` | `/timeline_folder?id=eq.{folder_id}` | Get folder by ID | Required |
| `POST` | `/timeline_folder` | Create folder | Required |
| `PATCH` | `/timeline_folder?id=eq.{folder_id}` | Update folder | Required |
| `DELETE` | `/timeline_folder?id=eq.{folder_id}` | Delete folder (soft) | Required |

### Timeline Plan Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `GET` | `/timeline_plan` | List all plans | Required |
| `GET` | `/timeline_plan?id=eq.{plan_id}` | Get plan by ID | Required |
| `GET` | `/timeline_plan?folder_id=eq.{folder_id}` | Get plans by folder | Required |
| `POST` | `/timeline_plan` | Create plan | Required |
| `PATCH` | `/timeline_plan?id=eq.{plan_id}` | Update plan | Required |
| `DELETE` | `/timeline_plan?id=eq.{plan_id}` | Delete plan (soft) | Required |

### Timeline Node Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `GET` | `/timeline_node` | List all nodes | Required |
| `GET` | `/timeline_node?plan_id=eq.{plan_id}` | Get nodes by plan | Required |
| `GET` | `/timeline_node?entity_type=eq.{type}&entity_id=eq.{id}` | Get nodes by entity | Required |
| `GET` | `/view_timeline_with_details?node_id=eq.{node_id}` | Get node with details | Required |
| `PATCH` | `/timeline_node?node_id=eq.{node_id}` | Update node | Required |

### Timeline Style Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `GET` | `/timeline_style` | List all style milestones | Required |
| `GET` | `/timeline_style?style_id=eq.{style_id}` | Get style milestones | Required |
| `GET` | `/view_timeline_with_details?entity_type=eq.style&style_id=eq.{id}` | Get style timeline | Required |

### Timeline Material Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `GET` | `/timeline_material` | List all material milestones | Required |
| `GET` | `/timeline_material?material_id=eq.{material_id}` | Get material milestones | Required |
| `GET` | `/view_timeline_with_details?entity_type=eq.material&material_id=eq.{id}` | Get material timeline | Required |

### Progress & Analytics Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `GET` | `/view_timeline_progress?plan_id=eq.{plan_id}` | Get plan progress | Required |
| `GET` | `/view_timeline_progress?plan_id=eq.{plan_id}&entity_type=eq.style` | Get style progress | Required |
| `GET` | `/view_user_workload?user_id=eq.{user_id}` | Get user workload | Required |
| `GET` | `/view_timeline_plan_summary?plan_id=eq.{plan_id}` | Get plan summary | Required |

### Assignment & Sharing Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `POST` | `/timeline_assignment` | Assign user to milestone | Required |
| `DELETE` | `/timeline_assignment?node_id=eq.{node_id}&user_id=eq.{user_id}` | Remove assignment | Required |
| `POST` | `/timeline_share` | Share milestone with user | Required |
| `DELETE` | `/timeline_share?node_id=eq.{node_id}&user_id=eq.{user_id}` | Remove sharing | Required |

### Dependency Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `GET` | `/timeline_dependency?dependent_node_id=eq.{node_id}` | Get dependencies | Required |
| `POST` | `/timeline_dependency` | Create dependency | Required |
| `DELETE` | `/timeline_dependency?id=eq.{dependency_id}` | Remove dependency | Required |

### Template Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| `GET` | `/timeline_template` | List templates | Required |
| `GET` | `/timeline_template?id=eq.{template_id}` | Get template | Required |
| `GET` | `/timeline_template_milestone?template_id=eq.{template_id}` | Get template milestones | Required |
| `POST` | `/rpc/fn_instantiate_plan_timeline` | Instantiate template for entity | Required |

### RPC Function Endpoints

| Method | Endpoint | Purpose | Parameters |
|--------|----------|---------|------------|
| `POST` | `/rpc/fn_calculate_due_date` | Calculate due date | `p_node_id` |
| `POST` | `/rpc/fn_calculate_is_late` | Calculate late flag | `p_node_id` |
| `POST` | `/rpc/fn_recalculate_downstream_timelines` | Cascade date changes | `p_node_id`, `p_delta_days` |
| `POST` | `/rpc/fn_get_timeline_critical_path` | Get critical path | `p_plan_id` |
| `POST` | `/rpc/fn_get_user_timeline_workload` | Get user workload | `p_user_id`, `p_include_completed` |
| `POST` | `/rpc/fn_bulk_update_timeline_status` | Bulk status update | `p_node_ids[]`, `p_new_status`, `p_updated_by` |

---

## Reference Data Catalog

### ref_timeline_status
**Purpose:** Valid timeline status values

| Code | Label | Terminal | Color | Icon |
|------|-------|----------|-------|------|
| `not_started` | Not Started | NO | `#9CA3AF` | ⏸️ |
| `in_progress` | In Progress | NO | `#3B82F6` | ▶️ |
| `waiting_on` | Waiting On | NO | `#F59E0B` | ⏳ |
| `rejected` | Rejected | NO | `#EF4444` | ❌ |
| `approved` | Approved | YES | `#10B981` | ✅ |
| `approved_with_corrections` | Approved w/ Corrections | YES | `#84CC16` | ✅ |
| `na` | N/A | YES | `#6B7280` | ➖ |

### ref_timeline_entity_type
**Purpose:** Valid entity types for timeline nodes

| Code | Label | Description |
|------|-------|-------------|
| `style` | Style | Style/garment tracking |
| `material` | Material | Material/fabric tracking |
| `order` | Order | Purchase order tracking |
| `production` | Production | Production batch tracking |

### ref_dependency_type
**Purpose:** Valid dependency relationship types

| Code | Label | Description |
|------|-------|-------------|
| `finish_to_start` | Finish-to-Start | B starts when A finishes (most common) |
| `start_to_start` | Start-to-Start | B starts when A starts |
| `finish_to_finish` | Finish-to-Finish | B finishes when A finishes |
| `start_to_finish` | Start-to-Finish | B finishes when A starts (rare) |

### ref_risk_level
**Purpose:** Valid risk level thresholds

| Code | Label | Description | Default Threshold |
|------|-------|-------------|-------------------|
| `low` | Low Risk | Minor delays | < 7 days |
| `medium` | Medium Risk | Moderate delays | 7-14 days |
| `high` | High Risk | Significant delays | 15-30 days |
| `critical` | Critical Risk | Severe delays | > 30 days |

### ref_phase
**Purpose:** Valid project phases

| Code | Label | Color |
|------|-------|-------|
| `planning` | Planning | `#94A3B8` |
| `design` | Design | `#8B5CF6` |
| `development` | Development | `#3B82F6` |
| `sampling` | Sampling | `#10B981` |
| `production` | Production | `#F59E0B` |
| `delivery` | Delivery | `#6366F1` |

### ref_department
**Purpose:** Valid department assignments

| Code | Label |
|------|-------|
| `design` | Design |
| `product_development` | Product Development |
| `sourcing` | Sourcing |
| `production` | Production |
| `quality` | Quality |
| `logistics` | Logistics |

### ref_page_type
**Purpose:** Valid BeProduct page types

| Code | Label |
|------|-------|
| `techpack` | Techpack |
| `sample` | Sample Request |
| `bom` | Bill of Materials |
| `form` | Custom Form |
| `none` | No Page |

### ref_node_type
**Purpose:** Valid template node types

| Code | Label | Description |
|------|-------|-------------|
| `anchor` | Anchor | Fixed date milestone (e.g., "Start Date") |
| `task` | Task | Calculated date milestone |

### ref_offset_relation
**Purpose:** Valid offset direction

| Code | Label |
|------|-------|
| `after` | After |
| `before` | Before |

### ref_offset_unit
**Purpose:** Valid date offset units

| Code | Label |
|------|-------|
| `days` | Calendar Days |
| `business_days` | Business Days |

---

## Entity Relationship Diagrams

### Core Schema Relationships

```
┌─────────────────────┐
│  timeline_folder    │
│  ─────────────────  │
│  folder_id (PK)     │
│  name               │
│  brand              │
│  season             │
└──────────┬──────────┘
           │ 1:N
           ▼
┌─────────────────────┐
│  timeline_plan      │
│  ─────────────────  │
│  plan_id (PK)       │
│  folder_id (FK)     │◄─────┐
│  template_id (FK)   │      │
│  start_date         │      │
│  end_date           │      │
└──────────┬──────────┘      │
           │ 1:N             │ N:1
           ▼                 │
┌─────────────────────┐      │
│  timeline_node      │      │
│  ─────────────────  │      │
│  node_id (PK)       │      │
│  plan_id (FK)       ├──────┘
│  entity_type (FK)   │◄─────┐
│  entity_id          │      │
│  milestone_id (FK)  │      │
│  status (FK)        │      │
│  plan_date          │      │
│  rev_date           │      │
│  due_date           │      │
│  final_date         │      │
└──────────┬──────────┘      │
           │ 1:1             │
           ├─────────────────┤
           ▼                 ▼
┌──────────────────┐  ┌──────────────────┐
│ timeline_style   │  │timeline_material │
│ ──────────────── │  │ ──────────────── │
│ node_id (PK,FK)  │  │ node_id (PK,FK)  │
│ style_id (FK)    │  │ material_id (FK) │
│ colorway_id (FK) │  │ milestone_name   │
│ milestone_name   │  │ phase (FK)       │
│ phase (FK)       │  │ department (FK)  │
│ department (FK)  │  │ page_type (FK)   │
│ page_type (FK)   │  └──────────────────┘
└──────────────────┘
```

### Dependency Relationships

```
┌─────────────────────┐
│  timeline_node      │
│  ─────────────────  │
│  node_id (PK)       │◄──────┐
└──────────┬──────────┘       │
           │                  │
           │ N:M              │
           ▼                  │
┌─────────────────────────────┴───┐
│  timeline_dependency            │
│  ─────────────────────────────  │
│  dependency_id (PK)             │
│  dependent_node_id (FK)         │
│  predecessor_node_id (FK) ──────┘
│  dependency_type (FK)           │
│  lag_days                       │
│  lag_type (FK)                  │
└─────────────────────────────────┘
```

### Assignment & Sharing Relationships

```
┌─────────────────────┐
│  timeline_node      │
│  ─────────────────  │
│  node_id (PK)       │◄────────┐
└─────────────────────┘         │
                                │
    ┌───────────────────────────┼───────────────────────────┐
    │                           │                           │
    │ N:M                       │ N:M                       │
    ▼                           ▼                           ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│timeline_assignment│  │ timeline_share   │  │timeline_audit_log│
│ ──────────────── │  │ ──────────────── │  │ ──────────────── │
│assignment_id (PK)│  │ share_id (PK)    │  │ audit_id (PK)    │
│node_id (FK) ─────┘  │ node_id (FK) ────┘  │ node_id (FK) ────┘
│user_id (FK)      │  │ user_id (FK)     │  │ changed_field    │
│assigned_at       │  │ shared_at        │  │ old_value        │
│assigned_by (FK)  │  │ shared_by (FK)   │  │ new_value        │
└──────────────────┘  └──────────────────┘  │ changed_by (FK)  │
                                            └──────────────────┘
```

### Template Relationships

```
┌─────────────────────────┐
│  timeline_template      │
│  ─────────────────────  │
│  template_id (PK)       │
│  name                   │
│  brand                  │
└──────────┬──────────────┘
           │ 1:N
           ▼
┌─────────────────────────────────┐
│  timeline_template_milestone    │
│  ─────────────────────────────  │
│  milestone_id (PK)              │
│  template_id (FK)               │
│  predecessor_milestone_id (FK)  │◄─┐ Self-referential
│  node_type (FK)                 │  │ for dependencies
│  name                           │  │
│  phase (FK)                     │──┘
│  department (FK)                │
│  offset_value                   │
│  offset_unit (FK)               │
│  duration_value                 │
│  applies_to_style               │
│  applies_to_material            │
└─────────────────────────────────┘
```

### Reference Data Relationships

```
┌─────────────────────┐
│  ref_* tables       │
│  ─────────────────  │
│  code (PK)          │
│  label              │
│  description        │
│  display_order      │
│  is_active          │
└─────────────────────┘
         │
         │ Referenced by:
         │
         ├─► timeline_node.entity_type
         ├─► timeline_node.status
         ├─► timeline_style.phase
         ├─► timeline_style.department
         ├─► timeline_style.page_type
         ├─► timeline_material.phase
         ├─► timeline_material.department
         ├─► timeline_dependency.dependency_type
         ├─► timeline_dependency.lag_type
         └─► timeline_template_milestone.*
```

---

## System Architecture

### Data Flow Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        FRONTEND LAYER                         │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Timeline UI  │  │ Gantt Chart  │  │ Dashboard    │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
└─────────┼──────────────────┼──────────────────┼───────────────┘
          │                  │                  │
          │ REST API         │                  │
          ▼                  ▼                  ▼
┌──────────────────────────────────────────────────────────────┐
│                        SUPABASE LAYER                         │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              PostgREST API Gateway                      │ │
│  │  - Auto-generated REST endpoints                       │ │
│  │  - Row-level security enforcement                      │ │
│  │  - Authentication & authorization                       │ │
│  └────────────────────┬───────────────────────────────────┘ │
│                       │                                       │
│  ┌────────────────────┼───────────────────────────────────┐ │
│  │                    │  PostgreSQL Database              │ │
│  │                    ▼                                    │ │
│  │  ┌──────────────────────────────────────────────┐     │ │
│  │  │           ops.timeline_* Tables              │     │ │
│  │  │  - timeline_folder                           │     │ │
│  │  │  - timeline_plan                             │     │ │
│  │  │  - timeline_node (Universal Graph)           │     │ │
│  │  │  - timeline_style, timeline_material         │     │ │
│  │  │  - timeline_dependency                       │     │ │
│  │  │  - timeline_assignment, timeline_share       │     │ │
│  │  └──────────────────────────────────────────────┘     │ │
│  │                                                         │ │
│  │  ┌──────────────────────────────────────────────┐     │ │
│  │  │            Views & Functions                  │     │ │
│  │  │  - view_timeline_with_details                │     │ │
│  │  │  - view_timeline_progress                    │     │ │
│  │  │  - fn_instantiate_plan_timeline              │     │ │
│  │  │  - fn_recalculate_downstream_timelines       │     │ │
│  │  └──────────────────────────────────────────────┘     │ │
│  │                                                         │ │
│  │  ┌──────────────────────────────────────────────┐     │ │
│  │  │              Triggers                         │     │ │
│  │  │  - trigger_calculate_due_date                │     │ │
│  │  │  - trigger_calculate_is_late                 │     │ │
│  │  │  - trigger_recalculate_downstream            │     │ │
│  │  │  - trigger_audit_timeline_changes            │     │ │
│  │  └──────────────────────────────────────────────┘     │ │
│  │                                                         │ │
│  │  ┌──────────────────────────────────────────────┐     │ │
│  │  │          Reference Data (ref schema)          │     │ │
│  │  │  - ref_timeline_status                       │     │ │
│  │  │  - ref_timeline_entity_type                  │     │ │
│  │  │  - ref_dependency_type                       │     │ │
│  │  │  - ref_phase, ref_department, etc.           │     │ │
│  │  └──────────────────────────────────────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Migration Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                     MIGRATION PHASES                         │
└─────────────────────────────────────────────────────────────┘

Phase 1: Schema Creation (Week 1)
├─► Create ref.* reference tables
├─► Create ops.timeline_folder
├─► Create ops.timeline_plan
├─► Create ops.timeline_node
├─► Create ops.timeline_style
├─► Create ops.timeline_material
├─► Create ops.timeline_dependency
├─► Create ops.timeline_assignment
├─► Create ops.timeline_share
├─► Create ops.timeline_template
└─► Create ops.timeline_template_milestone

Phase 2: Views & Functions (Week 2)
├─► Create views (view_timeline_with_details, etc.)
├─► Create functions (fn_instantiate_plan_timeline, etc.)
├─► Create triggers (calculate_due_date, recalculate_downstream, etc.)
└─► Test all automation logic

Phase 3: Data Migration (Week 3)
├─► Backup existing tracking_* tables
├─► Migrate tracking_folder → timeline_folder
├─► Migrate tracking_plan → timeline_plan
├─► Migrate tracking_plan_style_timeline → timeline_node + timeline_style
├─► Migrate tracking_plan_material_timeline → timeline_node + timeline_material
├─► Migrate dependencies
├─► Validate data integrity
└─► Test queries against new schema

Phase 4: API Rollout (Week 4-5)
├─► Deploy new PostgREST endpoints
├─► Update frontend to use new endpoints
├─► Run parallel testing (old vs new)
└─► Monitor performance

Phase 5: Deprecation (Week 6+)
├─► Deprecate old tracking_* endpoints
├─► Archive old tracking_* tables
└─► Drop old tables after grace period
```

---

## Quick Reference Cheatsheet

### Common Queries

**Get timeline for a style:**
```sql
SELECT * FROM ops.view_timeline_with_details
WHERE entity_type = 'style' AND style_id = '<uuid>'
ORDER BY due_date;
```

**Get plan progress:**
```sql
SELECT * FROM ops.view_timeline_progress
WHERE plan_id = '<uuid>';
```

**Get user workload:**
```sql
SELECT * FROM ops.view_user_workload
WHERE user_id = '<uuid>'
ORDER BY due_date;
```

**Instantiate template for style:**
```sql
SELECT * FROM ops.fn_instantiate_plan_timeline(
  '<plan_id>'::uuid,
  'style',
  '<style_id>'::uuid,
  '2025-05-01'::date
);
```

### Common Endpoints

**Get folder plans:**
```
GET /timeline_plan?folder_id=eq.<folder_id>&select=*,timeline_folder(name,brand)
```

**Get style timeline with details:**
```
GET /view_timeline_with_details?entity_type=eq.style&style_id=eq.<style_id>&order=due_date.asc
```

**Get plan progress:**
```
GET /view_timeline_progress?plan_id=eq.<plan_id>
```

**Update milestone status:**
```
PATCH /timeline_node?node_id=eq.<node_id>
Content-Type: application/json

{
  "status": "in_progress",
  "rev_date": "2025-11-15",
  "updated_by": "<user_id>"
}
```

---

## Maintenance & Operations

### Performance Monitoring

**Key metrics to monitor:**
1. Query performance on `timeline_node` (target: < 100ms)
2. Recursive CTE performance on `timeline_dependency` (target: < 500ms)
3. View materialization time (consider materializing `view_timeline_with_details`)
4. Index usage (monitor unused indexes)

### Backup Strategy

**Critical tables to backup:**
1. `timeline_folder` - Master data
2. `timeline_plan` - Master data
3. `timeline_node` - Transaction data
4. `timeline_dependency` - Transaction data
5. `timeline_audit_log` - Audit trail

**Backup frequency:**
- Real-time: Database-level continuous backup (Supabase automated)
- Daily: Table-level exports for compliance
- Weekly: Full schema dump for disaster recovery

### Data Retention

**Retention policies:**
- `timeline_audit_log`: 2 years (then archive to cold storage)
- `timeline_node` (completed): 3 years
- `timeline_folder/plan`: Indefinite (master data)
- Reference tables: Indefinite (append-only)

---

**Document Status:** ✅ Complete  
**Last Updated:** November 2, 2025  
**Version:** 1.0  
**Maintained By:** Backend Team
