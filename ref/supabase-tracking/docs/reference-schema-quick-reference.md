# Reference Schema - Quick Reference Card

## Schema Overview

**Schema**: `ref`  
**Purpose**: Shared reference/lookup tables  
**Naming**: All tables prefixed with `ref_` to avoid REST endpoint conflicts  
**Status**: ✅ Production Ready

---

## All Tables At a Glance

| Table | Rows | Purpose | Key Fields |
|-------|------|---------|------------|
| `ref.ref_timeline_status` | 6 | Milestone status values | code, label, color_hex, is_terminal |
| `ref.ref_node_type` | 2 | Template node types (ANCHOR/TASK) | code, label |
| `ref.ref_offset_relation` | 2 | Dependency direction (AFTER/BEFORE) | code, label |
| `ref.ref_offset_unit` | 2 | Time units (DAYS/BUSINESS_DAYS) | code, label |
| `ref.ref_page_type` | 6 | BeProduct page types | code, label |
| `ref.ref_timeline_type` | 3 | Timeline scope (MASTER/STYLE/MATERIAL) | code, label |
| `ref.ref_view_type` | 2 | View filter types | code, label |
| `ref.ref_phase` | 6 | Project phases | code, label, color_hex |
| `ref.ref_department` | 10 | Department assignments | code, label |

**Total Tables**: 9  
**Total Rows**: 39  
**Total Indexes**: 9 (all on `is_active`)

---

## Standard Table Schema

All tables follow this structure:

```sql
CREATE TABLE ref.ref_[name] (
  code text PRIMARY KEY,           -- API/DB code (immutable)
  label text NOT NULL,              -- User-facing name
  description text,                 -- Detailed explanation
  display_order integer NOT NULL,   -- Sort order for dropdowns
  is_active boolean DEFAULT true,   -- Soft delete flag
  created_at timestamptz,
  updated_at timestamptz
  
  -- Optional fields (varies by table):
  color_hex text,                   -- UI color code
  icon text,                        -- Icon name
  is_terminal boolean               -- Final state flag
);
```

---

## Timeline Status Reference

| Code | Label | Color | Terminal | Use Case |
|------|-------|-------|----------|----------|
| `NOT_STARTED` | Not Started | #CCCCCC | No | Default initial state |
| `IN_PROGRESS` | In Progress | #4A90E2 | No | Work in progress |
| `APPROVED` | Approved | #7ED321 | No | Passed review |
| `REJECTED` | Rejected | #D0021B | No | Needs revision |
| `COMPLETE` | Complete | #50E3C2 | Yes | Fully done |
| `BLOCKED` | Blocked | #F5A623 | No | Waiting on blocker |

**Usage**: Status dropdowns, Gantt chart colors, progress tracking

---

## Phase Reference

| Code | Label | Color | Order | Use Case |
|------|-------|-------|-------|----------|
| `PLAN` | Planning | #9B59B6 | 1 | Initial planning |
| `DESIGN` | Design | #3498DB | 2 | Creative development |
| `DEVELOPMENT` | Development | #1ABC9C | 3 | Product development |
| `SMS` | SMS | #F39C12 | 4 | Size/Material/Sample |
| `PRODUCTION` | Production | #E74C3C | 5 | Bulk production |
| `ALLOCATION` | Allocation | #95A5A6 | 6 | Order allocation |

**Usage**: Group milestones, Gantt phase sections, phase-based filters

---

## Department Reference

| Code | Label | Order | Use Case |
|------|-------|-------|----------|
| `SYSTEM` | System | 1 | Auto-generated tasks |
| `ACCOUNT MANAGER` | Account Manager | 2 | Account management |
| `DESIGN` | Design | 3 | Design team |
| `PD` | Product Development | 4 | PD team |
| `CFT` | Critical Fit Team | 5 | Fit/quality team |
| `PRODUCTION` | Production | 6 | Production planning |
| `FACTORY` | Factory | 7 | Supplier team |
| `CUSTOMER` | Customer | 8 | Buyer team |
| `FINANCE` | Finance | 9 | Finance/costing |
| `LOGISTICS` | Logistics | 10 | Shipping team |

**Usage**: Assign milestone responsibility, department filters, workload reports

---

## Common API Patterns

### Fetch All Active (Dropdown)

```typescript
// Get dropdown options
const { data } = await supabase
  .from('ref_timeline_status')
  .select('code, label')
  .eq('is_active', true)
  .order('display_order');

// Returns: [{ code: 'NOT_STARTED', label: 'Not Started' }, ...]
```

### Fetch Single (Lookup)

```typescript
// Get details for a code
const { data } = await supabase
  .from('ref_phase')
  .select('*')
  .eq('code', 'DESIGN')
  .single();

// Returns: { code: 'DESIGN', label: 'Design', color_hex: '#3498DB', ... }
```

### Join with Timeline

```typescript
// Get timeline with status metadata
const { data } = await supabase
  .from('tracking_plan_style_timeline')
  .select(`
    id,
    milestone_name,
    status,
    status_ref:ref_timeline_status!status(label, color_hex)
  `);

// Returns: 
// {
//   id: 'uuid',
//   milestone_name: 'Proto Production',
//   status: 'IN_PROGRESS',
//   status_ref: { label: 'In Progress', color_hex: '#4A90E2' }
// }
```

---

## Quick Queries

### Check Data Loaded

```sql
-- Verify all tables populated
SELECT table_name, n_live_tup as row_count
FROM pg_stat_user_tables 
WHERE schemaname = 'ref'
ORDER BY table_name;
```

### Get All Status Colors

```sql
SELECT code, label, color_hex 
FROM ref.ref_timeline_status 
WHERE is_active = true 
ORDER BY display_order;
```

### Get Phase Sequence

```sql
SELECT code, label, display_order 
FROM ref.ref_phase 
WHERE is_active = true 
ORDER BY display_order;
```

---

## REST Endpoints

All tables accessible via Supabase REST API:

```
GET /rest/v1/ref_timeline_status?is_active=eq.true&order=display_order
GET /rest/v1/ref_phase?select=code,label,color_hex&order=display_order
GET /rest/v1/ref_department?is_active=eq.true&order=display_order
GET /rest/v1/ref_offset_unit?select=code,label
```

**Headers Required**:
- `apikey`: Your anon key
- `Authorization`: Bearer {anon-key}

---

## TypeScript Quick Types

```typescript
// Enum-style string unions (use these for type safety)
type TimelineStatusCode = 'NOT_STARTED' | 'IN_PROGRESS' | 'APPROVED' | 'REJECTED' | 'COMPLETE' | 'BLOCKED';
type PhaseCode = 'PLAN' | 'DESIGN' | 'DEVELOPMENT' | 'SMS' | 'PRODUCTION' | 'ALLOCATION';
type DepartmentCode = 'SYSTEM' | 'ACCOUNT MANAGER' | 'DESIGN' | 'PD' | 'CFT' | 'PRODUCTION' | 'FACTORY' | 'CUSTOMER' | 'FINANCE' | 'LOGISTICS';
type NodeTypeCode = 'ANCHOR' | 'TASK';
type OffsetRelationCode = 'AFTER' | 'BEFORE';
type OffsetUnitCode = 'DAYS' | 'BUSINESS_DAYS';

// Reference table row type
interface RefRow {
  code: string;
  label: string;
  description: string | null;
  display_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// With color
interface RefRowWithColor extends RefRow {
  color_hex: string | null;
}
```

---

## Common Patterns

### React Hook for Reference Data

```typescript
function useReferenceData<T>(tableName: string) {
  return useQuery({
    queryKey: [tableName],
    queryFn: async () => {
      const { data, error } = await supabase
        .from(tableName)
        .select('*')
        .eq('is_active', true)
        .order('display_order');
      
      if (error) throw error;
      return data as T[];
    },
    staleTime: 1000 * 60 * 60 * 24, // 24 hours
  });
}

// Usage:
const { data: statuses } = useReferenceData<RefTimelineStatus>('ref_timeline_status');
const { data: phases } = useReferenceData<RefPhase>('ref_phase');
```

### Create Lookup Map

```typescript
function useStatusMap() {
  const { data: statuses } = useReferenceData('ref_timeline_status');
  
  return useMemo(() => {
    return statuses?.reduce((acc, status) => {
      acc[status.code] = status;
      return acc;
    }, {} as Record<string, RefTimelineStatus>);
  }, [statuses]);
}

// Usage:
const statusMap = useStatusMap();
const status = statusMap['IN_PROGRESS']; // { code, label, color_hex, ... }
```

### Dropdown Component

```typescript
function RefSelect({ 
  table, 
  value, 
  onChange 
}: { 
  table: string; 
  value: string; 
  onChange: (value: string) => void;
}) {
  const { data } = useReferenceData(table);
  
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)}>
      {data?.map(item => (
        <option key={item.code} value={item.code}>
          {item.label}
        </option>
      ))}
    </select>
  );
}
```

---

## Security

**RLS**: Enabled on all tables  
**Policy**: Read-only for all authenticated users  
**Updates**: Admin/service role only (future enhancement)

```sql
-- Current policy (all tables)
CREATE POLICY "Allow read access to all users" 
ON ref.[table_name] 
FOR SELECT 
USING (true);
```

---

## Maintenance

### Add New Status

```sql
INSERT INTO ref.ref_timeline_status (
  code, 
  label, 
  description, 
  display_order, 
  color_hex, 
  is_terminal
) VALUES (
  'ON_HOLD',
  'On Hold',
  'Temporarily paused pending decision',
  7,
  '#FFC107',
  false
);
```

### Deprecate Without Deleting

```sql
UPDATE ref.ref_phase 
SET is_active = false 
WHERE code = 'OLD_PHASE';
```

### Reorder Items

```sql
UPDATE ref.ref_department
SET display_order = CASE code
  WHEN 'SYSTEM' THEN 1
  WHEN 'DESIGN' THEN 2
  WHEN 'PD' THEN 3
  -- etc
END;
```

---

## Troubleshooting

### Issue: Can't see reference tables in API

**Solution**: Check RLS policies are enabled:
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'ref';
```

### Issue: Wrong sort order in dropdown

**Solution**: Ensure ordering by `display_order`:
```typescript
.order('display_order') // not alphabetically!
```

### Issue: Outdated colors showing

**Solution**: Clear client cache:
```typescript
queryClient.invalidateQueries(['ref_timeline_status']);
```

---

## Migration Info

**Migration Name**: `create_reference_schema_and_tables`  
**Date Applied**: 2025-10-24  
**Tables Created**: 9  
**Indexes Created**: 9  
**Policies Created**: 18 (2 per table: RLS enable + SELECT policy)  

---

## Summary

✅ **9 reference tables** with `ref_` prefix  
✅ **39 rows** of seed data  
✅ **Read-only REST API** access  
✅ **Type-safe** with TypeScript unions  
✅ **UI-friendly** with colors, labels, ordering  
✅ **Soft deletes** via `is_active` flag  

**Use Cases**:
- Dropdowns (statuses, phases, departments)
- Gantt colors (phases, statuses)
- Badge styling (phases, statuses)
- Filter options (all tables)
- Assignment workflows (departments)

**Best Practice**: Cache reference data on app init (rarely changes)
