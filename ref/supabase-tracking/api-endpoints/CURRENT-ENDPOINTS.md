# 🎯 Supabase Tracking API - Current Endpoints Reference

**Last Updated:** 2025-10-24  
**Status:** All endpoints operational  
**Base URL:** `https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1`

---

## 📋 Available Endpoints (9 total)

### ✅ Phase 1 - Folders & Plans (3 endpoints)
1. `/v_folder` - List tracking folders
2. `/v_folder_plan` - List plans with metadata
3. `/v_folder_plan_columns` - Column configurations per view

### ✅ Migration 0011 - Templates (2 endpoints)
4. `/v_timeline_template` - List timeline templates
5. `/v_timeline_template_item` - List template items/milestones

### ✅ Migration 0015 - Styles & Materials (4 endpoints)
6. `/v_plan_styles` - Styles in plans with milestone summaries
7. `/v_plan_style_timelines_enriched` - Detailed style timelines
8. `/v_plan_materials` - Materials in plans with milestone summaries
9. `/v_plan_material_timelines_enriched` - Detailed material timelines

---

## 🔐 Authentication

All requests require these headers:

```javascript
const headers = {
  'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU',
  'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU'
};
```

---

## 📖 Endpoint Details

### 1. Folder List
**GET** `/rest/v1/v_folder`

**Purpose:** Browse tracking folders by brand

**Query Parameters:**
- `brand=eq.GREYSON` - Filter by brand
- `order=folder_name.asc` - Sort by name

**Response Fields:**
```typescript
{
  folder_id: string;           // UUID
  folder_name: string;         // e.g., "GREYSON MENS"
  brand: string;               // e.g., "GREYSON"
  active_plan_count: number;   // Count of active plans
  total_plan_count: number;    // Total plans (active + inactive)
}
```

**Example:**
```bash
curl "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_folder" \
  -H "apikey: YOUR_KEY"
```

---

### 2. Plan Overview
**GET** `/rest/v1/v_folder_plan`

**Purpose:** View plans within folders with counts and template info

**Query Parameters:**
- `folder_id=eq.{uuid}` - Filter by folder
- `plan_season=eq.2026 Spring` - Filter by season
- `order=plan_name.asc` - Sort

**Response Fields:**
```typescript
{
  folder_id: string;
  folder_name: string;
  plan_id: string;
  plan_name: string;          // e.g., "GREYSON 2026 SPRING DROP 3"
  plan_season: string;        // e.g., "2026 Spring"
  plan_brand: string;
  start_date: string;         // ISO date
  end_date: string;           // ISO date
  template_id: string | null;
  template_name: string | null;
  style_count: number;        // Styles in this plan
  material_count: number;     // Materials in this plan
}
```

**Example:**
```bash
curl "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_folder_plan?folder_id=eq.82a698e1-9103-4bab-98af-a0ec423332a2" \
  -H "apikey: YOUR_KEY"
```

---

### 3. Plan View Columns
**GET** `/rest/v1/v_folder_plan_columns`

**Purpose:** Get column configurations for style/material grid views

**Query Parameters:**
- `plan_id=eq.{uuid}` - Filter by plan
- `view_id=eq.{uuid}` - Filter by specific view

**Response Fields:**
```typescript
{
  plan_id: string;
  view_id: string;
  view_name: string;
  view_type: 'STYLE' | 'MATERIAL';
  column_config: Array<{
    field_key: string;
    label: string;
    visible: boolean;
    pinned: boolean;
    width_px: number;
    sort_order: number;
    data_type: string;
  }>;
}
```

---

### 4. Timeline Templates
**GET** `/rest/v1/v_timeline_template`

**Purpose:** Browse timeline templates by brand/season

**Query Parameters:**
- `brand=eq.GREYSON`
- `is_active=eq.true`
- `order=brand.asc,season.asc`

**Response Fields:**
```typescript
{
  template_id: string;
  template_name: string;      // e.g., "Garment Tracking Timeline"
  brand: string | null;
  season: string | null;
  version: number;
  is_active: boolean;
  total_item_count: number;   // Total milestones
  style_item_count: number;   // Style-specific milestones
  material_item_count: number;// Material-specific milestones
  milestone_count: number;    // Task + Anchor nodes
  phase_count: number;        // Unique phases
  active_plan_count: number;  // Plans using this template
}
```

**Example:**
```bash
curl "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_timeline_template?is_active=eq.true" \
  -H "apikey: YOUR_KEY"
```

---

### 5. Template Items
**GET** `/rest/v1/v_timeline_template_item`

**Purpose:** View template milestone structure with dependencies

**Query Parameters:**
- `template_id=eq.{uuid}` - Filter by template
- `applies_to_style=eq.true` - Filter by applicability
- `order=display_order.asc` - Sort by order

**Response Fields:**
```typescript
{
  template_id: string;
  template_name: string;
  item_id: string;
  node_type: 'TASK' | 'ANCHOR';
  item_name: string;          // e.g., "PROTO PRODUCTION"
  short_name: string;         // e.g., "PROTO PRODUCTION"
  phase: string;              // e.g., "DEVELOPMENT"
  department: string;         // e.g., "PD"
  display_order: number;
  depends_on_template_item_id: string | null;
  depends_on_item_name: string | null;
  offset_relation: 'AFTER' | 'BEFORE' | null;
  offset_value: number | null;
  offset_unit: 'DAYS' | 'BUSINESS_DAYS' | null;
  applies_to_style: boolean;
  applies_to_material: boolean;
  required: boolean;
  page_type: string | null;
  page_label: string | null;
  visibility_config: Array<{
    view_type: 'STYLE' | 'MATERIAL';
    is_visible: boolean;
  }>;
}
```

**Example:**
```bash
curl "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_timeline_template_item?template_id=eq.{uuid}&order=display_order.asc" \
  -H "apikey: YOUR_KEY"
```

---

### 6. Plan Styles (Summary)
**GET** `/rest/v1/v_plan_styles`

**Purpose:** Get styles in a plan with milestone aggregates

**Query Parameters:**
- `plan_id=eq.{uuid}` - Filter by plan
- `style_number=eq.MSP26B26` - Filter by style number
- `order=style_number.asc`

**Response Fields:**
```typescript
{
  plan_style_id: string;
  plan_id: string;
  plan_name: string;
  plan_season: string;
  plan_brand: string;
  folder_id: string;
  folder_name: string;
  view_id: string | null;
  view_type: 'STYLE' | 'MATERIAL' | null;
  style_id: string;
  style_header_id: string;
  color_id: string;
  style_number: string;       // e.g., "MSP26B26"
  style_name: string;         // e.g., "MONTAUK SHORT - 8\" INSEAM"
  color_name: string;         // e.g., "220 - GROVE"
  style_season: string;
  delivery: string;           // e.g., "February"
  factory: string;            // e.g., "NAGACO"
  supplier_id: string;
  supplier_name: string;
  status_summary: object;
  suppliers: array;           // Supplier access config
  milestones_total: number;   // Total milestones (typically 27)
  milestones_completed: number;
  milestones_in_progress: number;
  milestones_not_started: number;
  milestones_blocked: number;
  milestones_late: number;
  earliest_due_date: string;  // ISO date
  latest_due_date: string;    // ISO date
  last_milestone_updated_at: string;
  status_breakdown: {         // Count by status
    NOT_STARTED?: number;
    IN_PROGRESS?: number;
    APPROVED?: number;
    COMPLETE?: number;
    BLOCKED?: number;
    REJECTED?: number;
  };
  created_at: string;
  updated_at: string;
}
```

**Example:**
```bash
curl "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_plan_styles?plan_id=eq.1305c5e9-39d5-4686-926c-c88c620d4f8a" \
  -H "apikey: YOUR_KEY"
```

---

### 7. Plan Style Timelines (Enriched)
**GET** `/rest/v1/v_plan_style_timelines_enriched`

**Purpose:** Get detailed timeline for each style with all milestone data

**Query Parameters:**
- `plan_style_id=eq.{uuid}` - Filter by specific style
- `style_number=eq.MSP26B26` - Filter by style number
- `milestone_name=ilike.%PROTO%` - Search milestone names
- `order=display_order.asc`

**Response Fields:**
```typescript
{
  timeline_id: string;
  plan_style_id: string;
  plan_id: string;
  plan_name: string;
  folder_id: string;
  folder_name: string;
  view_id: string;
  view_type: 'STYLE' | 'MATERIAL';
  style_number: string;
  style_name: string;
  color_name: string;
  supplier_name: string;
  factory: string;
  template_item_id: string;
  milestone_name: string;     // e.g., "PROTO PRODUCTION"
  short_name: string;
  node_type: 'TASK' | 'ANCHOR';
  phase: string;              // e.g., "DEVELOPMENT"
  department: string;         // e.g., "PD"
  display_order: number;
  timeline_type: 'STYLE' | 'MATERIAL' | 'MASTER';
  applies_to_style: boolean;
  required: boolean;
  supplier_visible: boolean;
  depends_on_template_item_id: string | null;
  depends_on_milestone_name: string | null;
  depends_on_node_type: string | null;
  status: 'NOT_STARTED' | 'IN_PROGRESS' | 'APPROVED' | 'REJECTED' | 'COMPLETE' | 'BLOCKED';
  plan_date: string | null;   // ISO date (baseline)
  rev_date: string | null;    // ISO date (revised)
  final_date: string | null;  // ISO date (final)
  due_date: string | null;    // ISO date (forecast)
  completed_date: string | null;
  late: boolean;
  is_completed: boolean;
  is_overdue: boolean;
  notes: string | null;
  page_id: string | null;
  page_type: string | null;
  page_name: string | null;
  request_id: string | null;
  request_code: string | null;
  request_status: string | null;
  shared_with: array;         // Company IDs with access
  assignments: array;         // User assignments
  recent_status_history: array; // Last 10 status changes
  predecessors: array;        // Dependency info
  created_at: string;
  updated_at: string;
}
```

**Example:**
```bash
curl "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_plan_style_timelines_enriched?style_number=eq.MSP26B26&order=display_order.asc" \
  -H "apikey: YOUR_KEY"
```

---

### 8. Plan Materials (Summary)
**GET** `/rest/v1/v_plan_materials`

**Purpose:** Get materials in a plan with milestone aggregates

**Query Parameters:**
- `plan_id=eq.{uuid}`
- `material_number=eq.{material_number}`
- `order=material_number.asc`

**Response Fields:**
```typescript
{
  plan_material_id: string;
  plan_id: string;
  plan_name: string;
  plan_season: string;
  plan_brand: string;
  folder_id: string;
  folder_name: string;
  view_id: string | null;
  view_type: 'STYLE' | 'MATERIAL' | null;
  material_id: string;
  material_header_id: string;
  color_id: string;
  material_number: string;
  material_name: string;
  color_name: string;
  supplier_id: string;
  supplier_name: string;
  bom_item_id: string;
  style_links: object;
  bom_references: array;
  suppliers: array;
  milestones_total: number;
  milestones_completed: number;
  milestones_in_progress: number;
  milestones_not_started: number;
  milestones_blocked: number;
  milestones_late: number;
  earliest_due_date: string;
  latest_due_date: string;
  last_milestone_updated_at: string;
  status_breakdown: object;
  created_at: string;
  updated_at: string;
}
```

---

### 9. Plan Material Timelines (Enriched)
**GET** `/rest/v1/v_plan_material_timelines_enriched`

**Purpose:** Get detailed timeline for each material (similar to style timelines)

**Query Parameters:**
- `plan_material_id=eq.{uuid}`
- `material_number=eq.{material_number}`
- `order=display_order.asc`

**Response Fields:** Same structure as style timelines enriched (see #7)

---

## 📊 Current Data Status

| View | Records | Status |
|------|---------|--------|
| `v_folder` | 1 | ✅ GREYSON MENS |
| `v_folder_plan` | 3 | ✅ Spring Drop 1, 2, 3 |
| `v_folder_plan_columns` | 0 | ⏳ No views configured |
| `v_timeline_template` | 1 | ✅ Garment Tracking Timeline |
| `v_timeline_template_item` | 27 | ✅ Full milestone set |
| `v_plan_styles` | 4 | ✅ Including 3 MSP26B26 colorways |
| `v_plan_style_timelines_enriched` | 108 | ✅ 27 milestones × 4 styles |
| `v_plan_materials` | 0 | ⏳ No materials yet |
| `v_plan_material_timelines_enriched` | 0 | ⏳ No materials yet |

---

## 🔍 PostgREST Query Features

All endpoints support PostgREST operators:

### Filtering
```bash
# Exact match
?style_number=eq.MSP26B26

# Pattern matching
?milestone_name=ilike.%proto%

# Multiple conditions
?plan_id=eq.{uuid}&status=eq.NOT_STARTED

# In list
?status=in.(NOT_STARTED,IN_PROGRESS)
```

### Sorting
```bash
# Ascending
?order=display_order.asc

# Descending
?order=updated_at.desc

# Multiple columns
?order=style_number.asc,color_name.asc
```

### Limiting & Pagination
```bash
# First 10 records
?limit=10

# Skip first 10, get next 10
?limit=10&offset=10
```

### Selecting Columns
```bash
# Only specific fields
?select=style_number,color_name,milestones_total

# Rename fields
?select=style:style_number,color:color_name
```

---

## 🚀 Quick Start Examples

### JavaScript/TypeScript
```typescript
const SUPABASE_URL = 'https://wjpbryjgtmmaqjbhjgap.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

async function getPlans() {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/v_folder_plan`, {
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`
    }
  });
  return response.json();
}

async function getStyleTimeline(styleNumber: string) {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/v_plan_style_timelines_enriched?style_number=eq.${styleNumber}&order=display_order.asc`,
    {
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`
      }
    }
  );
  return response.json();
}
```

### PowerShell
```powershell
$headers = @{
    'apikey' = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    'Authorization' = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
}

# Get all plans
$plans = Invoke-RestMethod -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_folder_plan" -Headers $headers

# Get styles for specific plan
$styles = Invoke-RestMethod -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_plan_styles?plan_id=eq.1305c5e9-39d5-4686-926c-c88c620d4f8a" -Headers $headers

# Get timeline for specific style
$timeline = Invoke-RestMethod -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_plan_style_timelines_enriched?style_number=eq.MSP26B26&color_name=eq.220 - GROVE&order=display_order.asc" -Headers $headers
```

---

## 📝 Notes

### Read-Only Access
All endpoints are **GET only** in current implementation. Write operations (POST/PATCH/DELETE) will require:
- Direct table access with RLS policies, OR
- Edge Functions for business logic

### Date Calculation
- Timeline dates are auto-calculated when styles are added to plans (Migration 0016)
- Based on plan `start_date` and `end_date` anchors
- Uses dependency chain from template

### Supplier Visibility
- `suppliers` array on plan/style/material for access control (Gate 1 & 2)
- `shared_with` array on timelines for milestone-level sharing (Gate 3)
- `supplier_visible` flag on template items for default visibility

---

## 🔗 Related Documentation

- **Frontend Integration:** `handoff/FRONTEND-HANDOFF.md`
- **Template Guide:** `templates/timeline-template-migration-guide.md`
- **Migration History:** `MIGRATION-STATUS.md`
- **Schema Reference:** `docs/02-supabase-schema-blueprint.md`

---

**Last Verified:** 2025-10-24  
**All Endpoints Tested:** ✅ Operational  
**Ready for Production:** ✅ Yes
