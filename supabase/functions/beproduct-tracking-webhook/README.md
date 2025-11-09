# BeProduct Tracking Webhook Edge Function

**Purpose:** Sync tracking data from BeProduct to Supabase via webhooks  
**Status:** Ready for deployment  
**Created:** November 6, 2025

---

## Overview

This edge function receives webhook events from BeProduct when tracking plan changes occur and syncs the data to Supabase `ops` schema tables.

## Supported Events

### OnCreate
Triggered when a style/colorway is added to a tracking plan.

**Actions:**
- Fetches plan metadata from BeProduct API (if not cached)
- Fetches folder metadata from BeProduct API (if not cached)
- Creates `tracking_plan_style` record
- Creates x `tracking_plan_style_timeline` records
- Syncs assignments to `tracking_timeline_assignment`

### OnChange
Triggered when a timeline milestone is updated.

**Actions:**
- Updates `tracking_plan_style_timeline` record (status, dates)
- Syncs changed assignments
- Updates `shared_with` array

### OnDelete
Triggered when a style/colorway is removed from a tracking plan.

**Actions:**
- Soft deletes `tracking_plan_style` (sets `active = false`)
- Preserves all timeline data for audit trail

---

## Environment Variables

Required in Supabase project settings:

```bash
# Supabase (auto-configured)
SUPABASE_URL=https://[project-id].supabase.co
SUPABASE_SERVICE_ROLE_KEY=...

# BeProduct API credentials
BEPRODUCT_API_URL=https://developers.beproduct.com
BEPRODUCT_COMPANY=activeapparelgroup
BEPRODUCT_ACCESS_TOKEN=... # Get from OAuth flow
BEPRODUCT_WEBHOOK_SECRET=... # Optional, for webhook authentication
```

---

## Prerequisites

### ⚠️ CRITICAL: Database Migration Required

**Before deploying this function**, you MUST run migration `009_disable_timeline_date_calculation_triggers.sql`:

```bash
# Apply the migration
supabase db push
```

**Why?** The existing timeline calculation triggers will **conflict** with webhook data:
- Triggers: Auto-calculate dates based on dependencies
- Webhooks: Provide pre-calculated dates from BeProduct (source of truth)
- Conflict: Triggers overwrite webhook dates, breaking sync

**What the migration does:**
- ✅ Drops `calculate_timeline_dates_trigger` (prevents date recalculation)
- ✅ Drops `cascade_timeline_updates_trigger` (prevents cascade recalculation)  
- ✅ Drops `recalculate_plan_timelines_trigger` (prevents plan-level recalculation)
- ✅ Drops FK constraints on dependency tables (dependencies deferred to Phase 2)
- ✅ **KEEPS** `trg_instantiate_style_timeline` (needed for template instantiation)

---

## Deployment

### Deploy to Supabase

```bash
# From repository root
cd supabase
supabase functions deploy beproduct-tracking-webhook --no-verify-jwt
```

### Set Environment Variables

```bash
# Using Supabase CLI
supabase secrets set BEPRODUCT_API_URL=https://developers.beproduct.com
supabase secrets set BEPRODUCT_COMPANY=activeapparelgroup
supabase secrets set BEPRODUCT_ACCESS_TOKEN=your_token_here
supabase secrets set BEPRODUCT_WEBHOOK_SECRET=your_secret_here
```

### Get Edge Function URL

```bash
# The deployed URL will be:
https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook
```

---

## Register Webhook in BeProduct

1. Log in to BeProduct
2. Navigate to **Settings** → **Webhooks**
3. Create new webhook:
   - **Name:** Supabase Tracking Sync
   - **URL:** `https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook`
   - **Events:** `OnCreate`, `OnChange`, `OnDelete`
   - **Object Type:** `Header` (Style)
   - **Authentication:** Bearer `[BEPRODUCT_WEBHOOK_SECRET]`
4. Test webhook with a sample event
5. Enable webhook

---

## Testing

### Local Testing

```bash
# Start Supabase locally
supabase start

# Serve function locally
supabase functions serve beproduct-tracking-webhook --no-verify-jwt

# Send test webhook (from another terminal)
curl -X POST http://localhost:54321/functions/v1/beproduct-tracking-webhook \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-secret" \
  -d @../../docs/supabase/supabase-beproduct-migration/99-webhook-payloads/tracking/tracking_oncreate.json
```

### Production Testing

1. Add a test style to a tracking plan in BeProduct
2. Check edge function logs:
   ```bash
   supabase functions logs beproduct-tracking-webhook --tail
   ```
3. Validate data in Supabase:
   ```sql
   SELECT * FROM ops.tracking_plan_style ORDER BY created_at DESC LIMIT 5;
   SELECT * FROM ops.tracking_plan_style_timeline ORDER BY created_at DESC LIMIT 10;
   SELECT * FROM ops.beproduct_sync_log ORDER BY processed_at DESC LIMIT 10;
   ```

---

## Monitoring

### Check Sync Logs

```sql
-- Recent sync events
SELECT 
  entity_type,
  action,
  entity_id,
  processed_at,
  payload->>'eventType' as event_type,
  payload->>'headerNumber' as style_number
FROM ops.beproduct_sync_log
ORDER BY processed_at DESC
LIMIT 20;

-- Sync errors
SELECT * 
FROM ops.import_errors
WHERE entity_type = 'tracking'
ORDER BY created_at DESC;
```

### Check Edge Function Logs

```bash
# Real-time logs
supabase functions logs beproduct-tracking-webhook --tail

# Filter by status
supabase functions logs beproduct-tracking-webhook --tail | grep "ERROR"
```

### Performance Metrics

```sql
-- Webhook processing performance
SELECT 
  DATE_TRUNC('hour', processed_at) as hour,
  action,
  COUNT(*) as event_count,
  AVG(EXTRACT(EPOCH FROM (processed_at - (payload->>'date')::timestamptz))) as avg_processing_seconds
FROM ops.beproduct_sync_log
WHERE processed_at > NOW() - INTERVAL '24 hours'
GROUP BY 1, 2
ORDER BY 1 DESC;
```

---

## Troubleshooting

### Webhook Not Received

1. Check BeProduct webhook status (should be enabled)
2. Verify edge function URL is correct
3. Check BeProduct webhook logs for delivery errors
4. Test edge function manually with curl

### API Call Failures

1. Check `BEPRODUCT_ACCESS_TOKEN` is valid
2. Verify token has not expired (refresh if needed)
3. Check BeProduct API rate limits
4. Review edge function logs for error details

### Data Not Syncing

1. Check `ops.beproduct_sync_log` for events
2. Check `ops.import_errors` for sync errors
3. Verify foreign key constraints (plan_id, folder_id must exist)
4. Check if style is marked inactive (`active = false`)

### Duplicate Records

1. Webhooks use upserts (should not create duplicates)
2. If duplicates exist, check primary key constraints
3. Review sync logs for duplicate event processing

---

## Data Flow Diagram

```
BeProduct Event → Webhook Payload
       ↓
Edge Function Receives
       ↓
Authenticate Request
       ↓
Parse Event Type
       ↓
┌──────────────┬──────────────┬──────────────┐
│  OnCreate    │  OnChange    │  OnDelete    │
└──────┬───────┴──────┬───────┴──────┬───────┘
       │              │              │
       ↓              ↓              ↓
Check Plan Exists   Update Timeline  Soft Delete
       ↓              │              │
Fetch from API?     Sync Assignments │
       ↓              │              │
Upsert Plan         Update ShareWith │
       ↓              ↓              ↓
Upsert Style   ────────────────────────────────→ Log Sync Event
       ↓                                              ↓
Upsert Timelines                              ops.beproduct_sync_log
       ↓
Sync Assignments
       ↓
Done (200 OK)
```

---

## Future Enhancements

### Phase 2 Features
- [ ] Reverse sync (Supabase → BeProduct)
- [ ] Webhook replay (manual retry failed events)
- [ ] Batch processing (handle multiple events in one call)
- [ ] Webhook queue (buffer during high traffic)
- [ ] Dead letter queue (failed events for manual review)
- [ ] Webhook signatures (verify payload authenticity)

### Optimizations
- [ ] Cache plan/folder data in Redis
- [ ] Batch insert timeline records
- [ ] Parallel processing for assignments
- [ ] Reduce API calls with smarter caching

---

## Related Documentation

- [Tracking Webhook Sync Plan](../../../docs/supabase/supabase-beproduct-migration/02a-tracking/TRACKING-WEBHOOK-SYNC-PLAN.md)
- [BeProduct API Mapping](../../../docs/supabase/supabase-beproduct-migration/02-timeline/docs/beproduct-api-mapping.md)
- [Endpoint Design](../../../docs/supabase/supabase-beproduct-migration/02-timeline/docs/endpoint-design.md)

---

**Maintained By:** Backend Team  
**Last Updated:** November 6, 2025
