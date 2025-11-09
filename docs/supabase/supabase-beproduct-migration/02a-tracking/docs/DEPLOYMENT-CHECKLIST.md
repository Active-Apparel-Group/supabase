# Tracking Webhook Sync - Deployment Checklist

**Purpose:** Step-by-step checklist for deploying the tracking webhook sync edge function  
**Date:** November 6, 2025

---

## Pre-Deployment

### Code Review
- [x] Implementation plan reviewed and approved
- [x] Edge function code written (`beproduct-tracking-webhook/index.ts`)
- [ ] Code reviewed by team member
- [ ] TypeScript types validated
- [ ] Error handling reviewed
- [ ] Logging statements added

### Testing
- [ ] Local testing completed
  - [ ] OnCreate event tested
  - [ ] OnChange event tested
  - [ ] OnDelete event tested
  - [ ] API call caching tested
  - [ ] Assignment sync tested
- [ ] Unit tests passing (if applicable)
- [ ] Edge function builds successfully
- [ ] No TypeScript errors

### Database Validation
- [ ] All required tables exist in `ops` schema:
  - [ ] `tracking_folder`
  - [ ] `tracking_plan`
  - [ ] `tracking_plan_style`
  - [ ] `tracking_plan_style_timeline`
  - [ ] `tracking_timeline_assignment`
  - [ ] `beproduct_sync_log`
  - [ ] `import_errors`
- [ ] Required indexes created (see plan appendix B)
- [ ] Row-level security (RLS) policies reviewed
- [ ] Foreign key constraints validated

---

## Deployment Steps

### Step 0: ⚠️ CRITICAL - Run Database Migration

**MUST BE DONE FIRST** before deploying the edge function.

```bash
# Apply migration 009 to disable date calculation triggers
cd supabase
supabase db push
```

**Why this is critical:**
- Existing triggers auto-calculate timeline dates based on dependencies
- BeProduct webhooks provide pre-calculated dates (source of truth)
- If triggers remain active, they will **overwrite webhook dates** and break sync
- Migration drops calculation triggers but keeps instantiation trigger

**Checklist:**
- [ ] Migration `009_disable_timeline_date_calculation_triggers.sql` reviewed
- [ ] Migration applied via `supabase db push`
- [ ] Verify triggers dropped:
  ```sql
  -- Should return 0 rows (triggers removed)
  SELECT trigger_name FROM information_schema.triggers
  WHERE event_object_schema = 'ops' 
    AND trigger_name LIKE '%calculate%';
  ```
- [ ] Verify instantiation trigger still exists:
  ```sql
  -- Should return 1 row (this trigger is kept)
  SELECT trigger_name FROM information_schema.triggers
  WHERE event_object_schema = 'ops' 
    AND trigger_name = 'trg_instantiate_style_timeline';
  ```
- [ ] Verify dependency FK constraints removed:
  ```sql
  -- Should return 0 rows (FKs removed for Phase 1)
  SELECT constraint_name FROM information_schema.table_constraints
  WHERE table_schema = 'ops'
    AND table_name LIKE '%dependency%'
    AND constraint_type = 'FOREIGN KEY';
  ```
- [ ] Table comments updated (confirms triggers disabled, FKs removed)

---

### Step 1: Configure Environment Variables

```bash
# Set BeProduct API credentials
supabase secrets set BEPRODUCT_API_URL=https://developers.beproduct.com
supabase secrets set BEPRODUCT_COMPANY=activeapparelgroup
supabase secrets set BEPRODUCT_ACCESS_TOKEN=[get_from_oauth]
supabase secrets set BEPRODUCT_WEBHOOK_SECRET=[generate_random_string]
```

**Checklist:**
- [ ] `BEPRODUCT_API_URL` configured
- [ ] `BEPRODUCT_COMPANY` configured
- [ ] `BEPRODUCT_ACCESS_TOKEN` obtained and configured
- [ ] `BEPRODUCT_WEBHOOK_SECRET` generated and configured
- [ ] Secrets verified with `supabase secrets list`

### Step 2: Deploy Edge Function

```bash
cd supabase
supabase functions deploy beproduct-tracking-webhook --no-verify-jwt
```

**Checklist:**
- [ ] Function deployed successfully
- [ ] Deployment logs reviewed (no errors)
- [ ] Function URL noted:
  ```
  https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook
  ```
- [ ] Function accessible (returns 401 without auth)

### Step 3: Test Edge Function

```bash
# Test with sample OnCreate payload
curl -X POST https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [BEPRODUCT_WEBHOOK_SECRET]" \
  -d @docs/supabase/supabase-beproduct-migration/99-webhook-payloads/tracking/tracking_oncreate.json
```

**Checklist:**
- [ ] OnCreate webhook test successful
- [ ] OnChange webhook test successful
- [ ] OnDelete webhook test successful
- [ ] Data appears in `ops.tracking_plan_style`
- [ ] Data appears in `ops.tracking_plan_style_timeline`
- [ ] Data appears in `ops.beproduct_sync_log`
- [ ] No errors in `ops.import_errors`
- [ ] Edge function logs reviewed

### Step 4: Register Webhook in BeProduct

1. Log in to BeProduct: https://developers.beproduct.com/activeapparelgroup
2. Navigate to **Settings** → **Webhooks** → **Create Webhook**
3. Configure webhook:
   - **Name:** `Supabase Tracking Sync - Production`
   - **URL:** `https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook`
   - **Events:** ✅ OnCreate, ✅ OnChange, ✅ OnDelete
   - **Object Type:** Header (Style)
   - **Authentication Type:** Bearer Token
   - **Token:** `[BEPRODUCT_WEBHOOK_SECRET]`
4. Test webhook with BeProduct's test tool
5. Enable webhook

**Checklist:**
- [ ] Webhook created in BeProduct
- [ ] Webhook URL configured correctly
- [ ] All three events selected (OnCreate, OnChange, OnDelete)
- [ ] Object type set to "Header"
- [ ] Authentication configured (Bearer token)
- [ ] Test webhook successful in BeProduct UI
- [ ] Webhook enabled

---

## Post-Deployment Validation

### Immediate Checks (First 30 minutes)

**Monitor Edge Function:**
```bash
# Watch logs in real-time
supabase functions logs beproduct-tracking-webhook --tail
```

**Checklist:**
- [ ] No errors in edge function logs
- [ ] Webhook events appearing in logs
- [ ] Processing time < 2 seconds per event
- [ ] API calls cached (no duplicate plan fetches)

**Validate Database:**
```sql
-- Check recent sync events
SELECT * FROM ops.beproduct_sync_log 
WHERE processed_at > NOW() - INTERVAL '30 minutes'
ORDER BY processed_at DESC;

-- Check for errors
SELECT * FROM ops.import_errors
WHERE created_at > NOW() - INTERVAL '30 minutes';

-- Check new styles synced
SELECT * FROM ops.tracking_plan_style
WHERE created_at > NOW() - INTERVAL '30 minutes'
ORDER BY created_at DESC;
```

**Checklist:**
- [ ] Sync log entries present
- [ ] Zero errors in import_errors table
- [ ] New styles appearing in tracking_plan_style
- [ ] Timeline records created (24+ per style)
- [ ] Assignments synced correctly

### Extended Validation (First 24 hours)

**Performance Metrics:**
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

**Checklist:**
- [ ] Webhook processing success rate > 99%
- [ ] Average processing time < 2 seconds
- [ ] Zero duplicate records created
- [ ] API call cache hit rate > 90%
- [ ] No blocked/failed webhooks in BeProduct

### Data Quality Checks

```sql
-- Validate timeline completeness (should have ~24 milestones per style)
SELECT 
  ps.style_number,
  ps.style_name,
  COUNT(pst.id) as milestone_count
FROM ops.tracking_plan_style ps
LEFT JOIN ops.tracking_plan_style_timeline pst ON ps.id = pst.plan_style_id
WHERE ps.created_at > NOW() - INTERVAL '24 hours'
GROUP BY ps.id, ps.style_number, ps.style_name
HAVING COUNT(pst.id) < 20  -- Flag incomplete syncs
ORDER BY milestone_count ASC;

-- Check for orphaned records
SELECT * FROM ops.tracking_plan_style
WHERE plan_id NOT IN (SELECT id FROM ops.tracking_plan)
  AND created_at > NOW() - INTERVAL '24 hours';
```

**Checklist:**
- [ ] All styles have complete timeline records (20-30 milestones)
- [ ] No orphaned style records (all have valid plan_id)
- [ ] Status values mapped correctly
- [ ] Dates in correct format (YYYY-MM-DD)
- [ ] Assignments linked to valid users

---

## Rollback Plan

### If Critical Issues Detected

**Step 1: Disable Webhook in BeProduct**
1. Log in to BeProduct
2. Navigate to **Settings** → **Webhooks**
3. Find "Supabase Tracking Sync - Production"
4. Click **Disable**
5. Verify no new events are being sent

**Step 2: Investigate Issue**
```bash
# Review recent logs
supabase functions logs beproduct-tracking-webhook --tail | grep "ERROR"

# Check database for errors
SELECT * FROM ops.import_errors
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
```

**Step 3: Fix and Redeploy**
1. Fix code issue
2. Test locally
3. Redeploy edge function
4. Re-enable webhook in BeProduct

**Step 4: Backfill Missed Events (if needed)**
```sql
-- Identify gap period
SELECT MIN(processed_at), MAX(processed_at)
FROM ops.beproduct_sync_log
WHERE processed_at > NOW() - INTERVAL '24 hours';

-- Manual sync (if BeProduct provides replay)
-- Or use BeProduct API to fetch missing data
```

---

## Success Criteria

### Phase 1 (Webhook Sync)
- ✅ Webhook processing success rate > 99%
- ✅ Average webhook processing time < 2 seconds
- ✅ Zero data loss (all events logged)
- ✅ API call cache hit rate > 90%
- ✅ Zero duplicate records created
- ✅ 100% of timeline fields mapped correctly
- ✅ No production incidents

### Business Impact
- ✅ Tracking data synced in real-time (< 5 second latency)
- ✅ No manual CSV imports required
- ✅ Audit trail complete (all changes logged)
- ✅ Data available for analytics and reporting

---

## Known Limitations

1. **Material Timelines:** Phase 1 does not sync `tracking_plan_material` (future work)
2. **Historical Data:** Only syncs changes going forward (not backfill)
3. **One-Way Sync:** Phase 1 is BeProduct → Supabase only (no reverse sync)
4. **API Rate Limits:** Plan/folder fetches subject to BeProduct API rate limits

---

## Next Steps (Phase 2)

After Phase 1 is stable:
- [ ] Add start_date and duration fields to timeline tables
- [ ] Build Supabase API endpoints (see endpoint-design.md)
- [ ] Create reverse sync edge function (Supabase → BeProduct)
- [ ] Implement bidirectional sync with conflict resolution
- [ ] Add material timeline support
- [ ] Historical data backfill

---

## Contacts

**Technical Issues:**
- Backend Team: [backend-team@yourcompany.com]
- DevOps: [devops@yourcompany.com]

**BeProduct Support:**
- BeProduct Support: [support@beproduct.com]
- Account Manager: [account-manager@beproduct.com]

**Emergency Escalation:**
- On-call Engineer: [Use PagerDuty]

---

**Document Status:** ✅ Ready for Use  
**Last Updated:** November 6, 2025  
**Next Review:** After Phase 1 deployment
