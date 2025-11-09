# SQL Query Examples

**Purpose:** Common SQL queries for timeline operations  
**Audience:** Backend Developers, API Implementation  
**Status:** Ready for Implementation  
**Date:** October 31, 2025

---

## Table of Contents
1. [Timeline Queries](#timeline-queries)
2. [Progress Queries](#progress-queries)
3. [Assignment & Sharing Queries](#assignment--sharing-queries)
4. [Dependency Queries](#dependency-queries)
5. [User Workload Queries](#user-workload-queries)
6. [Performance Optimization](#performance-optimization)

---

## Timeline Queries

### 1. Get Complete Timeline for Style (Replicates BeProduct planStyleTimeline)

```sql
SELECT 
  tn.node_id,
  tn.milestone_id,
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
  
  -- Page references
  jsonb_build_object(
    'id', ts.page_id,
    'title', ts.page_title,
    'type', ts.page_type
  ) AS page,
  
  -- Visibility flags
  ts.customer_visible,
  ts.supplier_visible,
  ts.submits_quantity,
  
  -- Aggregate assignments as JSON array (matches BeProduct assignedTo)
  COALESCE(
    json_agg(
      DISTINCT jsonb_build_object(
        'id', ta.user_id,
        'name', u1.raw_user_meta_data->>'name',
        'email', u1.email,
        'assigned_at', ta.assigned_at
      )
    ) FILTER (WHERE ta.user_id IS NOT NULL),
    '[]'::json
  ) AS assigned_to,
  
  -- Aggregate sharing as JSON array (matches BeProduct shareWith)
  COALESCE(
    json_agg(
      DISTINCT jsonb_build_object(
        'id', ts_share.user_id,
        'name', u2.raw_user_meta_data->>'name',
        'email', u2.email,
        'shared_at', ts_share.shared_at
      )
    ) FILTER (WHERE ts_share.user_id IS NOT NULL),
    '[]'::json
  ) AS shared_with,
  
  -- Timestamps
  tn.created_at,
  tn.updated_at

FROM ops.timeline_node tn
JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.tracking_timeline_assignment ta ON tn.node_id = ta.node_id
LEFT JOIN ops.tracking_timeline_share ts_share ON tn.node_id = ts_share.node_id
LEFT JOIN auth.users u1 ON ta.user_id = u1.id
LEFT JOIN auth.users u2 ON ts_share.user_id = u2.id

WHERE tn.entity_type = 'style'
  AND tn.entity_id = $1  -- style_id parameter
  AND tn.plan_id = $2    -- plan_id parameter

GROUP BY tn.node_id, ts.node_id
ORDER BY tn.plan_date, tn.created_at;
```

**Parameters:**
- `$1`: `style_id` (UUID)
- `$2`: `plan_id` (UUID)

**Example Output:**
```json
[
  {
    "node_id": "node-uuid-1",
    "milestone_id": "template-uuid-1",
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
    "page": {
      "id": "page-uuid",
      "title": "Techpack",
      "type": "techpack"
    },
    "customer_visible": true,
    "supplier_visible": false,
    "submits_quantity": 0,
    "assigned_to": [],
    "shared_with": [],
    "created_at": "2025-05-01T10:00:00Z",
    "updated_at": "2025-05-01T15:30:00Z"
  }
]
```

---

### 2. Get Timeline with Dependencies

```sql
SELECT 
  tn.node_id,
  COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
  tn.status,
  tn.due_date,
  tn.is_late,
  
  -- Dependencies (predecessors)
  COALESCE(
    json_agg(
      DISTINCT jsonb_build_object(
        'predecessor_node_id', td.predecessor_node_id,
        'predecessor_milestone', COALESCE(ts_pred.milestone_name, tm_pred.milestone_name),
        'dependency_type', td.dependency_type,
        'lag_days', td.lag_days
      )
    ) FILTER (WHERE td.predecessor_node_id IS NOT NULL),
    '[]'::json
  ) AS dependencies

FROM ops.timeline_node tn
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
LEFT JOIN ops.timeline_dependency td ON tn.node_id = td.dependent_node_id
LEFT JOIN ops.timeline_node tn_pred ON td.predecessor_node_id = tn_pred.node_id
LEFT JOIN ops.timeline_style ts_pred ON tn_pred.node_id = ts_pred.node_id
LEFT JOIN ops.timeline_material tm_pred ON tn_pred.node_id = tm_pred.node_id

WHERE tn.plan_id = $1

GROUP BY tn.node_id, ts.node_id, tm.node_id
ORDER BY tn.plan_date;
```

---

### 3. Get Single Milestone Detail

```sql
SELECT 
  tn.*,
  COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
  COALESCE(ts.phase, tm.phase) AS phase,
  COALESCE(ts.department, tm.department) AS department,
  COALESCE(ts.page_id, tm.page_id) AS page_id,
  COALESCE(ts.page_title, tm.page_title) AS page_title,
  COALESCE(ts.page_type, tm.page_type) AS page_type,
  COALESCE(ts.customer_visible, tm.customer_visible) AS customer_visible,
  COALESCE(ts.supplier_visible, tm.supplier_visible) AS supplier_visible

FROM ops.timeline_node tn
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id

WHERE tn.node_id = $1;
```

---

## Progress Queries

### 4. Get Plan Progress Summary (Enhanced with Health Metrics)

**Purpose:** Retrieve plan health with comprehensive risk analysis and recovery opportunities.

```sql
WITH base_metrics AS (
  SELECT
    tn.node_id,
    tn.plan_id,
    tn.entity_type,
    COALESCE(st.phase, mt.phase) AS phase,
    tn.status,
    tn.is_late,
    tn.plan_date,
    tn.due_date,
    tn.final_date,
    -- Days late from due_date (current schedule slip)
    CASE 
      WHEN tn.is_late AND tn.final_date IS NULL THEN 
        CURRENT_DATE - tn.due_date
      WHEN tn.is_late AND tn.final_date IS NOT NULL THEN
        tn.final_date - tn.due_date
      ELSE 0
    END AS days_late_from_due,
    -- Days late from plan_date (baseline drift)
    CASE 
      WHEN tn.due_date > tn.plan_date THEN 
        tn.due_date - tn.plan_date
      ELSE 0
    END AS days_late_to_plan
  FROM ops.timeline_node tn
  LEFT JOIN ops.timeline_style st ON st.node_id = tn.node_id
  LEFT JOIN ops.timeline_material mt ON mt.node_id = tn.node_id
  WHERE tn.plan_id = $1 -- plan_id parameter
    AND ($2::text IS NULL OR tn.entity_type = $2) -- entity_type filter (optional)
),
risk_thresholds AS (
  SELECT
    risk_level,
    threshold_days,
    sort_order
  FROM ops.tracking_setting_health
  ORDER BY sort_order DESC
),
overall_health AS (
  SELECT
    COUNT(*) AS total_milestones,
    COUNT(*) FILTER (WHERE is_late = true) AS late_count,
    COUNT(*) FILTER (WHERE is_late = false) AS on_time_count,
    COUNT(*) FILTER (WHERE status IN ('approved', 'na')) AS completed_count,
    ROUND(COUNT(*) FILTER (WHERE status IN ('approved', 'na'))::numeric / NULLIF(COUNT(*), 0) * 100, 2) AS completion_percentage,
    
    -- Entity-specific late counts
    COUNT(*) FILTER (WHERE entity_type = 'style' AND is_late = true) AS number_of_styles_late,
    COUNT(*) FILTER (WHERE entity_type = 'material' AND is_late = true) AS number_of_materials_late,
    
    -- Max days late by entity
    MAX(days_late_from_due) FILTER (WHERE entity_type = 'style') AS max_days_late_styles,
    MAX(days_late_from_due) FILTER (WHERE entity_type = 'material') AS max_days_late_materials,
    MAX(days_late_from_due) AS max_days_late_overall,
    
    -- Baseline drift
    MAX(days_late_to_plan) AS max_days_late_to_plan,
    ROUND(AVG(days_late_to_plan) FILTER (WHERE days_late_to_plan > 0), 1) AS avg_days_late_to_plan,
    
    -- Recovery opportunities (late but not started or in progress)
    COUNT(*) FILTER (WHERE is_late = true AND status IN ('not_started', 'in_progress')) AS recovery_opportunities
  FROM base_metrics
)
SELECT
  oh.total_milestones,
  oh.late_count,
  oh.on_time_count,
  oh.completed_count,
  oh.completion_percentage,
  
  -- Status breakdown
  json_build_object(
    'not_started', COUNT(*) FILTER (WHERE bm.status = 'not_started'),
    'in_progress', COUNT(*) FILTER (WHERE bm.status = 'in_progress'),
    'waiting_on', COUNT(*) FILTER (WHERE bm.status = 'waiting_on'),
    'rejected', COUNT(*) FILTER (WHERE bm.status = 'rejected'),
    'approved', COUNT(*) FILTER (WHERE bm.status = 'approved'),
    'approved_with_corrections', COUNT(*) FILTER (WHERE bm.status = 'approved_with_corrections'),
    'na', COUNT(*) FILTER (WHERE bm.status = 'na')
  ) AS by_status,
  
  -- Health metrics with dynamic risk level
  json_build_object(
    'late_count', oh.late_count,
    'on_time_count', oh.on_time_count,
    'completion_percentage', oh.completion_percentage,
    'number_of_styles_late', oh.number_of_styles_late,
    'number_of_materials_late', oh.number_of_materials_late,
    'max_days_late_styles', oh.max_days_late_styles,
    'max_days_late_materials', oh.max_days_late_materials,
    'max_days_late_overall', oh.max_days_late_overall,
    'max_days_late_to_plan', oh.max_days_late_to_plan,
    'avg_days_late_to_plan', oh.avg_days_late_to_plan,
    'risk_level', (
      SELECT risk_level::text
      FROM risk_thresholds
      WHERE oh.max_days_late_overall >= threshold_days
      LIMIT 1
    ),
    'recovery_opportunities', oh.recovery_opportunities
  ) AS health

FROM base_metrics bm
CROSS JOIN overall_health oh
GROUP BY oh.total_milestones, oh.late_count, oh.on_time_count, oh.completed_count, 
         oh.completion_percentage, oh.number_of_styles_late, oh.number_of_materials_late,
         oh.max_days_late_styles, oh.max_days_late_materials, oh.max_days_late_overall,
         oh.max_days_late_to_plan, oh.avg_days_late_to_plan, oh.recovery_opportunities;
```

**Parameters:**
- `$1` = `plan_id` (UUID, required)
- `$2` = `entity_type` (text, optional: 'style', 'material', or NULL for all)

**Example Output:**
```json
{
  "total_milestones": 125,
  "late_count": 110,
  "on_time_count": 15,
  "completed_count": 5,
  "completion_percentage": 4.0,
  "by_status": {
    "not_started": 109,
    "in_progress": 11,
    "waiting_on": 0,
    "rejected": 0,
    "approved": 5,
    "approved_with_corrections": 0,
    "na": 0
  },
  "health": {
    "late_count": 110,
    "on_time_count": 15,
    "completion_percentage": 4.0,
    "number_of_styles_late": 65,
    "number_of_materials_late": 45,
    "max_days_late_styles": 45,
    "max_days_late_materials": 30,
    "max_days_late_overall": 45,
    "max_days_late_to_plan": 150,
    "avg_days_late_to_plan": 12.5,
    "risk_level": "high",
    "recovery_opportunities": 23
  }
}
```

**Note:** Risk level is dynamically calculated based on `tracking_setting_health` table thresholds.

---

### 5. Progress Breakdown by Entity Type

```sql
SELECT 
  entity_type,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE status = 'approved') AS completed,
  COUNT(*) FILTER (WHERE is_late = true) AS late,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'approved') / NULLIF(COUNT(*), 0), 2) AS completion_percentage

FROM ops.timeline_node

WHERE plan_id = $1

GROUP BY entity_type;
```

**Example Output:**
```json
[
  {
    "entity_type": "style",
    "total": 75,
    "completed": 5,
    "late": 65,
    "completion_percentage": 6.67
  },
  {
    "entity_type": "material",
    "total": 50,
    "completed": 0,
    "late": 45,
    "completion_percentage": 0.0
  }
]
```

---

### 6. Progress Breakdown by Phase

```sql
SELECT 
  COALESCE(ts.phase, tm.phase) AS phase,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE tn.status = 'approved') AS completed,
  COUNT(*) FILTER (WHERE tn.is_late = true) AS late

FROM ops.timeline_node tn
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id

WHERE tn.plan_id = $1

GROUP BY COALESCE(ts.phase, tm.phase)
ORDER BY 
  CASE COALESCE(ts.phase, tm.phase)
    WHEN 'DEVELOPMENT' THEN 1
    WHEN 'SMS' THEN 2
    WHEN 'ALLOCATION' THEN 3
    WHEN 'PRODUCTION' THEN 4
    ELSE 5
  END;
```

---

### 7. Per-Style Progress Rollup

```sql
SELECT 
  s.id AS style_id,
  s.name AS style_name,
  sc.id AS colorway_id,
  sc.name AS colorway_name,
  COUNT(*) AS total_milestones,
  COUNT(*) FILTER (WHERE tn.status = 'approved') AS completed_milestones,
  COUNT(*) FILTER (WHERE tn.is_late = true) AS late_milestones,
  ROUND(100.0 * COUNT(*) FILTER (WHERE tn.status = 'approved') / NULLIF(COUNT(*), 0), 2) AS completion_percentage

FROM ops.timeline_node tn
JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
JOIN pim.styles s ON ts.style_id = s.id
LEFT JOIN pim.style_colorways sc ON ts.colorway_id = sc.id

WHERE tn.plan_id = $1

GROUP BY s.id, s.name, sc.id, sc.name
ORDER BY s.name, sc.name;
```

---

## Assignment & Sharing Queries

### 8. Get Milestones Assigned to User

```sql
SELECT 
  tn.node_id,
  tn.entity_type,
  CASE 
    WHEN tn.entity_type = 'style' THEN s.name
    WHEN tn.entity_type = 'material' THEN m.name
  END AS entity_name,
  COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
  tn.status,
  tn.due_date,
  tn.is_late,
  p.name AS plan_name,
  ta.assigned_at

FROM ops.tracking_timeline_assignment ta
JOIN ops.timeline_node tn ON ta.node_id = tn.node_id
JOIN ops.tracking_plan p ON tn.plan_id = p.id
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
LEFT JOIN pim.styles s ON ts.style_id = s.id
LEFT JOIN pim.materials m ON tm.material_id = m.id

WHERE ta.user_id = $1
  AND tn.status NOT IN ('approved', 'na')

ORDER BY tn.due_date, tn.is_late DESC;
```

---

### 9. Get Milestones Shared with User

```sql
SELECT 
  tn.node_id,
  COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
  tn.status,
  tn.due_date,
  ts_share.shared_at

FROM ops.tracking_timeline_share ts_share
JOIN ops.timeline_node tn ON ts_share.node_id = tn.node_id
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id

WHERE ts_share.user_id = $1

ORDER BY tn.due_date;
```

---

### 10. Get All Users Assigned to a Milestone

```sql
SELECT 
  u.id AS user_id,
  u.email,
  u.raw_user_meta_data->>'name' AS name,
  ta.assigned_at,
  au.raw_user_meta_data->>'name' AS assigned_by_name

FROM ops.tracking_timeline_assignment ta
JOIN auth.users u ON ta.user_id = u.id
LEFT JOIN auth.users au ON ta.assigned_by = au.id

WHERE ta.node_id = $1

ORDER BY ta.assigned_at;
```

---

## Dependency Queries

### 11. Get All Predecessors for a Milestone

```sql
SELECT 
  tn_pred.node_id AS predecessor_node_id,
  COALESCE(ts_pred.milestone_name, tm_pred.milestone_name) AS predecessor_milestone,
  td.dependency_type,
  td.lag_days,
  tn_pred.due_date AS predecessor_due_date

FROM ops.timeline_dependency td
JOIN ops.timeline_node tn_pred ON td.predecessor_node_id = tn_pred.node_id
LEFT JOIN ops.timeline_style ts_pred ON tn_pred.node_id = ts_pred.node_id
LEFT JOIN ops.timeline_material tm_pred ON tn_pred.node_id = tm_pred.node_id

WHERE td.dependent_node_id = $1;
```

---

### 12. Get All Dependents for a Milestone (Downstream)

```sql
SELECT 
  tn_dep.node_id AS dependent_node_id,
  COALESCE(ts_dep.milestone_name, tm_dep.milestone_name) AS dependent_milestone,
  td.dependency_type,
  td.lag_days,
  tn_dep.due_date AS dependent_due_date

FROM ops.timeline_dependency td
JOIN ops.timeline_node tn_dep ON td.dependent_node_id = tn_dep.node_id
LEFT JOIN ops.timeline_style ts_dep ON tn_dep.node_id = ts_dep.node_id
LEFT JOIN ops.timeline_material tm_dep ON tn_dep.node_id = tm_dep.node_id

WHERE td.predecessor_node_id = $1;
```

---

### 13. Get Complete Dependency Chain (Recursive)

```sql
WITH RECURSIVE dependency_chain AS (
  -- Base case: start milestone
  SELECT 
    tn.node_id,
    COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
    tn.due_date,
    0 AS depth,
    ARRAY[tn.node_id] AS path
  FROM ops.timeline_node tn
  LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
  LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
  WHERE tn.node_id = $1
  
  UNION ALL
  
  -- Recursive case: follow dependencies
  SELECT 
    tn.node_id,
    COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
    tn.due_date,
    dc.depth + 1,
    dc.path || tn.node_id
  FROM ops.timeline_dependency td
  JOIN ops.timeline_node tn ON td.dependent_node_id = tn.node_id
  LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
  LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
  JOIN dependency_chain dc ON td.predecessor_node_id = dc.node_id
  WHERE dc.depth < 50  -- Prevent infinite loops
    AND NOT (tn.node_id = ANY(dc.path))  -- Prevent cycles
)
SELECT * FROM dependency_chain ORDER BY depth, due_date;
```

---

### 14. Get Critical Path (Longest Dependency Chain)

```sql
WITH RECURSIVE path AS (
  -- Base case: milestones with no predecessors
  SELECT 
    tn.node_id,
    COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
    tn.due_date,
    0 AS path_length,
    ARRAY[tn.node_id] AS path_nodes
  FROM ops.timeline_node tn
  LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
  LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
  WHERE tn.plan_id = $1
    AND NOT EXISTS (
      SELECT 1 FROM ops.timeline_dependency td 
      WHERE td.dependent_node_id = tn.node_id
    )
  
  UNION ALL
  
  -- Recursive case: follow dependency chain
  SELECT 
    tn.node_id,
    COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
    tn.due_date,
    p.path_length + 1,
    p.path_nodes || tn.node_id
  FROM ops.timeline_node tn
  LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
  LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
  JOIN ops.timeline_dependency td ON tn.node_id = td.dependent_node_id
  JOIN path p ON td.predecessor_node_id = p.node_id
  WHERE tn.plan_id = $1
    AND NOT (tn.node_id = ANY(p.path_nodes))
)
SELECT 
  node_id,
  milestone_name,
  due_date,
  path_length
FROM path
WHERE path_length = (SELECT MAX(path_length) FROM path)
ORDER BY path_length, due_date;
```

---

## User Workload Queries

### 15. User Workload Summary

```sql
SELECT 
  COUNT(*) AS total_assignments,
  COUNT(*) FILTER (WHERE tn.is_late = true) AS late_assignments,
  COUNT(*) FILTER (WHERE tn.status = 'in_progress') AS in_progress,
  COUNT(*) FILTER (
    WHERE tn.status = 'approved' 
    AND tn.updated_at >= CURRENT_DATE - INTERVAL '7 days'
  ) AS completed_this_week

FROM ops.tracking_timeline_assignment ta
JOIN ops.timeline_node tn ON ta.node_id = tn.node_id

WHERE ta.user_id = $1
  AND tn.status NOT IN ('approved', 'na');
```

---

### 16. Late Milestones for User

```sql
SELECT 
  tn.node_id,
  tn.entity_type,
  CASE 
    WHEN tn.entity_type = 'style' THEN s.name
    WHEN tn.entity_type = 'material' THEN m.name
  END AS entity_name,
  COALESCE(ts.milestone_name, tm.milestone_name) AS milestone_name,
  tn.status,
  tn.plan_date,
  tn.due_date,
  (CURRENT_DATE - tn.due_date) AS days_overdue,
  p.name AS plan_name

FROM ops.tracking_timeline_assignment ta
JOIN ops.timeline_node tn ON ta.node_id = tn.node_id
JOIN ops.tracking_plan p ON tn.plan_id = p.id
LEFT JOIN ops.timeline_style ts ON tn.node_id = ts.node_id
LEFT JOIN ops.timeline_material tm ON tn.node_id = tm.node_id
LEFT JOIN pim.styles s ON ts.style_id = s.id
LEFT JOIN pim.materials m ON tm.material_id = m.id

WHERE ta.user_id = $1
  AND tn.is_late = true
  AND tn.status NOT IN ('approved', 'na')

ORDER BY tn.due_date;
```

---

## Performance Optimization

### Index Usage Verification

```sql
-- Verify index usage for timeline query
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM ops.timeline_node
WHERE entity_type = 'style' 
  AND entity_id = 'style-uuid' 
  AND plan_id = 'plan-uuid';

-- Expected: Index Scan on idx_timeline_node_plan_entity
```

### Query Performance Benchmarks

| Query | Target Time | Index Used |
|-------|-------------|------------|
| Get timeline for style | < 100ms | `idx_timeline_node_plan_entity` |
| Get plan progress | < 50ms | `idx_timeline_node_plan` |
| Get user workload | < 200ms | `idx_timeline_assignment_user` |
| Get critical path | < 300ms | `idx_timeline_dependency_both` |
| Bulk update (50 nodes) | < 2s | `idx_timeline_node_entity` |

---

**Document Status:** ✅ Ready for Implementation  
**Last Updated:** October 31, 2025  
**Version:** 1.0
