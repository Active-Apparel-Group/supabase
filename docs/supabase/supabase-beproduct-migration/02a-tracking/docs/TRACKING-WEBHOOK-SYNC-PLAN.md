# Tracking Webhook Sync Implementation Plan

**Purpose:** Comprehensive plan for syncing BeProduct tracking data via webhooks to Supabase  
**Status:** Ready for Implementation  
**Date:** November 6, 2025  
**Version:** 1.0

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Webhook Analysis](#webhook-analysis)
3. [Data Flow Architecture](#data-flow-architecture)
4. [Field Mapping](#field-mapping)
5. [Implementation Strategy](#implementation-strategy)
6. [Phase 1: Webhook Sync](#phase-1-webhook-sync)
7. [Phase 2: Enhancements & Reverse Sync](#phase-2-enhancements--reverse-sync)
8. [Testing Plan](#testing-plan)
9. [Deployment Checklist](#deployment-checklist)

---

## Executive Summary

### Objective
Create a single edge function (`beproduct-tracking-webhook`) to handle all tracking webhook events from BeProduct and sync data to Supabase `ops` schema tables.

### Scope
- **Phase 1 (Current):** One-way sync from BeProduct → Supabase via webhooks
- **Phase 2 (Future):** Two-way sync (Supabase updates trigger BeProduct API calls)

### Key Constraints
1. **No table deletions** - All existing `tracking_*` tables remain intact
2. **No material plan migration** - `tracking_plan_material` ignored for now (future: nest under styles)
3. **Intelligent API calls** - Check if plan/folder exists before calling BeProduct API

### Webhook Events
- `OnCreate` - New style/colorway added to tracking plan
- `OnChange` - Timeline milestone updated (status, dates, assignments)
- `OnDelete` - Style/colorway removed from tracking plan

---

## Database Schema Overview

### Table Relationships

```
tracking_folder (1:N)
├── tracking_plan (1:N)
    ├── tracking_plan_style (1:N)
    │   ├── tracking_plan_style_timeline (1:N)
    │   │   ├── tracking_timeline_assignment (1:N)
    │   │   └── tracking_plan_style_dependency (as successor)
    │   └── tracking_plan_style_dependency (M:N between timelines)
    └── tracking_timeline_template (template)
        └── tracking_timeline_template_item (1:N)
            └── depends_on_template_item_id (self-referencing)
```

### Key Foreign Key Relationships

| Child Table | FK Column | Parent Table | Parent Column |
|-------------|-----------|--------------|---------------|
| `tracking_plan` | `folder_id` | `tracking_folder` | `id` |
| `tracking_plan` | `template_id` | `tracking_timeline_template` | `id` |
| `tracking_plan_style` | `plan_id` | `tracking_plan` | `id` |
| `tracking_plan_style_timeline` | `plan_style_id` | `tracking_plan_style` | `id` |
| `tracking_plan_style_timeline` | `template_item_id` | `tracking_timeline_template_item` | `id` |
| `tracking_timeline_assignment` | `timeline_id` | `tracking_plan_style_timeline` | `id` |
| `tracking_plan_style_dependency` | `predecessor_id` | `tracking_plan_style_timeline` | `id` |
| `tracking_plan_style_dependency` | `successor_id` | `tracking_plan_style_timeline` | `id` |

### Dependency Table Structure

**Purpose:** Stores predecessor/successor relationships between timeline milestones for Gantt chart calculations.

**Table:** `tracking_plan_style_dependency`

| Column | Type | Description |
|--------|------|-------------|
| `successor_id` | uuid | Timeline milestone that depends on predecessor |
| `predecessor_id` | uuid | Timeline milestone that must complete first |
| `offset_relation` | enum | `BEFORE` or `AFTER` predecessor |
| `offset_value` | integer | Number of days offset |
| `offset_unit` | enum | `DAYS` or `BUSINESS_DAYS` |

**⚠️ Phase 1 Status:** Dependencies and their FK constraints have been **disabled** for Phase 1. The dependency tables exist but foreign key constraints are removed. Dependency implementation is deferred to Phase 2.

### Start/End Date Bookends

When a style is instantiated from a template, **two special anchor milestones** are created:
- **START DATE** - Anchored to `tracking_plan.start_date`
- **END DATE** - Anchored to `tracking_plan.end_date`

All other milestones chain off these anchors via the dependency table. This creates a bounded timeline.

### Date Fields

**Timeline tables have TWO sets of date columns:**

| Column | Purpose | Source |
|--------|---------|--------|
| `plan_date` | Original planned date | BeProduct calculation (via webhook) |
| `start_date_plan` | Milestone start date | BeProduct calculation (via webhook) |
| `due_date` | Current target date | BeProduct (updated by users) |
| `start_date_due` | Current start date | BeProduct (updated by users) |
| `rev_date` | Revised date | BeProduct (user override) |
| `final_date` | Final approved date | BeProduct (when status = APPROVED) |

**Important:** With webhook integration, **BeProduct is the source of truth** for all dates. Local calculation triggers must be disabled to avoid conflicts.

### ⚠️ Trigger Conflict Resolution

**Problem:**  
Existing triggers (`calculate_timeline_dates`, `cascade_timeline_updates`, `recalculate_plan_timelines`) auto-calculate dates based on dependencies. When webhooks arrive with pre-calculated dates, triggers fire and **overwrite** the webhook data.

**Solution:**  
Migration `009_disable_timeline_date_calculation_triggers.sql` drops calculation triggers and dependency FKs:
- ✅ `trg_instantiate_style_timeline` - Creates timeline structure from template (still needed!)
- ❌ `calculate_timeline_dates_trigger` - Removed (conflicts with webhook dates)
- ❌ `cascade_timeline_updates_trigger` - Removed (conflicts with webhook dates)
- ❌ `recalculate_plan_timelines_trigger` - Removed (conflicts with webhook dates)
- ❌ Dependency FK constraints - Removed (dependencies deferred to Phase 2)

**Workflow after migration:**
1. User adds style to plan in BeProduct
2. `trg_instantiate_style_timeline` creates timeline structure with NULL dates
3. BeProduct calculates dates based on template dependencies
4. Webhook fires with calculated dates
5. Edge function updates timeline records with BeProduct's dates
6. No triggers fire to recalculate

---

## Webhook Analysis

### Available Webhook Examples

#### 1. OnCreate Event (`tracking_oncreate.json`)

**Trigger:** Style/colorway added to tracking plan  
**Key Data:**
```json
{
  "eventType": "OnCreate",
  "objectType": "Header",
  "headerId": "0972758d-5fd7-442c-943f-c1195a26d108",
  "headerNumber": "MSP26O73",
  "headerName": "Trailwolf Vest",
  "folderId": "66f377be-d3d6-4e42-b50a-b46f4e156191",
  "folderName": "Style",
  "data": {
    "after": {
      "Id": "b9f9d07f-7edf-496d-80c6-d51b57a3052b",
      "PlanId": "4b6a1504-5c27-4698-a883-2d57e8219d6c",
      "HeaderId": "0972758d-5fd7-442c-943f-c1195a26d108",
      "Color": {
        "_id": "52e8403c-7084-432c-a423-452924063016",
        "suggested_name": "STINGRAY"
      },
      "Timelines": [
        {
          "Id": "73431d54-c2c1-429e-b2f1-2746e4429790",
          "TimeLineId": "fbf37368-6c6a-47f5-a1b7-4a32cdca6ea3",
          "Status": "Not Started",
          "Rev": null,
          "Final": null,
          "DueDate": "2025-11-05T18:52:05.0708456Z",
          "ProjectDate": "2025-11-05T18:52:05.0708456Z",
          "AssignedTo": [],
          "ShareWith": [],
          "Late": false
        }
        // ... 23 more timeline milestones
      ]
    }
  }
}
```

**What's Included:**
- ✅ Plan ID
- ✅ Style header ID
- ✅ Color ID and name
- ✅ All 24 timeline milestones with IDs, statuses, dates
- ✅ Assignment/sharing arrays (empty on create)

**What's Missing:**
- ❌ Plan details (name, start_date, end_date, folder_id)
- ❌ Folder details (name, brand)
- ❌ Style number (only have header name)
- ❌ Timeline template details (milestone names, phases, departments)

**Required API Calls:**
1. `planGet` - Get plan metadata if not in database
2. `folderList` - Get folder metadata if not in database (or infer from plan)

---

#### 2. OnChange Event (`tracking_onchangetimeline.json`)

**Trigger:** Timeline milestone updated (status, dates, assignments)  
**Key Data:**
```json
{
  "eventType": "OnChange",
  "objectType": "Header",
  "data": {
    "before": {
      "TimeLineItem": {
        "Id": "5cc6d0e0-29d3-410b-a69a-eb90bface938",
        "TimeLineId": "fbf37368-6c6a-47f5-a1b7-4a32cdca6ea3",
        "Status": "Approved",
        "Final": "2025-11-05T15:09:06Z",
        "AssignedTo": [{"value": "chrisk", "code": "875fe554-cd04-430d-a9a4-f95c27659293"}]
      }
    },
    "after": {
      "TimeLineItem": {
        "Id": "5cc6d0e0-29d3-410b-a69a-eb90bface938",
        "TimeLineId": "fbf37368-6c6a-47f5-a1b7-4a32cdca6ea3",
        "Status": "Approved",
        "Final": "2025-11-06T15:09:56Z",  // Changed!
        "AssignedTo": [{"value": "chrisk", "code": "875fe554-cd04-430d-a9a4-f95c27659293"}]
      }
    },
    "timeLineSchema": {
      "Id": "fbf37368-6c6a-47f5-a1b7-4a32cdca6ea3",
      "Department": "PRE-PRODUCTION | CUSTOMER",
      "TaskDescription": "TECHPACKS PASS OFF",
      "ShortDescription": "TECHPACKS PASS OFF",
      "Plan": "2025-11-01T00:00:00Z"
    }
  }
}
```

**What's Included:**
- ✅ Before/after states (enables delta detection)
- ✅ Timeline milestone template details (name, department, phase)
- ✅ Timeline instance ID
- ✅ Status, dates, assignments

**What's Missing:**
- ❌ Plan ID (in webhook but need to extract from root)
- ❌ Style/colorway context (need from parent data object)

**Required API Calls:**
- None (if plan/style already exist in database)

---

#### 3. OnDelete Event (`tracking_ondelete.json`)

**Trigger:** Style/colorway removed from tracking plan  
**Key Data:**
```json
{
  "eventType": "OnDelete",
  "objectType": "Header",
  "data": {
    "before": {
      "Id": "b9f9d07f-7edf-496d-80c6-d51b57a3052b",
      "PlanId": "4b6a1504-5c27-4698-a883-2d57e8219d6c",
      "HeaderId": "0972758d-5fd7-442c-943f-c1195a26d108",
      "Timelines": [...]
    },
    "after": null
  }
}
```

**What's Included:**
- ✅ Plan ID
- ✅ Style header ID
- ✅ Timeline record ID
- ✅ Full state before deletion

**What's Missing:**
- Nothing - soft delete, keep data

**Required API Calls:**
- None

---

## Data Flow Architecture

### High-Level Flow

```
┌─────────────────┐
│   BeProduct     │
│   Webhook       │
└────────┬────────┘
         │
         │ POST /beproduct-tracking-webhook
         ▼
┌─────────────────────────────────────────────────────────┐
│         Supabase Edge Function                          │
│  (beproduct-tracking-webhook)                           │
│                                                         │
│  1. Authenticate webhook request                        │
│  2. Parse event type (OnCreate/OnChange/OnDelete)       │
│  3. Extract plan_id, style_id, timeline_id             │
│  4. Check if plan exists in ops.tracking_plan          │
│     ├─ If NO → Call BeProduct API (planGet)           │
│     └─ If YES → Use cached data                        │
│  5. Check if folder exists in ops.tracking_folder      │
│     ├─ If NO → Call BeProduct API (folderList)        │
│     └─ If YES → Use cached data                        │
│  6. Upsert data to appropriate tables:                 │
│     - ops.tracking_plan_style                          │
│     - ops.tracking_plan_style_timeline                 │
│     - ops.tracking_timeline_assignment                 │
│  7. Log to ops.beproduct_sync_log                      │
│  8. Return 200 OK                                      │
└─────────────────────────────────────────────────────────┘
         │
         │ INSERT/UPDATE
         ▼
┌─────────────────────────────────────────────────────────┐
│              Supabase Database (ops schema)             │
│                                                         │
│  ┌──────────────────┐  ┌──────────────────────────┐   │
│  │ tracking_folder  │  │  tracking_plan           │   │
│  └──────────────────┘  └──────────────────────────┘   │
│           │                      │                      │
│           │                      │                      │
│  ┌────────▼──────────────────────▼─────────────────┐   │
│  │         tracking_plan_style                     │   │
│  └────────┬────────────────────────────────────────┘   │
│           │                                             │
│  ┌────────▼────────────────────────────────────────┐   │
│  │    tracking_plan_style_timeline                 │   │
│  └────────┬────────────────────────────────────────┘   │
│           │                                             │
│  ┌────────▼────────────────────────────────────────┐   │
│  │    tracking_timeline_assignment                 │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Event-Specific Flows

#### OnCreate Flow
```
1. Webhook received with full timeline data
2. Extract planId, check ops.tracking_plan
   ├─ NOT EXISTS → Call planGet API → Insert to tracking_plan
   └─ EXISTS → Skip
3. Extract folderId (from plan), check ops.tracking_folder
   ├─ NOT EXISTS → Call folderList API → Insert to tracking_folder
   └─ EXISTS → Skip
4. Upsert to tracking_plan_style
   - style_id (generate new if not exists)
   - style_header_id (from webhook)
   - color_id (from webhook)
   - style_number, style_name (from webhook)
   - plan_id
5. For each timeline milestone in webhook:
   - Upsert to tracking_plan_style_timeline
   - timeline_id = Id (instance ID from webhook)
   - template_item_id = TimeLineId (template milestone ID)
   - status, plan_date, rev_date, final_date, due_date, late
6. For each assignedTo user:
   - Insert to tracking_timeline_assignment
7. Log to beproduct_sync_log
```

#### OnChange Flow
```
1. Webhook received with before/after states
2. Extract timeline instance ID
3. Find existing record in tracking_plan_style_timeline
4. Update changed fields:
   - status (if changed)
   - rev_date (if changed)
   - final_date (if changed)
   - late flag (if changed)
5. Compare assignedTo arrays:
   - Delete removed assignments
   - Insert new assignments
6. Compare shareWith arrays:
   - Update shared_with JSONB column
7. Log to beproduct_sync_log
```

#### OnDelete Flow
```
1. Webhook received with before state
2. Extract timeline record ID (data.before.Id)
3. Soft delete:
   - UPDATE tracking_plan_style SET active = false
   - WHERE id = timeline_record_id
4. Keep all timeline data for audit trail
5. Log to beproduct_sync_log
```

---

## Field Mapping

### Webhook → Supabase Table Mapping

#### tracking_plan

| Webhook Field | Supabase Column | Source | Notes |
|--------------|----------------|--------|-------|
| `data.planId` | `id` | Webhook | UUID primary key |
| N/A (API call) | `name` | `planGet` API | Plan name |
| N/A (API call) | `start_date` | `planGet` API | Plan start date |
| N/A (API call) | `end_date` | `planGet` API | Plan end date |
| N/A (API call) | `folder_id` | `planGet` API | Parent folder ID |
| N/A (API call) | `template_id` | `planGet` API | Timeline template ID |
| `data.planFolderId` | - | Webhook | (Not used directly) |
| - | `raw_payload` | Webhook | Store full `planGet` response |

#### tracking_folder

| Webhook Field | Supabase Column | Source | Notes |
|--------------|----------------|--------|-------|
| `data.planFolderId` | `id` | Webhook | UUID primary key |
| `folderName` | `name` | Webhook | Folder name |
| N/A (infer) | `brand` | Infer from name | Extract from folder name |
| N/A | `style_folder_id` | NULL | Not in webhook |
| N/A | `style_folder_name` | NULL | Not in webhook |
| - | `raw_payload` | Webhook | Store full folder data |

#### tracking_plan_style

| Webhook Field | Supabase Column | Source | Notes |
|--------------|----------------|--------|-------|
| `data.after.Id` | `id` | Webhook | Timeline record ID (UUID) |
| `data.after.PlanId` | `plan_id` | Webhook | Foreign key to tracking_plan |
| `headerId` | `style_header_id` | Webhook | BeProduct style header ID |
| `data.after.Color._id` | `color_id` | Webhook | BeProduct color ID |
| `headerNumber` | `style_number` | Webhook | Style number (MSP26O73) |
| `headerName` | `style_name` | Webhook | Style name |
| `data.after.Color.suggested_name` | `color_name` | Webhook | Color name |
| N/A | `season` | NULL | Not in webhook |
| N/A | `delivery` | NULL | Not in webhook |
| N/A | `factory` | NULL | Not in webhook |
| `data.after.Supplier[0]` | `supplier_name` | Webhook | First supplier (if array) |
| - | `active` | TRUE | Default active on create |

#### tracking_plan_style_timeline

| Webhook Field | Supabase Column | Source | Notes |
|--------------|----------------|--------|-------|
| `Timelines[].Id` | `id` | Webhook | Timeline instance ID |
| `data.after.Id` | `plan_style_id` | Webhook | FK to tracking_plan_style |
| `Timelines[].TimeLineId` | `template_item_id` | Webhook | Template milestone ID |
| `Timelines[].Status` | `status` | Webhook | Map to enum (see below) |
| `Timelines[].ProjectDate` | `plan_date` | Webhook | Original baseline date |
| `Timelines[].Rev` | `rev_date` | Webhook | Revised date (nullable) |
| `Timelines[].Final` | `final_date` | Webhook | Completion date (nullable) |
| `Timelines[].DueDate` | `due_date` | Webhook | Current due date |
| `Timelines[].Late` | `late` | Webhook | Late flag |
| N/A | `notes` | NULL | Not in webhook |
| N/A | `page_id` | NULL | Not in webhook |
| N/A | `page_name` | NULL | Not in webhook |
| N/A | `page_type` | NULL | Not in webhook |
| `Timelines[].SubmitsQuantity` | - | Webhook | (No column yet) |

**Status Enum Mapping:**
| BeProduct Status | Supabase Enum |
|-----------------|---------------|
| "Not Started" | `NOT_STARTED` |
| "In Progress" | `IN_PROGRESS` |
| "Approved" | `APPROVED` |
| "Waiting On" | `BLOCKED` |
| "Rejected" | `REJECTED` |
| "Approved with Corrections" | `APPROVED` |
| "N/A" | `NOT_STARTED` |

#### tracking_timeline_assignment

| Webhook Field | Supabase Column | Source | Notes |
|--------------|----------------|--------|-------|
| `Timelines[].Id` | `timeline_id` | Webhook | FK to timeline |
| `AssignedTo[].code` | `assignee_id` | Webhook | User UUID |
| `user.id` | `source_user_id` | Webhook | Who assigned |
| N/A | `role_name` | NULL | Not in webhook |
| N/A | `role_id` | NULL | Not in webhook |

---

## Implementation Strategy

### Edge Function Structure

```typescript
// supabase/functions/beproduct-tracking-webhook/index.ts

import { serve } from "std/server";
import { createClient } from "@supabase/supabase-js";

interface WebhookPayload {
  eventType: "OnCreate" | "OnChange" | "OnDelete";
  objectType: string;
  headerId: string;
  headerNumber: string;
  headerName: string;
  folderId: string;
  folderName: string;
  data: {
    before?: any;
    after?: any;
    planId: string;
    planFolderId: string;
    timelineId?: string;
    timeLineSchema?: any;
  };
  user: {
    id: string;
    userName: string;
  };
  date: string;
}

serve(async (req: Request) => {
  try {
    // 1. Authenticate webhook (verify signature or token)
    const authHeader = req.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response("Unauthorized", { status: 401 });
    }

    // 2. Parse webhook payload
    const payload: WebhookPayload = await req.json();
    
    // 3. Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 4. Route to appropriate handler
    switch (payload.eventType) {
      case "OnCreate":
        await handleOnCreate(supabaseClient, payload);
        break;
      case "OnChange":
        await handleOnChange(supabaseClient, payload);
        break;
      case "OnDelete":
        await handleOnDelete(supabaseClient, payload);
        break;
      default:
        console.warn(`Unknown event type: ${payload.eventType}`);
    }

    // 5. Log sync
    await logSync(supabaseClient, payload);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    );
  }
});
```

### Handler Functions

#### handleOnCreate
```typescript
async function handleOnCreate(client, payload) {
  // 1. Ensure plan exists
  const planId = payload.data.planId;
  const planExists = await checkPlanExists(client, planId);
  
  if (!planExists) {
    const planData = await fetchPlanFromBeProduct(planId);
    await upsertPlan(client, planData);
  }

  // 2. Ensure folder exists
  const folderId = payload.data.planFolderId;
  const folderExists = await checkFolderExists(client, folderId);
  
  if (!folderExists) {
    await upsertFolder(client, {
      id: folderId,
      name: payload.folderName,
      brand: extractBrand(payload.folderName),
    });
  }

  // 3. Upsert style record
  await upsertPlanStyle(client, {
    id: payload.data.after.Id,
    plan_id: planId,
    style_header_id: payload.headerId,
    color_id: payload.data.after.Color._id,
    style_number: payload.headerNumber,
    style_name: payload.headerName,
    color_name: payload.data.after.Color.suggested_name,
    active: true,
  });

  // 4. Upsert timeline milestones
  for (const timeline of payload.data.after.Timelines) {
    await upsertTimeline(client, {
      id: timeline.Id,
      plan_style_id: payload.data.after.Id,
      template_item_id: timeline.TimeLineId,
      status: mapStatus(timeline.Status),
      plan_date: timeline.ProjectDate,
      rev_date: timeline.Rev,
      final_date: timeline.Final,
      due_date: timeline.DueDate,
      late: timeline.Late,
    });

    // 5. Handle assignments
    await syncAssignments(client, timeline.Id, timeline.AssignedTo);
  }
}
```

#### handleOnChange
```typescript
async function handleOnChange(client, payload) {
  const timelineId = payload.data.after.TimeLineItem.Id;
  const before = payload.data.before.TimeLineItem;
  const after = payload.data.after.TimeLineItem;

  // 1. Update timeline record
  const updates: any = {};
  
  if (before.Status !== after.Status) {
    updates.status = mapStatus(after.Status);
  }
  if (before.Rev !== after.Rev) {
    updates.rev_date = after.Rev;
  }
  if (before.Final !== after.Final) {
    updates.final_date = after.Final;
  }
  if (before.Late !== after.Late) {
    updates.late = after.Late;
  }

  if (Object.keys(updates).length > 0) {
    await client
      .from("ops.tracking_plan_style_timeline")
      .update(updates)
      .eq("id", timelineId);
  }

  // 2. Sync assignments
  await syncAssignments(client, timelineId, after.AssignedTo);

  // 3. Update shareWith
  await client
    .from("ops.tracking_plan_style_timeline")
    .update({ shared_with: after.ShareWith || [] })
    .eq("id", timelineId);
}
```

#### handleOnDelete
```typescript
async function handleOnDelete(client, payload) {
  const recordId = payload.data.before.Id;

  // Soft delete
  await client
    .from("ops.tracking_plan_style")
    .update({ active: false })
    .eq("id", recordId);
}
```

---

## Phase 1: Webhook Sync

### Deliverables
- [x] Webhook analysis complete
- [x] Field mapping documented
- [ ] Edge function implemented
- [ ] Helper functions (checkPlanExists, fetchPlanFromBeProduct, etc.)
- [ ] Status enum mapper
- [ ] Assignment sync logic
- [ ] Error handling and logging
- [ ] Deployment to Supabase
- [ ] Webhook registration in BeProduct
- [ ] End-to-end testing

### Implementation Steps

#### Step 1: Create Edge Function
```bash
cd supabase/functions
mkdir beproduct-tracking-webhook
touch beproduct-tracking-webhook/index.ts
```

#### Step 2: Implement Core Logic
- Parse webhook payload
- Route by event type
- Call appropriate handler

#### Step 3: Implement Helper Functions
- `checkPlanExists(client, planId): Promise<boolean>`
- `checkFolderExists(client, folderId): Promise<boolean>`
- `fetchPlanFromBeProduct(planId): Promise<PlanData>`
- `fetchFolderFromBeProduct(folderId): Promise<FolderData>`
- `upsertPlan(client, planData): Promise<void>`
- `upsertFolder(client, folderData): Promise<void>`
- `upsertPlanStyle(client, styleData): Promise<void>`
- `upsertTimeline(client, timelineData): Promise<void>`
- `syncAssignments(client, timelineId, assignedTo): Promise<void>`
- `mapStatus(beproductStatus): TimelineStatus`
- `extractBrand(folderName): string`
- `logSync(client, payload): Promise<void>`

#### Step 4: Add Error Handling
- Try-catch blocks
- Retry logic for API calls
- Log to `ops.import_errors` on failure

#### Step 5: Deploy Function
```bash
supabase functions deploy beproduct-tracking-webhook
```

#### Step 6: Register Webhook in BeProduct
- URL: `https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook`
- Events: OnCreate, OnChange, OnDelete
- Object Type: Header (Style)
- Authentication: Bearer token

#### Step 7: Test with Real Data
- Trigger OnCreate (add style to plan)
- Trigger OnChange (update milestone)
- Trigger OnDelete (remove style from plan)
- Validate data in Supabase tables

---

## Phase 2: Enhancements & Reverse Sync

### Objectives
1. Enhance tracking tables with design elements (start_dates, duration)
2. Build reciprocal API endpoints in Supabase
3. Create reverse sync edge function (Supabase → BeProduct)

### Enhancements

#### 1. Add Start Dates and Duration
```sql
-- Already exists in tracking_plan_style_timeline
ALTER TABLE ops.tracking_plan_style_timeline
  ADD COLUMN IF NOT EXISTS start_date_plan DATE,
  ADD COLUMN IF NOT EXISTS start_date_due DATE,
  ADD COLUMN IF NOT EXISTS duration_value INTEGER,
  ADD COLUMN IF NOT EXISTS duration_unit ops.offset_unit_enum DEFAULT 'DAYS';
```

#### 2. Build Supabase API Endpoints
Per `endpoint-design.md`:
- `GET /api/v1/tracking/timeline/style/{style_id}`
- `GET /api/v1/tracking/plans/{plan_id}/timeline`
- `GET /api/v1/tracking/plans/{plan_id}/progress`
- `PATCH /api/v1/tracking/timeline/bulk`
- `PATCH /api/v1/tracking/timeline/node/{node_id}`
- `POST /api/v1/tracking/timeline/node/{node_id}/assignments`
- `GET /api/v1/tracking/users/{user_id}/assignments`
- `GET /api/v1/tracking/plans/{plan_id}/critical-path`

#### 3. Create Reverse Sync Edge Function
```typescript
// supabase/functions/tracking-update-to-beproduct/index.ts

serve(async (req: Request) => {
  // 1. Receive update from Supabase frontend
  const { timeline_id, updates } = await req.json();

  // 2. Fetch timeline record from database
  const timeline = await fetchTimeline(timeline_id);

  // 3. Call BeProduct API to update
  const result = await updateBeProductTimeline(timeline.plan_id, {
    timelineId: timeline_id,
    status: updates.status,
    revDate: updates.rev_date,
    finalDate: updates.final_date,
  });

  // 4. Return result
  return new Response(JSON.stringify({ ok: true, result }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

#### 4. Implement Database Triggers
- Trigger on `tracking_plan_style_timeline` UPDATE
- Call reverse sync edge function
- Handle conflicts (optimistic locking)

### Deliverables (Phase 2)
- [ ] Start dates calculated for all timelines
- [ ] Duration fields populated
- [ ] 8+ API endpoints implemented
- [ ] Reverse sync edge function created
- [ ] Database triggers for auto-sync
- [ ] Conflict resolution strategy
- [ ] End-to-end bidirectional sync tested

---

## Testing Plan

### Unit Tests
- [ ] Status enum mapper
- [ ] Date parsing and formatting
- [ ] Field extraction from webhook
- [ ] Assignment sync logic

### Integration Tests
- [ ] OnCreate with new plan (API call triggered)
- [ ] OnCreate with existing plan (no API call)
- [ ] OnChange with status update
- [ ] OnChange with date update
- [ ] OnChange with assignment change
- [ ] OnDelete soft delete

### End-to-End Tests
1. **Scenario 1: New Style Added**
   - Add style to plan in BeProduct
   - Verify webhook received
   - Verify plan fetched from API
   - Verify folder fetched from API
   - Verify style record created
   - Verify 24 timeline records created
   - Verify assignments synced

2. **Scenario 2: Milestone Updated**
   - Update milestone status in BeProduct
   - Verify webhook received
   - Verify timeline record updated
   - Verify assignments synced
   - Verify no API calls made

3. **Scenario 3: Style Removed**
   - Remove style from plan in BeProduct
   - Verify webhook received
   - Verify style marked inactive
   - Verify timeline data preserved

### Performance Tests
- [ ] Webhook processing time < 2 seconds
- [ ] API call caching works (no duplicate calls)
- [ ] Bulk create (24 timelines) completes in < 5 seconds
- [ ] Concurrent webhooks handled correctly

---

## Deployment Checklist

### Pre-Deployment
- [ ] Code reviewed
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Edge function deployed to staging
- [ ] Staging tests completed
- [ ] Documentation updated

### Deployment
- [ ] Deploy edge function to production
  ```bash
  supabase functions deploy beproduct-tracking-webhook --project-ref [prod-ref]
  ```
- [ ] Configure environment variables
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `BEPRODUCT_API_URL`
  - `BEPRODUCT_CLIENT_ID`
  - `BEPRODUCT_CLIENT_SECRET`
- [ ] Register webhook in BeProduct
  - URL: Production edge function URL
  - Events: OnCreate, OnChange, OnDelete
  - Authentication: Bearer token
- [ ] Enable webhook in BeProduct UI
- [ ] Monitor initial webhooks

### Post-Deployment
- [ ] Monitor error logs (first 24 hours)
- [ ] Validate data accuracy (spot check 10 styles)
- [ ] Check sync log entries
- [ ] Verify no duplicate records
- [ ] Confirm API call caching working
- [ ] Performance metrics within SLA

### Rollback Plan
If critical issues detected:
1. Disable webhook in BeProduct UI (stop new events)
2. Investigate error logs
3. Fix issue in code
4. Redeploy edge function
5. Re-enable webhook
6. Backfill missed events (if needed)

---

## Success Metrics

### Phase 1
- ✅ Webhook processing success rate > 99%
- ✅ Average webhook processing time < 2 seconds
- ✅ Zero data loss (all events logged)
- ✅ API call cache hit rate > 90% (plans/folders)
- ✅ Zero duplicate records created
- ✅ 100% of timeline fields mapped correctly

### Phase 2
- ✅ Bidirectional sync working (Supabase ↔ BeProduct)
- ✅ API endpoints return data in < 500ms
- ✅ Critical path calculation < 1 second
- ✅ Start dates calculated for 100% of timelines
- ✅ Conflict resolution working (no data loss)

---

## Risk Assessment

### High Risk
1. **API Rate Limiting**
   - Mitigation: Cache plan/folder data, batch API calls
2. **Webhook Replay**
   - Mitigation: Idempotent upserts, check created_at timestamps
3. **Data Consistency**
   - Mitigation: Use transactions, log all changes

### Medium Risk
1. **Webhook Delivery Failures**
   - Mitigation: BeProduct will retry, log failures for manual reconciliation
2. **Schema Mismatches**
   - Mitigation: Validate webhook payload against expected schema
3. **Performance Degradation**
   - Mitigation: Optimize queries, add indexes, monitor performance

### Low Risk
1. **Edge Function Cold Starts**
   - Impact: First webhook may be slow (< 5% of requests)
   - Mitigation: Keep function warm with health check pings

---

## Appendices

### A. Status Enum Reference
```typescript
const STATUS_MAP: Record<string, string> = {
  "Not Started": "NOT_STARTED",
  "In Progress": "IN_PROGRESS",
  "Approved": "APPROVED",
  "Waiting On": "BLOCKED",
  "Rejected": "REJECTED",
  "Approved with Corrections": "APPROVED",
  "N/A": "NOT_STARTED",
  "Complete": "COMPLETE",
};
```

### B. Required Database Indexes
```sql
-- Optimize webhook processing
CREATE INDEX IF NOT EXISTS idx_tracking_plan_id ON ops.tracking_plan(id);
CREATE INDEX IF NOT EXISTS idx_tracking_folder_id ON ops.tracking_folder(id);
CREATE INDEX IF NOT EXISTS idx_tracking_plan_style_id ON ops.tracking_plan_style(id);
CREATE INDEX IF NOT EXISTS idx_tracking_plan_style_plan_id ON ops.tracking_plan_style(plan_id);
CREATE INDEX IF NOT EXISTS idx_tracking_plan_style_timeline_id ON ops.tracking_plan_style_timeline(id);
CREATE INDEX IF NOT EXISTS idx_tracking_plan_style_timeline_plan_style_id ON ops.tracking_plan_style_timeline(plan_style_id);
```

### C. Sync Log Schema
```sql
-- ops.beproduct_sync_log already exists
-- Columns: id, batch_id, entity_type, entity_id, action, processed_at, payload
```

---

**Document Status:** ✅ Ready for Implementation  
**Last Updated:** November 6, 2025  
**Version:** 1.0  
**Next Review:** After Phase 1 completion
