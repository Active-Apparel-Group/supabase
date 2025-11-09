# Additional API Endpoints Analysis - Phase 02a Tracking

**Date:** November 9, 2025  
**Purpose:** Identify additional/enhanced endpoints from 02-timeline that could be implemented  
**Status:** ✅ Analysis Complete  
**Requested By:** @ChrisKalathas

---

## Executive Summary

Based on review of the 02-timeline documentation (specifically `endpoint-design.md` and `hybrid-timeline-schema-redesign.md`), I've identified **8 additional endpoint opportunities** that would enhance the tracking API beyond the 4 critical issues already proposed.

**Recommendation:** Add these as **Phase 2 issues** (after current API work complete). They provide significant value but are not blocking frontend migration.

---

## Current State vs. 02-Timeline Vision

### Already in Proposed Issues (✅ Covered)

| Endpoint | Issue | Priority |
|----------|-------|----------|
| CRUD on tracking tables | Issue #0A | 🔴 CRITICAL |
| Plan progress aggregation | Issue #0B | 🟡 HIGH |
| Bulk milestone updates | Issue #0C | 🟡 HIGH |
| API documentation | Issue #0D | 🔴 HIGH |

### From 02-Timeline - Not Yet Proposed (🆕 New Opportunities)

| Endpoint | Purpose | Priority | Phase |
|----------|---------|----------|-------|
| 1. Style-level progress/health | Individual style completion tracking | 🟢 MEDIUM | 2 |
| 2. Critical path calculation | Gantt chart support, longest dependency chain | 🟢 MEDIUM | 2 |
| 3. Timeline dependencies query | Predecessor/dependent milestone relationships | 🟢 MEDIUM | 2 |
| 4. Single node assignment/sharing | Per-milestone user management | 🟡 HIGH | 1-2 |
| 5. Risk/health thresholds | Late milestone alerting configuration | 🟢 MEDIUM | 2 |
| 6. Timeline audit log query | Change history tracking | 🟢 MEDIUM | 2 |
| 7. Search/filter plans | Advanced plan discovery | 🟡 HIGH | 1-2 |
| 8. Entity timeline query | Get timeline for specific style/material | 🟡 HIGH | 1-2 |

---

## Detailed Analysis

### 🆕 **1. Style-Level Progress/Health Endpoint**

**Purpose:** Get completion status and health metrics for individual style (not just plan-level)

**Endpoint:** `GET /api/v1/tracking/styles/{style_id}/progress`

**Response:**
```json
{
  "style_id": "style-uuid",
  "style_number": "MSP26B26",
  "style_name": "MONTAUK SHORT - 8\" INSEAM",
  "colorway": "220 - GROVE",
  "plan_id": "plan-uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "total_milestones": 27,
  "by_status": {
    "NOT_STARTED": 22,
    "IN_PROGRESS": 3,
    "APPROVED": 2
  },
  "completion_percentage": 7.4,
  "late_count": 15,
  "health_status": "AT_RISK",
  "next_due_milestone": {
    "milestone_name": "PROTO PRODUCTION",
    "due_date": "2025-11-15",
    "is_late": true
  },
  "critical_path_length": 249
}
```

**Value:**
- Frontend can show per-style health cards
- Dashboard widgets for "at-risk styles"
- Style detail pages with progress bars
- Email alerts for late styles

**Implementation Complexity:** Medium (1-2 days)

**Recommendation:** ✅ Add to Phase 2 issues (after Issue #0B)

---

### 🆕 **2. Critical Path Calculation**

**Purpose:** Calculate longest dependency chain for Gantt chart rendering

**Endpoint:** `GET /api/v1/tracking/plans/{plan_id}/critical-path`

**Response:**
```json
{
  "plan_id": "plan-uuid",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "critical_path": [
    {
      "node_id": "node-uuid-1",
      "milestone_name": "START DATE",
      "due_date": "2025-05-01",
      "path_position": 0
    },
    {
      "node_id": "node-uuid-2",
      "milestone_name": "TECHPACKS PASS OFF",
      "due_date": "2025-05-01",
      "path_position": 1
    }
  ],
  "total_duration_days": 249,
  "path_length": 25
}
```

**Value:**
- **Gantt chart visualization** (highlight critical path in red)
- Identify bottleneck milestones
- Calculate float/slack for non-critical tasks
- Project timeline forecasting

**Implementation Complexity:** High (3-5 days - requires graph traversal algorithm)

**Recommendation:** ✅ Add to Phase 2 issues (nice-to-have for Gantt UI)

---

### 🆕 **3. Timeline Dependencies Query**

**Purpose:** Get predecessor/dependent relationships for a milestone

**Endpoint:** `GET /api/v1/tracking/timeline/node/{node_id}/dependencies`

**Response:**
```json
{
  "node_id": "node-uuid",
  "milestone_name": "PROTO PRODUCTION",
  "predecessors": [
    {
      "predecessor_node_id": "node-uuid-1",
      "predecessor_milestone": "TECHPACKS PASS OFF",
      "dependency_type": "finish_to_start",
      "lag_days": 4
    }
  ],
  "dependents": [
    {
      "dependent_node_id": "node-uuid-3",
      "dependent_milestone": "PROTO EX-FCTY",
      "dependency_type": "finish_to_start",
      "lag_days": 14
    }
  ]
}
```

**Value:**
- **Gantt chart dependency arrows**
- "What depends on this?" queries
- Impact analysis (show what breaks if milestone delayed)
- Dependency validation (prevent circular dependencies)

**Implementation Complexity:** Low (1 day - simple join query)

**Recommendation:** ✅ Add to Phase 2 issues (supports Gantt UI)

---

### 🆕 **4. Single Node Assignment/Sharing**

**Purpose:** Assign/share individual milestones (more granular than bulk update)

**Endpoints:**
- `POST /api/v1/tracking/timeline/node/{node_id}/assignments`
- `DELETE /api/v1/tracking/timeline/node/{node_id}/assignments/{user_id}`
- `POST /api/v1/tracking/timeline/node/{node_id}/sharing`
- `DELETE /api/v1/tracking/timeline/node/{node_id}/sharing/{user_id}`

**Value:**
- Per-milestone user management
- "Assign to me" button in UI
- Share with supplier on milestone-level
- Manage team workload distribution

**Implementation Complexity:** Low (1 day)

**Recommendation:** ⚠️ Consider adding to Phase 1 (Issue #0A could include these)

---

### 🆕 **5. Risk/Health Thresholds Configuration**

**Purpose:** Configure when milestones are flagged as "at risk" based on lateness

**Endpoint:** `GET /api/v1/tracking/health-thresholds`

**Response:**
```json
{
  "thresholds": [
    {
      "risk_level": "ON_TRACK",
      "threshold_days": 0,
      "definition": "Due date not exceeded"
    },
    {
      "risk_level": "AT_RISK",
      "threshold_days": 7,
      "definition": "1-7 days late"
    },
    {
      "risk_level": "CRITICAL",
      "threshold_days": 14,
      "definition": "14+ days late"
    }
  ]
}
```

**Value:**
- Configurable alert thresholds
- Dashboard color coding (green/yellow/red)
- Email notifications based on risk level
- Business rule customization per brand

**Implementation Complexity:** Low (1 day - simple config table)

**Recommendation:** ✅ Add to Phase 2 issues (enhances progress endpoints)

---

### 🆕 **6. Timeline Audit Log Query**

**Purpose:** Get change history for milestones (who changed what when)

**Endpoint:** `GET /api/v1/tracking/timeline/node/{node_id}/audit-log`

**Response:**
```json
{
  "node_id": "node-uuid",
  "milestone_name": "PROTO PRODUCTION",
  "changes": [
    {
      "change_id": "change-uuid",
      "changed_at": "2025-11-01T15:30:00Z",
      "changed_by": "user-uuid",
      "changed_by_name": "Natalie James",
      "field": "status",
      "old_value": "NOT_STARTED",
      "new_value": "IN_PROGRESS",
      "reason": "Started proto sample production"
    },
    {
      "change_id": "change-uuid-2",
      "changed_at": "2025-11-05T10:15:00Z",
      "changed_by": "user-uuid",
      "changed_by_name": "Natalie James",
      "field": "rev_date",
      "old_value": null,
      "new_value": "2025-11-15",
      "reason": "Revised due to factory delay"
    }
  ]
}
```

**Value:**
- **Compliance/audit trail** (who approved when)
- Debugging (why did this date change?)
- Performance review (how long did user take)
- Dispute resolution (vendor claims they submitted on time)

**Implementation Complexity:** Medium (2 days - requires trigger to populate audit table)

**Recommendation:** ✅ Add to Phase 2 issues (governance/compliance feature)

---

### 🆕 **7. Advanced Plan Search/Filter**

**Purpose:** Search plans with advanced filters (date range, brand, completion %)

**Endpoint:** `GET /api/v1/tracking/plans`

**Query Parameters:**
- `search` - Text search in plan name
- `folder_id` - Filter by folder
- `status` - active/archived
- `brand` - Filter by brand
- `season` - Filter by season
- `completion_min` - Min completion %
- `completion_max` - Max completion %
- `late_count_min` - Min late milestones

**Response:**
```json
{
  "plans": [
    {
      "id": "plan-uuid",
      "name": "GREYSON 2026 SPRING DROP 1",
      "brand": "GREYSON",
      "season": "2026 Spring",
      "completion_percentage": 4.0,
      "late_count": 110,
      "total_milestones": 125
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_items": 3,
    "total_pages": 1
  }
}
```

**Value:**
- **Plan discovery** ("show me all Spring 2026 plans")
- Dashboard filters ("show at-risk plans")
- Reporting ("export all plans with >50% late")
- Power user features

**Implementation Complexity:** Low (1 day - PostgREST handles most filtering)

**Recommendation:** ⚠️ Consider adding to Phase 1 (could be part of Issue #0A)

---

### 🆕 **8. Entity Timeline Query**

**Purpose:** Get timeline for specific style or material (not plan-level)

**Endpoint:** `GET /api/v1/tracking/timeline/{entity_type}/{entity_id}`

**Example:** `GET /api/v1/tracking/timeline/style/style-uuid-123`

**Response:**
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
      "node_id": "node-uuid-1",
      "milestone_name": "TECHPACKS PASS OFF",
      "status": "APPROVED",
      "due_date": "2025-05-01",
      "is_late": false
    }
  ],
  "metadata": {
    "total_milestones": 27,
    "completed": 2,
    "late": 15,
    "completion_percentage": 7.4
  }
}
```

**Value:**
- **Style detail page** (show timeline for one style)
- Cross-plan timeline view (if style in multiple plans)
- Material tracking (same pattern)
- Direct entity access (no need to know plan_id)

**Implementation Complexity:** Low (1 day)

**Recommendation:** ⚠️ Consider adding to Phase 1 (could enhance Issue #0B)

---

## Recommendations by Phase

### ✅ **Add to Phase 1 (Current API Work)**

**Rationale:** Natural extensions of already-proposed issues, low effort

1. **Single Node Assignment/Sharing** - Extend Issue #0A (CRUD operations)
2. **Advanced Plan Search** - Extend Issue #0A (already doing PostgREST queries)
3. **Entity Timeline Query** - Extend Issue #0B (progress endpoints)

**Effort:** +2 days to current Phase 1 work  
**Value:** High (commonly requested by frontend)

### 📝 **Add to Phase 2 (Post-Migration Enhancements)**

**Rationale:** Nice-to-have features, don't block frontend migration

4. **Style-level Progress/Health** - New issue after Issue #0B
5. **Critical Path Calculation** - New issue (supports Gantt UI)
6. **Timeline Dependencies Query** - New issue (supports Gantt UI)
7. **Risk/Health Thresholds** - New issue (enhances dashboards)
8. **Timeline Audit Log** - New issue (compliance/governance)

**Effort:** 8-10 days total  
**Value:** Medium-High (enhanced UX, not essential)

---

## Comparison with BeProduct APIs

| Feature | BeProduct | Supabase Proposed | Gap Analysis |
|---------|-----------|-------------------|--------------|
| Plan progress | ✅ `planStyleProgress` | ✅ Issue #0B | Parity |
| Style progress | ❌ Not available | 🆕 Recommended | **Enhancement** |
| Bulk update | ✅ `planUpdateStyleTimelines` | ✅ Issue #0C | Parity |
| Critical path | ❌ Not available | 🆕 Recommended | **Enhancement** |
| Dependencies | ⚠️ Limited | 🆕 Recommended | **Enhancement** |
| Audit log | ❌ Not available | 🆕 Recommended | **Enhancement** |
| User workload | ❌ Not available | ✅ Issue #0B | **Enhancement** |
| Assignment management | ⚠️ Bulk only | 🆕 Recommended | **Enhancement** |

**Summary:** Proposed additions would give Supabase **feature parity + 5 enhancements** over BeProduct.

---

## Proposed Issue Template (Phase 2)

### Issue #0E: Enhanced Progress and Health Endpoints
**Title:** `[02a-Tracking] Add style-level progress and health metrics endpoints`  
**Labels:** `phase-02a-tracking`, `edge-function`, `api`, `phase-2`  
**Priority:** 🟢 MEDIUM

**Description:**
Add granular progress tracking at style/material level (not just plan-level).

**Endpoints:**
1. `GET /functions/v1/tracking-style-progress?style_id={uuid}`
2. `GET /functions/v1/tracking-health-thresholds`
3. `PATCH /functions/v1/tracking-health-thresholds` (admin only)

**Timeline:** 2 days  
**Dependencies:** Issue #0B (plan progress endpoints)

---

### Issue #0F: Gantt Chart Support Endpoints
**Title:** `[02a-Tracking] Add critical path and dependency query endpoints`  
**Labels:** `phase-02a-tracking`, `edge-function`, `api`, `phase-2`  
**Priority:** 🟢 MEDIUM

**Description:**
Enable Gantt chart visualization with critical path highlighting and dependency management.

**Endpoints:**
1. `GET /functions/v1/tracking-critical-path?plan_id={uuid}`
2. `GET /functions/v1/tracking-dependencies?node_id={uuid}`

**Timeline:** 3-4 days (critical path algorithm is complex)  
**Dependencies:** Issue #0B (plan progress endpoints)

---

### Issue #0G: Timeline Audit and History
**Title:** `[02a-Tracking] Add timeline audit log and change history tracking`  
**Labels:** `phase-02a-tracking`, `database`, `edge-function`, `api`, `phase-2`  
**Priority:** 🟢 MEDIUM

**Description:**
Track all changes to timeline milestones for compliance and debugging.

**Deliverables:**
1. Migration: Create `tracking_timeline_audit_log` table
2. Trigger: Auto-populate on timeline updates
3. Endpoint: `GET /functions/v1/tracking-audit-log?node_id={uuid}`

**Timeline:** 2 days  
**Dependencies:** Issue #0A (CRUD operations)

---

### Issue #0H: Assignment and Sharing Management
**Title:** `[02a-Tracking] Add per-milestone assignment and sharing endpoints`  
**Labels:** `phase-02a-tracking`, `edge-function`, `api`, `phase-2`  
**Priority:** 🟡 HIGH

**Description:**
Enable granular user management at milestone level.

**Endpoints:**
1. `POST /rest/v1/tracking_timeline_assignment` (create assignment)
2. `DELETE /rest/v1/tracking_timeline_assignment?node_id=eq.{uuid}&user_id=eq.{uuid}`
3. Similar for sharing

**Timeline:** 1 day  
**Dependencies:** Issue #0A (CRUD operations)

---

## Summary

**Immediate Actions:**
1. ✅ Review this analysis with stakeholders
2. ✅ Decide: Add 3 endpoints to Phase 1, or defer all to Phase 2?
3. ✅ Create Phase 2 issues in GitHub (Issues #0E-0H)

**Total Additional Endpoints Identified:** 8  
**Recommended for Phase 1:** 3 (low effort, high value)  
**Recommended for Phase 2:** 5 (medium effort, enhanced UX)

**Estimated Effort:**
- Phase 1 additions: +2 days (if included)
- Phase 2 work: 8-10 days total

**Value Proposition:**
- BeProduct parity + 5 enhancements
- Better UX (Gantt charts, audit logs, granular progress)
- Compliance features (change tracking)
- Power user features (advanced search, critical path)

---

**Status:** ✅ Analysis Complete  
**Reviewer:** Supabase Agent  
**Date:** November 9, 2025  
**Next Action:** Stakeholder review and decision on Phase 1 vs Phase 2
