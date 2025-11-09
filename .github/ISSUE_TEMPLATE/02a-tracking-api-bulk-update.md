---
name: 02a-Tracking API Bulk Update Endpoint
about: Create edge function for bulk milestone updates
title: '[02a-Tracking] Create edge function for bulk milestone updates'
labels: ['phase-02a-tracking', 'edge-function', 'api']
assignees: ''
---

## Context
Frontend needs to update multiple milestones in a single operation (e.g., approve all SMS milestones, bulk status updates).

## Required Edge Function

**File:** `supabase/functions/tracking-bulk-update/index.ts`

**Endpoint:** `POST /functions/v1/tracking-bulk-update`

### Request Body
```json
{
  "updates": [
    {
      "timeline_id": "timeline-uuid-1",
      "status": "IN_PROGRESS",
      "rev_date": "2025-11-15",
      "notes": "Started proto production"
    },
    {
      "timeline_id": "timeline-uuid-2",
      "status": "APPROVED",
      "final_date": "2025-11-01"
    },
    {
      "timeline_id": "timeline-uuid-3",
      "status": "NA"
    }
  ],
  "updated_by": "user-uuid",
  "bulk_action_note": "Bulk approve all Development milestones"
}
```

### Response
```json
{
  "success": true,
  "updated_count": 3,
  "failed_count": 0,
  "errors": [],
  "updates": [
    {
      "timeline_id": "timeline-uuid-1",
      "old_status": "NOT_STARTED",
      "new_status": "IN_PROGRESS",
      "old_due_date": null,
      "new_due_date": "2025-11-15",
      "success": true
    },
    {
      "timeline_id": "timeline-uuid-2",
      "old_status": "IN_PROGRESS",
      "new_status": "APPROVED",
      "old_due_date": "2025-11-05",
      "new_due_date": "2025-11-01",
      "success": true
    },
    {
      "timeline_id": "timeline-uuid-3",
      "old_status": "NOT_STARTED",
      "new_status": "NA",
      "success": true
    }
  ]
}
```

### Error Response Example
```json
{
  "success": false,
  "updated_count": 2,
  "failed_count": 1,
  "errors": [
    {
      "timeline_id": "invalid-uuid",
      "error": "Timeline not found"
    }
  ],
  "updates": [
    {
      "timeline_id": "timeline-uuid-1",
      "success": true
    },
    {
      "timeline_id": "timeline-uuid-2",
      "success": true
    },
    {
      "timeline_id": "invalid-uuid",
      "success": false,
      "error": "Timeline not found"
    }
  ]
}
```

## Implementation

```typescript
import { createClient } from "jsr:@supabase/supabase-js@2";

interface UpdateRequest {
  timeline_id: string;
  status?: string;
  rev_date?: string;
  final_date?: string;
  due_date?: string;
  notes?: string;
}

interface BulkUpdateRequest {
  updates: UpdateRequest[];
  updated_by: string;
  bulk_action_note?: string;
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  try {
    const body: BulkUpdateRequest = await req.json();
    
    if (!body.updates || !Array.isArray(body.updates) || body.updates.length === 0) {
      return new Response(
        JSON.stringify({ error: "updates array is required and must not be empty" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (body.updates.length > 100) {
      return new Response(
        JSON.stringify({ error: "Maximum 100 updates per request" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const results = [];
    let successCount = 0;
    let failureCount = 0;
    const errors = [];

    // Process each update
    for (const update of body.updates) {
      try {
        // Fetch current state
        const { data: current, error: fetchError } = await supabaseClient
          .from("tracking_plan_style_timeline")
          .select("*")
          .eq("id", update.timeline_id)
          .single();

        if (fetchError || !current) {
          failureCount++;
          errors.push({
            timeline_id: update.timeline_id,
            error: "Timeline not found"
          });
          results.push({
            timeline_id: update.timeline_id,
            success: false,
            error: "Timeline not found"
          });
          continue;
        }

        // Build update object
        const updateData: any = {
          updated_at: new Date().toISOString(),
          updated_by: body.updated_by,
        };

        if (update.status) updateData.status = update.status;
        if (update.rev_date) updateData.rev_date = update.rev_date;
        if (update.final_date) updateData.final_date = update.final_date;
        if (update.due_date) updateData.due_date = update.due_date;

        // Perform update
        const { error: updateError } = await supabaseClient
          .from("tracking_plan_style_timeline")
          .update(updateData)
          .eq("id", update.timeline_id);

        if (updateError) {
          failureCount++;
          errors.push({
            timeline_id: update.timeline_id,
            error: updateError.message
          });
          results.push({
            timeline_id: update.timeline_id,
            success: false,
            error: updateError.message
          });
          continue;
        }

        // Log to status history (if table exists)
        if (update.status && update.status !== current.status) {
          await supabaseClient
            .from("tracking_timeline_status_history")
            .insert({
              timeline_id: update.timeline_id,
              old_status: current.status,
              new_status: update.status,
              changed_by: body.updated_by,
              changed_at: new Date().toISOString(),
              notes: update.notes || body.bulk_action_note,
            })
            .catch((err) => console.warn("Failed to log status history:", err));
        }

        successCount++;
        results.push({
          timeline_id: update.timeline_id,
          old_status: current.status,
          new_status: update.status || current.status,
          old_due_date: current.due_date,
          new_due_date: update.due_date || current.due_date,
          success: true
        });
      } catch (err) {
        failureCount++;
        errors.push({
          timeline_id: update.timeline_id,
          error: err.message
        });
        results.push({
          timeline_id: update.timeline_id,
          success: false,
          error: err.message
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: failureCount === 0,
        updated_count: successCount,
        failed_count: failureCount,
        errors: errors,
        updates: results
      }),
      {
        status: failureCount === 0 ? 200 : 207, // 207 Multi-Status for partial success
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("Bulk update error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        } 
      }
    );
  }
});
```

## Deployment

```bash
cd supabase
npx supabase functions deploy tracking-bulk-update --no-verify-jwt
```

## Testing

### Test Valid Bulk Update
```bash
curl -X POST "https://[project-id].supabase.co/functions/v1/tracking-bulk-update" \
  -H "Authorization: Bearer [service-key]" \
  -H "Content-Type: application/json" \
  -d '{
    "updates": [
      {
        "timeline_id": "[valid-uuid-1]",
        "status": "IN_PROGRESS",
        "rev_date": "2025-11-15"
      },
      {
        "timeline_id": "[valid-uuid-2]",
        "status": "APPROVED",
        "final_date": "2025-11-01"
      }
    ],
    "updated_by": "[user-uuid]"
  }'
```

### Test with Invalid Timeline ID
```bash
curl -X POST "https://[project-id].supabase.co/functions/v1/tracking-bulk-update" \
  -H "Authorization: Bearer [service-key]" \
  -H "Content-Type: application/json" \
  -d '{
    "updates": [
      {
        "timeline_id": "invalid-uuid",
        "status": "APPROVED"
      }
    ],
    "updated_by": "[user-uuid]"
  }'
```

### Test with 100 Updates (Performance)
```bash
# Generate 100 update objects (script or tool)
# Measure response time (should be < 2 seconds)
```

### Test Transaction Safety
```bash
# Attempt update with mix of valid/invalid IDs
# Verify partial success response (207 Multi-Status)
# Verify valid updates were applied
```

## Business Logic Requirements

1. **Validation:**
   - All timeline_ids must be valid UUIDs
   - Maximum 100 updates per request
   - Status values must be valid enum values

2. **Atomicity:**
   - Each update is independent (partial success allowed)
   - Failed updates don't prevent other updates
   - Return 207 Multi-Status if any failures

3. **Audit Trail:**
   - Log all status changes to `tracking_timeline_status_history`
   - Record `updated_by` and `updated_at` on each timeline
   - Include optional notes/bulk_action_note

4. **Performance:**
   - Process updates sequentially (for now)
   - Consider parallel processing for 50+ updates (future)
   - Response time < 2 seconds for 50 updates

## Success Criteria
- [ ] Edge function created and deployed
- [ ] Handles 1-100 updates per request
- [ ] Validates all timeline_ids exist
- [ ] Returns detailed results for each update
- [ ] Logs all changes to status history
- [ ] Partial success returns 207 Multi-Status
- [ ] Complete success returns 200 OK
- [ ] Complete failure returns 400/500 with error
- [ ] CORS headers correct
- [ ] Performance < 2 seconds for 50 updates
- [ ] Function documented in API reference

## Performance Targets
- **1-10 updates:** < 500ms
- **10-50 updates:** < 1 second
- **50-100 updates:** < 2 seconds

## Dependencies
- **Depends on:** #[enable CRUD issue] - Need UPDATE permission on tracking tables
- **Optional:** `tracking_timeline_status_history` table (log status changes)
- **Blocks:** Frontend bulk actions (multi-select updates)

## Related Documentation
- [Endpoint Design](../docs/supabase/supabase-beproduct-migration/02-timeline/docs/endpoint-design.md)
- [Supabase Edge Functions Guide](https://supabase.com/docs/guides/functions)
