---
name: 02a-Tracking API Documentation for Frontend
about: Create comprehensive API documentation for frontend migration
title: '[02a-Tracking] Document Supabase tracking APIs for frontend migration'
labels: ['phase-02a-tracking', 'documentation', 'frontend']
assignees: ''
---

## Context
Frontend developers need comprehensive API documentation to migrate from BeProduct APIs to Supabase APIs.

**Priority:** 🔴 HIGH - Blocks frontend development

## Required Documentation

### 1. API Reference Document

**File:** `docs/supabase/supabase-beproduct-migration/02a-tracking/API-REFERENCE.md`

**Required Sections:**
1. **Overview**
   - Purpose and scope
   - Base URL(s)
   - Authentication methods
   - Versioning strategy

2. **Authentication**
   - API key setup
   - JWT authentication
   - Service role vs anon key usage
   - Example headers

3. **PostgREST Endpoints**
   - All tracking tables exposed via REST
   - Query syntax (filtering, sorting, pagination)
   - Relationship expansion (foreign keys)
   - Response format

4. **Edge Function Endpoints**
   - Plan progress endpoint
   - Folder progress endpoint
   - User workload endpoint
   - Bulk update endpoint

5. **Query Examples**
   - Common use cases
   - Complex filters
   - Joins and relationships
   - Performance tips

6. **Error Handling**
   - Error codes and meanings
   - Retry strategies
   - Rate limiting (if applicable)

7. **Performance**
   - Pagination best practices
   - Caching recommendations
   - Query optimization tips

**Template Outline:**
```markdown
# Supabase Tracking API Reference

## Base URL
https://[project-id].supabase.co

## Authentication

### Headers Required
- apikey: [anon-key] (for public access)
- Authorization: Bearer [anon-key or service-key]

### Example
```javascript
const headers = {
  'apikey': 'your-anon-key',
  'Authorization': 'Bearer your-anon-key'
};
```

## PostgREST Endpoints

### Tracking Folders
**GET** `/rest/v1/tracking_folder`

Returns all tracking folders.

**Query Parameters:**
- `select`: Columns to return (default: `*`)
- `brand=eq.GREYSON`: Filter by brand
- `order=name.asc`: Sort results
- `limit=10`: Limit results

**Example:**
```bash
curl "https://[project-id].supabase.co/rest/v1/tracking_folder?brand=eq.GREYSON" \
  -H "apikey: [key]" \
  -H "Authorization: Bearer [key]"
```

**Response:**
```json
[
  {
    "id": "folder-uuid",
    "name": "GREYSON MENS",
    "brand": "GREYSON",
    "active": true,
    "created_at": "2025-01-01T00:00:00Z"
  }
]
```

[Continue for all tables...]

## Edge Function Endpoints

### Plan Progress
**GET** `/functions/v1/tracking-plan-progress?plan_id={uuid}`

[Details...]

[Continue for all functions...]

## Common Use Cases

### Get all late milestones in a plan
```bash
curl "https://[project-id].supabase.co/rest/v1/tracking_plan_style_timeline?plan_style_id->plan_id=eq.{uuid}&late=eq.true&order=due_date.asc" \
  -H "apikey: [key]"
```

[Continue with more examples...]
```

---

### 2. Migration Guide

**File:** `docs/supabase/supabase-beproduct-migration/02a-tracking/BEPRODUCT-TO-SUPABASE-MIGRATION.md`

**Required Sections:**
1. **Overview**
   - Why migrate?
   - Timeline
   - Support during transition

2. **API Comparison**
   - Side-by-side comparison table
   - Feature parity
   - New capabilities

3. **Code Examples (Before/After)**
   - At least 10 common operations
   - JavaScript/TypeScript examples
   - Error handling changes

4. **Breaking Changes**
   - Field name changes
   - Response structure differences
   - Required code changes

5. **Migration Checklist**
   - Step-by-step process
   - Testing recommendations
   - Rollback plan

**Example Mapping Table:**

| Feature | BeProduct API | Supabase API | Notes |
|---------|--------------|--------------|-------|
| **Get folders** | `GET /api/{co}/Tracking/Folders` | `GET /rest/v1/tracking_folder` | Same response structure |
| **Get plan** | `GET /api/{co}/Tracking/Plan/{id}` | `GET /rest/v1/tracking_plan?id=eq.{uuid}` | Use PostgREST query syntax |
| **Get styles in plan** | `planStyleTimeline` (MCP operation) | `GET /rest/v1/v_plan_styles?plan_id=eq.{uuid}` | Paginate with `limit` and `offset` |
| **Update milestone** | `PATCH /tracking/milestone/{id}` | `PATCH /rest/v1/tracking_plan_style_timeline?id=eq.{uuid}` | Direct table access |
| **Bulk update** | Not available | `POST /functions/v1/tracking-bulk-update` | **New capability** |
| **Plan progress** | `planStyleProgress` (MCP) | `GET /functions/v1/tracking-plan-progress?plan_id={uuid}` | Enhanced aggregations |

**Example Code Migration:**

**Before (BeProduct):**
```typescript
// BeProduct API
const response = await fetch(
  'https://developers.beproduct.com/api/activeapparelgroup/Tracking/Plan/162eedf3-0230-4e4c-88e1-6db332e3707b',
  {
    headers: {
      'Authorization': `Bearer ${beproductToken}`
    }
  }
);
const plan = await response.json();
```

**After (Supabase):**
```typescript
// Supabase API
const response = await fetch(
  'https://[project-id].supabase.co/rest/v1/tracking_plan?id=eq.162eedf3-0230-4e4c-88e1-6db332e3707b',
  {
    headers: {
      'apikey': supabaseAnonKey,
      'Authorization': `Bearer ${supabaseAnonKey}`
    }
  }
);
const plans = await response.json(); // Note: returns array
const plan = plans[0];
```

---

### 3. TypeScript Type Definitions

**File:** `docs/supabase/supabase-beproduct-migration/02a-tracking/typescript-types.ts`

**Contents:**
```typescript
// Database Types
export interface TrackingFolder {
  id: string;
  name: string;
  brand: string;
  active: boolean;
  created_at: string;
  updated_at: string;
  created_by?: string;
  updated_by?: string;
}

export interface TrackingPlan {
  id: string;
  folder_id: string;
  name: string;
  season: string;
  brand: string;
  start_date: string | null;
  end_date: string | null;
  active: boolean;
  created_at: string;
  updated_at: string;
}

export interface TrackingPlanStyle {
  id: string;
  plan_id: string;
  style_header_id: string;
  color_id: string;
  style_number: string;
  style_name: string;
  color_name: string;
  supplier_id: string | null;
  supplier_name: string | null;
  active: boolean;
  created_at: string;
  updated_at: string;
}

export enum TimelineStatus {
  NOT_STARTED = 'NOT_STARTED',
  IN_PROGRESS = 'IN_PROGRESS',
  WAITING_ON = 'WAITING_ON',
  REJECTED = 'REJECTED',
  APPROVED = 'APPROVED',
  APPROVED_WITH_CORRECTIONS = 'APPROVED_WITH_CORRECTIONS',
  NA = 'NA'
}

export interface TrackingPlanStyleTimeline {
  id: string;
  plan_style_id: string;
  milestone_id: string;
  milestone_name: string;
  phase: string;
  department: string;
  status: TimelineStatus;
  plan_date: string | null;
  rev_date: string | null;
  due_date: string | null;
  final_date: string | null;
  late: boolean;
  display_order: number;
  customer_visible: boolean;
  supplier_visible: boolean;
  created_at: string;
  updated_at: string;
}

// API Response Types
export interface PlanProgressResponse {
  plan_id: string;
  plan_name: string;
  folder_id: string;
  folder_name: string;
  total_milestones: number;
  by_status: Record<TimelineStatus, number>;
  late_count: number;
  on_time_count: number;
  completion_percentage: number;
  by_phase: Record<string, {
    total: number;
    late: number;
    completed: number;
  }>;
}

export interface BulkUpdateRequest {
  updates: Array<{
    timeline_id: string;
    status?: TimelineStatus;
    rev_date?: string;
    final_date?: string;
    due_date?: string;
    notes?: string;
  }>;
  updated_by: string;
  bulk_action_note?: string;
}

export interface BulkUpdateResponse {
  success: boolean;
  updated_count: number;
  failed_count: number;
  errors: Array<{
    timeline_id: string;
    error: string;
  }>;
  updates: Array<{
    timeline_id: string;
    old_status: TimelineStatus;
    new_status: TimelineStatus;
    success: boolean;
    error?: string;
  }>;
}

// Supabase Client Configuration
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://[project-id].supabase.co';
const supabaseAnonKey = '[anon-key]';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Example usage
export async function getTrackingFolders(): Promise<TrackingFolder[]> {
  const { data, error } = await supabase
    .from('tracking_folder')
    .select('*')
    .eq('active', true)
    .order('name', { ascending: true });
  
  if (error) throw error;
  return data;
}

export async function getPlanProgress(planId: string): Promise<PlanProgressResponse> {
  const response = await fetch(
    `${supabaseUrl}/functions/v1/tracking-plan-progress?plan_id=${planId}`,
    {
      headers: {
        'Authorization': `Bearer ${supabaseAnonKey}`
      }
    }
  );
  
  if (!response.ok) {
    throw new Error(`Failed to fetch plan progress: ${response.statusText}`);
  }
  
  return response.json();
}
```

---

### 4. Postman Collection

**File:** `docs/supabase/supabase-beproduct-migration/02a-tracking/Supabase-Tracking-API.postman_collection.json`

**Required Requests:**
1. **Folders**
   - Get all folders
   - Get folder by ID
   - Create folder (if enabled)

2. **Plans**
   - Get plans in folder
   - Get plan by ID
   - Get plan progress (edge function)

3. **Styles**
   - Get styles in plan
   - Get style timelines (enriched view)
   - Get single style detail

4. **Timelines**
   - Get late milestones
   - Get milestones by status
   - Update milestone (single)
   - Bulk update milestones (edge function)

5. **Filters & Sorting**
   - Filter by brand
   - Filter by date range
   - Sort by multiple columns
   - Pagination example

**Environment Variables:**
```json
{
  "SUPABASE_URL": "https://[project-id].supabase.co",
  "SUPABASE_ANON_KEY": "[anon-key]",
  "SUPABASE_SERVICE_KEY": "[service-key]",
  "SAMPLE_FOLDER_ID": "82a698e1-9103-4bab-98af-a0ec423332a2",
  "SAMPLE_PLAN_ID": "162eedf3-0230-4e4c-88e1-6db332e3707b"
}
```

---

## Acceptance Criteria

### API Reference
- [ ] All PostgREST endpoints documented
- [ ] All edge function endpoints documented
- [ ] At least 20 query examples
- [ ] Error handling documented
- [ ] Performance tips included
- [ ] Frontend team reviews and approves

### Migration Guide
- [ ] API comparison table complete (20+ operations)
- [ ] 10+ before/after code examples
- [ ] Breaking changes identified
- [ ] Migration checklist provided
- [ ] Frontend team reviews and approves

### TypeScript Types
- [ ] All database table interfaces defined
- [ ] All API response types defined
- [ ] Enums for status values
- [ ] Example client code included
- [ ] Types tested with actual API

### Postman Collection
- [ ] All endpoints have example requests
- [ ] Environment variables configured
- [ ] Tests included for each request
- [ ] Collection tested and working
- [ ] Exported and committed to repo

## Deliverables

1. ✅ `API-REFERENCE.md` - Comprehensive endpoint documentation
2. ✅ `BEPRODUCT-TO-SUPABASE-MIGRATION.md` - Migration guide with examples
3. ✅ `typescript-types.ts` - Type definitions for TypeScript projects
4. ✅ `Supabase-Tracking-API.postman_collection.json` - Postman collection

## Testing

- [ ] All code examples tested and working
- [ ] All API endpoints verified
- [ ] All TypeScript types validated
- [ ] Postman collection tested end-to-end
- [ ] Frontend team successfully uses documentation

## Dependencies
- **Depends on:** #[enable CRUD issue] - Need endpoints operational
- **Depends on:** #[progress endpoints issue] - Need edge functions deployed
- **Depends on:** #[bulk update issue] - Need bulk update endpoint
- **Blocks:** Frontend migration work

## Success Metrics
- ✅ Frontend team can find any API in < 1 minute
- ✅ Code examples are copy-paste ready
- ✅ Zero API questions during migration (docs answer everything)
- ✅ Migration guide reduces migration time by 50%

## Timeline
- **Day 1:** API Reference draft
- **Day 2:** Migration guide draft
- **Day 3:** TypeScript types + Postman collection
- **Day 4:** Frontend team review and feedback
- **Day 5:** Final revisions and approval

**Total:** 5 days

## Related Documentation
- [Endpoint Design](../docs/supabase/supabase-beproduct-migration/02-timeline/docs/endpoint-design.md)
- [Current Endpoints](../../../ref/supabase-tracking/api-endpoints/CURRENT-ENDPOINTS.md)
- [BeProduct API Mapping](../02-timeline/docs/beproduct-api-mapping.md)
