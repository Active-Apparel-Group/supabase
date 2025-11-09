# Reference Schema - Frontend Developer Guide

## Overview

The `ref` schema provides shared reference data (lookup tables) for the tracking system. All tables use the `ref_` prefix to avoid naming conflicts with public REST endpoints.

**Migration**: `create_reference_schema_and_tables`  
**Date**: 2025-10-24  
**Status**: ✅ Complete

---

## Why Reference Tables Instead of Enums?

### Previous Approach (Enums)
```sql
CREATE TYPE tracking.timeline_status_enum AS ENUM (
  'NOT_STARTED', 'IN_PROGRESS', 'COMPLETE'
);
```

**Limitations**:
- Cannot add metadata (labels, colors, descriptions)
- Difficult to modify without migrations
- No soft delete (is_active flag)
- No display ordering

### New Approach (Reference Tables)
```sql
CREATE TABLE ref.ref_timeline_status (
  code text PRIMARY KEY,
  label text,
  color_hex text,
  display_order integer,
  is_active boolean
);
```

**Benefits**:
- ✅ User-friendly labels separate from codes
- ✅ UI metadata (colors, icons, descriptions)
- ✅ Soft delete via `is_active` flag
- ✅ Custom ordering via `display_order`
- ✅ Can update without migrations

---

## Complete Reference Tables

### 1. Timeline Status (`ref.ref_timeline_status`)

**Purpose**: Status values for timeline milestones

| Code | Label | Color | Terminal | Description |
|------|-------|-------|----------|-------------|
| `NOT_STARTED` | Not Started | #CCCCCC | No | Milestone not started |
| `IN_PROGRESS` | In Progress | #4A90E2 | No | Currently being worked on |
| `APPROVED` | Approved | #7ED321 | No | Reviewed and approved |
| `REJECTED` | Rejected | #D0021B | No | Rejected, needs revision |
| `COMPLETE` | Complete | #50E3C2 | Yes | Fully completed |
| `BLOCKED` | Blocked | #F5A623 | No | Blocked by dependencies |

**Fields**:
- `code` (text, PK) - API/database code (immutable)
- `label` (text) - User-facing display name
- `description` (text) - Detailed explanation
- `display_order` (integer) - Sort order for dropdowns
- `color_hex` (text) - UI color code
- `icon` (text) - Icon name/class (nullable)
- `is_terminal` (boolean) - True if status is final state
- `is_active` (boolean) - Soft delete flag

---

### 2. Node Type (`ref.ref_node_type`)

**Purpose**: Template item node types

| Code | Label | Description |
|------|-------|-------------|
| `ANCHOR` | Anchor | Fixed date anchor point (e.g., season start) |
| `TASK` | Task | Regular milestone with dependencies |

**Use Case**: Templates can have ANCHOR nodes (fixed dates) vs TASK nodes (calculated from dependencies)

---

### 3. Offset Relation (`ref.ref_offset_relation`)

**Purpose**: Dependency relationship direction

| Code | Label | Description |
|------|-------|-------------|
| `AFTER` | After | Start this task N units AFTER predecessor completes |
| `BEFORE` | Before | Complete this task N units BEFORE successor starts |

**Use Case**: Define whether offset is forward (AFTER) or backward (BEFORE)

---

### 4. Offset Unit (`ref.ref_offset_unit`)

**Purpose**: Time units for offsets and durations

| Code | Label | Description |
|------|-------|-------------|
| `DAYS` | Calendar Days | Standard calendar days (includes weekends) |
| `BUSINESS_DAYS` | Business Days | Working days only (excludes weekends/holidays) |

**Use Case**: Dropdown for selecting duration/offset units

---

### 5. Page Type (`ref.ref_page_type`)

**Purpose**: BeProduct page types linkable to milestones

| Code | Label | Description |
|------|-------|-------------|
| `BOM` | Bill of Materials | BOM page link |
| `SAMPLE_REQUEST_MULTI` | Multi-Sample Request | Multi-sample request page |
| `SAMPLE_REQUEST` | Sample Request | Single sample request page |
| `FORM` | Form | Custom form page |
| `TECHPACK` | Tech Pack | Tech pack page |
| `NONE` | None | No page link |

**Use Case**: Link timeline milestones to specific BeProduct pages

---

### 6. Timeline Type (`ref.ref_timeline_type`)

**Purpose**: Timeline scope levels

| Code | Label | Description |
|------|-------|-------------|
| `MASTER` | Master Timeline | Plan-level master timeline |
| `STYLE` | Style Timeline | Style-specific timeline |
| `MATERIAL` | Material Timeline | Material-specific timeline |

**Use Case**: Differentiate between plan-level, style-level, and material-level timelines

---

### 7. View Type (`ref.ref_view_type`)

**Purpose**: Plan view filter types

| Code | Label | Description |
|------|-------|-------------|
| `STYLE` | Style View | View showing style timelines |
| `MATERIAL` | Material View | View showing material timelines |

**Use Case**: Filter which timeline type to display in a view

---

### 8. Phase (`ref.ref_phase`)

**Purpose**: Project phases for grouping milestones

| Code | Label | Color | Description |
|------|-------|-------|-------------|
| `PLAN` | Planning | #9B59B6 | Initial planning and setup |
| `DESIGN` | Design | #3498DB | Design and creative development |
| `DEVELOPMENT` | Development | #1ABC9C | Product development and sampling |
| `SMS` | SMS | #F39C12 | Size/Material/Sample phase |
| `PRODUCTION` | Production | #E74C3C | Bulk production |
| `ALLOCATION` | Allocation | #95A5A6 | Order allocation and delivery |

**Use Case**: 
- Group timeline milestones into phases
- Color-code Gantt chart sections
- Filter milestones by phase

---

### 9. Department (`ref.ref_department`)

**Purpose**: Departments responsible for milestones

| Code | Label | Description |
|------|-------|-------------|
| `SYSTEM` | System | System-generated milestones |
| `ACCOUNT MANAGER` | Account Manager | Account management team |
| `DESIGN` | Design | Design and creative team |
| `PD` | Product Development | Product development team |
| `CFT` | Critical Fit Team | Fit and quality team |
| `PRODUCTION` | Production | Production planning team |
| `FACTORY` | Factory | Factory/supplier team |
| `CUSTOMER` | Customer | Customer/buyer team |
| `FINANCE` | Finance | Finance and costing team |
| `LOGISTICS` | Logistics | Logistics and shipping team |

**Use Case**:
- Assign milestone responsibility
- Filter by department
- Department-specific views/reports

---

## TypeScript Types

```typescript
// Base reference type
interface RefBase {
  code: string;
  label: string;
  description: string | null;
  display_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// Timeline Status
interface RefTimelineStatus extends RefBase {
  color_hex: string | null;
  icon: string | null;
  is_terminal: boolean;
}

// Phase (with color)
interface RefPhase extends RefBase {
  color_hex: string | null;
}

// Simple reference types
type RefNodeType = RefBase;
type RefOffsetRelation = RefBase;
type RefOffsetUnit = RefBase;
type RefPageType = RefBase;
type RefTimelineType = RefBase;
type RefViewType = RefBase;
type RefDepartment = RefBase;

// Type-safe code unions
type TimelineStatusCode = 
  | 'NOT_STARTED' 
  | 'IN_PROGRESS' 
  | 'APPROVED' 
  | 'REJECTED' 
  | 'COMPLETE' 
  | 'BLOCKED';

type NodeTypeCode = 'ANCHOR' | 'TASK';
type OffsetRelationCode = 'AFTER' | 'BEFORE';
type OffsetUnitCode = 'DAYS' | 'BUSINESS_DAYS';
type PageTypeCode = 'BOM' | 'SAMPLE_REQUEST_MULTI' | 'SAMPLE_REQUEST' | 'FORM' | 'TECHPACK' | 'NONE';
type TimelineTypeCode = 'MASTER' | 'STYLE' | 'MATERIAL';
type ViewTypeCode = 'STYLE' | 'MATERIAL';
type PhaseCode = 'PLAN' | 'DESIGN' | 'DEVELOPMENT' | 'SMS' | 'PRODUCTION' | 'ALLOCATION';
type DepartmentCode = 'SYSTEM' | 'ACCOUNT MANAGER' | 'DESIGN' | 'PD' | 'CFT' | 'PRODUCTION' | 'FACTORY' | 'CUSTOMER' | 'FINANCE' | 'LOGISTICS';
```

---

## API Usage

### Fetching Reference Data

```typescript
// Fetch all active statuses
const { data: statuses } = await supabase
  .from('ref_timeline_status')
  .select('*')
  .eq('is_active', true)
  .order('display_order');

// Fetch all phases with colors
const { data: phases } = await supabase
  .from('ref_phase')
  .select('code, label, color_hex, display_order')
  .eq('is_active', true)
  .order('display_order');

// Fetch all departments
const { data: departments } = await supabase
  .from('ref_department')
  .select('*')
  .eq('is_active', true)
  .order('display_order');

// Fetch offset units for dropdown
const { data: units } = await supabase
  .from('ref_offset_unit')
  .select('code, label')
  .eq('is_active', true)
  .order('display_order');
```

### Using in Joins

```typescript
// Fetch timeline with status details
const { data: timeline } = await supabase
  .from('tracking_plan_style_timeline')
  .select(`
    id,
    milestone_name,
    plan_date,
    status:ref_timeline_status!tracking_plan_style_timeline_status_fkey(
      code,
      label,
      color_hex
    )
  `)
  .eq('plan_style_id', styleId);

// Result:
// {
//   id: 'uuid',
//   milestone_name: 'Proto Production',
//   plan_date: '2024-02-15',
//   status: {
//     code: 'IN_PROGRESS',
//     label: 'In Progress',
//     color_hex: '#4A90E2'
//   }
// }
```

---

## UI Component Examples

### 1. Status Dropdown

```typescript
function StatusDropdown({ value, onChange }: Props) {
  const { data: statuses } = useQuery({
    queryKey: ['ref_timeline_status'],
    queryFn: async () => {
      const { data } = await supabase
        .from('ref_timeline_status')
        .select('*')
        .eq('is_active', true)
        .order('display_order');
      return data;
    }
  });

  return (
    <Select value={value} onChange={(e) => onChange(e.target.value)}>
      {statuses?.map(status => (
        <option key={status.code} value={status.code}>
          {status.label}
        </option>
      ))}
    </Select>
  );
}
```

### 2. Phase Badge with Color

```typescript
function PhaseBadge({ phaseCode }: { phaseCode: string }) {
  const { data: phase } = useQuery({
    queryKey: ['ref_phase', phaseCode],
    queryFn: async () => {
      const { data } = await supabase
        .from('ref_phase')
        .select('*')
        .eq('code', phaseCode)
        .single();
      return data;
    }
  });

  if (!phase) return null;

  return (
    <Badge 
      style={{ backgroundColor: phase.color_hex || '#CCCCCC' }}
      title={phase.description}
    >
      {phase.label}
    </Badge>
  );
}
```

### 3. Status Indicator with Color

```typescript
function StatusIndicator({ statusCode }: { statusCode: TimelineStatusCode }) {
  const { data: status } = useQuery({
    queryKey: ['ref_timeline_status', statusCode],
    queryFn: async () => {
      const { data } = await supabase
        .from('ref_timeline_status')
        .select('*')
        .eq('code', statusCode)
        .single();
      return data;
    }
  });

  if (!status) return null;

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
      <div 
        style={{
          width: '12px',
          height: '12px',
          borderRadius: '50%',
          backgroundColor: status.color_hex
        }}
      />
      <span>{status.label}</span>
    </div>
  );
}
```

### 4. Gantt Chart Phase Colors

```typescript
function GanttChart({ timelines }: { timelines: Timeline[] }) {
  const { data: phases } = useQuery({
    queryKey: ['ref_phase'],
    queryFn: async () => {
      const { data } = await supabase
        .from('ref_phase')
        .select('*')
        .eq('is_active', true);
      return data;
    }
  });

  const phaseColorMap = useMemo(() => {
    return phases?.reduce((acc, phase) => {
      acc[phase.code] = phase.color_hex || '#CCCCCC';
      return acc;
    }, {} as Record<string, string>);
  }, [phases]);

  return (
    <GanttComponent
      tasks={timelines.map(t => ({
        ...t,
        backgroundColor: phaseColorMap?.[t.phase] || '#CCCCCC'
      }))}
    />
  );
}
```

---

## Caching Strategy

### Client-Side Cache

Reference data rarely changes, so cache aggressively:

```typescript
// React Query with long stale time
const { data: statuses } = useQuery({
  queryKey: ['ref_timeline_status'],
  queryFn: fetchStatuses,
  staleTime: 1000 * 60 * 60 * 24, // 24 hours
  cacheTime: 1000 * 60 * 60 * 24 * 7 // 7 days
});

// Or use SWR
const { data: departments } = useSWR(
  'ref_department',
  fetchDepartments,
  { revalidateOnFocus: false }
);
```

### Preload on App Init

```typescript
// Load all reference data on app startup
async function preloadReferenceData() {
  const [
    statuses,
    phases,
    departments,
    offsetUnits,
    pageTypes
  ] = await Promise.all([
    supabase.from('ref_timeline_status').select('*').eq('is_active', true),
    supabase.from('ref_phase').select('*').eq('is_active', true),
    supabase.from('ref_department').select('*').eq('is_active', true),
    supabase.from('ref_offset_unit').select('*').eq('is_active', true),
    supabase.from('ref_page_type').select('*').eq('is_active', true)
  ]);

  // Store in React Query cache or global state
  queryClient.setQueryData(['ref_timeline_status'], statuses.data);
  queryClient.setQueryData(['ref_phase'], phases.data);
  // etc...
}
```

---

## Migration Path

### Current State (Enums)

Timeline tables currently use enums:
```typescript
interface Timeline {
  status: 'NOT_STARTED' | 'IN_PROGRESS' | 'COMPLETE'; // enum
  timeline_type: 'MASTER' | 'STYLE' | 'MATERIAL'; // enum
}
```

### Future State (Reference Tables)

**Option 1: Keep enums, use refs for UI only**
- No schema changes needed
- Reference tables provide UI metadata (labels, colors)
- Code continues to use enum values

**Option 2: Migrate to FK relationships**
```sql
-- Future migration (not included)
ALTER TABLE tracking.tracking_plan_style_timeline
  ADD CONSTRAINT fk_status 
  FOREIGN KEY (status) 
  REFERENCES ref.ref_timeline_status(code);
```

**Recommendation**: Start with Option 1. Reference tables are immediately useful for UI without requiring schema changes. Migrate to FKs later if needed.

---

## REST API Endpoints

All reference tables are accessible via Supabase REST API:

```bash
# Get all statuses
GET https://[project].supabase.co/rest/v1/ref_timeline_status?is_active=eq.true&order=display_order

# Get specific phase
GET https://[project].supabase.co/rest/v1/ref_phase?code=eq.DESIGN

# Get all departments ordered
GET https://[project].supabase.co/rest/v1/ref_department?is_active=eq.true&order=display_order
```

**PowerShell Example**:
```powershell
$headers = @{
  'apikey' = 'your-anon-key'
  'Authorization' = 'Bearer your-anon-key'
}

Invoke-RestMethod `
  -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/ref_timeline_status?select=*&is_active=eq.true" `
  -Headers $headers
```

---

## Security & Permissions

### Row Level Security

All reference tables have RLS enabled with read-only policies:

```sql
-- All authenticated users can read
CREATE POLICY "Allow read access to all users" 
ON ref.ref_timeline_status 
FOR SELECT 
USING (true);
```

### Updating Reference Data

**Admin-only**: Updates to reference data should be controlled:

```sql
-- Future: Add admin-only UPDATE policies
CREATE POLICY "Allow admin updates" 
ON ref.ref_timeline_status 
FOR UPDATE 
USING (auth.jwt() ->> 'role' = 'admin');
```

**For now**: Updates via migrations or direct SQL (service role)

---

## Testing

### Verify Data Loaded

```sql
-- Check row counts
SELECT 
  'ref_timeline_status' as table_name, 
  COUNT(*) as row_count 
FROM ref.ref_timeline_status
UNION ALL 
SELECT 'ref_phase', COUNT(*) FROM ref.ref_phase
UNION ALL 
SELECT 'ref_department', COUNT(*) FROM ref.ref_department;

-- Expected:
-- ref_timeline_status: 6
-- ref_phase: 6
-- ref_department: 10
```

### Integration Tests

```typescript
describe('Reference Data', () => {
  it('should fetch all active statuses', async () => {
    const { data, error } = await supabase
      .from('ref_timeline_status')
      .select('*')
      .eq('is_active', true);
    
    expect(error).toBeNull();
    expect(data).toHaveLength(6);
    expect(data[0]).toHaveProperty('code');
    expect(data[0]).toHaveProperty('label');
    expect(data[0]).toHaveProperty('color_hex');
  });

  it('should return phases in display order', async () => {
    const { data } = await supabase
      .from('ref_phase')
      .select('code, display_order')
      .eq('is_active', true)
      .order('display_order');
    
    expect(data[0].code).toBe('PLAN'); // display_order = 1
    expect(data[1].code).toBe('DESIGN'); // display_order = 2
  });
});
```

---

## Summary

### ✅ What Was Created

- **1 new schema**: `ref`
- **9 reference tables**: All with `ref_` prefix
- **39 total rows**: Seeded with data from existing usage
- **9 indexes**: For active records
- **18 RLS policies**: Read-only access for all users

### 🎯 Benefits for Frontend

1. **Rich UI Metadata**: Colors, labels, descriptions for all dropdowns/badges
2. **Consistent Ordering**: `display_order` ensures consistent UX
3. **Soft Deletes**: `is_active` flag allows deprecation without breaking data
4. **Type Safety**: TypeScript types for all codes
5. **No Enum Limits**: Can add new values without migrations
6. **Flexible Updates**: Change labels/colors without code deploys

### 📊 Usage Patterns

**Dropdowns**: Use `label` for display, `code` for value
**Badges**: Use `label` + `color_hex` for styling
**Filters**: Query by `code`, display by `label`
**Gantt Charts**: Use `phase.color_hex` for section colors
**Status Indicators**: Use `status.color_hex` + `status.label`

### 🚀 Next Steps

1. **Immediate**: Start using reference tables for UI rendering
2. **Soon**: Add reference data fetching to app initialization
3. **Later**: Consider migrating from enums to FK constraints (optional)
4. **Future**: Add admin UI for managing reference data

---

## Support

**Migration File**: `supabase-tracking/migrations/create_reference_schema_and_tables.sql`  
**Schema Docs**: All tables have inline comments  
**Type Generation**: Run `supabase gen types typescript --schema ref`  

**Questions?** Check existing data:
```sql
SELECT * FROM ref.ref_timeline_status ORDER BY display_order;
SELECT * FROM ref.ref_phase ORDER BY display_order;
SELECT * FROM ref.ref_department ORDER BY display_order;
```
