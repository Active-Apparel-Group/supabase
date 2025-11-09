# Frontend Change Guide

**Purpose:** Breaking changes, migration steps, and UI implementation guide  
**Audience:** Frontend Developers  
**Status:** Ready for Review  
**Date:** October 31, 2025

---

## 🚨 Breaking Changes Summary

### High-Level Impact
- ✅ **Timeline Data Structure:** Changed from entity-specific tables to hybrid architecture
- ✅ **API Endpoints:** New endpoint structure (backward compatibility where possible)
- ✅ **Assignment/Sharing:** Changed from JSONB arrays to normalized tables (query results still arrays)
- ✅ **Enhanced Features:** Start dates now available for Gantt charts
- ⚠️ **No Database Changes to Style/Material Records:** Entity records unchanged

### Migration Timeline
- **Phase 1 (Week 1):** Backend schema migration (no frontend changes yet)
- **Phase 2 (Weeks 2-4):** Frontend migration (all timeline components)
- **Phase 3 (Week 5):** Testing & QA
- **Phase 4 (Week 6+):** Deployment & monitoring

---

## 📋 Component Migration Checklist

| Component | Current State | Required Changes | Priority | Estimated Effort |
|-----------|--------------|------------------|----------|------------------|
| Timeline List View | Uses old API endpoints | Update API calls, data mapping | 🔴 High | 2 days |
| Gantt Chart | Only end dates | Add start date rendering | 🟡 Medium | 3 days |
| Progress Dashboard | Separate style/material queries | Use unified progress endpoint | 🔴 High | 1 day |
| Milestone Edit Modal | JSONB assignment/sharing | Update save/fetch logic | 🔴 High | 2 days |
| User Workload View | Not implemented | New feature implementation | 🟢 Low | 2 days |
| Dependency Editor | Entity-specific | Support cross-entity dependencies | 🟢 Low | 3 days |
| Bulk Status Update | Uses old bulk endpoint | Update payload structure | 🔴 High | 1 day |

---

## 🔄 API Endpoint Changes

### 1. Timeline List Query

#### Before (Old API)
```typescript
// Separate queries for styles and materials
const styleTimeline = await fetch(
  `/api/tracking/plan/${planId}/styles/${styleId}/timeline`
);

const materialTimeline = await fetch(
  `/api/tracking/plan/${planId}/materials/${materialId}/timeline`
);
```

#### After (New API)
```typescript
// Unified endpoint for all entity types
const timeline = await fetch(
  `/api/v1/tracking/timeline/style/${styleId}?plan_id=${planId}`
);

// Or get entire plan timeline
const planTimeline = await fetch(
  `/api/v1/tracking/plans/${planId}/timeline?entity_type=style`
);
```

**Migration Steps:**
1. Update API client to use new endpoint paths
2. Update TypeScript interfaces (see [Type Definitions](#type-definitions))
3. Update data mapping logic (field names unchanged)
4. Test with real data

---

### 2. Progress Dashboard

#### Before (Old API)
```typescript
// Separate queries for progress
const styleProgress = await fetch(
  `/api/tracking/plan/${planId}/styles/progress`
);

const materialProgress = await fetch(
  `/api/tracking/plan/${planId}/materials/progress`
);

// Manual aggregation
const totalProgress = {
  total: styleProgress.total + materialProgress.total,
  approved: styleProgress.approved + materialProgress.approved,
  // ...
};
```

#### After (New API)
```typescript
// Single unified query
const progress = await fetch(
  `/api/v1/tracking/plans/${planId}/progress`
);

// Response includes breakdown by entity type
console.log(progress.by_entity_type.style.total); // 75
console.log(progress.by_entity_type.material.total); // 50
console.log(progress.total_milestones); // 125
```

**Migration Steps:**
1. Replace separate queries with single unified query
2. Update chart rendering to use `by_entity_type` breakdown
3. Add phase/department breakdown if needed (use `group_by` param)

---

### 3. Bulk Status Update

#### Before (Old API)
```typescript
// Entity-specific bulk update
await fetch(`/api/tracking/plan/${planId}/styles/timeline/bulk-update`, {
  method: 'PATCH',
  body: JSON.stringify({
    updates: [
      { timelineId: 'id-1', status: 'approved', finalDate: '2025-11-01' },
      { timelineId: 'id-2', status: 'in_progress' }
    ]
  })
});
```

#### After (New API)
```typescript
// Unified bulk update
await fetch(`/api/v1/tracking/timeline/bulk`, {
  method: 'PATCH',
  body: JSON.stringify({
    updates: [
      { node_id: 'node-id-1', status: 'approved', final_date: '2025-11-01' },
      { node_id: 'node-id-2', status: 'in_progress' }
    ]
  })
});
```

**Key Changes:**
- ✅ `timelineId` → `node_id`
- ✅ `finalDate` → `final_date` (snake_case)
- ✅ Response includes `downstream_affected` count (new enhancement!)

---

## 📐 Type Definitions

### Timeline Node (Core Type)

```typescript
export enum TimelineStatus {
  NOT_STARTED = 'not_started',
  IN_PROGRESS = 'in_progress',
  WAITING_ON = 'waiting_on',
  REJECTED = 'rejected',
  APPROVED = 'approved',
  APPROVED_WITH_CORRECTIONS = 'approved_with_corrections',
  NA = 'na'
}

export enum EntityType {
  STYLE = 'style',
  MATERIAL = 'material',
  ORDER = 'order',
  PRODUCTION = 'production'
}

export interface TimelineNode {
  node_id: string; // UUID
  entity_type: EntityType;
  entity_id: string; // UUID
  plan_id: string; // UUID
  milestone_id: string; // UUID
  milestone_name: string;
  phase: string | null;
  department: string | null;
  status: TimelineStatus;
  
  // Date fields (ISO 8601 format)
  plan_date: string;
  rev_date: string | null;
  due_date: string;
  final_date: string | null;
  
  // NEW: Start dates for Gantt
  start_date_plan: string | null;
  start_date_due: string | null;
  
  // Computed flags
  is_late: boolean;
  
  // Relationships (when included)
  assigned_to: AssignedUser[];
  shared_with: SharedUser[];
  dependencies: Dependency[];
  
  // Page references
  page: {
    id: string | null;
    title: string | null;
    type: string | null;
  } | null;
  
  // Visibility flags
  customer_visible: boolean;
  supplier_visible: boolean;
  
  // Audit
  created_at: string;
  updated_at: string;
}

export interface AssignedUser {
  id: string; // UUID
  name: string;
  email: string;
  assigned_at: string;
}

export interface SharedUser {
  id: string; // UUID
  name: string;
  email: string;
  shared_at: string;
}

export interface Dependency {
  predecessor_node_id: string;
  predecessor_milestone: string;
  dependency_type: 'finish_to_start' | 'start_to_start' | 'finish_to_finish' | 'start_to_finish';
  lag_days: number;
}
```

### Timeline Response Type

```typescript
export interface TimelineResponse {
  entity_type: EntityType;
  entity_id: string;
  entity_name: string;
  colorway_id?: string | null;
  colorway_name?: string | null;
  plan_id: string;
  plan_name: string;
  timeline: TimelineNode[];
  metadata: {
    total_milestones: number;
    completed_milestones: number;
    late_milestones: number;
    completion_percentage: number;
  };
}
```

### Progress Response Type

```typescript
export enum RiskLevel {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

export interface HealthMetrics {
  late_count: number;
  on_time_count: number;
  completion_percentage: number;
  number_of_styles_late: number;
  number_of_materials_late: number;
  max_days_late_styles: number;
  max_days_late_materials: number;
  max_days_late_overall: number;
  max_days_late_to_plan: number;
  avg_days_late_to_plan: number;
  risk_level: RiskLevel;
  recovery_opportunities: number;
}

export interface HealthSetting {
  id: string;
  risk_level: RiskLevel;
  threshold_days: number;
  definition: string;
  sort_order: number;
  created_at: string;
  updated_at: string;
  created_by?: string;
  updated_by?: string;
}

export interface ProgressResponse {
  plan_id: string;
  plan_name: string;
  total_milestones: number;
  by_status: {
    not_started: number;
    in_progress: number;
    waiting_on: number;
    rejected: number;
    approved: number;
    approved_with_corrections: number;
    na: number;
  };
  late_count: number;
  on_time_count: number;
  completion_percentage: number;
  health: HealthMetrics; // Enhanced health metrics
  by_entity_type: {
    [key in EntityType]?: {
      total: number;
      late: number;
      completed: number;
      completion_percentage: number;
      max_days_late: number;
      avg_days_late: number;
      max_days_late_to_plan: number;
      avg_days_late_to_plan: number;
    };
  };
  by_phase?: {
    [phase: string]: {
      total: number;
      late: number;
      completed: number;
      completion_percentage: number;
      max_days_late: number;
      avg_days_late: number;
      max_days_late_to_plan: number;
      risk_level: RiskLevel;
    };
  };
}
```

---

## 🎨 UI Component Updates

### 1. Timeline List Component

**File:** `src/components/timeline/TimelineList.tsx`

**Changes:**
```diff
// Update API call
- const { data } = await api.get(`/tracking/plan/${planId}/styles/${styleId}/timeline`);
+ const { data } = await api.get(`/v1/tracking/timeline/style/${styleId}?plan_id=${planId}`);

// Data structure unchanged (backward compatible)
{data.timeline.map(milestone => (
  <TimelineRow
    key={milestone.node_id} // Changed from milestone.id
    milestone={milestone}
    // ... props unchanged
  />
))}
```

**New Features Available:**
- ✅ `start_date_plan` and `start_date_due` for duration display
- ✅ `dependencies` array for dependency visualization
- ✅ `is_late` boolean for styling

---

### 2. Gantt Chart Component

**File:** `src/components/timeline/GanttChart.tsx`

**Major Enhancement:** Start dates now available!

**Changes:**
```diff
// OLD: Only end dates available (render bars with estimated duration)
- const barStart = new Date(milestone.due_date);
- barStart.setDate(barStart.getDate() - 7); // Guess 7 days
- const barEnd = new Date(milestone.due_date);

// NEW: Actual start and end dates
+ const barStart = new Date(milestone.start_date_due);
+ const barEnd = new Date(milestone.due_date);

// Render bar
<GanttBar
  start={barStart}
  end={barEnd}
  label={milestone.milestone_name}
  isLate={milestone.is_late}
  status={milestone.status}
/>
```

**Additional Enhancements:**
```typescript
// Fetch critical path for highlighting
const { critical_path } = await api.get(`/v1/tracking/plans/${planId}/critical-path`);
const criticalNodeIds = new Set(critical_path.map(n => n.node_id));

// Highlight critical path milestones
<GanttBar
  start={barStart}
  end={barEnd}
  isCritical={criticalNodeIds.has(milestone.node_id)}
  className={criticalNodeIds.has(milestone.node_id) ? 'critical-path' : ''}
/>
```

---

### 3. Progress Dashboard Component

**File:** `src/components/dashboard/ProgressDashboard.tsx`

**Changes:**
```diff
// OLD: Separate queries and manual aggregation
- const styleProgress = await api.get(`/tracking/plan/${planId}/styles/progress`);
- const materialProgress = await api.get(`/tracking/plan/${planId}/materials/progress`);
- const totalProgress = {
-   total: styleProgress.total + materialProgress.total,
-   approved: styleProgress.approved + materialProgress.approved,
- };

// NEW: Single unified query
+ const progress = await api.get(`/v1/tracking/plans/${planId}/progress`);

// Render breakdown by entity type
<ProgressChart
  data={[
    { name: 'Styles', value: progress.by_entity_type.style.total },
    { name: 'Materials', value: progress.by_entity_type.material.total },
  ]}
/>
```

**New Visualizations:**
```typescript
// Phase breakdown (new capability!)
const progressByPhase = await api.get(
  `/v1/tracking/plans/${planId}/progress?group_by=phase`
);

<PhaseBreakdownChart data={progressByPhase.by_phase} />
```

---

### 4. Milestone Edit Modal

**File:** `src/components/timeline/MilestoneEditModal.tsx`

**Changes:**
```diff
// Assignment handling (normalized table, but query returns arrays)
// Data structure in response is UNCHANGED
const milestone = {
  node_id: 'node-uuid',
  assigned_to: [
    { id: 'user-uuid', name: 'Natalie James', email: 'natalie@example.com' }
  ],
  shared_with: [
    { id: 'user-uuid-2', name: 'Chris K', email: 'chris@example.com' }
  ]
};

// Update assignment (NEW endpoint)
- await api.post(`/tracking/timeline/${milestone.id}/assign`, { userId });
+ await api.post(`/v1/tracking/timeline/node/${milestone.node_id}/assignments`, { 
+   user_id: userId 
+ });

// Update sharing (NEW endpoint)
- await api.post(`/tracking/timeline/${milestone.id}/share`, { userId });
+ await api.post(`/v1/tracking/timeline/node/${milestone.node_id}/sharing`, { 
+   user_id: userId 
+ });
```

**Status Update:**
```diff
// Single milestone update
- await api.patch(`/tracking/timeline/${milestone.id}`, {
-   status: 'approved',
-   finalDate: '2025-11-01'
- });

+ await api.patch(`/v1/tracking/timeline/node/${milestone.node_id}`, {
+   status: 'approved',
+   final_date: '2025-11-01',
+   updated_by: currentUserId
+ });
```

---

### 5. User Workload Component (NEW)

**File:** `src/components/user/UserWorkload.tsx` *(new component)*

**Implementation:**
```typescript
import React, { useEffect, useState } from 'react';
import { api } from '@/lib/api';

interface UserWorkloadProps {
  userId: string;
}

export const UserWorkload: React.FC<UserWorkloadProps> = ({ userId }) => {
  const [workload, setWorkload] = useState(null);
  
  useEffect(() => {
    const fetchWorkload = async () => {
      const { data } = await api.get(`/v1/tracking/users/${userId}/assignments`);
      setWorkload(data);
    };
    fetchWorkload();
  }, [userId]);
  
  if (!workload) return <Loading />;
  
  return (
    <div className="user-workload">
      <h2>{workload.user_name}'s Workload</h2>
      <div className="summary">
        <Badge count={workload.summary.total_assignments} label="Total" />
        <Badge count={workload.summary.late_assignments} label="Late" variant="danger" />
        <Badge count={workload.summary.completed_this_week} label="Completed" variant="success" />
      </div>
      <WorkloadTable assignments={workload.assignments} />
    </div>
  );
};
```

---

## 🎛️ Health Settings Configuration UI (NEW)

### Requirements

**Location:** Add "Health Settings" tab/section to existing Plans & Timelines interface

**Purpose:** Allow users to customize risk level thresholds for timeline health calculations

### UI Components

#### Health Settings Panel

```typescript
import React, { useState, useEffect } from 'react';
import { api } from '@/lib/api';
import { HealthSetting, RiskLevel } from '@/types/timeline';

export const HealthSettingsPanel: React.FC = () => {
  const [settings, setSettings] = useState<HealthSetting[]>([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    fetchSettings();
  }, []);
  
  const fetchSettings = async () => {
    const { data } = await api.get('/v1/tracking/settings/health');
    setSettings(data.sort((a, b) => a.sort_order - b.sort_order));
    setLoading(false);
  };
  
  const handleUpdate = async (id: string, updates: Partial<HealthSetting>) => {
    await api.patch(`/v1/tracking/settings/health/${id}`, updates);
    fetchSettings(); // Refresh
  };
  
  const handleReset = async () => {
    if (confirm('Reset to default thresholds?')) {
      await api.post('/v1/tracking/settings/health/reset');
      fetchSettings();
    }
  };
  
  const getRiskColor = (level: RiskLevel) => {
    switch (level) {
      case RiskLevel.LOW: return 'green';
      case RiskLevel.MEDIUM: return 'yellow';
      case RiskLevel.HIGH: return 'orange';
      case RiskLevel.CRITICAL: return 'red';
    }
  };
  
  if (loading) return <Loading />;
  
  return (
    <div className="health-settings-panel">
      <div className="settings-header">
        <h3>Timeline Health Risk Thresholds</h3>
        <button onClick={handleReset} className="btn-secondary">
          Reset to Defaults
        </button>
      </div>
      
      <table className="settings-table">
        <thead>
          <tr>
            <th>Risk Level</th>
            <th>Threshold (Days Late)</th>
            <th>Definition</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {settings.map(setting => (
            <HealthSettingRow
              key={setting.id}
              setting={setting}
              onUpdate={(updates) => handleUpdate(setting.id, updates)}
              riskColor={getRiskColor(setting.risk_level)}
            />
          ))}
        </tbody>
      </table>
      
      <div className="settings-footer">
        <InfoBox>
          Risk levels are calculated based on maximum days late. 
          Lower thresholds = more sensitive alerts.
        </InfoBox>
      </div>
    </div>
  );
};

interface HealthSettingRowProps {
  setting: HealthSetting;
  onUpdate: (updates: Partial<HealthSetting>) => void;
  riskColor: string;
}

const HealthSettingRow: React.FC<HealthSettingRowProps> = ({ 
  setting, 
  onUpdate, 
  riskColor 
}) => {
  const [thresholdDays, setThresholdDays] = useState(setting.threshold_days);
  const [definition, setDefinition] = useState(setting.definition);
  const [editing, setEditing] = useState(false);
  
  const handleSave = () => {
    onUpdate({ threshold_days: thresholdDays, definition });
    setEditing(false);
  };
  
  return (
    <tr className={`risk-${setting.risk_level}`}>
      <td>
        <span className="risk-badge" style={{ backgroundColor: riskColor }}>
          {setting.risk_level.toUpperCase()}
        </span>
      </td>
      <td>
        {editing ? (
          <input
            type="number"
            value={thresholdDays}
            min={0}
            max={999}
            onChange={(e) => setThresholdDays(parseInt(e.target.value))}
            className="input-sm"
          />
        ) : (
          <span>{setting.threshold_days} days</span>
        )}
      </td>
      <td>
        {editing ? (
          <input
            type="text"
            value={definition}
            onChange={(e) => setDefinition(e.target.value)}
            placeholder="Enter custom definition"
            className="input-text"
          />
        ) : (
          <span>{setting.definition}</span>
        )}
      </td>
      <td>
        {editing ? (
          <>
            <button onClick={handleSave} className="btn-sm btn-primary">Save</button>
            <button onClick={() => setEditing(false)} className="btn-sm">Cancel</button>
          </>
        ) : (
          <button onClick={() => setEditing(true)} className="btn-sm btn-secondary">Edit</button>
        )}
      </td>
    </tr>
  );
};
```

### API Client Methods

```typescript
// src/lib/api/timeline.ts

export const healthSettingsApi = {
  getAll: async (): Promise<HealthSetting[]> => {
    const { data } = await api.get('/v1/tracking/settings/health');
    return data;
  },
  
  update: async (id: string, updates: Partial<HealthSetting>): Promise<void> => {
    await api.patch(`/v1/tracking/settings/health/${id}`, updates);
  },
  
  reset: async (): Promise<void> => {
    await api.post('/v1/tracking/settings/health/reset');
  }
};
```

### Validation Rules

- `threshold_days` must be >= 0
- `threshold_days` should increase with risk level severity (low < medium < high < critical)
- `definition` is optional (free text, max 500 characters)
- Changes take effect immediately for all new progress calculations

### User Permissions

- **View:** All users with access to Plans & Timelines
- **Edit:** Admin users or users with "Manage Settings" permission
- **Audit:** All changes logged with user ID and timestamp

---

## 🧪 Testing Checklist

### Unit Tests
- [ ] API client methods for new endpoints
- [ ] Type definitions match API responses
- [ ] Date parsing and formatting utilities
- [ ] Status enum conversions
- [ ] Health settings validation logic
- [ ] Risk level badge color mapping

### Integration Tests
- [ ] Timeline list renders correctly with new data structure
- [ ] Gantt chart displays start and end dates
- [ ] Progress dashboard aggregates correctly
- [ ] Milestone edit modal saves assignments/sharing
- [ ] Bulk update handles multiple milestones
- [ ] Health settings panel loads current values
- [ ] Health settings update saves correctly
- [ ] Reset to defaults restores original thresholds

### E2E Tests
- [ ] User can view timeline for a style
- [ ] User can update milestone status
- [ ] User can assign/share milestones
- [ ] User can view their workload
- [ ] User can bulk update multiple milestones
- [ ] Late milestones highlighted correctly
- [ ] Gantt chart renders with proper date ranges
- [ ] Admin can configure health settings
- [ ] Health settings changes affect risk level calculations
- [ ] Risk levels update dynamically when thresholds change

---

## 🚀 Deployment Strategy

### Phase 1: Backend Migration (Week 1)
- Backend deploys new schema
- Old API endpoints remain functional (backward compatible)
- Frontend continues using old endpoints (no changes yet)

### Phase 2: Frontend Migration (Weeks 2-4)
- Update API client library
- Migrate components one by one
- Feature flags for gradual rollout
- A/B testing for new UI features

### Phase 3: Testing & QA (Week 5)
- Comprehensive regression testing
- Performance testing (query response times)
- User acceptance testing
- Bug fixes and refinements

### Phase 4: Deployment & Monitoring (Week 6+)
- Deploy to production
- Monitor error rates and performance
- Collect user feedback
- Iterate on enhancements

---

## 📞 Support & Resources

### Documentation
- [API Endpoint Design](./endpoint-design.md) - Complete API specification
- [BeProduct API Mapping](./beproduct-api-mapping.md) - Field-level mappings
- [Query Examples](./query-examples.md) - SQL query examples
- [Schema DDL](./schema-ddl.md) - Database schema reference

### Support Channels
- **Slack:** #timeline-migration
- **Backend Team:** [Backend lead]
- **Frontend Team:** [Frontend lead]
- **QA Team:** [QA lead]

### Testing Environment
- **API Base URL:** `https://staging-api.yourcompany.com/api/v1`
- **Test Plan ID:** `162eedf3-0230-4e4c-88e1-6db332e3707b` (GREYSON 2026 SPRING DROP 1)
- **Test Style ID:** [To be provided]
- **Test User:** [To be provided]

---

**Document Status:** ✅ Ready for Review  
**Last Updated:** October 31, 2025  
**Version:** 1.0
