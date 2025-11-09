# Phase 02a-Tracking: GitHub Issues Breakdown

**Purpose**: Translate deployment checklist into trackable GitHub issues  
**Status**: Ready to create issues  
**Date**: November 9, 2025

---

## Issue Workflow Strategy

### Labels to Create
```bash
# In your GitHub repo settings, create these labels:
- phase-02a-tracking (blue)
- deployment (yellow)
- testing (green)
- database (purple)
- edge-function (orange)
- documentation (gray)
- blocked (red)
```

### Milestone
- **Name**: Phase 02a-Tracking Deployment
- **Due Date**: [Set your target]
- **Description**: Deploy real-time BeProduct → Supabase tracking webhook sync

---

## Issues to Create

### Pre-Deployment Issues

#### Issue #1: Code Review for beproduct-tracking-webhook
**Title**: `[02a-Tracking] Code review for beproduct-tracking-webhook edge function`  
**Labels**: `phase-02a-tracking`, `edge-function`  
**Assignee**: @copilot (or team member)

**Description**:
```markdown
## Context
Edge function implementation is complete and ready for peer review before deployment.

## Review Checklist
- [ ] TypeScript types are explicit (no `any`)
- [ ] Error handling is comprehensive
- [ ] All webhook events covered (OnCreate, OnChange, OnDelete)
- [ ] API caching logic is correct
- [ ] Database upserts use `ON CONFLICT DO UPDATE`
- [ ] Logging statements are in place
- [ ] CORS headers are correct
- [ ] Webhook authentication is secure
- [ ] Status enum mapping is accurate
- [ ] Assignment sync logic is correct

## Files to Review
- `supabase/functions/beproduct-tracking-webhook/index.ts`
- `supabase/functions/beproduct-tracking-webhook/README.md`

## Documentation
- [Implementation Plan](../docs/supabase/supabase-beproduct-migration/02a-tracking/docs/TRACKING-WEBHOOK-SYNC-PLAN.md)

## Success Criteria
- [ ] Two team members have reviewed
- [ ] No blocking issues found
- [ ] All comments addressed
```

---

#### Issue #2: Validate Database Schema for Tracking Sync
**Title**: `[02a-Tracking] Validate ops schema tables exist and have correct structure`  
**Labels**: `phase-02a-tracking`, `database`

**Description**:
```markdown
## Context
Before deploying the webhook, verify all required database tables exist with correct schema.

## Required Tables
- [ ] `ops.tracking_folder` exists
- [ ] `ops.tracking_plan` exists
- [ ] `ops.tracking_plan_style` exists
- [ ] `ops.tracking_plan_style_timeline` exists
- [ ] `ops.tracking_timeline_assignment` exists
- [ ] `ops.beproduct_sync_log` exists
- [ ] `ops.import_errors` exists

## Validation Queries
```sql
-- Check all tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'ops' 
  AND table_name LIKE 'tracking%'
ORDER BY table_name;

-- Verify tracking_plan_style_timeline has correct columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'ops' 
  AND table_name = 'tracking_plan_style_timeline'
ORDER BY ordinal_position;

-- Check indexes exist (see plan appendix B)
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'ops' 
  AND tablename LIKE 'tracking%';
```

## Success Criteria
- [ ] All 7 tables exist
- [ ] All required columns present
- [ ] Indexes created for foreign keys
- [ ] RLS policies reviewed
```

---

#### Issue #3: Run Critical Database Migration 009
**Title**: `[02a-Tracking] Apply migration 009 to disable date calculation triggers`  
**Labels**: `phase-02a-tracking`, `database`, `deployment`  
**Priority**: 🔴 CRITICAL - Must be done before webhook deployment

**Description**:
```markdown
## ⚠️ CRITICAL - Must Complete Before Webhook Deployment

## Context
Existing triggers auto-calculate timeline dates. BeProduct webhooks provide pre-calculated dates (source of truth). If triggers remain active, they will **overwrite webhook dates** and break sync.

## Migration File
`supabase/migrations/009_disable_timeline_date_calculation_triggers.sql`

## Deployment Steps
```bash
cd supabase
npx supabase db push
```

## Validation Queries
```sql
-- Should return 0 rows (triggers removed)
SELECT trigger_name 
FROM information_schema.triggers
WHERE event_object_schema = 'ops' 
  AND trigger_name LIKE '%calculate%';

-- Should return 1 row (instantiation trigger kept)
SELECT trigger_name 
FROM information_schema.triggers
WHERE event_object_schema = 'ops' 
  AND trigger_name = 'trg_instantiate_style_timeline';

-- Verify dependency FK constraints removed
SELECT constraint_name 
FROM information_schema.table_constraints
WHERE table_schema = 'ops'
  AND table_name LIKE '%dependency%'
  AND constraint_type = 'FOREIGN KEY';
```

## Success Criteria
- [ ] Migration applied successfully
- [ ] Date calculation triggers removed
- [ ] Instantiation trigger still exists
- [ ] Table comments updated
- [ ] No errors in migration log
- [ ] Validation queries confirm changes

## Blocks
- Blocks: #[webhook deployment issue number]
```

---

### Deployment Issues

#### Issue #4: Configure Supabase Secrets for BeProduct Integration
**Title**: `[02a-Tracking] Set up environment variables in Supabase`  
**Labels**: `phase-02a-tracking`, `deployment`

**Description**:
```markdown
## Context
Edge function requires BeProduct API credentials and webhook secret.

## Required Secrets
```bash
# Set these in Supabase dashboard or via CLI
supabase secrets set BEPRODUCT_API_URL=https://developers.beproduct.com
supabase secrets set BEPRODUCT_COMPANY=activeapparelgroup
supabase secrets set BEPRODUCT_ACCESS_TOKEN=[obtain from OAuth flow]
supabase secrets set BEPRODUCT_WEBHOOK_SECRET=[generate random 32-char string]
```

## Steps
1. Generate webhook secret: `openssl rand -hex 32`
2. Set secrets in Supabase (staging first, then production)
3. Verify with: `supabase secrets list`
4. Document webhook secret in secure location (1Password, etc.)

## Success Criteria
- [ ] All 4 secrets configured
- [ ] Secrets verified with `supabase secrets list`
- [ ] Webhook secret stored securely
- [ ] Credentials tested (can call BeProduct API)

## Dependencies
- Requires: Valid BeProduct OAuth token
```

---

#### Issue #5: Deploy beproduct-tracking-webhook to Staging
**Title**: `[02a-Tracking] Deploy edge function to staging environment`  
**Labels**: `phase-02a-tracking`, `deployment`, `edge-function`

**Description**:
```markdown
## Context
Deploy tracking webhook edge function to staging for initial testing.

## Deployment Command
```bash
cd supabase
npx supabase functions deploy beproduct-tracking-webhook --no-verify-jwt
```

## Post-Deployment Checks
- [ ] Function deployed successfully
- [ ] No errors in deployment logs
- [ ] Function URL noted: `https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook`
- [ ] Function returns 401 without auth (expected)
- [ ] Function returns 200 with valid webhook secret

## Test Request
```bash
# Test with minimal payload
curl -X POST https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [BEPRODUCT_WEBHOOK_SECRET]" \
  -d '{"event":"ping"}'
```

## Success Criteria
- [ ] Deployment completes without errors
- [ ] Function accessible at public URL
- [ ] Authentication working (401 without secret)
- [ ] Logs show function is running

## Dependencies
- Depends on: #[secrets configuration issue]
- Depends on: #[migration 009 issue]
```

---

### Testing Issues

#### Issue #6: Test Webhook with OnCreate Event
**Title**: `[02a-Tracking] Integration test: OnCreate webhook event`  
**Labels**: `phase-02a-tracking`, `testing`

**Description**:
```markdown
## Context
Test full OnCreate workflow with sample payload.

## Test Payload
Use: `docs/supabase/supabase-beproduct-migration/99-webhook-payloads/tracking/tracking_oncreate.json`

## Test Command
```bash
curl -X POST https://[staging-url]/functions/v1/beproduct-tracking-webhook \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [WEBHOOK_SECRET]" \
  -d @docs/supabase/supabase-beproduct-migration/99-webhook-payloads/tracking/tracking_oncreate.json
```

## Validation Queries
```sql
-- Check sync log
SELECT * FROM ops.beproduct_sync_log 
WHERE action = 'OnCreate' 
ORDER BY processed_at DESC LIMIT 1;

-- Check style created
SELECT * FROM ops.tracking_plan_style 
ORDER BY created_at DESC LIMIT 1;

-- Check timeline records (should be ~24)
SELECT COUNT(*) FROM ops.tracking_plan_style_timeline 
WHERE plan_style_id = (
  SELECT id FROM ops.tracking_plan_style 
  ORDER BY created_at DESC LIMIT 1
);

-- Check assignments synced
SELECT * FROM ops.tracking_timeline_assignment 
WHERE timeline_id IN (
  SELECT id FROM ops.tracking_plan_style_timeline 
  WHERE plan_style_id = (
    SELECT id FROM ops.tracking_plan_style 
    ORDER BY created_at DESC LIMIT 1
  )
);
```

## Success Criteria
- [ ] Webhook returns 200 OK
- [ ] Event logged in `beproduct_sync_log`
- [ ] Style record created in `tracking_plan_style`
- [ ] 24+ timeline records created
- [ ] Assignments created (if in payload)
- [ ] No errors in `import_errors` table
- [ ] Processing time < 2 seconds

## Dependencies
- Depends on: #[deployment issue]
```

---

#### Issue #7: Test Webhook with OnChange Event
**Title**: `[02a-Tracking] Integration test: OnChange webhook event`  
**Labels**: `phase-02a-tracking`, `testing`

**Description**:
```markdown
## Context
Test timeline update workflow with OnChange event.

## Test Payload
Use: `docs/supabase/supabase-beproduct-migration/99-webhook-payloads/tracking/tracking_onchangetimeline.json`

## Test Steps
1. First run OnCreate test to create base records
2. Run OnChange test to update timeline
3. Verify updates applied correctly

## Validation Queries
```sql
-- Check sync log
SELECT * FROM ops.beproduct_sync_log 
WHERE action = 'OnChange' 
ORDER BY processed_at DESC LIMIT 1;

-- Check timeline updated
SELECT status, plan_date, rev_date, final_date 
FROM ops.tracking_plan_style_timeline 
WHERE id = '[timeline_id_from_payload]';

-- Check assignments updated
SELECT * FROM ops.tracking_timeline_assignment 
WHERE timeline_id = '[timeline_id_from_payload]';
```

## Success Criteria
- [ ] Webhook returns 200 OK
- [ ] Event logged in sync log
- [ ] Timeline status updated
- [ ] Dates updated (if changed)
- [ ] Assignments synced correctly
- [ ] No duplicate assignments
- [ ] Processing time < 1 second (no API calls)

## Dependencies
- Depends on: #[OnCreate test issue]
```

---

#### Issue #8: Test Webhook with OnDelete Event
**Title**: `[02a-Tracking] Integration test: OnDelete webhook event`  
**Labels**: `phase-02a-tracking`, `testing`

**Description**:
```markdown
## Context
Test soft delete workflow when style removed from tracking plan.

## Test Payload
Use: `docs/supabase/supabase-beproduct-migration/99-webhook-payloads/tracking/tracking_ondelete.json`

## Validation Queries
```sql
-- Check sync log
SELECT * FROM ops.beproduct_sync_log 
WHERE action = 'OnDelete' 
ORDER BY processed_at DESC LIMIT 1;

-- Check soft delete (active = false)
SELECT id, style_number, active 
FROM ops.tracking_plan_style 
WHERE id = '[style_id_from_payload]';

-- Verify timeline data preserved
SELECT COUNT(*) FROM ops.tracking_plan_style_timeline 
WHERE plan_style_id = '[style_id_from_payload]';
```

## Success Criteria
- [ ] Webhook returns 200 OK
- [ ] Event logged in sync log
- [ ] Style marked inactive (`active = false`)
- [ ] Timeline data preserved (not deleted)
- [ ] Processing time < 1 second

## Dependencies
- Depends on: #[OnCreate test issue]
```

---

#### Issue #9: Load Test Webhook Performance
**Title**: `[02a-Tracking] Performance test: Process 100 webhook events`  
**Labels**: `phase-02a-tracking`, `testing`

**Description**:
```markdown
## Context
Validate webhook can handle production load (target: < 2 seconds per event).

## Test Approach
Send 100 rapid webhook requests and measure:
- Average processing time
- Success rate
- Database performance
- Memory usage

## Test Script
Create `scripts/load-test-webhook.sh`:
```bash
#!/bin/bash
for i in {1..100}; do
  curl -X POST [webhook-url] \
    -H "Authorization: Bearer [secret]" \
    -d @tracking_oncreate.json \
    -w "%{time_total}\n" &
done
wait
```

## Performance Queries
```sql
-- Processing time statistics
SELECT 
  COUNT(*) as event_count,
  AVG(EXTRACT(EPOCH FROM (processed_at - (payload->>'date')::timestamptz))) as avg_seconds,
  MIN(EXTRACT(EPOCH FROM (processed_at - (payload->>'date')::timestamptz))) as min_seconds,
  MAX(EXTRACT(EPOCH FROM (processed_at - (payload->>'date')::timestamptz))) as max_seconds
FROM ops.beproduct_sync_log
WHERE processed_at > NOW() - INTERVAL '5 minutes';
```

## Success Criteria
- [ ] 100 webhooks processed successfully
- [ ] Success rate > 99%
- [ ] Average processing time < 2 seconds
- [ ] No database errors
- [ ] No memory issues
- [ ] API cache hit rate > 90%

## Dependencies
- Depends on: All integration tests passing
```

---

### Production Deployment Issues

#### Issue #10: Register Webhook in BeProduct Staging
**Title**: `[02a-Tracking] Configure webhook in BeProduct staging environment`  
**Labels**: `phase-02a-tracking`, `deployment`

**Description**:
```markdown
## Context
Register Supabase webhook endpoint in BeProduct to receive real events.

## Configuration Steps
1. Log in to BeProduct: https://developers.beproduct.com/activeapparelgroup
2. Navigate to **Settings** → **Webhooks** → **Create Webhook**
3. Configure:
   - **Name**: `Supabase Tracking Sync - Staging`
   - **URL**: `https://[staging-project-id].supabase.co/functions/v1/beproduct-tracking-webhook`
   - **Events**: ✅ OnCreate, ✅ OnChange, ✅ OnDelete
   - **Object Type**: Header (Style)
   - **Authentication Type**: Bearer Token
   - **Token**: `[BEPRODUCT_WEBHOOK_SECRET]`
4. Test webhook with BeProduct's test tool
5. Enable webhook

## Validation
- [ ] Webhook created successfully
- [ ] Test webhook fires successfully
- [ ] Check Supabase logs for incoming webhook
- [ ] Validate data synced to database

## Success Criteria
- [ ] Webhook registered in BeProduct
- [ ] Test webhook successful
- [ ] Real events flowing to Supabase
- [ ] Data syncing correctly

## Dependencies
- Depends on: All staging tests passing
```

---

#### Issue #11: Monitor Staging for 24 Hours
**Title**: `[02a-Tracking] Monitor staging webhook for 24 hours`  
**Labels**: `phase-02a-tracking`, `testing`

**Description**:
```markdown
## Context
Validate stability and performance with real BeProduct events before production deployment.

## Monitoring Tasks

### Real-Time Monitoring (First 4 Hours)
```bash
# Watch edge function logs
npx supabase functions logs beproduct-tracking-webhook --tail
```

### Periodic Checks (Every 6 Hours)
```sql
-- Sync event counts
SELECT 
  action,
  COUNT(*) as event_count,
  MAX(processed_at) as last_event
FROM ops.beproduct_sync_log
WHERE processed_at > NOW() - INTERVAL '24 hours'
GROUP BY action;

-- Error rate
SELECT COUNT(*) as error_count
FROM ops.import_errors
WHERE created_at > NOW() - INTERVAL '24 hours';

-- Performance metrics
SELECT 
  action,
  AVG(EXTRACT(EPOCH FROM (processed_at - (payload->>'date')::timestamptz))) as avg_seconds
FROM ops.beproduct_sync_log
WHERE processed_at > NOW() - INTERVAL '24 hours'
GROUP BY action;
```

### Data Quality Checks
```sql
-- Incomplete syncs (missing timelines)
SELECT 
  ps.style_number,
  COUNT(pst.id) as milestone_count
FROM ops.tracking_plan_style ps
LEFT JOIN ops.tracking_plan_style_timeline pst ON ps.id = pst.plan_style_id
WHERE ps.created_at > NOW() - INTERVAL '24 hours'
GROUP BY ps.id, ps.style_number
HAVING COUNT(pst.id) < 20;
```

## Success Metrics
- [ ] > 99% success rate
- [ ] < 2 second average processing time
- [ ] Zero duplicate records
- [ ] Zero orphaned records
- [ ] All timeline records complete (20-30 per style)
- [ ] No production incidents

## Report
Document findings in issue comment after 24 hours.

## Dependencies
- Depends on: #[BeProduct webhook registration]
```

---

#### Issue #12: Deploy to Production
**Title**: `[02a-Tracking] Deploy webhook to production environment`  
**Labels**: `phase-02a-tracking`, `deployment`

**Description**:
```markdown
## Context
After successful staging validation, deploy to production.

## Pre-Deployment Checklist
- [ ] Staging monitored for 24+ hours
- [ ] All success metrics met
- [ ] No critical issues found
- [ ] Team signoff obtained

## Deployment Steps
1. Configure production secrets (same as staging)
2. Apply migration 009 to production
3. Deploy edge function to production
4. Register webhook in BeProduct production
5. Monitor for first 2 hours

## Rollback Plan
If critical issues:
1. Disable webhook in BeProduct immediately
2. Investigate logs
3. Fix issue
4. Redeploy
5. Re-enable webhook

## Success Criteria
- [ ] Function deployed to production
- [ ] Webhook registered in BeProduct production
- [ ] First 10 events processed successfully
- [ ] No errors in first 2 hours
- [ ] Team notified of successful deployment

## Dependencies
- Depends on: #[staging monitoring issue]
- Depends on: All tests passing
```

---

### Documentation Issues

#### Issue #13: Update README with Production Endpoints
**Title**: `[02a-Tracking] Document production webhook URL and monitoring`  
**Labels**: `phase-02a-tracking`, `documentation`

**Description**:
```markdown
## Context
Update documentation with production URLs, monitoring procedures, and lessons learned.

## Files to Update
- [ ] `supabase/functions/beproduct-tracking-webhook/README.md`
  - Add production URL
  - Add monitoring queries
  - Document any deployment quirks
- [ ] `docs/supabase/supabase-beproduct-migration/02a-tracking/README.md`
  - Update status to "✅ Deployed to Production"
  - Add production metrics
- [ ] `docs/supabase/supabase-beproduct-migration/02a-tracking/docs/DEPLOYMENT-CHECKLIST.md`
  - Mark all items complete
  - Add "Lessons Learned" section

## Lessons Learned Section
Document:
- What went smoothly
- What was challenging
- What would you do differently
- Tips for future deployments

## Success Criteria
- [ ] All documentation updated
- [ ] Production URLs documented
- [ ] Monitoring procedures clear
- [ ] Lessons learned captured
```

---

## Issue Creation Workflow

### Using GitHub CLI
```bash
# Install GitHub CLI
gh --version

# Create all issues at once
gh issue create --title "[02a-Tracking] Code review for beproduct-tracking-webhook edge function" \
  --label "phase-02a-tracking,edge-function" \
  --body-file .github/issues/issue-01-code-review.md

# Or create interactively
gh issue create
```

### Using GitHub Copilot Agent
In VS Code:
1. Open Copilot Chat (Ctrl+Alt+I)
2. Prompt: "Create GitHub issue from this template: [paste issue content]"
3. Copilot will draft the issue and optionally submit it

### Manual Creation
1. Go to GitHub repo → Issues → New Issue
2. Copy/paste issue content from above
3. Add labels and milestone
4. Assign to team member or @copilot

---

## Project Board Setup

Create a GitHub Project board:
- **Columns**:
  - 📋 Backlog
  - 🔜 Ready
  - 🏃 In Progress
  - 👀 In Review
  - ✅ Done
  - 🚫 Blocked

- **Automation**:
  - New issues → Backlog
  - Assigned → Ready
  - PR opened → In Review
  - PR merged → Done

---

## Assigning to GitHub Copilot

For issues that Copilot can handle autonomously:

1. **Enable Coding Agent**: Settings → Copilot → Coding Agent
2. **Assign Issue**: In issue, type `/copilot assign`
3. **Monitor Progress**: Agent will:
   - Create branch
   - Implement solution
   - Run tests
   - Open PR
4. **Review PR**: Human reviews before merge

**Good for Copilot**:
- Database migrations (Issue #3)
- Test script generation (Issues #6-9)
- Documentation updates (Issue #13)

**Not good for Copilot** (requires human judgment):
- Code review (Issue #1)
- Production deployment (Issue #12)
- Monitoring/analysis (Issue #11)

---

## Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Pre-Deployment (Issues #1-3) | 1-2 days | None |
| Deployment Setup (Issues #4-5) | 1 day | Pre-deployment complete |
| Testing (Issues #6-9) | 2-3 days | Deployment complete |
| Staging (Issues #10-11) | 24+ hours | All tests passing |
| Production (Issue #12) | 0.5 day | Staging validated |
| Documentation (Issue #13) | 0.5 day | Production deployed |

**Total**: ~5-7 days from start to production

---

## Next Steps

1. **Create labels** in GitHub repo settings
2. **Create milestone** "Phase 02a-Tracking Deployment"
3. **Create issues** from templates above (or use Copilot)
4. **Set up project board** for visibility
5. **Start with Issue #1** (code review)
6. **Assign issues** to team members or Copilot agent

---

**Status**: Ready to create issues  
**Last Updated**: November 9, 2025
