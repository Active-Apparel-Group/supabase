# Timeline Schema Migration Plan

**Purpose:** Step-by-step migration from old timeline tables to hybrid architecture  
**Audience:** Backend Developers, DevOps, Database Administrators  
**Status:** Ready for Execution  
**Date:** October 31, 2025

---

## Migration Overview

**Scope:** Transform timeline tracking from entity-specific tables to unified hybrid architecture

**Timeline:** 6-11 weeks total
- **Week 1:** Schema migration and data transformation
- **Weeks 2-4:** API and frontend updates
- **Week 5:** Testing and QA
- **Week 6:** Production deployment
- **Weeks 7-10:** Grace period (old endpoints remain)
- **Week 11:** Cleanup and deprecation

**Risk Level:** Medium (non-production data, but breaking changes for frontend)

---

## Pre-Migration Checklist

- [ ] **Backup all data** (tracking_plan, tracking_plan_style_timeline, tracking_plan_material_timeline)
- [ ] **Review all dependent services** (API endpoints, frontend components, reports)
- [ ] **Test migration script on staging** (validate data transformation)
- [ ] **Notify stakeholders** (frontend team, QA team, product team)
- [ ] **Prepare rollback plan** (backup restoration procedure)
- [ ] **Schedule maintenance window** (if needed for production)

---

## Phase 1: Schema Migration (Week 1)

### Step 1.1: Create Enums

**File:** `001_create_timeline_enums.sql`

```sql
-- Timeline status enum
CREATE TYPE ops.timeline_status AS ENUM (
  'not_started',
  'in_progress',
  'waiting_on',
  'rejected',
  'approved',
  'approved_with_corrections',
  'na'
);

-- Entity type enum
CREATE TYPE ops.timeline_entity_type AS ENUM (
  'style',
  'material',
  'order',
  'production'
);

-- Dependency type enum
CREATE TYPE ops.dependency_type AS ENUM (
  'finish_to_start',
  'start_to_start',
  'finish_to_finish',
  'start_to_finish'
);

-- Lag type enum
CREATE TYPE ops.lag_type AS ENUM (
  'calendar_days',
  'business_days'
);
```

**Validation:**
```sql
SELECT typname FROM pg_type WHERE typname LIKE 'timeline%' OR typname IN ('dependency_type', 'lag_type');
-- Expected: 4 rows
```

---

### Step 1.2: Create Core Tables

**File:** `002_create_timeline_node.sql`

```sql
CREATE TABLE IF NOT EXISTS ops.timeline_node (
  node_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type ops.timeline_entity_type NOT NULL,
  entity_id UUID NOT NULL,
  plan_id UUID NOT NULL REFERENCES ops.tracking_plan(id) ON DELETE CASCADE,
  milestone_id UUID NOT NULL REFERENCES ops.timeline_template_milestone(id),
  status ops.timeline_status NOT NULL DEFAULT 'not_started',
  plan_date DATE NOT NULL,
  rev_date DATE,
  due_date DATE NOT NULL,
  final_date DATE,
  start_date_plan DATE,
  start_date_due DATE,
  is_late BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  
  CONSTRAINT check_entity_id_not_null CHECK (entity_id IS NOT NULL),
  CONSTRAINT check_due_date_with_dates CHECK (
    due_date = COALESCE(final_date, rev_date, plan_date)
  )
);

CREATE INDEX idx_timeline_node_entity ON ops.timeline_node(entity_type, entity_id);
CREATE INDEX idx_timeline_node_plan ON ops.timeline_node(plan_id);
CREATE INDEX idx_timeline_node_milestone ON ops.timeline_node(milestone_id);
CREATE INDEX idx_timeline_node_status ON ops.timeline_node(status);
CREATE INDEX idx_timeline_node_late ON ops.timeline_node(is_late) WHERE is_late = true;
CREATE INDEX idx_timeline_node_plan_entity ON ops.timeline_node(plan_id, entity_type, entity_id);
```

**Validation:**
```sql
SELECT tablename FROM pg_tables WHERE schemaname = 'ops' AND tablename = 'timeline_node';
-- Expected: 1 row

SELECT count(*) FROM pg_indexes WHERE schemaname = 'ops' AND tablename = 'timeline_node';
-- Expected: 6 indexes
```

---

### Step 1.3: Create Detail Tables

**File:** `003_create_timeline_detail_tables.sql`

```sql
-- Style detail table
CREATE TABLE IF NOT EXISTS ops.timeline_style (
  node_id UUID PRIMARY KEY REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  style_id UUID NOT NULL REFERENCES pim.styles(id) ON DELETE CASCADE,
  colorway_id UUID REFERENCES pim.style_colorways(id) ON DELETE CASCADE,
  milestone_name TEXT NOT NULL,
  phase TEXT,
  department TEXT,
  page_id UUID,
  page_title TEXT,
  page_type TEXT,
  customer_visible BOOLEAN NOT NULL DEFAULT false,
  supplier_visible BOOLEAN NOT NULL DEFAULT false,
  submits_quantity INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_timeline_style_style ON ops.timeline_style(style_id);
CREATE INDEX idx_timeline_style_colorway ON ops.timeline_style(colorway_id);

-- Material detail table
CREATE TABLE IF NOT EXISTS ops.timeline_material (
  node_id UUID PRIMARY KEY REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  material_id UUID NOT NULL REFERENCES pim.materials(id) ON DELETE CASCADE,
  milestone_name TEXT NOT NULL,
  phase TEXT,
  department TEXT,
  page_id UUID,
  page_title TEXT,
  page_type TEXT,
  customer_visible BOOLEAN NOT NULL DEFAULT false,
  supplier_visible BOOLEAN NOT NULL DEFAULT false,
  submits_quantity INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_timeline_material_material ON ops.timeline_material(material_id);
```

---

### Step 1.4: Create Supporting Tables

**File:** `004_create_timeline_supporting_tables.sql`

```sql
-- Dependency table (unified)
CREATE TABLE IF NOT EXISTS ops.timeline_dependency (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dependent_node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  predecessor_node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  dependency_type ops.dependency_type NOT NULL DEFAULT 'finish_to_start',
  lag_days INTEGER NOT NULL DEFAULT 0,
  lag_type ops.lag_type NOT NULL DEFAULT 'calendar_days',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT check_no_self_dependency CHECK (dependent_node_id != predecessor_node_id),
  CONSTRAINT unique_dependency UNIQUE (dependent_node_id, predecessor_node_id)
);

CREATE INDEX idx_timeline_dependency_dependent ON ops.timeline_dependency(dependent_node_id);
CREATE INDEX idx_timeline_dependency_predecessor ON ops.timeline_dependency(predecessor_node_id);

-- Assignment table (normalized)
CREATE TABLE IF NOT EXISTS ops.tracking_timeline_assignment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_by UUID REFERENCES auth.users(id),
  
  CONSTRAINT unique_assignment UNIQUE (node_id, user_id)
);

CREATE INDEX idx_timeline_assignment_node ON ops.tracking_timeline_assignment(node_id);
CREATE INDEX idx_timeline_assignment_user ON ops.tracking_timeline_assignment(user_id);

-- Share table (normalized)
CREATE TABLE IF NOT EXISTS ops.tracking_timeline_share (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  shared_by UUID REFERENCES auth.users(id),
  
  CONSTRAINT unique_share UNIQUE (node_id, user_id)
);

CREATE INDEX idx_timeline_share_node ON ops.tracking_timeline_share(node_id);
CREATE INDEX idx_timeline_share_user ON ops.tracking_timeline_share(user_id);

-- Audit log table
CREATE TABLE IF NOT EXISTS ops.timeline_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  node_id UUID NOT NULL REFERENCES ops.timeline_node(node_id) ON DELETE CASCADE,
  changed_field TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  changed_by UUID REFERENCES auth.users(id),
  change_reason TEXT
);

CREATE INDEX idx_timeline_audit_node ON ops.timeline_audit_log(node_id);
CREATE INDEX idx_timeline_audit_changed_at ON ops.timeline_audit_log(changed_at DESC);

-- Health settings table (customizable risk thresholds)
CREATE TABLE IF NOT EXISTS ops.tracking_setting_health (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_level ops.risk_level_enum NOT NULL UNIQUE,
  threshold_days INTEGER NOT NULL CHECK (threshold_days >= 0),
  definition TEXT,
  sort_order INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX idx_tracking_setting_health_risk_level ON ops.tracking_setting_health(risk_level);
CREATE INDEX idx_tracking_setting_health_sort_order ON ops.tracking_setting_health(sort_order);

-- Seed default health settings
INSERT INTO ops.tracking_setting_health (risk_level, threshold_days, definition, sort_order) VALUES
  ('low', 7, 'Less than 1 week late', 1),
  ('medium', 14, '1-2 weeks late', 2),
  ('high', 30, '2-4 weeks late', 3),
  ('critical', 999, 'More than 1 month late', 4)
ON CONFLICT (risk_level) DO NOTHING;

-- Audit trigger for health settings
CREATE TRIGGER tracking_setting_health_updated_at
  BEFORE UPDATE ON ops.tracking_setting_health
  FOR EACH ROW
  EXECUTE FUNCTION ops.update_updated_at_column();
```

---

### Step 1.5: Create Triggers and Functions

**File:** `005_create_timeline_triggers.sql`

See [Triggers & Functions](./triggers-functions.md) for complete implementations:
- `fn_calculate_due_date()` + trigger
- `fn_calculate_is_late()` + trigger
- `fn_calculate_start_dates()` + trigger
- `fn_recalculate_downstream_timelines()` + trigger
- `fn_audit_timeline_changes()` + trigger

---

### Step 1.6: Create Views

**File:** `006_create_timeline_views.sql`

```sql
-- Denormalized view
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
  COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
  COALESCE(ts.phase, tm.phase) AS phase,
  COALESCE(ts.department, tm.department) AS department,
  COALESCE(ts.page_id, tm.page_id) AS page_id,
  COALESCE(ts.page_title, tm.page_title) AS page_title,
  COALESCE(ts.page_type, tm.page_type) AS page_type,
  COALESCE(ts.customer_visible, tm.customer_visible) AS customer_visible,
  COALESCE(ts.supplier_visible, tm.supplier_visible) AS supplier_visible,
  ts.style_id,
  ts.colorway_id,
  tm.material_id
FROM ops.timeline_node tn
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id;

-- Progress view
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
  COUNT(*) FILTER (WHERE is_late = true) AS late
FROM ops.timeline_node
GROUP BY plan_id, entity_type;
```

---

### Step 1.7: Enhance Existing Tables

**File:** `007_enhance_existing_tables.sql`

```sql
-- Add plan_style_id FK to tracking_plan_material
ALTER TABLE ops.tracking_plan_material
ADD COLUMN IF NOT EXISTS plan_style_id UUID REFERENCES ops.tracking_plan_style(id);

CREATE INDEX IF NOT EXISTS idx_plan_material_style ON ops.tracking_plan_material(plan_style_id);

-- Populate plan_style_id based on existing business relationships
-- (Implementation depends on your data structure)
```

---

## Phase 2: Data Migration (Week 1)

### Step 2.1: Backup Existing Data

```sql
-- Create backup tables
CREATE TABLE ops.tracking_plan_style_timeline_backup AS 
SELECT * FROM ops.tracking_plan_style_timeline;

CREATE TABLE ops.tracking_plan_material_timeline_backup AS 
SELECT * FROM ops.tracking_plan_material_timeline;

-- Verify backup
SELECT 
  (SELECT count(*) FROM ops.tracking_plan_style_timeline) AS original_style_count,
  (SELECT count(*) FROM ops.tracking_plan_style_timeline_backup) AS backup_style_count,
  (SELECT count(*) FROM ops.tracking_plan_material_timeline) AS original_material_count,
  (SELECT count(*) FROM ops.tracking_plan_material_timeline_backup) AS backup_material_count;
-- Expected: All counts match
```

---

### Step 2.2: Migrate Style Timeline Data

**File:** `008_migrate_style_timeline_data.sql`

```sql
-- Migrate to timeline_node + timeline_style
WITH style_timeline_migration AS (
  INSERT INTO ops.timeline_node (
    entity_type,
    entity_id,
    plan_id,
    milestone_id,
    status,
    plan_date,
    rev_date,
    due_date,
    final_date,
    is_late,
    created_at,
    updated_at
  )
  SELECT 
    'style'::ops.timeline_entity_type AS entity_type,
    pst.style_id AS entity_id,
    pst.plan_id,
    pst.milestone_id,
    -- Map old status to new enum
    CASE pst.status
      WHEN 'Not Started' THEN 'not_started'
      WHEN 'In Progress' THEN 'in_progress'
      WHEN 'Waiting On' THEN 'waiting_on'
      WHEN 'Rejected' THEN 'rejected'
      WHEN 'Approved' THEN 'approved'
      WHEN 'Approved with Corrections' THEN 'approved_with_corrections'
      WHEN 'N/A' THEN 'na'
      ELSE 'not_started'
    END::ops.timeline_status AS status,
    pst.plan_date,
    pst.rev_date,
    COALESCE(pst.due_date, pst.rev_date, pst.plan_date) AS due_date,
    pst.final_date,
    pst.is_late,
    pst.created_at,
    pst.updated_at
  FROM ops.tracking_plan_style_timeline pst
  RETURNING node_id, entity_id AS style_id
)
-- Insert style details
INSERT INTO ops.timeline_style (
  node_id,
  style_id,
  colorway_id,
  milestone_name,
  phase,
  department,
  page_id,
  page_title,
  page_type,
  customer_visible,
  supplier_visible,
  submits_quantity
)
SELECT 
  stm.node_id,
  stm.style_id,
  pst.colorway_id,
  ttm.name AS milestone_name,
  pst.phase,
  pst.department,
  pst.page_id,
  pst.page_title,
  pst.page_type,
  pst.customer_visible,
  pst.supplier_visible,
  pst.submits_quantity
FROM style_timeline_migration stm
JOIN ops.tracking_plan_style_timeline pst ON pst.style_id = stm.style_id
JOIN ops.timeline_template_milestone ttm ON pst.milestone_id = ttm.id;

-- Verify migration
SELECT 
  (SELECT count(*) FROM ops.tracking_plan_style_timeline) AS original_count,
  (SELECT count(*) FROM ops.timeline_node WHERE entity_type = 'style') AS migrated_count,
  (SELECT count(*) FROM ops.timeline_style) AS detail_count;
-- Expected: All counts match
```

---

### Step 2.3: Migrate Material Timeline Data

**File:** `009_migrate_material_timeline_data.sql`

Similar structure to Step 2.2, but for materials:

```sql
-- Migrate to timeline_node + timeline_material
WITH material_timeline_migration AS (
  INSERT INTO ops.timeline_node (
    entity_type,
    entity_id,
    plan_id,
    milestone_id,
    status,
    plan_date,
    rev_date,
    due_date,
    final_date,
    is_late,
    created_at,
    updated_at
  )
  SELECT 
    'material'::ops.timeline_entity_type AS entity_type,
    pmt.material_id AS entity_id,
    pmt.plan_id,
    pmt.milestone_id,
    CASE pmt.status
      WHEN 'Not Started' THEN 'not_started'
      WHEN 'In Progress' THEN 'in_progress'
      WHEN 'Waiting On' THEN 'waiting_on'
      WHEN 'Rejected' THEN 'rejected'
      WHEN 'Approved' THEN 'approved'
      WHEN 'Approved with Corrections' THEN 'approved_with_corrections'
      WHEN 'N/A' THEN 'na'
      ELSE 'not_started'
    END::ops.timeline_status AS status,
    pmt.plan_date,
    pmt.rev_date,
    COALESCE(pmt.due_date, pmt.rev_date, pmt.plan_date) AS due_date,
    pmt.final_date,
    pmt.is_late,
    pmt.created_at,
    pmt.updated_at
  FROM ops.tracking_plan_material_timeline pmt
  RETURNING node_id, entity_id AS material_id
)
-- Insert material details
INSERT INTO ops.timeline_material (
  node_id,
  material_id,
  milestone_name,
  phase,
  department,
  page_id,
  page_title,
  page_type,
  customer_visible,
  supplier_visible,
  submits_quantity
)
SELECT 
  mtm.node_id,
  mtm.material_id,
  ttm.name AS milestone_name,
  pmt.phase,
  pmt.department,
  pmt.page_id,
  pmt.page_title,
  pmt.page_type,
  pmt.customer_visible,
  pmt.supplier_visible,
  pmt.submits_quantity
FROM material_timeline_migration mtm
JOIN ops.tracking_plan_material_timeline pmt ON pmt.material_id = mtm.material_id
JOIN ops.timeline_template_milestone ttm ON pmt.milestone_id = ttm.id;
```

---

### Step 2.4: Migrate Assignments and Sharing

**File:** `010_migrate_assignments_sharing.sql`

```sql
-- Migrate style timeline assignments (from JSONB array to normalized table)
INSERT INTO ops.tracking_timeline_assignment (node_id, user_id, assigned_at)
SELECT 
  tn.node_id,
  (assigned_user->>'id')::UUID AS user_id,
  COALESCE((assigned_user->>'assigned_at')::TIMESTAMPTZ, tn.created_at) AS assigned_at
FROM ops.tracking_plan_style_timeline pst
JOIN ops.timeline_node tn ON tn.entity_id = pst.style_id AND tn.entity_type = 'style'
CROSS JOIN LATERAL jsonb_array_elements(COALESCE(pst.assigned_to, '[]'::jsonb)) AS assigned_user
WHERE (assigned_user->>'id') IS NOT NULL
ON CONFLICT (node_id, user_id) DO NOTHING;

-- Migrate style timeline sharing
INSERT INTO ops.tracking_timeline_share (node_id, user_id, shared_at)
SELECT 
  tn.node_id,
  (shared_user->>'id')::UUID AS user_id,
  COALESCE((shared_user->>'shared_at')::TIMESTAMPTZ, tn.created_at) AS shared_at
FROM ops.tracking_plan_style_timeline pst
JOIN ops.timeline_node tn ON tn.entity_id = pst.style_id AND tn.entity_type = 'style'
CROSS JOIN LATERAL jsonb_array_elements(COALESCE(pst.shared_with, '[]'::jsonb)) AS shared_user
WHERE (shared_user->>'id') IS NOT NULL
ON CONFLICT (node_id, user_id) DO NOTHING;

-- Repeat for material timeline assignments and sharing
-- (Similar structure)
```

---

### Step 2.5: Migrate Dependencies

**File:** `011_migrate_dependencies.sql`

```sql
-- Migrate style timeline dependencies
INSERT INTO ops.timeline_dependency (dependent_node_id, predecessor_node_id, dependency_type, lag_days)
SELECT 
  tn_dep.node_id AS dependent_node_id,
  tn_pred.node_id AS predecessor_node_id,
  'finish_to_start'::ops.dependency_type AS dependency_type,
  COALESCE(pst_dep.lag_days, 0) AS lag_days
FROM ops.tracking_plan_style_timeline pst_dep
JOIN ops.timeline_node tn_dep ON tn_dep.entity_id = pst_dep.style_id AND tn_dep.entity_type = 'style'
JOIN ops.tracking_plan_style_timeline pst_pred ON pst_pred.id = pst_dep.predecessor_timeline_id
JOIN ops.timeline_node tn_pred ON tn_pred.entity_id = pst_pred.style_id AND tn_pred.entity_type = 'style'
WHERE pst_dep.predecessor_timeline_id IS NOT NULL
ON CONFLICT (dependent_node_id, predecessor_node_id) DO NOTHING;

-- Repeat for material timeline dependencies
```

---

### Step 2.6: Validate Migration

**File:** `012_validate_migration.sql`

```sql
-- Validation query
SELECT 
  'Style Timeline' AS source,
  (SELECT count(*) FROM ops.tracking_plan_style_timeline) AS original_count,
  (SELECT count(*) FROM ops.timeline_node WHERE entity_type = 'style') AS migrated_count,
  (SELECT count(*) FROM ops.timeline_style) AS detail_count

UNION ALL

SELECT 
  'Material Timeline' AS source,
  (SELECT count(*) FROM ops.tracking_plan_material_timeline) AS original_count,
  (SELECT count(*) FROM ops.timeline_node WHERE entity_type = 'material') AS migrated_count,
  (SELECT count(*) FROM ops.timeline_material) AS detail_count

UNION ALL

SELECT 
  'Assignments' AS source,
  (SELECT count(*) FROM (
    SELECT jsonb_array_length(COALESCE(assigned_to, '[]'::jsonb)) AS cnt
    FROM ops.tracking_plan_style_timeline
  ) sub) AS original_count,
  (SELECT count(*) FROM ops.tracking_timeline_assignment) AS migrated_count,
  NULL AS detail_count;

-- Expected: original_count = migrated_count = detail_count (where applicable)
```

---

## Phase 3: API Migration (Weeks 2-3)

### Step 3.1: Implement New Endpoints

**Tasks:**
- [ ] Create new API routes (see [Endpoint Design](./endpoint-design.md))
- [ ] Implement query functions (see [Query Examples](./query-examples.md))
- [ ] Add request/response validation
- [ ] Add error handling
- [ ] Add authentication/authorization checks
- [ ] Write unit tests for each endpoint

### Step 3.2: Maintain Backward Compatibility (Temporary)

**Strategy:** Old endpoints remain functional during migration period

```typescript
// Example: Old endpoint redirects to new implementation
app.get('/api/tracking/plan/:planId/styles/:styleId/timeline', async (req, res) => {
  // Redirect to new endpoint
  const newResponse = await fetch(
    `/api/v1/tracking/timeline/style/${req.params.styleId}?plan_id=${req.params.planId}`
  );
  res.json(await newResponse.json());
});
```

---

## Phase 4: Frontend Migration (Weeks 3-4)

See [Frontend Change Guide](./frontend-change-guide.md) for complete migration steps.

**Tasks:**
- [ ] Update API client library
- [ ] Update TypeScript interfaces
- [ ] Migrate Timeline List component
- [ ] Migrate Gantt Chart component
- [ ] Migrate Progress Dashboard component
- [ ] Migrate Milestone Edit Modal
- [ ] Implement User Workload component (new)
- [ ] Update bulk status update component
- [ ] Write component tests

---

## Phase 5: Testing & QA (Week 5)

See [Testing Plan](./testing-plan.md) for complete test coverage.

**Tasks:**
- [ ] Run schema validation tests
- [ ] Run trigger/function tests
- [ ] Run API endpoint tests
- [ ] Run frontend integration tests
- [ ] Run performance benchmarks
- [ ] Run E2E tests
- [ ] User acceptance testing
- [ ] Bug fixes and refinements

---

## Phase 6: Deployment (Week 6)

### Step 6.1: Pre-Deployment Checks

- [ ] All tests passing (backend + frontend)
- [ ] Performance benchmarks met
- [ ] Stakeholder sign-off received
- [ ] Deployment runbook reviewed
- [ ] Rollback plan ready
- [ ] Monitoring dashboards configured

### Step 6.2: Deployment Steps

1. **Deploy backend** (schema + API)
   - Run all migration scripts in sequence
   - Validate schema creation
   - Deploy new API endpoints
   - Keep old endpoints active

2. **Deploy frontend** (gradual rollout)
   - Deploy behind feature flag
   - Enable for 10% of users
   - Monitor error rates
   - Expand to 50% of users
   - Expand to 100% of users

3. **Monitor** (48 hours)
   - Watch error rates
   - Monitor query performance
   - Collect user feedback
   - Address any issues

### Step 6.3: Post-Deployment Validation

```sql
-- Verify all data accessible
SELECT count(*) FROM ops.timeline_node;
SELECT count(*) FROM ops.timeline_style;
SELECT count(*) FROM ops.timeline_material;

-- Verify triggers working
SELECT count(*) FROM ops.timeline_audit_log WHERE changed_at > NOW() - INTERVAL '1 hour';

-- Verify no orphaned records
SELECT count(*) FROM ops.timeline_node tn
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
WHERE ts.node_id IS NULL AND tm.node_id IS NULL;
-- Expected: 0
```

---

## Phase 7: Grace Period (Weeks 7-10)

**Purpose:** Allow time for full adoption and identify any edge cases

**Activities:**
- Monitor usage of old vs new endpoints
- Support any issues that arise
- Collect feedback from users
- Address any bugs or performance issues
- Prepare final deprecation notice

---

## Phase 8: Cleanup & Deprecation (Week 11)

### Step 8.1: Deprecate Old Endpoints

**File:** `013_deprecate_old_endpoints.sql`

```sql
-- Add deprecation warnings to old tables
COMMENT ON TABLE ops.tracking_plan_style_timeline IS 'DEPRECATED: Use timeline_node + timeline_style instead. Will be removed after [date].';
COMMENT ON TABLE ops.tracking_plan_material_timeline IS 'DEPRECATED: Use timeline_node + timeline_material instead. Will be removed after [date].';
```

### Step 8.2: Remove Old API Endpoints

```typescript
// Remove old endpoint implementations
// app.get('/api/tracking/plan/:planId/styles/:styleId/timeline', ...); // REMOVED
```

### Step 8.3: Drop Old Tables (After Approval)

**File:** `014_drop_old_tables.sql`

```sql
-- Final backup before drop
CREATE TABLE ops.tracking_plan_style_timeline_final_backup AS 
SELECT * FROM ops.tracking_plan_style_timeline;

CREATE TABLE ops.tracking_plan_material_timeline_final_backup AS 
SELECT * FROM ops.tracking_plan_material_timeline;

-- Drop old tables (after stakeholder approval)
-- DROP TABLE IF EXISTS ops.tracking_plan_style_timeline;
-- DROP TABLE IF EXISTS ops.tracking_plan_material_timeline;
```

---

## Rollback Plan

### Scenario 1: Schema Migration Failure (Week 1)

**Action:**
1. Drop newly created tables
2. Restore from backup (no data loss, old tables untouched)
3. Investigate and fix schema issues
4. Retry migration

```sql
-- Rollback script
DROP TABLE IF EXISTS ops.timeline_audit_log CASCADE;
DROP TABLE IF EXISTS ops.tracking_timeline_share CASCADE;
DROP TABLE IF EXISTS ops.tracking_timeline_assignment CASCADE;
DROP TABLE IF EXISTS ops.timeline_dependency CASCADE;
DROP TABLE IF EXISTS ops.timeline_material CASCADE;
DROP TABLE IF EXISTS ops.timeline_style CASCADE;
DROP TABLE IF EXISTS ops.timeline_node CASCADE;
DROP VIEW IF EXISTS ops.view_timeline_progress;
DROP VIEW IF EXISTS ops.view_timeline_with_details;
DROP TYPE IF EXISTS ops.lag_type;
DROP TYPE IF EXISTS ops.dependency_type;
DROP TYPE IF EXISTS ops.timeline_entity_type;
DROP TYPE IF EXISTS ops.timeline_status;

-- Old tables remain intact
```

### Scenario 2: API/Frontend Issues (Weeks 2-6)

**Action:**
1. Revert frontend to old API endpoints (feature flag toggle)
2. Keep new schema in place (data not affected)
3. Fix API/frontend issues
4. Retry deployment

### Scenario 3: Production Issues (After Week 6)

**Action:**
1. Restore old endpoints from backup
2. Toggle frontend to use old endpoints
3. Keep new schema and data in place
4. Investigate and fix issues
5. Re-enable new endpoints gradually

---

## Monitoring & Alerts

**Key Metrics:**
- Query response times (timeline, progress, workload)
- API error rates (4xx, 5xx)
- Database CPU/memory usage
- Table sizes and growth
- Trigger execution times

**Alerts:**
- Query response time > 500ms (warning)
- Query response time > 1s (critical)
- API error rate > 1% (warning)
- API error rate > 5% (critical)
- Database CPU > 80% (warning)

---

## Success Criteria

- ✅ All data migrated successfully (no data loss)
- ✅ All queries < performance targets
- ✅ Frontend components working correctly
- ✅ User acceptance testing passed
- ✅ No critical production issues
- ✅ Old endpoints deprecated and removed
- ✅ Stakeholder sign-off received

---

**Document Status:** ✅ Ready for Execution  
**Last Updated:** October 31, 2025  
**Version:** 1.0
