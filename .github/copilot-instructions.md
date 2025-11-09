# GitHub Copilot Instructions

## Project Overview
This is a **Supabase-based PLM (Product Lifecycle Management)** backend for apparel/fashion industry, syncing data from BeProduct (SaaS PLM) via webhooks and providing custom APIs.

## Tech Stack
- **Database**: PostgreSQL (Supabase) with `pim`, `ops`, `config` schemas
- **Edge Functions**: Deno/TypeScript (Supabase Functions)
- **Integration**: BeProduct REST API + Webhooks
- **Deployment**: Supabase CLI (`npx supabase`)

## Code Conventions

### TypeScript/Deno Edge Functions
- Use **explicit types** (no `any`)
- Import Supabase client from `../_shared/supabase-client.ts`
- Always use `try-catch` with detailed error logging
- Log all webhook events to `ops.beproduct_sync_log`
- Log errors to `ops.import_errors`
- Use `ON CONFLICT DO UPDATE` for idempotent upserts
- Environment variables: `Deno.env.get('VAR_NAME')`
- CORS: Include `Access-Control-Allow-Origin: *` for all responses

### Database Patterns
- **Schemas**: `pim` (styles/materials), `ops` (tracking/forecasting), `config` (master data)
- **Naming**: Snake_case for tables/columns
- **UUIDs**: Use `uuid` type for primary keys (gen_random_uuid())
- **Timestamps**: Always include `created_at` (default NOW()), `updated_at` (trigger-based)
- **Soft Delete**: Use `active BOOLEAN DEFAULT true` (never hard delete)
- **Audit**: Log changes to `*_sync_log` tables
- **RLS**: Enable Row Level Security on all tables (auth.uid() for user context)

### BeProduct Integration
- **API Base**: `https://developers.beproduct.com`
- **Company**: `activeapparelgroup`
- **Auth**: OAuth2 Bearer token (store in `BEPRODUCT_ACCESS_TOKEN`)
- **Webhook Secret**: Validate with `Authorization` header
- **Field Mapping**: BeProduct uses PascalCase, Supabase uses snake_case
- **Status Enums**: Map BeProduct strings to Supabase enums (e.g., "Not Started" → `NOT_STARTED`)
- **Caching**: Always check if plan/folder exists in DB before calling API

### Migration Patterns
- **File Naming**: `###_descriptive_name.sql` (e.g., `001_create_pim_style.sql`)
- **Structure**:
  ```sql
  -- Description
  -- Author: [name]
  -- Date: YYYY-MM-DD
  
  BEGIN;
  
  -- DDL here
  
  -- Comments on tables/columns
  COMMENT ON TABLE ...
  
  COMMIT;
  ```
- **Never**: Drop columns with data (use soft delete)
- **Always**: Add indexes for foreign keys
- **RLS**: Create policies immediately after table creation

### Testing
- Test edge functions locally: `npx supabase functions serve [name] --no-verify-jwt`
- Test webhooks: Use payloads from `docs/supabase/supabase-beproduct-migration/99-webhook-payloads/`
- Validate data: Query `ops.beproduct_sync_log` and `ops.import_errors`
- Load test: Target < 2 seconds per webhook

## Current Phase: 02a-Tracking (One-Way Sync)

### Active Work
- **Goal**: Real-time BeProduct → Supabase sync via `beproduct-tracking-webhook`
- **Status**: Implementation complete, ready for testing
- **Next**: Deploy to staging, test with real webhooks

### What NOT to Touch
- **02-timeline** folder: Future schema redesign (on hold)
- Date calculation triggers: Disabled in migration `009` (BeProduct is source of truth)
- Template/dependency foreign keys: Removed for Phase 1

### Future Phases
- **Phase 2**: Add Supabase → BeProduct reverse sync (bidirectional)
- **Phase 3**: Custom timeline APIs with critical path calculations

## Common Tasks

### Adding a New Edge Function
1. Create: `supabase/functions/[name]/index.ts`
2. Import shared utilities from `_shared/`
3. Add environment variables to `supabase/config.toml`
4. Deploy: `npx supabase functions deploy [name] --no-verify-jwt`
5. Document in function's `README.md`

### Creating a Migration
1. Generate: `npx supabase migration new [name]`
2. Write SQL in `supabase/migrations/###_[name].sql`
3. Test locally: `npx supabase db reset`
4. Apply: `npx supabase db push`

### Webhook Event Handling
1. Authenticate with `BEPRODUCT_WEBHOOK_SECRET`
2. Parse event type (OnCreate, OnChange, OnDelete)
3. Check cache (plan/folder in DB)
4. Upsert to target tables
5. Log to `ops.beproduct_sync_log`
6. Return 200 OK (or error with details)

## Documentation Standards
- **Plans**: Store in `docs/supabase/supabase-beproduct-migration/[phase]/docs/`
- **README**: Each phase folder needs a README with quick start, architecture, status
- **Code Comments**: Explain "why", not "what"
- **Migration Comments**: SQL comments on all tables/columns

## Prohibited Patterns
- ❌ No `SELECT *` in production queries
- ❌ No hardcoded credentials (use env vars)
- ❌ No unhandled promise rejections
- ❌ No `console.log` (use structured logging)
- ❌ No direct database deletes (soft delete only)
- ❌ No FK constraints to template tables (removed for Phase 1)

## When in Doubt
1. Check existing code in `supabase/functions/beproduct-tracking-webhook/`
2. Reference `docs/supabase/supabase-beproduct-migration/02a-tracking/` plans
3. Review sample payloads in `99-webhook-payloads/`
4. Follow Supabase best practices: https://supabase.com/docs
