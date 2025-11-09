# ✅ Phase 1 Endpoints - READY FOR FRONTEND

**Date:** 2025-10-23  
**Status:** All endpoints deployed and tested  
**Base URL:** `https://wjpbryjgtmmaqjbhjgap.supabase.co`

---

## 🎯 Available Endpoints

⚠️ **IMPORTANT: Phase 1 is READ-ONLY**  
All endpoints are **GET requests only** - no POST/PATCH/DELETE operations available.  
Templates must be imported via backend SQL (see migration guide) or wait for Phase 2 CRUD features.

All endpoints support anonymous access.

### 1. Folder List
**Endpoint:** `GET /rest/v1/v_folder`  
**Purpose:** Browse tracking folders by brand  
**Returns:** Array of folders with plan counts  
**Test Result:** ✅ 1 folder (GREYSON MENS)

**Example:**
```bash
GET /rest/v1/v_folder?order=folder_name.asc
```

**Response:**
```json
[
  {
    "folder_id": "82a698e1-9103-4bab-98af-a0ec423332a2",
    "folder_name": "GREYSON MENS",
    "brand": "GREYSON",
    "active_plan_count": 3,
    "total_plan_count": 3
  }
]
```

---

### 2. Plan Overview
**Endpoint:** `GET /rest/v1/v_folder_plan`  
**Purpose:** View plans within a folder with metadata  
**Returns:** Array of plans with template names and counts  
**Test Result:** ✅ 3 plans (Spring Drop 1, 2, 3)

**Example:**
```bash
GET /rest/v1/v_folder_plan?folder_id=eq.82a698e1-9103-4bab-98af-a0ec423332a2
```

**Response:**
```json
[
  {
    "folder_id": "82a698e1-9103-4bab-98af-a0ec423332a2",
    "folder_name": "GREYSON MENS",
    "plan_id": "uuid",
    "plan_name": "GREYSON 2026 SPRING DROP 1",
    "plan_season": "2026 Spring",
    "template_name": null,
    "style_count": 0,
    "material_count": 0
  }
]
```

---

### 3. Plan View Columns
**Endpoint:** `GET /rest/v1/v_folder_plan_columns`  
**Purpose:** Column configuration for grid views  
**Returns:** Array of column definitions  
**Test Result:** ✅ Empty (no views configured yet)

**Example:**
```bash
GET /rest/v1/v_folder_plan_columns?plan_id=eq.{uuid}
```

---

### 4. Template List (NEW)
**Endpoint:** `GET /rest/v1/v_timeline_template`  
**Purpose:** Browse timeline templates by brand/season  
**Returns:** Array of templates with item counts  
**Test Result:** ✅ Empty (no templates yet - import needed)

**Example:**
```bash
GET /rest/v1/v_timeline_template?is_active=eq.true&order=brand.asc
```

**Expected Response (after import):**
```json
[
  {
    "template_id": "uuid",
    "template_name": "GREYSON 2026 Spring Standard",
    "brand": "GREYSON",
    "season": "2026 Spring",
    "version": 1,
    "is_active": true,
    "total_item_count": 6,
    "style_item_count": 4,
    "material_item_count": 2,
    "milestone_count": 6,
    "phase_count": 0,
    "active_plan_count": 3
  }
]
```

---

### 5. Template Items (NEW)
**Endpoint:** `GET /rest/v1/v_timeline_template_item`  
**Purpose:** View template milestone structure  
**Returns:** Array of template items with dependencies  
**Test Result:** ✅ Empty (no templates yet - import needed)

**Example:**
```bash
GET /rest/v1/v_timeline_template_item?template_id=eq.{uuid}&order=display_order.asc
```

**Expected Response (after import):**
```json
[
  {
    "template_id": "uuid",
    "template_name": "GREYSON 2026 Spring Standard",
    "item_id": "uuid",
    "node_type": "TASK",
    "item_name": "Proto Submit",
    "short_name": "Proto",
    "phase": "DEVELOPMENT",
    "department": "DESIGN",
    "display_order": 1,
    "depends_on_template_item_id": null,
    "depends_on_item_name": null,
    "applies_to_style": true,
    "applies_to_material": false,
    "required": true,
    "visibility_config": [
      {"view_type": "STYLE", "is_visible": true}
    ]
  }
]
```

---

## 🔐 Authentication

All endpoints use the same headers:

```javascript
const headers = {
  'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU',
  'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU'
};
```

---

## 📊 Current Data Status

| Entity | Count | Status |
|--------|-------|--------|
| Folders | 1 | ✅ GREYSON MENS loaded |
| Plans | 3 | ✅ Spring Drop 1, 2, 3 loaded |
| Templates | 0 | ⚠️ Import needed |
| Template Items | 0 | ⚠️ Import needed |
| Styles | 0 | ⏳ Phase 2 data |
| Materials | 0 | ⏳ Phase 2 data |

---

## 🚀 Frontend Can Start

### ✅ Ready Now (Tasks 1-3)
### ⏳ Needs Template Data (Tasks 4-5)
4. **Template List Screen** - Endpoints ready, awaiting backend data import (SQL only - no POST endpoint)
5. **Template Detail View** - Endpoints ready, awaiting backend data import (SQL only - no POST endpoint)

**⚠️ Note for Frontend:** Template creation UI not available in Phase 1. Phase 1 is view-only. If you need to create templates via UI, that's a Phase 2 feature requiring POST endpoints.)

### ⏳ Needs Template Data (Tasks 4-5)
4. **Template List Screen** - Endpoints ready, awaiting data import
5. **Template Detail View** - Endpoints ready, awaiting data import

---

## 📝 Quick Test Commands (PowerShell)

```powershell
# Set headers
$headers = @{
    'apikey' = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU'
    'Authorization' = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndqcGJyeWpndG1tYXFqYmhqZ2FwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwMjk4MjksImV4cCI6MjA2NTYwNTgyOX0.QFx5qIQCGP8VoEoDLEbTpV2Ywq_f7ZXeySpuZnDY4oU'
}

# Test folder list
Invoke-RestMethod -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_folder" -Headers $headers

# Test plans for GREYSON MENS
Invoke-RestMethod -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_folder_plan?folder_id=eq.82a698e1-9103-4bab-98af-a0ec423332a2" -Headers $headers

# Test template list (will be empty until data imported)
Invoke-RestMethod -Uri "https://wjpbryjgtmmaqjbhjgap.supabase.co/rest/v1/v_timeline_template" -Headers $headers
```

---

## 📚 Documentation

- **Frontend Plan:** `plans/phase-1-folders-and-plans.md`
- **TypeScript Interfaces:** All included in frontend plan
- **Data Migration Guide:** `templates/timeline-template-migration-guide.md`
- **CRUD Status:** `docs/crud-endpoint-status.md`
- **Complete Summary:** `PHASE1-SUMMARY.md`

---

## ✅ Verification Results

**Tested:** 2025-10-23  
**Method:** PowerShell Invoke-RestMethod  
**Results:**
- ✅ `/rest/v1/v_folder` - Returns 1 folder
- ✅ `/rest/v1/v_folder_plan` - Returns 3 plans
- ✅ `/rest/v1/v_folder_plan_columns` - Returns empty array
- ✅ `/rest/v1/v_timeline_template` - Returns empty array (expected)
- ✅ `/rest/v1/v_timeline_template_item` - Returns empty array (expected)

**Conclusion:** All Phase 1 endpoints operational and ready for frontend development! 🎉

**Next Steps:**
1. Frontend dev starts Tasks 1-3 (folders and plans) - ✅ READ-ONLY UI
2. Backend imports template data using migration guide (SQL only)
3. Frontend dev completes Tasks 4-5 (templates) after data import - ✅ READ-ONLY UI
4. Phase 2: Add POST/PATCH/DELETE endpoints if template creation UI needed

**If Frontend Needs Template Creation:**
- This requires Phase 2 (CRUD operations)
- Backend must create Edge Function or expose base tables with RLS
- Current Phase 1 scope: View-only UI for all entities
2. Backend imports template data using migration guide
3. Frontend dev completes Tasks 4-5 (templates) after data import
