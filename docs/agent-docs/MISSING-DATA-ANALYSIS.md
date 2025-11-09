...existing code...
# Missing Data Analysis: BeProduct Tracking Webhook

## Summary of Findings

### ✅ What We're Currently Storing
- Timeline milestone IDs (`template_item_id`)
- Status, dates (plan, rev, final, due, completed)
- Late flag
- Page type enum, page ID, request ID/code/status
- Notes
- Shared with (JSONB array)
- Duration value/unit
- Customer/supplier visibility flags

### ❌ What We're NOT Storing (but should be)

#### **1. Milestone Identity** (CRITICAL - NO WAY TO DISPLAY MILESTONE NAMES!)
- `milestone_name` - Full task description (e.g., "PROTO PRODUCTION", "LAB DIP APPROVAL CUT OFF")
- `milestone_short_name` - Short description (same as full in most cases)
- `department` - Department responsible (e.g., "PRE-PRODUCTION | PD", "CUSTOMER", "ALLOCATION")
- `milestone_page_name` - Associated page name (e.g., "Proto Sample", "Tech Pack", "Lab Dip")

**Impact:** Currently IMPOSSIBLE to display milestone names without joining to template table. BeProduct sends these in EVERY webhook payload but we're discarding them.

#### **2. Milestone Configuration** (Important for date calculations)
From `TimelineSchema` in webhook payload `data.timeLineSchema`:
- `offset_days` (Days) - Offset from predecessor
- `calendar_days` (CalendarDays) - Calendar-based duration
- `calendar_name` (Calendar) - Calendar system
- `group_task` (GroupTask) - Task grouping
- `when_rule` (When) - Timing activation rule
- `share_when_rule` (ShareWhen) - External sharing timing
- `activity_description` (ActDesc) - Detailed activity notes
- `revised_days` (RevisedDays) - Schedule adjustments
- `default_status` (DefaultStatus) - Initial status
- `auto_share_linked_page` (AutoShareLinkedPage) - Auto-link behavior
- `sync_with_group_task` (SyncWithGroupTask) - Group sync flag
- `external_share_with` (ExternalShareWith) - Default external parties

**Impact:** Missing business logic for date calculations, grouping, and sharing rules.

#### **3. Plan Views** (Not populated)
From Plan API `/api/{company}/Tracking/Plan/{planId}`:
- Style views (Allocations, Production, Logistics, Sample Tracking)
- Material views (Purchase Material, Material Sample Tracking)

**Impact:** `tracking_plan_view` table exists but empty. No way to filter timelines by view context.

## Webhook Payload Structure

### OnCreate/OnChange Payload
```json
{
  "eventType": "OnCreate",
  "data": {
    "after": {
      "Timelines": [
        {
          "Id": "timeline-uuid",
          "TimeLineId": "template-item-uuid",  // What we store as template_item_id
          "Status": "Not Started",
          "DueDate": "2025-11-05T18:52:05Z",
          "ProjectDate": "2025-11-05T18:52:05Z",
          "AssignedTo": [],
          "ShareWith": []
        }
      ]
    },
    "timeLineSchema": {  // NOT STORED - CRITICAL METADATA!
      "Id": "template-item-uuid",
      "Department": "PRE-PRODUCTION | PD",
      "TaskDescription": "PROTO PRODUCTION",
      "ShortDescription": "PROTO PRODUCTION",
      "Page": "Proto Sample",
      "Days": 4,
      "CalendarDays": 4,
      "Calendar": "US Business Days",
      "GroupTask": "Proto",
      "When": "AFTER",
      "ActDesc": "Production phase for prototype",
      "RevisedDays": 0,
      "ShareWhen": "ON_COMPLETE",
      "SharedPermission": "VIEW",
      "DefaultStatus": "Not Started",
      "ExternalShareWith": [],
      "AutoShareLinkedPage": true,
      "SyncWithGroupTask": false
    }
  }
}
```

### Plan API Response
```json
{
  "id": "plan-uuid",
  "name": "TEST AAAA",
  "style": {
    "views": [
      {"id": "view-uuid", "name": "Allocations", "description": "...", "active": true},
      {"id": "view-uuid", "name": "Production", "description": "...", "active": true}
    ],
    "timelines": [
      {
        "id": "template-item-uuid",
        "department": "PRE-PRODUCTION | PD",
        "actionDescription": "PROTO PRODUCTION",
        "shortDescription": "PROTO PRODUCTION",
        "pageName": "Proto Sample"
      }
    ]
  },
  "material": {
    "views": [...],
    "timelines": [...]
  }
}
```

## Database Schema Gaps

### FIXED (Migration 013)
Added to `tracking_plan_style_timeline` and `tracking_plan_material_timeline`:
- milestone_name TEXT
- milestone_short_name TEXT
- department TEXT
- milestone_page_name TEXT
- offset_days INTEGER
- calendar_days INTEGER
- calendar_name TEXT
- group_task TEXT
- when_rule TEXT
- share_when_rule TEXT
- activity_description TEXT
- revised_days INTEGER
- default_status TEXT
- auto_share_linked_page BOOLEAN
- sync_with_group_task BOOLEAN
- external_share_with JSONB

### TODO (Edge Function Updates)
1. **beproduct-tracking-webhook** - Extract and store milestone metadata
   - Map TimelineSchema fields to new columns
   - Handle both OnCreate (has timeLineSchema) and OnChange (may not have schema)
   
2. **Plan view population** - Fetch and store views
   - Call Plan API to get view definitions
   - Populate tracking_plan_view table
   - Link plan_styles and plan_materials to views

## Recommended Next Steps

1. ✅ Apply migration 013 (DONE)
2. 🔄 Update `beproduct-tracking-webhook/index.ts`:
   - Add TimelineSchema interface to types
   - Extract department, TaskDescription, ShortDescription, Page from schema
   - Extract all metadata fields (Days, Calendar, etc.)
   - Store in new columns during timeline upsert
3. 🔄 Add view population logic:
   - Fetch plan details when plan is created
   - Upsert style/material views
   - Associate timelines with views (if view context available)

## Testing Plan

1. Trigger OnCreate webhook with existing payload
2. Verify milestone names populated in database
3. Query timeline without template join to confirm names visible
4. Verify date calculation metadata stored correctly
