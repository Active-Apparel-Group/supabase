# Supabase PLM Backend

**Purpose**: Product Lifecycle Management (PLM) backend for apparel/fashion industry  
**Stack**: Supabase (PostgreSQL + Edge Functions) + BeProduct Integration  
**Status**: Phase 02a-Tracking deployment in progress

---

## Quick Start

### For New Developers
1. **Read**: [.github/COPILOT-SETUP-README.md](.github/COPILOT-SETUP-README.md) - Learn GitHub Copilot workflow (15 min setup)
2. **Review**: [.github/copilot-instructions.md](.github/copilot-instructions.md) - Project conventions
3. **Onboard**: [docs/dba-docs/DBA-ONBOARDING.md](docs/dba-docs/DBA-ONBOARDING.md) - Database setup

### For Current Phase Work
- **Active Phase**: [docs/supabase/supabase-beproduct-migration/02a-tracking/](docs/supabase/supabase-beproduct-migration/02a-tracking/) - Tracking webhook sync
- **Issues**: See [GITHUB-ISSUES-BREAKDOWN.md](docs/supabase/supabase-beproduct-migration/02a-tracking/docs/GITHUB-ISSUES-BREAKDOWN.md)
- **Deployment**: Follow [DEPLOYMENT-CHECKLIST.md](docs/supabase/supabase-beproduct-migration/02a-tracking/docs/DEPLOYMENT-CHECKLIST.md)

---

## Project Structure

```
.github/                           # GitHub config and Copilot instructions
  ├── copilot-instructions.md      # ⭐ Project conventions for Copilot
  ├── COPILOT-SETUP-README.md      # ⭐ Quick start for Copilot workflow
  └── ISSUE_TEMPLATE/              # Issue templates

supabase/                          # Supabase CLI project
  ├── functions/                   # Edge functions (Deno/TypeScript)
  │   ├── beproduct-tracking-webhook/  # ⭐ Phase 02a-Tracking
  │   ├── beproduct-material-webhook/
  │   └── _shared/                 # Shared utilities
  ├── migrations/                  # Database migrations
  └── config.toml                  # Supabase configuration

docs/                              # Developer documentation
  ├── agent-docs/                  # AI agent guides
  │   └── COPILOT-WORKFLOW-GUIDE.md  # ⭐ Comprehensive Copilot guide
  ├── supabase/supabase-beproduct-migration/
  │   ├── 02a-tracking/            # ⭐ Current phase (webhook sync)
  │   ├── 02-timeline/             # Future phase (on hold)
  │   └── 99-webhook-payloads/     # Test data
  └── dba-docs/                    # Database documentation

apps/                              # Frontend applications (future)
scripts/                           # Utility scripts
```

---

## Current Phase: 02a-Tracking

### Goal
Real-time BeProduct → Supabase sync via `beproduct-tracking-webhook`

### Status
✅ Implementation complete  
🔄 Testing in progress  
⬜ Production deployment pending

### Quick Links
- [Phase README](docs/supabase/supabase-beproduct-migration/02a-tracking/README.md)
- [Deployment Checklist](docs/supabase/supabase-beproduct-migration/02a-tracking/docs/DEPLOYMENT-CHECKLIST.md)
- [GitHub Issues](docs/supabase/supabase-beproduct-migration/02a-tracking/docs/GITHUB-ISSUES-BREAKDOWN.md)

---

## Using GitHub Copilot (⭐ Important!)

This project uses **GitHub Copilot agents** for development acceleration.

### Quick Setup (15 minutes)
1. Read [.github/COPILOT-SETUP-README.md](.github/COPILOT-SETUP-README.md)
2. Enable agent mode in VS Code
3. Create GitHub issues from breakdown
4. Assign issues to Copilot

### Expected Impact
- 75% faster implementation
- Auto-generated tests
- Automated code review
- Always-updated documentation

**Full Guide**: [docs/agent-docs/COPILOT-WORKFLOW-GUIDE.md](docs/agent-docs/COPILOT-WORKFLOW-GUIDE.md)

---

## Development Workflow

### Issue-Driven Development
1. **Plan**: Break work into GitHub issues
2. **Assign**: Delegate to Copilot agent or team member
3. **Review**: Copilot creates PR, you review
4. **Deploy**: Use generated scripts

### Common Commands

```powershell
# Database
npx supabase db reset              # Reset local DB
npx supabase db push               # Apply migrations
npx supabase migration new [name]  # Create migration

# Edge Functions
npx supabase functions serve [name] --no-verify-jwt  # Test locally
npx supabase functions deploy [name] --no-verify-jwt # Deploy
npx supabase functions logs [name] --tail            # Monitor

# Testing
deno test                          # Run tests
.\scripts\load-test-webhook.ps1    # Load test
```

---

## Tech Stack

- **Database**: PostgreSQL (Supabase) with `pim`, `ops`, `config` schemas
- **Backend**: Supabase Edge Functions (Deno/TypeScript)
- **Integration**: BeProduct REST API + Webhooks
- **Frontend**: React/Next.js (future)
- **Deployment**: Supabase CLI

---

## Documentation Index

### Getting Started
- [Copilot Setup](.github/COPILOT-SETUP-README.md) ⭐
- [Copilot Workflow Guide](docs/agent-docs/COPILOT-WORKFLOW-GUIDE.md) ⭐
- [Project Conventions](.github/copilot-instructions.md) ⭐
- [DBA Onboarding](docs/dba-docs/DBA-ONBOARDING.md)

### Current Phase (02a-Tracking)
- [Phase Overview](docs/supabase/supabase-beproduct-migration/02a-tracking/README.md)
- [Implementation Summary](docs/supabase/supabase-beproduct-migration/02a-tracking/docs/IMPLEMENTATION-SUMMARY.md)
- [Deployment Checklist](docs/supabase/supabase-beproduct-migration/02a-tracking/docs/DEPLOYMENT-CHECKLIST.md)
- [GitHub Issues Breakdown](docs/supabase/supabase-beproduct-migration/02a-tracking/docs/GITHUB-ISSUES-BREAKDOWN.md)

### API & Integration
- [Webhook Documentation](docs/api/webhooks.md)
- [Edge Functions](docs/api/edge-functions.md)
- [BeProduct Integration](docs/integration/WORKFLOW-OVERVIEW.md)

### Database
- [Schema Overview](docs/schema/README.md)
- [PIM Schema](docs/schema/pim-schema.md)
- [OPS Schema](docs/schema/ops-schema.md)

### Future Phases
- [Phase 02-Timeline](docs/supabase/supabase-beproduct-migration/02-timeline/) (on hold)
- [Phase 03-Forecasting](docs/supabase/supabase-beproduct-migration/03-forecasting/)

---

## Contributing

1. Create GitHub issue (or use Copilot to generate)
2. Create branch: `git checkout -b feature/issue-123`
3. Implement (use Copilot agent for automation)
4. Open PR (Copilot can auto-review)
5. Merge after approval

**See**: [COPILOT-WORKFLOW-GUIDE.md](docs/agent-docs/COPILOT-WORKFLOW-GUIDE.md) for details

---

## License

[Your License]

---

**Last Updated**: November 9, 2025  
**Current Phase**: 02a-Tracking  
**Next Milestone**: Production deployment
