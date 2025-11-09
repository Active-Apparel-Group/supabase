---
name: 02a-Tracking API Progress Endpoints
about: Create edge functions for plan progress and aggregations
title: '[02a-Tracking] Create edge functions for plan progress and aggregations'
labels: ['phase-02a-tracking', 'edge-function', 'api']
assignees: ''
---

## Context
Frontend needs plan progress metrics (completion %, late count, status breakdown). PostgREST can't efficiently aggregate across tables.

## Required Edge Functions

### 1. Plan Progress Function

**File:** `supabase/functions/tracking-plan-progress/index.ts`

**Endpoint:** `GET /functions/v1/tracking-plan-progress?plan_id={uuid}`

**Response Example:**
```json
{
  "plan_id": "162eedf3-0230-4e4c-88e1-6db332e3707b",
  "plan_name": "GREYSON 2026 SPRING DROP 1",
  "folder_id": "82a698e1-9103-4bab-98af-a0ec423332a2",
  "folder_name": "GREYSON MENS",
  "start_date": "2025-05-01",
  "end_date": "2026-01-05",
  "total_milestones": 125,
  "by_status": {
    "NOT_STARTED": 109,
    "IN_PROGRESS": 11,
    "WAITING_ON": 0,
    "REJECTED": 0,
    "APPROVED": 5,
    "APPROVED_WITH_CORRECTIONS": 0,
    "NA": 0
  },
  "late_count": 10,
  "on_time_count": 115,
  "completion_percentage": 4.0,
  "by_entity_type": {
    "style": {
      "total": 75,
      "late": 8,
      "completed": 5,
      "completion_percentage": 6.67
    },
    "material": {
      "total": 50,
      "late": 2,
      "completed": 0,
      "completion_percentage": 0.0
    }
  },
  "by_phase": {
    "DEVELOPMENT": {
      "total": 50,
      "late": 5,
      "completed": 5
    },
    "SMS": {
      "total": 30,
      "late": 3,
      "completed": 0
    },
    "PRODUCTION": {
      "total": 25,
      "late": 2,
      "completed": 0
    },
    "SHIPPING": {
      "total": 20,
      "late": 0,
      "completed": 0
    }
  }
}
```

**Implementation:**
```typescript
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const url = new URL(req.url);
  const planId = url.searchParams.get("plan_id");

  if (!planId) {
    return new Response(
      JSON.stringify({ error: "plan_id parameter required" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    // Get plan details
    const { data: plan, error: planError } = await supabaseClient
      .from("tracking_plan")
      .select("*, tracking_folder(id, name)")
      .eq("id", planId)
      .single();

    if (planError) throw planError;

    // Get style timeline aggregates
    const { data: styleTimelines } = await supabaseClient
      .from("tracking_plan_style_timeline")
      .select(`
        id,
        status,
        late,
        phase,
        tracking_plan_style!inner(plan_id)
      `)
      .eq("tracking_plan_style.plan_id", planId);

    // Calculate aggregates
    const statusCounts = {};
    let lateCount = 0;
    const phaseCounts = {};

    styleTimelines?.forEach((timeline) => {
      // Status counts
      statusCounts[timeline.status] = (statusCounts[timeline.status] || 0) + 1;
      
      // Late count
      if (timeline.late) lateCount++;
      
      // Phase counts
      if (!phaseCounts[timeline.phase]) {
        phaseCounts[timeline.phase] = { total: 0, late: 0, completed: 0 };
      }
      phaseCounts[timeline.phase].total++;
      if (timeline.late) phaseCounts[timeline.phase].late++;
      if (timeline.status === "APPROVED") phaseCounts[timeline.phase].completed++;
    });

    const totalMilestones = styleTimelines?.length || 0;
    const completedCount = statusCounts["APPROVED"] || 0;
    const completionPercentage = totalMilestones > 0 
      ? (completedCount / totalMilestones) * 100 
      : 0;

    return new Response(
      JSON.stringify({
        plan_id: planId,
        plan_name: plan.name,
        folder_id: plan.folder_id,
        folder_name: plan.tracking_folder.name,
        start_date: plan.start_date,
        end_date: plan.end_date,
        total_milestones: totalMilestones,
        by_status: statusCounts,
        late_count: lateCount,
        on_time_count: totalMilestones - lateCount,
        completion_percentage: Math.round(completionPercentage * 10) / 10,
        by_phase: phaseCounts,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("Error fetching plan progress:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

### 2. Folder Progress Function

**File:** `supabase/functions/tracking-folder-progress/index.ts`

**Endpoint:** `GET /functions/v1/tracking-folder-progress?folder_id={uuid}`

**Response:** Aggregates across all plans in folder (similar structure to plan progress)

### 3. User Workload Function

**File:** `supabase/functions/tracking-user-workload/index.ts`

**Endpoint:** `GET /functions/v1/tracking-user-workload?user_id={uuid}`

**Response Example:**
```json
{
  "user_id": "user-uuid",
  "user_name": "Natalie James",
  "total_assigned": 45,
  "by_status": {
    "NOT_STARTED": 30,
    "IN_PROGRESS": 10,
    "APPROVED": 5
  },
  "late_count": 12,
  "due_this_week": 8,
  "assignments": [
    {
      "timeline_id": "timeline-uuid",
      "plan_id": "plan-uuid",
      "plan_name": "GREYSON 2026 SPRING DROP 1",
      "style_number": "MSP26B26",
      "color_name": "220 - GROVE",
      "milestone_name": "PROTO PRODUCTION",
      "phase": "DEVELOPMENT",
      "department": "PD",
      "due_date": "2025-09-16",
      "status": "IN_PROGRESS",
      "is_late": true
    }
  ]
}
```

## Deployment

```bash
# Deploy all three functions
cd supabase
npx supabase functions deploy tracking-plan-progress --no-verify-jwt
npx supabase functions deploy tracking-folder-progress --no-verify-jwt
npx supabase functions deploy tracking-user-workload --no-verify-jwt
```

## Testing

### Test Plan Progress
```bash
curl "https://[project-id].supabase.co/functions/v1/tracking-plan-progress?plan_id=162eedf3-0230-4e4c-88e1-6db332e3707b" \
  -H "Authorization: Bearer [anon-key]"
```

### Test Folder Progress
```bash
curl "https://[project-id].supabase.co/functions/v1/tracking-folder-progress?folder_id=82a698e1-9103-4bab-98af-a0ec423332a2" \
  -H "Authorization: Bearer [anon-key]"
```

### Test User Workload
```bash
curl "https://[project-id].supabase.co/functions/v1/tracking-user-workload?user_id=[user-uuid]" \
  -H "Authorization: Bearer [anon-key]"
```

### Validate Aggregation Accuracy
```sql
-- Manual verification query for plan progress
SELECT 
  status,
  COUNT(*) as count,
  SUM(CASE WHEN late THEN 1 ELSE 0 END) as late_count
FROM tracking_plan_style_timeline t
JOIN tracking_plan_style s ON t.plan_style_id = s.id
WHERE s.plan_id = '162eedf3-0230-4e4c-88e1-6db332e3707b'
GROUP BY status;
```

## Success Criteria
- [ ] All 3 edge functions created
- [ ] All 3 functions deployed successfully
- [ ] Response times < 500ms for typical plan
- [ ] Aggregation accuracy validated (100% match with SQL queries)
- [ ] CORS headers correct (allow all origins)
- [ ] Error handling comprehensive (400 for bad params, 500 for server errors)
- [ ] Functions work with empty plans (return zeros)
- [ ] Functions work with large plans (100+ styles)
- [ ] All endpoints documented in API reference

## Performance Targets
- **Plan Progress:** < 500ms for plans with 100-200 milestones
- **Folder Progress:** < 1 second for folders with 3-5 plans
- **User Workload:** < 500ms for users with 50-100 assignments

## Dependencies
- **Depends on:** #[enable CRUD issue] - Need access to tracking tables
- **Blocks:** Frontend dashboard development

## Related Documentation
- [Endpoint Design](../docs/supabase/supabase-beproduct-migration/02-timeline/docs/endpoint-design.md)
- [Supabase Edge Functions Guide](https://supabase.com/docs/guides/functions)
