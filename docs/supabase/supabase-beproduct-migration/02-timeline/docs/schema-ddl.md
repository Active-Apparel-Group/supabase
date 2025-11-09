# Timeline Schema DDL

**Purpose:** Complete table definitions, indexes, and constraints for hybrid timeline architecture  
**Status:** Ready for Implementation  
**Date:** October 31, 2025

---

## Table of Contents
1. [Reference Data Tables](#reference-data-tables)
2. [Master Data Tables](#master-data-tables)
3. [Core Timeline Tables](#core-timeline-tables)
4. [Detail Tables](#detail-tables)
5. [Supporting Tables](#supporting-tables)
6. [Settings Tables](#settings-tables)
7. [Indexes](#indexes)
8. [Constraints](#constraints)
9. [Views](#views)

---

## Reference Data Tables

### ref_timeline_entity_type

```sql
CREATE TABLE IF NOT EXISTS ref.ref_timeline_entity_type (
  -- Primary identifier (code-based)
  code TEXT PRIMARY KEY,
  
  -- Display metadata
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed data
INSERT INTO ref.ref_timeline_entity_type (code, label, description, display_order) VALUES
  ('style', 'Style', 'Style/garment tracking', 1),
  ('material', 'Material', 'Material/fabric tracking', 2),
  ('order', 'Order', 'Purchase order tracking', 3),
  ('production', 'Production', 'Production batch tracking', 4)
ON CONFLICT (code) DO NOTHING;

COMMENT ON TABLE ref.ref_timeline_entity_type IS 'Valid entity types for timeline nodes';
```

### ref_dependency_type

```sql
CREATE TABLE IF NOT EXISTS ref.ref_dependency_type (
  -- Primary identifier (code-based)
  code TEXT PRIMARY KEY,
  
  -- Display metadata
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed data
INSERT INTO ref.ref_dependency_type (code, label, description, display_order) VALUES
  ('finish_to_start', 'Finish-to-Start', 'B starts when A finishes (most common)', 1),
  ('start_to_start', 'Start-to-Start', 'B starts when A starts', 2),
  ('finish_to_finish', 'Finish-to-Finish', 'B finishes when A finishes', 3),
  ('start_to_finish', 'Start-to-Finish', 'B finishes when A starts (rare)', 4)
ON CONFLICT (code) DO NOTHING;

COMMENT ON TABLE ref.ref_dependency_type IS 'Valid dependency relationship types for milestone dependencies';
```

### ref_risk_level

```sql
CREATE TABLE IF NOT EXISTS ref.ref_risk_level (
  -- Primary identifier (code-based)
  code TEXT PRIMARY KEY,
  
  -- Display metadata
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed data
INSERT INTO ref.ref_risk_level (code, label, description, display_order) VALUES
  ('low', 'Low Risk', 'Minor delays (< 7 days)', 1),
  ('medium', 'Medium Risk', 'Moderate delays (7-14 days)', 2),
  ('high', 'High Risk', 'Significant delays (15-30 days)', 3),
  ('critical', 'Critical Risk', 'Severe delays (> 30 days)', 4)
ON CONFLICT (code) DO NOTHING;

COMMENT ON TABLE ref.ref_risk_level IS 'Valid risk level classifications for timeline health';
```

---

## Master Data Tables

### 1. timeline_folder (Brand/Season Organization)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_folder (
  -- Primary identifier
  folder_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Folder metadata
  name TEXT NOT NULL,
  brand TEXT,
  season TEXT,
  year TEXT,
  description TEXT,
  
  -- Soft delete
  active BOOLEAN NOT NULL DEFAULT true,
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

-- Indexes
CREATE INDEX idx_timeline_folder_brand ON ops.timeline_folder(brand) WHERE active = true;
CREATE INDEX idx_timeline_folder_season ON ops.timeline_folder(season) WHERE active = true;
CREATE INDEX idx_timeline_folder_active ON ops.timeline_folder(active);

-- Comments
COMMENT ON TABLE ops.timeline_folder IS 'Top-level organization by brand/season (e.g., GREYSON 2026 SPRING)';
COMMENT ON COLUMN ops.timeline_folder.name IS 'Display name for folder (e.g., "GREYSON 2026 SPRING")';
COMMENT ON COLUMN ops.timeline_folder.brand IS 'Brand name';
COMMENT ON COLUMN ops.timeline_folder.season IS 'Season designation (e.g., "SPRING", "FALL")';
COMMENT ON COLUMN ops.timeline_folder.year IS 'Year (e.g., "2026")';
```

### 2. timeline_plan (Tracking Plan Header)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_plan (
  -- Primary identifier
  plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Hierarchy
  folder_id UUID REFERENCES ops.timeline_folder(folder_id) ON DELETE SET NULL,
  
  -- Plan metadata
  name TEXT NOT NULL,
  description TEXT,
  
  -- Template reference
  template_id UUID REFERENCES ops.timeline_template(template_id) ON DELETE SET NULL,
  
  -- Date range
  start_date DATE,
  end_date DATE,
  timezone TEXT,
  
  -- UI preferences
  color_theme TEXT,
  
  -- Supplier access control (JSONB array of company IDs)
  suppliers JSONB,
  
  -- Soft delete
  active BOOLEAN NOT NULL DEFAULT true,
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  
  -- Constraints
  CONSTRAINT check_timeline_plan_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Indexes
CREATE INDEX idx_timeline_plan_folder ON ops.timeline_plan(folder_id) WHERE active = true;
CREATE INDEX idx_timeline_plan_template ON ops.timeline_plan(template_id);
CREATE INDEX idx_timeline_plan_dates ON ops.timeline_plan(start_date, end_date) WHERE active = true;
CREATE INDEX idx_timeline_plan_active ON ops.timeline_plan(active);

-- Comments
COMMENT ON TABLE ops.timeline_plan IS 'Tracking plan header with dates and template reference';
COMMENT ON COLUMN ops.timeline_plan.folder_id IS 'FK to timeline_folder for brand/season organization';
COMMENT ON COLUMN ops.timeline_plan.name IS 'Plan name (e.g., "DROP 1", "MAIN COLLECTION")';
COMMENT ON COLUMN ops.timeline_plan.template_id IS 'FK to timeline_template used for instantiation';
COMMENT ON COLUMN ops.timeline_plan.suppliers IS 'JSONB array of supplier company IDs with access to this plan';
COMMENT ON COLUMN ops.timeline_plan.timezone IS 'Timezone for date calculations (e.g., "America/New_York")';
```

---

## Core Timeline Tables

### 3. timeline_node (Universal Graph Layer)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_node (
  -- Primary identifier
  node_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Entity relationship (polymorphic)
  entity_type TEXT NOT NULL REFERENCES ref.ref_timeline_entity_type(code),
  entity_id UUID NOT NULL,  -- FK to style/material/order/production
  
  -- Plan relationship
  plan_id UUID NOT NULL REFERENCES ops.timeline_plan(plan_id) ON DELETE CASCADE,
  
  -- Milestone template reference
  milestone_id UUID NOT NULL REFERENCES ops.timeline_template_milestone(milestone_id),
  
  -- Status tracking
  status TEXT NOT NULL DEFAULT 'not_started' REFERENCES ref.ref_timeline_status(code),
  
  -- Date fields (4-date system from BeProduct)
  plan_date DATE NOT NULL,              -- Original baseline date
  rev_date DATE,                         -- Revised/rescheduled date
  due_date DATE NOT NULL,                -- Current working due date (computed)
  final_date DATE,                       -- Actual completion date
  
  -- Enhanced: Start dates for Gantt chart support
  start_date_plan DATE,                  -- Planned start date (plan_date - duration)
  start_date_due DATE,                   -- Current start date (due_date - duration)
  
  -- Computed flags
  is_late BOOLEAN NOT NULL DEFAULT false,
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  
  -- Constraints
  CONSTRAINT check_entity_id_not_null CHECK (entity_id IS NOT NULL),
  CONSTRAINT check_due_date_with_dates CHECK (
    due_date = COALESCE(final_date, rev_date, plan_date)
  ),
  CONSTRAINT check_final_date_order CHECK (
    final_date IS NULL OR final_date >= plan_date - INTERVAL '60 days'
  )
);

-- Comments
COMMENT ON TABLE ops.timeline_node IS 'Universal timeline graph layer supporting all entity types';
COMMENT ON COLUMN ops.timeline_node.entity_type IS 'Polymorphic entity type: style, material, order, production';
COMMENT ON COLUMN ops.timeline_node.entity_id IS 'FK to entity-specific table (e.g., pim.styles.id)';
COMMENT ON COLUMN ops.timeline_node.plan_date IS 'Original baseline date from template instantiation';
COMMENT ON COLUMN ops.timeline_node.rev_date IS 'Revised date when milestone is rescheduled';
COMMENT ON COLUMN ops.timeline_node.due_date IS 'Current working due date (auto-calculated from plan/rev/final)';
COMMENT ON COLUMN ops.timeline_node.final_date IS 'Actual completion date when milestone is done';
COMMENT ON COLUMN ops.timeline_node.start_date_plan IS 'Planned start date for Gantt chart (plan_date - duration)';
COMMENT ON COLUMN ops.timeline_node.start_date_due IS 'Current start date for Gantt chart (due_date - duration)';
COMMENT ON COLUMN ops.timeline_node.is_late IS 'True when due_date > plan_date OR current_date > due_date';
```

---

## Detail Tables

### 4. timeline_style (Style-Specific Business Logic)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_style (
  -- Primary key (1-to-1 with timeline_node)
  node_id UUID PRIMARY KEY REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  
  -- Entity references
  style_id UUID NOT NULL REFERENCES pim.styles(id) ON DELETE CASCADE,
  colorway_id UUID REFERENCES pim.style_colorways(id) ON DELETE CASCADE,
  
  -- Milestone metadata
  milestone_name TEXT NOT NULL,
  phase TEXT REFERENCES ref.ref_phase(code),
  department TEXT REFERENCES ref.ref_department(code),
  
  -- BeProduct page references
  page_id UUID,
  page_title TEXT,
  page_type TEXT REFERENCES ref.ref_page_type(code),
  
  -- Visibility flags (per milestone)
  customer_visible BOOLEAN NOT NULL DEFAULT false,
  supplier_visible BOOLEAN NOT NULL DEFAULT false,
  
  -- Submit tracking
  submits_quantity INTEGER DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Ensure entity_type matches
  CONSTRAINT check_style_entity_type CHECK (
    EXISTS (
      SELECT 1 FROM ops.timeline_node 
      WHERE node_id = timeline_style.node_id 
      AND entity_type = 'style'
    )
  )
);

-- Comments
COMMENT ON TABLE ops.timeline_style IS 'Style-specific timeline milestone details';
COMMENT ON COLUMN ops.timeline_style.colorway_id IS 'Optional: specific colorway/SKU, NULL for style-level milestones';
COMMENT ON COLUMN ops.timeline_style.page_id IS 'BeProduct page reference (techpack, sample, BOM, etc.)';
COMMENT ON COLUMN ops.timeline_style.customer_visible IS 'Whether this milestone is visible to customers';
COMMENT ON COLUMN ops.timeline_style.supplier_visible IS 'Whether this milestone is visible to suppliers';
COMMENT ON COLUMN ops.timeline_style.submits_quantity IS 'Number of submissions for this milestone (e.g., sample rounds)';
```

### 5. timeline_material (Material-Specific Business Logic)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_material (
  -- Primary key (1-to-1 with timeline_node)
  node_id UUID PRIMARY KEY REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  
  -- Entity references
  material_id UUID NOT NULL REFERENCES pim.materials(id) ON DELETE CASCADE,
  
  -- Milestone metadata
  milestone_name TEXT NOT NULL,
  phase TEXT REFERENCES ref.ref_phase(code),
  department TEXT REFERENCES ref.ref_department(code),
  
  -- BeProduct page references
  page_id UUID,
  page_title TEXT,
  page_type TEXT REFERENCES ref.ref_page_type(code),
  
  -- Visibility flags
  customer_visible BOOLEAN NOT NULL DEFAULT false,
  supplier_visible BOOLEAN NOT NULL DEFAULT false,
  
  -- Submit tracking
  submits_quantity INTEGER DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Ensure entity_type matches
  CONSTRAINT check_material_entity_type CHECK (
    EXISTS (
      SELECT 1 FROM ops.timeline_node 
      WHERE node_id = timeline_material.node_id 
      AND entity_type = 'material'
    )
  )
);

-- Comments
COMMENT ON TABLE ops.timeline_material IS 'Material-specific timeline milestone details';
COMMENT ON COLUMN ops.timeline_material.page_id IS 'BeProduct page reference (lab dip, strike-off, etc.)';
```

---

## Supporting Tables

### 6. timeline_dependency (Unified Dependencies)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_dependency (
  -- Primary key
  dependency_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Dependency relationship
  dependent_node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  predecessor_node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  
  -- Dependency configuration
  dependency_type TEXT NOT NULL DEFAULT 'finish_to_start' REFERENCES ref.ref_dependency_type(code),
  lag_days INTEGER NOT NULL DEFAULT 0,
  lag_type TEXT NOT NULL DEFAULT 'days' REFERENCES ref.ref_offset_unit(code),
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT check_no_self_dependency CHECK (dependent_node_id != predecessor_node_id),
  CONSTRAINT check_same_plan CHECK (
    (SELECT plan_id FROM ops.timeline_node WHERE node_id = dependent_node_id) =
    (SELECT plan_id FROM ops.timeline_node WHERE node_id = predecessor_node_id)
  ),
  CONSTRAINT unique_dependency UNIQUE (dependent_node_id, predecessor_node_id)
);

-- Comments
COMMENT ON TABLE ops.timeline_dependency IS 'Cross-entity timeline dependencies (styles can depend on materials, etc.)';
COMMENT ON COLUMN ops.timeline_dependency.dependency_type IS 'Finish-to-start (FS), start-to-start (SS), finish-to-finish (FF), start-to-finish (SF)';
COMMENT ON COLUMN ops.timeline_dependency.lag_days IS 'Days to offset after predecessor (positive) or before (negative)';
COMMENT ON COLUMN ops.timeline_dependency.lag_type IS 'Offset unit from ref_offset_unit (days, business_days)';
```

### 7. timeline_assignment (Normalized User Assignments)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_assignment (
  -- Primary key
  assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Assignment relationship
  node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Audit fields
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_by UUID REFERENCES auth.users(id),
  
  -- Constraints
  CONSTRAINT unique_assignment UNIQUE (node_id, user_id)
);

-- Comments
COMMENT ON TABLE ops.timeline_assignment IS 'Many-to-many user assignments to milestones (replaces JSONB assignedTo array)';
COMMENT ON COLUMN ops.timeline_assignment.user_id IS 'User responsible for completing this milestone';
```

### 8. timeline_share (Normalized User Sharing)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_share (
  -- Primary key
  share_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Sharing relationship
  node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Audit fields
  shared_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  shared_by UUID REFERENCES auth.users(id),
  
  -- Constraints
  CONSTRAINT unique_share UNIQUE (node_id, user_id)
);

-- Comments
COMMENT ON TABLE ops.timeline_share IS 'Many-to-many user sharing for milestone visibility (replaces JSONB shareWith array)';
COMMENT ON COLUMN ops.timeline_share.user_id IS 'User with visibility to this milestone';
```

### 9. timeline_audit_log (Change Tracking)

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_audit_log (
  -- Primary key
  audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- What changed
  node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  changed_field TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  
  -- Who and when
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  changed_by UUID REFERENCES auth.users(id),
  
  -- Context
  change_reason TEXT
);

-- Comments
COMMENT ON TABLE ops.timeline_audit_log IS 'Audit trail for all timeline changes (dates, status, assignments)';
```

---

## Indexes

```sql
-- Reference table indexes (created in ref schema creation, listed here for completeness)
CREATE INDEX idx_ref_timeline_entity_type_active ON ref.ref_timeline_entity_type(is_active) WHERE is_active = true;
CREATE INDEX idx_ref_dependency_type_active ON ref.ref_dependency_type(is_active) WHERE is_active = true;
CREATE INDEX idx_ref_risk_level_active ON ref.ref_risk_level(is_active) WHERE is_active = true;

-- timeline_folder indexes (already created in DDL above)
-- CREATE INDEX idx_timeline_folder_brand ON ops.timeline_folder(brand) WHERE active = true;
-- CREATE INDEX idx_timeline_folder_season ON ops.timeline_folder(season) WHERE active = true;
-- CREATE INDEX idx_timeline_folder_active ON ops.timeline_folder(active);

-- timeline_plan indexes (already created in DDL above)
-- CREATE INDEX idx_timeline_plan_folder ON ops.timeline_plan(folder_id) WHERE active = true;
-- CREATE INDEX idx_timeline_plan_template ON ops.timeline_plan(template_id);
-- CREATE INDEX idx_timeline_plan_dates ON ops.timeline_plan(start_date, end_date) WHERE active = true;
-- CREATE INDEX idx_timeline_plan_active ON ops.timeline_plan(active);

-- timeline_node indexes
CREATE INDEX idx_timeline_node_entity ON ops.timeline_node(entity_type, entity_id);
CREATE INDEX idx_timeline_node_plan ON ops.timeline_node(plan_id);
CREATE INDEX idx_timeline_node_milestone ON ops.timeline_node(milestone_id);
CREATE INDEX idx_timeline_node_status ON ops.timeline_node(status);
CREATE INDEX idx_timeline_node_late ON ops.timeline_node(is_late) WHERE is_late = true;
CREATE INDEX idx_timeline_node_due_date ON ops.timeline_node(due_date) WHERE status NOT IN ('approved', 'na');
CREATE INDEX idx_timeline_node_plan_entity ON ops.timeline_node(plan_id, entity_type, entity_id);

-- timeline_style indexes
CREATE INDEX idx_timeline_style_style ON ops.timeline_style(style_id);
CREATE INDEX idx_timeline_style_colorway ON ops.timeline_style(colorway_id);
CREATE INDEX idx_timeline_style_page ON ops.timeline_style(page_id);
CREATE INDEX idx_timeline_style_phase ON ops.timeline_style(phase);

-- timeline_material indexes
CREATE INDEX idx_timeline_material_material ON ops.timeline_material(material_id);
CREATE INDEX idx_timeline_material_page ON ops.timeline_material(page_id);
CREATE INDEX idx_timeline_material_phase ON ops.timeline_material(phase);

-- timeline_dependency indexes (critical for recursive queries)
CREATE INDEX idx_timeline_dependency_dependent ON ops.timeline_dependency(dependent_node_id);
CREATE INDEX idx_timeline_dependency_predecessor ON ops.timeline_dependency(predecessor_node_id);
CREATE INDEX idx_timeline_dependency_both ON ops.timeline_dependency(dependent_node_id, predecessor_node_id);

-- timeline_assignment indexes
CREATE INDEX idx_timeline_assignment_node ON ops.timeline_assignment(node_id);
CREATE INDEX idx_timeline_assignment_user ON ops.timeline_assignment(user_id);

-- timeline_share indexes
CREATE INDEX idx_timeline_share_node ON ops.timeline_share(node_id);
CREATE INDEX idx_timeline_share_user ON ops.timeline_share(user_id);

-- timeline_audit_log indexes
CREATE INDEX idx_timeline_audit_node ON ops.timeline_audit_log(node_id);
CREATE INDEX idx_timeline_audit_changed_at ON ops.timeline_audit_log(changed_at DESC);
CREATE INDEX idx_timeline_audit_changed_by ON ops.timeline_audit_log(changed_by);

-- timeline_setting_health indexes
CREATE INDEX idx_timeline_setting_health_risk_level ON ops.timeline_setting_health(risk_level);
CREATE INDEX idx_timeline_setting_health_sort_order ON ops.timeline_setting_health(sort_order);
```

---

## Views

### 1. view_timeline_with_details (Denormalized Timeline View)

```sql
CREATE OR REPLACE VIEW ops.view_timeline_with_details AS
SELECT 
  tn.node_id,
  tn.entity_type,
  tn.entity_id,
  tn.plan_id,
  tn.milestone_id,
  tn.status,
  tn.plan_date,
  tn.rev_date,
  tn.due_date,
  tn.final_date,
  tn.start_date_plan,
  tn.start_date_due,
  tn.is_late,
  tn.created_at,
  tn.updated_at,
  
  -- Style-specific fields
  ts.style_id,
  ts.colorway_id,
  ts.milestone_name AS style_milestone_name,
  ts.phase AS style_phase,
  ts.department AS style_department,
  ts.page_id AS style_page_id,
  ts.page_title AS style_page_title,
  ts.page_type AS style_page_type,
  ts.customer_visible AS style_customer_visible,
  ts.supplier_visible AS style_supplier_visible,
  ts.submits_quantity AS style_submits_quantity,
  
  -- Material-specific fields
  tm.material_id,
  tm.milestone_name AS material_milestone_name,
  tm.phase AS material_phase,
  tm.department AS material_department,
  tm.page_id AS material_page_id,
  tm.page_title AS material_page_title,
  tm.page_type AS material_page_type,
  tm.customer_visible AS material_customer_visible,
  tm.supplier_visible AS material_supplier_visible,
  tm.submits_quantity AS material_submits_quantity,
  
  -- Unified fields (coalesce across entity types)
  COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
  COALESCE(ts.phase, tm.phase) AS phase,
  COALESCE(ts.department, tm.department) AS department,
  COALESCE(ts.page_id, tm.page_id) AS page_id,
  COALESCE(ts.page_title, tm.page_title) AS page_title,
  COALESCE(ts.page_type, tm.page_type) AS page_type,
  COALESCE(ts.customer_visible, tm.customer_visible) AS customer_visible,
  COALESCE(ts.supplier_visible, tm.supplier_visible) AS supplier_visible,
  COALESCE(ts.submits_quantity, tm.submits_quantity) AS submits_quantity
  
FROM ops.timeline_node tn
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id;

COMMENT ON VIEW ops.view_timeline_with_details IS 'Denormalized view joining timeline_node with entity-specific detail tables';
```

### 2. view_timeline_progress (Plan Progress Summary)

```sql
CREATE OR REPLACE VIEW ops.view_timeline_progress AS
SELECT 
  plan_id,
  entity_type,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE status = 'not_started') AS not_started,
  COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress,
  COUNT(*) FILTER (WHERE status = 'waiting_on') AS waiting_on,
  COUNT(*) FILTER (WHERE status = 'rejected') AS rejected,
  COUNT(*) FILTER (WHERE status = 'approved') AS approved,
  COUNT(*) FILTER (WHERE status = 'approved_with_corrections') AS approved_with_corrections,
  COUNT(*) FILTER (WHERE status = 'na') AS na,
  COUNT(*) FILTER (WHERE is_late = true) AS late,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'approved') / NULLIF(COUNT(*), 0), 2) AS completion_percentage
FROM ops.timeline_node
GROUP BY plan_id, entity_type;

COMMENT ON VIEW ops.view_timeline_progress IS 'Progress summary by plan and entity type (replicates BeProduct planStyleProgress/planMaterialProgress)';
```

### 3. view_user_workload (User Assignment Summary)

```sql
CREATE OR REPLACE VIEW ops.view_user_workload AS
SELECT 
  ta.user_id,
  u.email AS user_email,
  u.raw_user_meta_data->>'name' AS user_name,
  tn.node_id,
  tn.entity_type,
  tn.entity_id,
  tn.plan_id,
  p.name AS plan_name,
  tn.status,
  tn.due_date,
  tn.is_late,
  COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
  COALESCE(ts.phase, tm.phase) AS phase,
  ta.assigned_at
FROM ops.timeline_assignment ta
JOIN ops.timeline_node tn ON ta.node_id = tn.node_id
JOIN auth.users u ON ta.user_id = u.id
JOIN ops.timeline_plan p ON tn.plan_id = p.plan_id
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
WHERE tn.status NOT IN ('approved', 'na');

COMMENT ON VIEW ops.view_user_workload IS 'All active milestone assignments per user (excludes completed/NA milestones)';
```

---

## Constraints Summary

| Table | Constraint Type | Description |
|-------|----------------|-------------|
| `timeline_folder` | PK | `folder_id` UUID primary key |
| `timeline_plan` | PK | `plan_id` UUID primary key |
| `timeline_plan` | FK | `folder_id` → `timeline_folder(folder_id)` |
| `timeline_plan` | FK | `template_id` → `timeline_template(template_id)` |
| `timeline_plan` | CHECK | `end_date >= start_date` |
| `timeline_node` | PK | `node_id` UUID primary key |
| `timeline_node` | FK | `plan_id` → `timeline_plan(plan_id)` CASCADE |
| `timeline_node` | FK | `milestone_id` → `timeline_template_milestone(milestone_id)` |
| `timeline_node` | FK | `entity_type` → `ref_timeline_entity_type(code)` |
| `timeline_node` | FK | `status` → `ref_timeline_status(code)` |
| `timeline_node` | CHECK | `due_date = COALESCE(final_date, rev_date, plan_date)` |
| `timeline_node` | CHECK | `final_date >= plan_date - 60 days` (sanity check) |
| `timeline_style` | PK | `node_id` (1-to-1 with timeline_node) |
| `timeline_style` | FK | `node_id` → `timeline_node(node_id)` CASCADE |
| `timeline_style` | FK | `style_id` → `pim.styles(id)` CASCADE |
| `timeline_style` | FK | `colorway_id` → `pim.style_colorways(id)` CASCADE |
| `timeline_style` | FK | `phase` → `ref_phase(code)` |
| `timeline_style` | FK | `department` → `ref_department(code)` |
| `timeline_style` | FK | `page_type` → `ref_page_type(code)` |
| `timeline_style` | CHECK | `entity_type = 'style'` (enforced via subquery) |
| `timeline_material` | PK | `node_id` (1-to-1 with timeline_node) |
| `timeline_material` | FK | `node_id` → `timeline_node(node_id)` CASCADE |
| `timeline_material` | FK | `material_id` → `pim.materials(id)` CASCADE |
| `timeline_material` | FK | `phase` → `ref_phase(code)` |
| `timeline_material` | FK | `department` → `ref_department(code)` |
| `timeline_material` | FK | `page_type` → `ref_page_type(code)` |
| `timeline_material` | CHECK | `entity_type = 'material'` (enforced via subquery) |
| `timeline_dependency` | PK | `dependency_id` UUID primary key |
| `timeline_dependency` | FK | `dependent_node_id` → `timeline_node(node_id)` CASCADE |
| `timeline_dependency` | FK | `predecessor_node_id` → `timeline_node(node_id)` CASCADE |
| `timeline_dependency` | FK | `dependency_type` → `ref_dependency_type(code)` |
| `timeline_dependency` | FK | `lag_type` → `ref_offset_unit(code)` |
| `timeline_dependency` | CHECK | No self-dependencies (`dependent != predecessor`) |
| `timeline_dependency` | CHECK | Same plan (both nodes in same plan) |
| `timeline_dependency` | UNIQUE | `(dependent_node_id, predecessor_node_id)` |
| `timeline_assignment` | PK | `assignment_id` UUID primary key |
| `timeline_assignment` | FK | `node_id` → `timeline_node(node_id)` CASCADE |
| `timeline_assignment` | FK | `user_id` → `auth.users(id)` CASCADE |
| `timeline_assignment` | UNIQUE | `(node_id, user_id)` |
| `timeline_share` | PK | `share_id` UUID primary key |
| `timeline_share` | FK | `node_id` → `timeline_node(node_id)` CASCADE |
| `timeline_share` | FK | `user_id` → `auth.users(id)` CASCADE |
| `timeline_share` | UNIQUE | `(node_id, user_id)` |
| `timeline_audit_log` | PK | `audit_id` UUID primary key |
| `timeline_audit_log` | FK | `node_id` → `timeline_node(node_id)` CASCADE |
| `timeline_setting_health` | PK | `setting_id` UUID primary key |
| `timeline_setting_health` | FK | `risk_level` → `ref_risk_level(code)` |
| `timeline_setting_health` | UNIQUE | `risk_level` |
| `timeline_setting_health` | CHECK | `threshold_days >= 0` |

---

## Migration Notes

### Existing Tables to Deprecate (from tracking_* to timeline_*)

1. **`tracking_folder`** → Migrate to `timeline_folder`
2. **`tracking_plan`** → Migrate to `timeline_plan`
3. **`tracking_plan_style_timeline`** → Migrate to `timeline_node` + `timeline_style`
4. **`tracking_plan_material_timeline`** → Migrate to `timeline_node` + `timeline_material`

### Key Migration Differences

- All ENUMs replaced with TEXT columns + FK to ref schema
- Table naming convention: `timeline_*` (not `tracking_*`)
- Primary key naming: `{table}_id` (e.g., `folder_id`, `plan_id`, `node_id`)
- Assignment/share tables renamed without `tracking_` prefix
- All timestamps use TIMESTAMPTZ
- Consistent use of ref schema for lookups

---

## Settings Tables

### 10. timeline_setting_health (Customizable Risk Thresholds)

**Purpose:** Store user-configurable risk level thresholds for timeline health calculations.

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_setting_health (
  -- Primary identifier
  setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Risk configuration
  risk_level TEXT NOT NULL UNIQUE REFERENCES ref.ref_risk_level(code),
  threshold_days INTEGER NOT NULL CHECK (threshold_days >= 0),
  definition TEXT,  -- User-editable description
  sort_order INTEGER NOT NULL,
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

-- Indexes
CREATE INDEX idx_tracking_setting_health_risk_level 
  ON ops.tracking_setting_health(risk_level);
CREATE INDEX idx_tracking_setting_health_sort_order 
  ON ops.tracking_setting_health(sort_order);

-- Seed default values
INSERT INTO ops.timeline_setting_health (risk_level, threshold_days, definition, sort_order) 
VALUES
  ('low', 7, 'Less than 1 week late', 1),
  ('medium', 14, '1-2 weeks late', 2),
  ('high', 30, '2-4 weeks late', 3),
  ('critical', 999, 'More than 1 month late', 4)
ON CONFLICT (risk_level) DO NOTHING;

-- Audit trigger
CREATE TRIGGER timeline_setting_health_updated_at
  BEFORE UPDATE ON ops.timeline_setting_health
  FOR EACH ROW
  EXECUTE FUNCTION ops.update_updated_at_column();
```

**Usage:** These thresholds are used in progress queries to dynamically calculate `risk_level` based on `max_days_late`.

---

### Migration Order

1. Create ref schema reference tables (ref_timeline_entity_type, ref_dependency_type, ref_risk_level)
2. Create master data tables (`timeline_folder`, `timeline_plan`)
3. Create `timeline_node` table
4. Create detail tables (`timeline_style`, `timeline_material`)
5. Create supporting tables (`timeline_dependency`, `timeline_assignment`, `timeline_share`, `timeline_audit_log`)
6. Create settings tables (`timeline_setting_health`)
6. Create indexes
7. Create views
8. Migrate data from old tables
9. Validate data integrity
10. Create triggers (see [Triggers & Functions](./triggers-functions.md))

---

## Performance Considerations

### Query Optimization
- Use `view_timeline_with_details` for UI queries (pre-joined)
- Use `timeline_node` directly for bulk operations
- Index on `(plan_id, entity_type, entity_id)` for plan timeline queries
- Index on `(user_id)` for workload queries
- Partition `timeline_audit_log` by month if volume is high

### Expected Record Counts
- **timeline_node:** ~1M records (1000 plans × 100 styles × 10 milestones)
- **timeline_style:** ~1M records (1-to-1 with timeline_node for styles)
- **timeline_material:** ~500K records (1-to-1 with timeline_node for materials)
- **timeline_dependency:** ~5M records (5 dependencies per milestone avg)
- **tracking_timeline_assignment:** ~500K records (0.5 assignments per milestone avg)
- **tracking_timeline_share:** ~2M records (2 shares per milestone avg)

### Maintenance
- Run `VACUUM ANALYZE` on `timeline_node` weekly
- Reindex `timeline_dependency` monthly (heavy updates)
- Archive `timeline_audit_log` records older than 2 years

---

**Document Status:** ✅ Ready for Implementation  
**Last Updated:** October 31, 2025  
**Version:** 1.0
