# Phase 1: Folders & Plans UI

**Status:** ✅ READY FOR DEVELOPMENT  
**Deployment Date:** 2025-10-23  
**Backend Migrations:** 0007, 0008, 0011, 0012, 0013, 0014  
**Target:** Folder list + Plan overview + Template management (READ-ONLY)

---

## ⚠️ IMPORTANT: Phase 1 is READ-ONLY

**NO POST/PATCH/DELETE endpoints available in Phase 1.**

All data displayed is read-only. Template and plan editing will come in a future phase.

---

## 🎯 Objectives

## 📊 Data Layer

| Endpoint | Purpose | Response Type | Status |
|----------|---------|---------------|--------|
| `GET /rest/v1/v_folder` | Folder list with plan counts | `FolderView[]` | ✅ Ready |
| `GET /rest/v1/v_folder_plan` | Plan details within folders | `FolderPlanView[]` | ✅ Ready |
| `GET /rest/v1/v_folder_plan_columns` | Column configuration (future) | `FolderPlanColumns[]` | ✅ Ready |
| `GET /rest/v1/v_timeline_template` | Timeline template list with counts | `TimelineTemplateView[]` | ✅ Ready |
| `GET /rest/v1/v_timeline_template_item` | Template items with dependencies | `TimelineTemplateItemView[]` | ✅ Ready |

### Connection Details

**Production Base URL:** `https://wjpbryjgtmmaqjbhjgap.supabase.co`

**Authentication:**
```typescript
const headers = {
  'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU',
  'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU'
};
```

### Template Data Available

**1 Template Loaded:** "Garment Tracking Timeline"
- Brand: Default
- Season: 2026 Spring
- Version: 1
- **27 timeline items** (2 ANCHOR + 25 TASK nodes)
- **25 dependencies** properly linked by UUID
- **5 phases:** PLAN, DEVELOPMENT, SMS, ALLOCATION, PRODUCTION

**Test Plan with Template:**
- Plan: "GREYSON 2026 SPRING DROP 3" (ID: `1305c5e9-39d5-4686-926c-c88c620d4f8a`)
- Template assigned: ✅ Garment Tracking Timeline
- Dates: 2025-11-01 to 2026-03-15
- Test style: "TEST-001" with full timeline instantiated (27 milestones with calculated dates)ase URL:** `https://wjpbryjgtmmaqjbhjgap.supabase.co`

**Authentication:**
```typescript
const headers = {
  'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU',
  'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9zZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU'
};
```

---

## 🔨 Implementation Tasks

### Task 1: Folder List Screen

**API Endpoint:** `GET /rest/v1/v_folder`

**TypeScript Interface:**
```typescript
interface FolderView {
  folder_id: string;              // UUID
  folder_name: string;
  brand: string | null;
  style_folder_id: string | null;
  style_folder_name: string | null;
  active: boolean;
  created_at: string;
  updated_at: string;
  active_plan_count: number;
  total_plan_count: number;
  latest_plan_date: string | null;
  active_seasons: string | null;  // Comma-separated
}
```

**Example Request:**
```typescript
const response = await fetch(
  'https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_folder?order=folder_name.asc',
  { headers }
);
const folders: FolderView[] = await response.json();
```

**Example Response:**
```json
[
  {
    "folder_id": "82a698e1-9103-4bab-98af-a0ec423332a2",
    "folder_name": "GREYSON MENS",
    "brand": "GREYSON",
    "active_plan_count": 3,
    "total_plan_count": 3,
    "latest_plan_date": "2025-05-01",
    "active_seasons": "2026 Spring"
  }
]
```

**UI Requirements:**
- [ ] Grid/list view of folders
- [ ] Display folder name, brand, plan count
- [ ] Show active seasons badge
- [ ] Click to navigate to plan overview
- [ ] Filter by brand (optional)
- [ ] Sort by name, plan count, or latest date

**Acceptance Criteria:**
- Shows GREYSON MENS folder with "3 plans" badge
- Clicking folder navigates to plan overview
- Empty state message when no folders exist

---

### Task 2: Plan Overview Screen

**API Endpoint:** `GET /rest/v1/v_folder_plan?folder_id=eq.{uuid}`

**TypeScript Interface:**
```typescript
interface FolderPlanView {
  // Folder metadata
  folder_id: string;
  folder_name: string;
  brand: string | null;
  
  // Plan details
  plan_id: string;
  plan_name: string;
  plan_season: string | null;
  start_date: string | null;
  end_date: string | null;
  plan_active: boolean;
  
  // Template & view references (may be null)
  template_id: string | null;
  template_name: string | null;
  default_view_id: string | null;
  default_view_name: string | null;
  
  // Counts
  style_count: number;
  material_count: number;
  style_milestone_count: number;
  material_milestone_count: number;
}
```

**Example Request:**
```typescript
const folderId = '82a698e1-9103-4bab-98af-a0ec423332a2';
const response = await fetch(
  `https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_folder_plan?folder_id=eq.${folderId}`,
  { headers }
);
const plans: FolderPlanView[] = await response.json();
```

**Example Response:**
```json
[
  {
    "folder_id": "82a698e1-9103-4bab-98af-a0ec423332a2",
    "folder_name": "GREYSON MENS",
    "brand": "GREYSON",
    "plan_id": "20fb4a1c-e6ea-46e8-b37b-40ca5e514ef3",
    "plan_name": "GREYSON 2026 SPRING DROP 1",
    "plan_season": "2026 Spring",
    "start_date": "2025-05-01",
    "end_date": "2026-01-05",
    "plan_active": true,
    "template_name": null,
    "default_view_name": null,
    "style_count": 0,
    "material_count": 0,
    "style_milestone_count": 0,
    "material_milestone_count": 0
  }
]
```

**UI Requirements:**
- [ ] Card/tile layout for plans within selected folder
- [ ] Display plan name, season, date range
- [ ] Show style count and material count badges
- [ ] Visual indicator when template_name is null (needs setup)
- [ ] Click plan to open detail drawer
- [ ] Filter by season (optional)
- [ ] Sort by start date (default)

**Acceptance Criteria:**
- Shows 3 GREYSON plans for GREYSON MENS folder
- Each plan displays dates and counts
- Clicking plan opens detail drawer
- Empty state when no plans in folder

---

### Task 3: Plan Detail Drawer

**Data Source:** Same as Task 2 (use selected plan from list)

**UI Requirements:**
- [ ] Drawer/modal component
- [ ] Display full plan metadata:
  - Plan name, season, brand
  - Date range (start → end)
  - Template name (or "No template assigned" message)
  - Default view name (or "Not configured")
  - Style/material counts
  - Milestone counts
- [ ] Action buttons:
  - [ ] "View Styles" (disabled if style_count = 0, ready for Phase 2)
  - [ ] "View Materials" (disabled if material_count = 0, ready for Phase 2)
  - [ ] "Close" button
**Acceptance Criteria:**
- Drawer opens when plan clicked
- All fields render correctly (handle nulls gracefully)
- Action buttons disabled appropriately
- Close button works

---

### Task 4: Template List Screen

**API Endpoint:** `GET /rest/v1/v_timeline_template`

**TypeScript Interface:**
```typescript
interface TimelineTemplateView {
  template_id: string;              // UUID
  template_name: string;
  brand: string | null;
  season: string | null;
  version: number;
  is_active: boolean;
  timezone: string | null;
  anchor_strategy: string | null;
  conflict_policy: string | null;
  business_days_calendar: object | null;
  created_at: string;
  created_by: string | null;
  updated_at: string;
  updated_by: string | null;
  total_item_count: number;
  style_item_count: number;
  material_item_count: number;
  milestone_count: number;
  phase_count: number;
  active_plan_count: number;
}
```

**Example Request:**
```typescript
const response = await fetch(
  'https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_timeline_template?is_active=eq.true&order=brand.asc,season.desc',
  { headers }
);
const templates: TimelineTemplateView[] = await response.json();
```

**Example Response:**
```json
[
  {
    "template_id": "550e8400-e29b-41d4-a716-446655440001",
    "template_name": "GREYSON 2026 Spring Standard",
    "brand": "GREYSON",
    "season": "2026 Spring",
    "version": 1,
    "is_active": true,
    "timezone": "America/Los_Angeles",
    "total_item_count": 12,
    "style_item_count": 8,
    "material_item_count": 6,
    "milestone_count": 10,
    "phase_count": 2,
    "active_plan_count": 3
  }
]
```

**UI Requirements:**
- [ ] Card/grid layout for templates
- [ ] Display template name, brand, season, version
- [ ] Show item counts (styles/materials/milestones)
- [ ] Badge for active_plan_count ("Used by 3 plans")
- [ ] Visual indicator for is_active status
- [ ] Click to view template details
- [ ] Filter by brand and season
**TypeScript Interface:**
```typescript
interface TimelineTemplateItemView {
  // Template info
  template_id: string;
  template_name: string;
  brand: string | null;
  season: string | null;
  version: number;
  template_active: boolean;
  
  // Item details
  item_id: string;
  node_type: 'ANCHOR' | 'TASK';              // ⚠️ Updated: ANCHOR/TASK not MILESTONE/PHASE
  item_name: string;
  short_name: string | null;
  phase: string | null;
  department: string | null;
  display_order: number;
  
  // Dependencies (⚠️ USE depends_on_template_item_id - it's a UUID!)
  depends_on_template_item_id: string | null;  // ✅ Primary dependency reference (UUID)
  depends_on_action: string | null;             // ⚠️ DEPRECATED: Legacy text name, ignore this
  offset_relation: 'AFTER' | 'BEFORE' | null;
  offset_value: number | null;
  offset_unit: 'DAYS' | 'BUSINESS_DAYS' | null;  // ⚠️ Updated: Added BUSINESS_DAYS
  
  // Page linkage
  page_type: 'BOM' | 'SAMPLE_REQUEST_MULTI' | 'SAMPLE_REQUEST' | 'FORM' | 'TECHPACK' | 'NONE' | null;
  page_label: string | null;
  
  // Applicability
  applies_to_style: boolean;
  applies_to_material: boolean;
  timeline_type: 'MASTER' | 'STYLE' | 'MATERIAL';
  required: boolean;
  notes: string | null;
  supplier_visible: boolean;
  
  // Dependency info (resolved via JOIN)
  depends_on_item_name: string | null;        // Name of dependency (for display)
  depends_on_node_type: string | null;        // Type of dependency
  
  // Visibility config (future use)
  visibility_config: Array<{
    view_type: string;
    is_visible: boolean;
  }> | null;
  
  // Assignment defaults (future use)
  default_assigned_to: string | null;
  default_shared_with: string[] | null;
} applies_to_material: boolean;
  timeline_type: string;
**Example Response (Real Production Data):**
```json
[
  {
    "template_id": "ac96a5d8-0552-4367-bab4-56957565983d",
    "template_name": "Garment Tracking Timeline",
    "brand": "Default",
    "season": "2026 Spring",
    "version": 1,
    "template_active": true,
    "item_id": "2abc81ed-4985-4431-90f2-e2162a205dbe",
    "node_type": "ANCHOR",
    "item_name": "START DATE",
    "short_name": "START DATE",
    "phase": "PLAN",
    "department": "SYSTEM",
    "display_order": 0,
    "depends_on_template_item_id": null,
    "depends_on_action": null,
    "depends_on_item_name": null,
    "depends_on_node_type": null,
    "offset_relation": null,
    "offset_value": 0,
    "offset_unit": "DAYS",
    "page_type": null,
    "page_label": null,
    "applies_to_style": true,
    "applies_to_material": true,
    "timeline_type": "STYLE",
    "required": true,
    "notes": null,
    "supplier_visible": false,
    "visibility_config": null,
    "default_assigned_to": null,
    "default_shared_with": null
  },
  {
    "template_id": "ac96a5d8-0552-4367-bab4-56957565983d",
    "template_name": "Garment Tracking Timeline",
    "brand": "Default",
    "season": "2026 Spring",
    "version": 1,
    "template_active": true,
    "item_id": "337b7d15-8d46-41e3-9533-9d69cff2b3e0",
    "node_type": "TASK",
    "item_name": "TECHPACKS PASS OFF",
    "short_name": "TECHPACKS PASS OFF",
    "phase": "DEVELOPMENT",
    "department": "CUSTOMER",
    "display_order": 1,
    "depends_on_template_item_id": "2abc81ed-4985-4431-90f2-e2162a205dbe",
    "depends_on_action": "START DATE",
    "depends_on_item_name": "START DATE",
    "depends_on_node_type": "ANCHOR",
**UI Requirements:**
- [ ] Panel/modal view showing template header
- [ ] Display template metadata (name, brand, season, version)
- [ ] List all template items ordered by display_order
- [ ] Group items by phase (visual separators): PLAN, DEVELOPMENT, SMS, ALLOCATION, PRODUCTION
- [ ] Show item details:
  - [ ] Item name (use `item_name`, short_name for compact view)
  - [ ] Node type badge: **ANCHOR** (yellow) or **TASK** (blue)
  - [ ] Department tag
  - [ ] Applies to: Style/Material/Both badges
  - [ ] Required indicator (checkmark icon)
  - [ ] Supplier visible indicator (eye icon)
  - [ ] Dependency display: 
    - Use `depends_on_item_name` for display text
    - Format: "AFTER START DATE + 0 days" or "BEFORE CUT DATE - 60 days"
    - Show offset_unit correctly: "days" or "business days"
  - [ ] Page type badge if present: BOM, SAMPLE_REQUEST, FORM, TECHPACK
- [ ] Visual timeline/flowchart representation (optional enhancement)
- [ ] Close/back button

**Critical Notes:**
- ⚠️ **Use `depends_on_template_item_id` (UUID) not `depends_on_action` (deprecated text field)**
- ⚠️ **Node types are ANCHOR/TASK not MILESTONE/PHASE**
- ⚠️ **Display order 0 and 99 are anchors (START DATE and END DATE)**
## 📋 Testing Checklist

### Backend Validation
- [x] Migration 0007 deployed (folder_plan views)
- [x] Migration 0008 deployed (folders view)
- [x] Migration 0011 deployed (template views)
- [x] Migration 0012 deployed (imported Garment Tracking Timeline template - 27 nodes)
- [x] Migration 0013 deployed (timeline instantiation trigger)
- [x] Migration 0014 deployed (date calculation function)
- [x] Test data loaded (GREYSON MENS folder + 3 plans)
- [x] Template data loaded ("Garment Tracking Timeline" with 27 items)
- [x] Test plan linked to template (GREYSON 2026 SPRING DROP 3)
- [x] Test style created with timeline instantiated (TEST-001, 27 milestones, dates calculated)
- [x] Views return correct data
- [x] Counts computed accurately
- [x] Dependencies use UUIDs (not text names)e list
    "phase": "DEVELOPMENT",
    "department": "PD",
    "display_order": 2,
    "depends_on_template_item_id": "337b7d15-8d46-41e3-9533-9d69cff2b3e0",
    "depends_on_action": "TECHPACKS PASS OFF",
    "depends_on_item_name": "TECHPACKS PASS OFF",
    "offset_relation": "AFTER",
    "offset_value": 4,
    "offset_unit": "DAYS",
    "page_type": null,
    "page_label": null,
    "applies_to_style": true,
    "applies_to_material": false,
    "timeline_type": "STYLE",
    "required": false,
    "notes": null,
    "supplier_visible": false
  }
]
```

### Frontend Testing - Templates
- [ ] Template list loads without errors
- [ ] Shows "Garment Tracking Timeline" template
- [ ] Displays correct counts: 27 total items, 27 style items
- [ ] Can filter templates by brand/season (only 1 template for now)
- [ ] Template detail view opens for selected template
- [ ] All 27 template items display in display_order sequence (0-99)
- [ ] ANCHOR items (seq 0, 99) display correctly with yellow badge
- [ ] TASK items display with blue badge
- [ ] Dependencies render as "AFTER [name] + X days" or "BEFORE [name] - X days"
- [ ] Negative offsets display correctly (BEFORE relationships)
- [ ] Business days label shown where applicable
- [ ] Phase grouping visible (PLAN → DEVELOPMENT → SMS → ALLOCATION → PRODUCTION)
- [ ] Style vs material badges display correctly (all items apply to style)
- [ ] Page type badges shown (BOM, SAMPLE_REQUEST, FORM, TECHPACK)
- [ ] Required checkmark shows on appropriate items
- [ ] Supplier visible indicator shows correctly
- [ ] Back navigation works

### Performance
- [ ] Folder list loads < 500ms
- [ ] Template list loads < 500ms
- [ ] Template detail (27 items) loads < 1sd": "660e8400-e29b-41d4-a716-446655440101",
    "depends_on_item_name": "Proto Submit",
    "offset_relation": "AFTER",
    "offset_value": 7,
    "offset_unit": "DAYS",
    "applies_to_style": true,
    "applies_to_material": false,
    "required": true,
    "visibility_config": [
### Edge Cases to Handle
1. **Folder with no plans:** Show empty state with "Create Plan" CTA
2. **Null template_name:** Display "No template assigned" warning badge
3. **Zero counts:** Show "0 styles" / "0 materials" (not errors)
4. **Long plan names:** Truncate with ellipsis, show full name on hover
5. **Date formatting:** Use locale-aware date formatting (ISO 8601 from API)
6. **Template with no items:** Show empty state (shouldn't happen - we have 27 items)
7. **Circular dependencies:** Shouldn't occur (prevented by `depends_on_template_item_id` logic)
8. **Inactive templates:** Gray out or hide based on filter preference
9. **Null dependencies:** ANCHOR nodes (START/END DATE) have no dependencies - handle gracefully
10. **Negative offsets:** BEFORE relationships have negative offset_value - display as "- X days" not "+ -X days"
### Prerequisites Met ✅
- ✅ Database migrations deployed to production (0007, 0008, 0011, 0012, 0013, 0014)
- ✅ Template views created (v_timeline_template, v_timeline_template_item)
- ✅ API endpoints tested and documented
- ✅ Test data available:
  - GREYSON MENS folder + 3 plans
  - "Garment Tracking Timeline" template (27 nodes, 25 dependencies)
  - Test plan linked to template (GREYSON 2026 SPRING DROP 3)
  - Test style with timeline instantiated (TEST-001)
- ✅ Authentication keys provided
- ✅ TypeScript interfaces documented
- ✅ Trigger system operational (auto-creates timeline when style added to plan)
- ✅ Date calculation function working (calculates plan_date and due_date)

### Backend Automation
**When BeProduct `planAddStyle` is called:**
1. Plan must have `template_id` assigned
2. Trigger automatically creates 27 `plan_style_timelines` records
3. Trigger automatically creates 25 `plan_style_dependencies` records
4. Status initialized to `NOT_STARTED`
5. Call `calculate_timeline_dates(plan_style_id)` to set dates
6. Timeline ready for frontend display!

---

## 🔧 Advanced Usage: Dependency Selection

**Frontend Dev Question:** "How do I get template items for dependency selection?"

**Answer:** Use existing Supabase endpoint with filters:

```typescript
// Get all template items EXCEPT current item (prevents circular dependencies)
const templateId = 'ac96a5d8-0552-4367-bab4-56957565983d';
const excludeItemId = '337b7d15-8d46-41e3-9533-9d69cff2b3e0'; // current item being edited

const response = await fetch(
  `https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_timeline_template_item?` +
  `template_id=eq.${templateId}&` +
  `item_id=neq.${excludeItemId}&` +  // ⚠️ 'neq' = not equal (excludes current item)
  `select=item_id,item_name,phase,department,display_order&` +
  `order=display_order.asc`,
  { headers }
);

const availableDependencies: Array<{
  item_id: string;
  item_name: string;
  phase: string;
  department: string;
  display_order: number;
}> = await response.json();
```

**PostgREST Query Operators:**
- `eq` = equals
- `neq` = not equals
- `gt` = greater than
- `lt` = less than
- `in` = in list
- `is` = is null/not null

**Why this works:**
- ✅ No custom endpoint needed
- ✅ Uses existing `v_timeline_template_item` view
- ✅ `neq` filter prevents circular dependencies
- ✅ `select` reduces payload size
- ✅ Returns items in correct sequence

**⚠️ REMINDER: Phase 1 is READ-ONLY**
- This query is for **display purposes** only
- Template editing (POST/PATCH/DELETE) not available until future phase
- Use this data to show dependencies in template detail view

---

**Reference Docs:**
- Migration 0007: `supabase-tracking/migrations/0007_create_folder_plan_views.sql`
- Migration 0008: `supabase-tracking/migrations/0008_create_folders_view.sql`
- Migration 0011: `supabase-tracking/migrations/0011_create_template_views.sql`
- Migration 0012: `supabase-tracking/migrations/import_garment_timeline_corrected.sql` (27 template nodes)
- Migration 0013: `supabase-tracking/migrations/create_timeline_instantiation_trigger.sql`
- Migration 0014: `supabase-tracking/migrations/fix_timeline_date_calculation.sql`
- Timeline Workflow: `supabase-tracking/TIMELINE-WORKFLOW.md` (complete technical guide)
- API Plan: `supabase-tracking/docs/03-import-and-api-plan.md`

---

**Document Version:** 3.0  
**Last Updated:** 2025-10-23 (Evening)  
**Changes:**
- ✅ Added template migration status (0012, 0013, 0014 deployed)
- ✅ Updated TypeScript interfaces with actual schema (ANCHOR/TASK not MILESTONE/PHASE)
- ✅ Added real production data examples (Garment Tracking Timeline)
- ✅ Documented dependency fix (UUID-based, not text names)
- ✅ Added critical UI notes for dependencies and offsets
- ✅ Updated testing checklist with 27 items validation
- ✅ Added edge cases for negative offsets and deprecated fields
- ✅ Confirmed all 5 endpoints operational with real data  
**Next Review:** After Phase 1 frontend completionew)
- [ ] Migration 0011 deployed (template views)
- [x] Test data loaded (GREYSON MENS folder + 3 plans)
- [ ] Template data loaded (GREYSON 2026 Spring template)
- [x] Views return correct data
- [x] Counts computed accurately

### Frontend Testing - Folders & Plans
- [ ] Folder list loads without errors
- [ ] Can filter folders by brand
- [ ] Plan overview loads for selected folder
- [ ] All 3 GREYSON plans display
- [ ] Plan detail drawer shows correct data
- [ ] Handles null template/view names gracefully
- [ ] Empty states work (try folder with no plans)
- [ ] Mobile responsive design works

### Frontend Testing - Templates
- [ ] Template list loads without errors
- [ ] Can filter templates by brand/season
- [ ] Template detail view opens for selected template
- [ ] All template items display in correct order
- [ ] Dependencies and offsets render correctly
- [ ] Phase grouping visible
- [ ] Style vs material badges display correctly
- [ ] Back navigation works

### Performance
- [ ] Folder list loads < 500ms
### User Flow
```
Main Nav
   ├── Folders → Folder List → Plan Overview → Plan Detail Drawer
   │                  ↑              ↓                ↓
   │                  └──── Back ────┴──── Back ─────┘
   │
   └── Templates → Template List → Template Detail View
                        ↑                  ↓
                        └───── Back ───────┘
```🎨 Design Notes

### Brand Consistency
- Use existing BeProduct color schemes
- Match folder icon styles from BeProduct
- Plan cards should feel similar to existing plan tiles

### User Flow
```
### Edge Cases to Handle
1. **Folder with no plans:** Show empty state with "Create Plan" CTA
2. **Null template_name:** Display "No template assigned" warning
3. **Zero counts:** Show "0 styles" / "0 materials" (not errors)
4. **Long plan names:** Truncate with ellipsis, show full name on hover
5. **Date formatting:** Use locale-aware date formatting
6. **Template with no items:** Show empty state (shouldn't happen in practice)
7. **Circular dependencies:** UI should render dependency chains correctly
8. **Inactive templates:** Gray out or hide based on filter preference
1. **Folder with no plans:** Show empty state with "Create Plan" CTA
2. **Null template_name:** Display "No template assigned" warning
### Prerequisites Met
- ✅ Database migrations deployed to production
- ⚠️ Template migration (0011) ready but not deployed
- ✅ API endpoints tested and documented
- ✅ Test data available (GREYSON MENS folder + 3 plans)
- ⚠️ Template test data needs preparation (see migration guide)
- ✅ Authentication keys provided
- ✅ TypeScript interfaces documented

### Data Import Required
Before frontend work on templates can begin:
1. Prepare template data using `templates/timeline-template-migration-guide.md`
2. Deploy migration 0011 to create template views
3. Import template data (GREYSON 2026 Spring Standard recommended)
4. Link templates to existing plans via `UPDATE tracking.plans SET template_id = ...`
5. Verify via `/rest/v1/v_timeline_template` and `/rest/v1/v_folder_plan`

### Next Phase Preview
**Phase 2** will add:
- Style timeline grid view (read-only)
- Material timeline grid view (read-only)
- Timeline milestone detail cards
**Reference Docs:**
- Migration 0007: `supabase-tracking/migrations/0007_create_folder_plan_views.sql`
- Migration 0008: `supabase-tracking/migrations/0008_create_folders_view.sql`
- Migration 0011: `supabase-tracking/migrations/0011_create_template_views.sql`
- Template Migration Guide: `supabase-tracking/templates/timeline-template-migration-guide.md`
- API Plan: `supabase-tracking/docs/03-import-and-api-plan.md`

---

**Document Version:** 2.0  
**Last Updated:** 2025-10-23  
**Changes:** Added template management screens (Task 4 & 5), updated endpoints and testing checklist  
**Next Review:** After Phase 1 completion
---

## 📞 Support

**Questions?** Contact backend team with:
- Specific endpoint URL
- Request/response examples
- Error messages (if any)

**Reference Docs:**
- Migration 0007: `supabase-tracking/migrations/0007_create_folder_plan_views.sql`
- Migration 0008: `supabase-tracking/migrations/0008_create_folders_view.sql`
- API Plan: `supabase-tracking/docs/03-import-and-api-plan.md`

---

**Document Version:** 1.0  
**Last Updated:** 2025-10-23  
**Next Review:** After Phase 1 completion
