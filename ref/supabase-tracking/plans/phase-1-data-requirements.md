# Phase 1: Data Requirements & Import Plan

**Phase:** Folders & Plans UI  
**Date:** 2025-10-23  
**Status:** 📋 DATA IMPORT NEEDED

---

## 🎯 Overview

Phase 1 views (`v_folder`, `v_folder_plan`, `v_folder_plan_columns`) are **already deployed** but need data populated from BeProduct to function properly.

---

## 📊 Current Data Status

### ✅ Tables with Data (GREYSON MENS)
- `tracking.folder` - ✅ 1 folder loaded
- `tracking.plans` - ✅ 3 plans loaded (Spring Drop 1, 2, 3)

### ❌ Tables Missing Data
- `tracking.plan_styles` - Empty (counts show 0)
- `tracking.plan_materials` - Empty (counts show 0)
- `tracking.plan_style_timelines` - Empty (milestone counts show 0)
- `tracking.plan_material_timelines` - Empty (milestone counts show 0)
- `tracking.timeline_templates` - Empty (template_name shows null)
- `tracking.plan_views` - Empty (default_view_name shows null, column_config view returns nothing)

---

## 📥 Required BeProduct Data Imports

### Import Priority 1: Folder & Plan Basics (✅ COMPLETE)

These are already loaded for GREYSON:

| BeProduct MCP Tool | Target Table | Status | Notes |
|-------------------|--------------|--------|-------|
| `beproduct-tracking.folderList` | `tracking.folder` | ✅ Complete | 1 folder (GREYSON MENS) |
| `beproduct-tracking.planSearch` | `tracking.plans` | ✅ Complete | 3 plans loaded |

**Result:** Folder list view works, but plan counts show 0.

---

### Import Priority 2: Timeline Templates (⚠️ REQUIRED)

**Why needed:** Plans reference `template_id` for timeline structure. Currently all plans show `template_name: null`.

| BeProduct Source | Target Table | Required Fields |
|-----------------|--------------|-----------------|
| Manual export / template definition | `tracking.timeline_templates` | `id`, `name`, `brand`, `season`, `version`, `is_active` |
| Manual export / template items | `tracking.timeline_template_items` | `id`, `template_id`, `name`, `node_type`, `phase`, `display_order`, `applies_to_style`, `applies_to_material` |
| Manual export / visibility rules | `tracking.timeline_template_visibility` | `template_id`, `item_id`, `view_type`, `default_visible` |

**BeProduct Data Location:**
- Template HTML/JSON export from BeProduct timeline editor
- Normalize into `ref/timeline_extract_beproduct.json`
- Load via SQL or Edge Function

**Impact on Phase 1:**
- `v_folder_plan.template_name` will populate
- Enables future phase timeline views

---

### Import Priority 3: Plan Views & Column Config (⚠️ REQUIRED FOR COLUMN VIEW)

**Why needed:** `v_folder_plan_columns` view flattens `plan_views.column_config` for grid rendering. Currently returns empty.

| BeProduct MCP Tool | Target Table | Required Fields |
|--------------------|--------------|-----------------|
| `beproduct-tracking.planStyleView` | `tracking.plan_views` | `id`, `plan_id`, `name`, `view_type: 'style'`, `active`, `sort_order`, `column_config` |
| `beproduct-tracking.planMaterialView` | `tracking.plan_views` | `id`, `plan_id`, `name`, `view_type: 'material'`, `active`, `sort_order`, `column_config` |

**BeProduct Payload Example:**
```json
{
  "views": [
    {
      "id": "uuid",
      "name": "Style Grid",
      "view_type": "style",
      "column_config": [
        {
          "field_key": "style_number",
          "label": "Style #",
          "visible": true,
          "pinned": true,
          "width_px": 120,
          "sort_order": 1,
          "data_type": "text"
        }
      ]
    }
  ]
}
```

**Impact on Phase 1:**
- `v_folder_plan.default_view_name` will populate (if plan has default view)
- `v_folder_plan_columns` will return column configuration for grid headers

---

### Import Priority 4: Styles & Materials (🟡 OPTIONAL FOR PHASE 1, REQUIRED FOR PHASE 2)

**Why needed:** Populates style/material counts in folder plan overview. Currently all counts show 0.

#### Style Import

| BeProduct MCP Tool | Target Table | Required Fields |
|--------------------|--------------|-----------------|
| `beproduct-tracking.planStyleTimeline` | `tracking.plan_styles` | `id`, `plan_id`, `view_id`, `style_id`, `style_header_id`, `color_id`, `style_number`, `style_name`, `color_name`, `season`, `supplier_name`, `brand` |

**BeProduct Payload Structure:**
```json
{
  "plan_id": "uuid",
  "styles": [
    {
      "style_id": "uuid",
      "style_header_id": "uuid",
      "color_id": "uuid",
      "style_number": "ABC123",
      "style_name": "Sample Tee",
      "color_name": "Black",
      "season": "2026 Spring",
      "supplier_name": "Factory A",
      "brand": "GREYSON"
    }
  ]
}
```

**Impact on Phase 1:**
- `v_folder_plan.style_count` will populate
- `v_folders.active_plan_count` still works (based on plans, not styles)

#### Material Import

| BeProduct MCP Tool | Target Table | Required Fields |
|--------------------|--------------|-----------------|
| `beproduct-tracking.planMaterialTimeline` | `tracking.plan_materials` | `id`, `plan_id`, `view_id`, `material_id`, `material_header_id`, `color_id`, `material_number`, `material_name`, `color_name`, `supplier_name`, `style_links` |

**BeProduct Payload Structure:**
```json
{
  "plan_id": "uuid",
  "materials": [
    {
      "material_id": "uuid",
      "material_header_id": "uuid",
      "material_number": "MAT-456",
      "material_name": "Cotton Jersey",
      "color_name": "White",
      "supplier_name": "Mill B",
      "style_links": [{"style_id": "uuid", "style_number": "ABC123"}]
    }
  ]
}
```

**Impact on Phase 1:**
- `v_folder_plan.material_count` will populate

---

### Import Priority 5: Timeline Milestones (🟡 OPTIONAL FOR PHASE 1, REQUIRED FOR PHASE 2+)

**Why needed:** Enables milestone counts and timeline grid views in future phases.

| BeProduct MCP Tool | Target Table | Required Fields |
|--------------------|--------------|-----------------|
| `beproduct-tracking.planStyleTimeline` | `tracking.plan_style_timelines` | `id`, `plan_style_id`, `template_item_id`, `status`, `plan_date`, `rev_date`, `final_date`, `due_date`, `completed_date`, `late`, `notes` |
| `beproduct-tracking.planMaterialTimeline` | `tracking.plan_material_timelines` | `id`, `plan_material_id`, `template_item_id`, `status`, `plan_date`, `rev_date`, `final_date`, `due_date`, `completed_date`, `late`, `notes` |

**Impact on Phase 1:**
- `v_folder_plan.style_milestone_count` will populate
- `v_folder_plan.material_milestone_count` will populate

---

## 🔄 Import Execution Order

### Minimal Phase 1 Functionality (Current State)
```
✅ 1. Folders         (tracking.folders)         - DONE
✅ 2. Plans           (tracking.plans)           - DONE
```
**Result:** Folder list works, plan list works, but all counts = 0 and template/view names = null.

---

### Recommended Phase 1 Complete
```
✅ 1. Folders         (tracking.folder)                  - DONE
✅ 2. Plans           (tracking.plans)                    - DONE
⬜ 3. Templates       (tracking.timeline_templates)       - IMPORT NEEDED
⬜ 4. Template Items  (tracking.timeline_template_items)  - IMPORT NEEDED
⬜ 5. Plan Views      (tracking.plan_views)               - IMPORT NEEDED
⬜ 6. Styles          (tracking.plan_styles)              - IMPORT NEEDED
⬜ 7. Materials       (tracking.plan_materials)           - IMPORT NEEDED
```
**Result:** All counts accurate, template/view names populated, ready for Phase 2.

---

### Full Phase 2+ Ready
```
✅ 1. Folders         (tracking.folder)                      - DONE
✅ 2. Plans           (tracking.plans)                        - DONE
⬜ 3. Templates       (tracking.timeline_templates)           - IMPORT NEEDED
⬜ 4. Template Items  (tracking.timeline_template_items)      - IMPORT NEEDED
⬜ 5. Plan Views      (tracking.plan_views)                   - IMPORT NEEDED
⬜ 6. Styles          (tracking.plan_styles)                  - IMPORT NEEDED
⬜ 7. Materials       (tracking.plan_materials)               - IMPORT NEEDED
⬜ 8. Style Timelines (tracking.plan_style_timelines)         - IMPORT NEEDED
⬜ 9. Material Timelines (tracking.plan_material_timelines)   - IMPORT NEEDED
```
**Result:** Complete data for timeline grids, milestone editing, progress tracking.

---

## 🛠️ Import Methods

### Option 1: MCP Tool Calls (Recommended)

Use the BeProduct MCP tools to fetch and transform data:

```typescript
// 1. Fetch folders
const folders = await beproduct_tracking.folderList({ brand: "GREYSON" });

// 2. Fetch plans per folder
const plans = await beproduct_tracking.planSearch({ folderId: folder.id });

// 3. Fetch style timelines (includes styles + milestones)
const styleData = await beproduct_tracking.planStyleTimeline({ planId: plan.id });

// 4. Fetch material timelines (includes materials + milestones)
const materialData = await beproduct_tracking.planMaterialTimeline({ planId: plan.id });

// 5. Fetch view configuration
const styleViews = await beproduct_tracking.planStyleView({ planId: plan.id });
const materialViews = await beproduct_tracking.planMaterialView({ planId: plan.id });
```

### Option 2: Edge Function Import (Future)

Create `tracking-import-beproduct` Edge Function:
- Input: `{ folderId, planIds[], includeMaterialTimelines, dryRun }`
- Calls BeProduct MCP tools
- Transforms payloads
- Upserts to Supabase tables
- Returns batch summary

### Option 3: Manual SQL Import (For Templates)

Templates may need manual export from BeProduct:
```sql
-- Insert template
INSERT INTO tracking.timeline_templates (id, name, brand, season, version, is_active)
VALUES (gen_random_uuid(), 'GREYSON 2026 Spring Template', 'GREYSON', '2026 Spring', 1, true);

-- Insert template items
INSERT INTO tracking.timeline_template_items (template_id, name, node_type, phase, display_order, applies_to_style, applies_to_material)
VALUES 
  (template_id, 'Proto Submit', 'MILESTONE', 'DEVELOPMENT', 1, true, false),
  (template_id, 'Material Submit', 'MILESTONE', 'DEVELOPMENT', 2, false, true);
```

---

## 📋 Import Checklist

### Step 1: Prepare Templates
- [ ] Export template structure from BeProduct
- [ ] Normalize into `ref/timeline_extract_beproduct.json`
- [ ] Create SQL seed script for templates
- [ ] Load templates to `tracking.timeline_templates`
- [ ] Load template items to `tracking.timeline_template_items`
- [ ] Verify: `SELECT * FROM tracking.timeline_templates;`

### Step 2: Associate Plans with Templates
- [ ] Update `tracking.plans.template_id` for each plan
- [ ] Verify: `SELECT plan_name, template_name FROM tracking.v_folder_plan;`

### Step 3: Import Plan Views
- [ ] Call `beproduct-tracking.planStyleView` for each plan
- [ ] Call `beproduct-tracking.planMaterialView` for each plan
- [ ] Transform to Supabase schema
- [ ] Insert into `tracking.plan_views` with `column_config`
- [ ] Verify: `SELECT * FROM tracking.v_folder_plan_columns;`

### Step 4: Import Styles & Materials
- [ ] Call `beproduct-tracking.planStyleTimeline` for each plan
- [ ] Transform style records → `tracking.plan_styles`
- [ ] Call `beproduct-tracking.planMaterialTimeline` for each plan
- [ ] Transform material records → `tracking.plan_materials`
- [ ] Verify: `SELECT folder_name, plan_name, style_count, material_count FROM tracking.v_folder_plan;`

### Step 5: Import Timelines (Phase 2 Prep)
- [ ] Transform style milestone records → `tracking.plan_style_timelines`
- [ ] Transform material milestone records → `tracking.plan_material_timelines`
- [ ] Link milestones to `template_item_id`
- [ ] Verify: `SELECT folder_name, plan_name, style_milestone_count, material_milestone_count FROM tracking.v_folder_plan;`

---

## 📊 Success Criteria

### Phase 1 UI Working
- [ ] `v_folder` returns all folders with accurate `active_plan_count`
- [ ] `v_folder_plan` returns all plans with `style_count` > 0
- [ ] `v_folder_plan` shows `template_name` (not null)
- [ ] `v_folder_plan` shows `default_view_name` (not null)
- [ ] `v_folder_plan_columns` returns column configuration for each view

### GREYSON Test Data Complete
- [ ] GREYSON MENS folder exists
- [ ] 3 plans exist (Spring Drop 1, 2, 3)
- [ ] Each plan has 5+ styles
- [ ] Each plan has 3+ materials
- [ ] Template assigned to all plans
- [ ] Default view assigned to all plans
- [ ] Column config populated for all views

---

## 📞 Next Steps

1. **Decision:** Import templates first or skip for Phase 1?
2. **Decision:** Import styles/materials or test with zeros?
3. **Execution:** Run MCP tool calls or wait for Edge Function?
4. **Testing:** Validate all view counts after import

---

**Last Updated:** 2025-10-23  
**Blocking Issue:** Need template data + style/material data for accurate counts  
**Recommendation:** Import templates + styles + materials before frontend dev starts Phase 1
