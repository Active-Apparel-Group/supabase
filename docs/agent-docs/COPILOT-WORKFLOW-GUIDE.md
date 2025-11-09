# GitHub Copilot Workflow Guide for Supabase PLM Project

**Purpose**: Practical guide for using GitHub Copilot effectively in this project  
**Audience**: Development team  
**Date**: November 9, 2025

---

## Overview

This guide shows how to leverage GitHub Copilot's full capabilities—not just autocomplete, but **agents** and **subagents**—to accelerate development of the Supabase PLM backend.

---

## Current State vs. Recommended State

### ❌ What You're Probably Doing Now
- Using Copilot only for inline autocomplete
- Writing plans in Markdown but not creating GitHub issues
- Manual testing of edge functions
- Reviewing code yourself without Copilot assistance
- Deploying manually with copy/paste commands

### ✅ What You Should Be Doing
- Using Copilot **agents** for autonomous multi-step tasks
- Breaking work into **GitHub issues** and assigning to Copilot
- Delegating test generation to **testing subagent**
- Using **review subagent** for automated code review
- Creating **deployment automation** with Copilot's help

---

## Setup (One-Time)

### 1. Enable Agent Mode in VS Code

```json
// .vscode/settings.json (add this)
{
  "github.copilot.enable": true,
  "github.copilot.editor.enableAutoCompletions": true,
  "github.copilot.advanced": {
    "agentMode": "enabled"
  }
}
```

### 2. Install GitHub CLI (for issue management)

```powershell
# Windows (using Chocolatey)
choco install gh

# Or download from https://cli.github.com/
# Authenticate
gh auth login
```

### 3. Configure Custom Instructions

Already done! See `.github/copilot-instructions.md` for project-specific conventions.

---

## Workflow: Plan → Build → Test → Deploy

### Phase 1: Plan with Issues

#### Create Issues from Your Deployment Checklist

**Option A: Use Copilot Chat**
```
Prompt: "@workspace Create GitHub issues from the deployment checklist at 
docs/supabase/supabase-beproduct-migration/02a-tracking/docs/DEPLOYMENT-CHECKLIST.md

Break into:
- Pre-deployment tasks (3 issues)
- Deployment tasks (2 issues)  
- Testing tasks (4 issues)
- Production tasks (3 issues)
- Documentation (1 issue)

Use template from .github/ISSUE_TEMPLATE/02a-tracking-deployment.md
Add dependencies between issues
Include acceptance criteria
Add labels: phase-02a-tracking, [task-type]"
```

**Option B: Manual with Template**
```powershell
# Create issue from template
gh issue create --template 02a-tracking-deployment.md
```

**Result**: 13 trackable issues (see `GITHUB-ISSUES-BREAKDOWN.md`)

---

### Phase 2: Build with Copilot Agent

#### Assign Simple Issues to Copilot Agent

**Example: Issue #3 (Database Migration)**

1. **Create the issue** (as above)
2. **Assign to Copilot**:
   ```
   # In issue description or comment:
   @copilot assign
   
   # Or in VS Code Copilot Chat:
   "@workspace Assign GitHub issue #3 to Copilot agent"
   ```

3. **Copilot will**:
   - Clone repo to cloud workspace
   - Read migration files and schema
   - Apply migration via `npx supabase db push`
   - Run validation queries
   - Create PR with results
   - Add comment with verification steps

4. **You review**: Check PR, verify queries passed, merge

**Good Issues for Copilot Agent**:
- ✅ Database migrations (Issue #3)
- ✅ Configuration files (Issue #4)
- ✅ Test script generation (Issues #6-9)
- ✅ Documentation updates (Issue #13)

**Bad Issues for Copilot Agent** (require human judgment):
- ❌ Code review (Issue #1) - You need to review
- ❌ Production deployment (Issue #12) - Too risky
- ❌ 24-hour monitoring (Issue #11) - Time-dependent

---

#### Interactive Agent Mode for Complex Tasks

**Example: Debugging a Failed Webhook**

```
# In Copilot Chat (Ctrl+Alt+I):
"@workspace I'm getting a 500 error from beproduct-tracking-webhook when testing OnCreate event.

Context:
- Payload: docs/supabase/.../tracking_oncreate.json
- Logs show: 'Error: Plan not found'
- But plan exists in database

Steps:
1. Read the edge function code
2. Check error handling for plan lookup
3. Review the cache logic
4. Suggest fix
5. Generate test to prevent regression"
```

**Copilot will**:
- Read `supabase/functions/beproduct-tracking-webhook/index.ts`
- Analyze plan lookup logic
- Find bug (e.g., wrong UUID format)
- Propose fix with code change
- Generate unit test for plan caching

**You**:
- Review suggested fix
- Accept or iterate
- Copilot implements and tests

---

### Phase 3: Test with Testing Subagent

#### Generate Integration Tests

**Prompt**:
```
"@workspace Generate integration tests for beproduct-tracking-webhook

Requirements:
1. Test all 3 webhook events (OnCreate, OnChange, OnDelete)
2. Use sample payloads from docs/supabase/.../99-webhook-payloads/tracking/
3. Follow conventions in .github/copilot-instructions.md
4. Assert:
   - Webhook returns 200
   - Data in ops.tracking_plan_style
   - Timelines created (24+ records)
   - Assignments synced
   - Events logged to ops.beproduct_sync_log
5. Use Deno test framework
6. Save to supabase/functions/beproduct-tracking-webhook/test.ts"
```

**Copilot will**:
- Read sample payloads
- Generate Deno tests with proper imports
- Add assertions based on schema
- Include setup/teardown (create test data)
- Document how to run tests

**Run tests**:
```powershell
cd supabase/functions/beproduct-tracking-webhook
deno test --allow-net --allow-env test.ts
```

---

#### Generate Load Test Script

**Prompt**:
```
"@workspace Create a PowerShell script to load test beproduct-tracking-webhook

Requirements:
- Send 100 concurrent webhook requests
- Measure response times
- Calculate success rate
- Output summary (avg time, min/max, errors)
- Use tracking_oncreate.json payload
- Save to scripts/load-test-webhook.ps1"
```

**Copilot generates**:
```powershell
# scripts/load-test-webhook.ps1
$webhookUrl = "https://[project-id].supabase.co/functions/v1/beproduct-tracking-webhook"
$secret = $env:BEPRODUCT_WEBHOOK_SECRET
$payload = Get-Content "docs/.../tracking_oncreate.json" -Raw

$jobs = 1..100 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url, $secret, $payload)
        $start = Get-Date
        $response = Invoke-WebRequest -Uri $url -Method Post `
            -Headers @{ Authorization = "Bearer $secret" } `
            -Body $payload -ContentType "application/json"
        $end = Get-Date
        @{
            Status = $response.StatusCode
            Time = ($end - $start).TotalSeconds
        }
    } -ArgumentList $webhookUrl, $secret, $payload
}

# ... aggregation logic
```

**Run it**: `.\scripts\load-test-webhook.ps1`

---

### Phase 4: Deploy with Copilot Automation

#### Generate Deployment Script

**Prompt**:
```
"@workspace Create a PowerShell deployment script for beproduct-tracking-webhook

Requirements:
1. Check prerequisites (Supabase CLI installed, logged in)
2. Validate migration 009 is applied
3. Deploy edge function with --no-verify-jwt
4. Verify deployment (curl health check)
5. Output deployment URL
6. Log all steps
7. Exit with error codes if failures
8. Follow DEPLOYMENT-CHECKLIST.md
9. Save to scripts/deploy-tracking-webhook.ps1"
```

**Copilot generates full script with**:
- Pre-flight checks
- Error handling
- Colored output
- Rollback on failure

**Use it**: `.\scripts\deploy-tracking-webhook.ps1 -Environment staging`

---

## Advanced Copilot Techniques

### 1. Multi-File Edits with Agents

**Scenario**: Update all edge functions to use new logging format

**Prompt**:
```
"@workspace Update all edge functions to use structured logging

Changes needed:
1. Import logger from _shared/logger.ts
2. Replace console.log with logger.info
3. Replace console.error with logger.error
4. Include context (function name, event type)

Files:
- supabase/functions/beproduct-tracking-webhook/index.ts
- supabase/functions/beproduct-material-webhook/index.ts
- supabase/functions/beproduct-masterdata-sync/index.ts

Create a single PR with all changes."
```

**Copilot agent**:
- Edits all 3 files
- Ensures consistent format
- Creates PR "feat: migrate to structured logging"
- You review and merge

---

### 2. Documentation Generation

**Prompt**:
```
"@workspace Generate OpenAPI spec for future Supabase tracking API

Based on:
- docs/.../02-timeline/docs/endpoint-design.md (API design)
- supabase/migrations/*.sql (database schema)

Output:
- Full OpenAPI 3.0 spec
- Include all endpoints (GET /styles/:id/timeline, etc.)
- Request/response schemas from database types
- Authentication (Bearer token)
- Save to docs/api/tracking-api-spec.yaml"
```

**Result**: Production-ready API spec in minutes

---

### 3. Code Review with Review Subagent

**In PR for edge function**:

Comment:
```
@copilot review this PR for:
1. Supabase best practices (RLS, soft delete, upserts)
2. BeProduct integration patterns (field mapping, caching)
3. Error handling completeness
4. TypeScript type safety
5. Security issues
6. Performance concerns

Reference: .github/copilot-instructions.md for conventions
```

**Copilot reviews**:
- Highlights missing RLS policy
- Suggests adding index for foreign key
- Flags potential SQL injection (none in this case)
- Approves or requests changes

---

### 4. Migration Generation

**Prompt**:
```
"@workspace Generate Supabase migration to add forecast tables

Requirements from docs/.../03-forecasting/docs/stage-overview.md:
- Table: ops.forecast_style_demand
- Columns: id (uuid), style_id (uuid FK), forecast_date (date), 
  quantity (int), confidence (numeric), created_at, updated_at
- Indexes on: style_id, forecast_date
- RLS: authenticated users read-only
- Trigger: update updated_at
- Comments on table and columns
- Follow migration template in .github/copilot-instructions.md

Save to: supabase/migrations/014_create_forecast_tables.sql"
```

**Copilot generates**:
```sql
-- Create forecast tables for demand planning
-- Author: GitHub Copilot
-- Date: 2025-11-09

BEGIN;

CREATE TABLE ops.forecast_style_demand (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  style_id UUID NOT NULL REFERENCES pim.style(id),
  forecast_date DATE NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity >= 0),
  confidence NUMERIC(5,2) CHECK (confidence BETWEEN 0 AND 100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_style_forecast UNIQUE (style_id, forecast_date)
);

-- ... indexes, RLS, triggers, comments ...

COMMIT;
```

**Apply it**: `npx supabase db push`

---

## Real-World Examples for Your Project

### Example 1: Implement Material Webhook (Phase 2)

**Your task**: Add support for material timeline webhooks

**With Copilot**:
```
"@workspace Create beproduct-material-timeline-webhook edge function

Copy structure from beproduct-tracking-webhook but for materials:
1. Same event types (OnCreate, OnChange, OnDelete)
2. Target table: ops.tracking_plan_material_timeline
3. Follow same caching pattern for plan/folder
4. Use same logging pattern
5. Add README with deployment steps
6. Generate test payloads

Deliverables:
- supabase/functions/beproduct-material-timeline-webhook/index.ts
- supabase/functions/beproduct-material-timeline-webhook/README.md
- docs/.../99-webhook-payloads/material-tracking/ (sample payloads)"
```

**Copilot implements in <10 minutes** what would take you 2-3 hours.

---

### Example 2: Add Timeline API Endpoints (Phase 2)

**Your task**: Build REST API for timeline queries

**With Copilot**:
```
"@workspace Implement Supabase edge function for timeline API

Based on docs/.../02-timeline/docs/endpoint-design.md:

Endpoints:
1. GET /styles/:id/timeline - Retrieve all milestones for style
2. PUT /styles/:id/timeline/:milestone - Update single milestone
3. POST /styles/:id/timeline/calculate-critical-path - Run critical path

Requirements:
- Authentication via Supabase JWT
- Validate user has access to style (check RLS)
- Return JSON matching schema in endpoint-design.md
- Log API calls to ops.api_usage table
- Error handling (404, 403, 500)
- CORS for frontend

Create:
- supabase/functions/tracking-api/index.ts
- Integration tests
- README
- Add to OpenAPI spec"
```

**Copilot builds full API** with routes, validation, auth.

---

### Example 3: Generate Monitoring Dashboard Queries

**Prompt**:
```
"@workspace Generate SQL monitoring queries for tracking webhook

Metrics needed:
1. Webhook event counts by action (last 24h, last 7d)
2. Average processing time by event type
3. Error rate (% of failed webhooks)
4. Top 10 slowest webhook events
5. API cache hit rate
6. Incomplete syncs (styles with <20 timelines)
7. Orphaned records (invalid foreign keys)

Format:
- Each query as separate CTE
- Comments explaining logic
- Easy to copy/paste to Supabase dashboard
- Save to docs/monitoring/webhook-metrics.sql"
```

**Copilot generates production monitoring queries**.

---

## Common Pitfalls to Avoid

### ❌ Don't: Use Copilot autocomplete only
**Why**: You're only using 10% of Copilot's capabilities

### ✅ Do: Use agents for multi-step tasks
**How**: Assign issues to Copilot, let it create PRs

---

### ❌ Don't: Write all tests manually
**Why**: Copilot can generate comprehensive test suites

### ✅ Do: Prompt for test generation
**How**: "@workspace generate tests for [function] covering [scenarios]"

---

### ❌ Don't: Review code without Copilot
**Why**: Copilot can spot issues you might miss

### ✅ Do: Use review subagent in PRs
**How**: Comment "@copilot review for [criteria]"

---

### ❌ Don't: Manually write boilerplate
**Why**: Edge functions, migrations, tests follow patterns

### ✅ Do: Prompt Copilot to generate from templates
**How**: Reference existing files: "Create webhook like beproduct-tracking-webhook"

---

## Measuring Impact

### Before Copilot Agents
- **Planning**: 2 hours (manual Markdown)
- **Implementation**: 4 hours (write edge function)
- **Testing**: 2 hours (write tests, run manually)
- **Deployment**: 1 hour (manual commands)
- **Documentation**: 1 hour
- **Total**: ~10 hours per feature

### After Copilot Agents
- **Planning**: 30 min (Copilot generates issues)
- **Implementation**: 1 hour (Copilot implements, you review)
- **Testing**: 30 min (Copilot generates tests)
- **Deployment**: 15 min (use generated script)
- **Documentation**: 15 min (Copilot updates docs)
- **Total**: ~2.5 hours per feature

**Time savings**: ~75% (10 hrs → 2.5 hrs)

---

## Next Steps

### Immediate (Today)
1. ✅ Custom instructions created (`.github/copilot-instructions.md`)
2. ✅ Issue template created (`.github/ISSUE_TEMPLATE/`)
3. ✅ Issue breakdown documented (`GITHUB-ISSUES-BREAKDOWN.md`)
4. ⬜ Create 13 GitHub issues from breakdown
5. ⬜ Assign Issues #3, #6-9, #13 to Copilot agent

### This Week
6. ⬜ Use Copilot to generate integration tests
7. ⬜ Use Copilot to create deployment script
8. ⬜ Use review subagent on next PR
9. ⬜ Generate monitoring queries with Copilot

### Next Phase (Phase 2 Prep)
10. ⬜ Use Copilot to draft Phase 2 issues (reverse sync)
11. ⬜ Generate material webhook with Copilot
12. ⬜ Build timeline API with Copilot agent
13. ⬜ Create full OpenAPI spec

---

## Resources

- [GitHub Copilot Docs](https://docs.github.com/en/copilot)
- [Copilot Agent Mode](https://code.visualstudio.com/docs/copilot/copilot-extensibility-overview)
- [Supabase Best Practices](https://supabase.com/docs/guides/platform)
- [Project's Copilot Instructions](.github/copilot-instructions.md)
- [Issue Breakdown](docs/.../02a-tracking/docs/GITHUB-ISSUES-BREAKDOWN.md)

---

**Status**: Ready to Use  
**Impact**: 75% time savings on development tasks  
**Next**: Create GitHub issues and assign to Copilot  
**Updated**: November 9, 2025
