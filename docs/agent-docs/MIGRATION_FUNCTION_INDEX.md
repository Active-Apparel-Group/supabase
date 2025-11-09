...existing code...
# Migration and Function Index

This file provides a canonical index of all SQL migration scripts and Edge Function code for the Supabase project. All code/scripts are centralized in the main `supabase/` folder. Documentation and planning files reference these canonical locations.

## SQL Migrations

- `supabase/migrations/001_create_pim_style.sql` — DDL for PIM schema tables (style, colorway, size class, color palette, etc.)
- `supabase/migrations/010_remove_template_foreign_keys.sql` — Drops foreign key constraints to local timeline template tables now sourced from BeProduct
- `supabase/migrations/011_merge_tracking_folders.sql` — Merges duplicate tracking folder IDs and realigns downstream references
- `supabase/migrations/test_timeline_assignment.sql` — pgTAP tests for timeline assignment, sharing, and responsibility
- `supabase/migrations/test_timeline_core.sql` — pgTAP tests for timeline core logic

## Edge Functions

- `supabase/functions/beproduct-webhook/index.ts` — BeProduct webhook handler for real-time PIM sync
- `supabase/functions/beproduct-webhook/README.md` — Documentation for the BeProduct webhook Edge Function

## How to Reference

- All documentation and planning files should reference the above canonical locations for code/scripts.
- To add new migrations or functions, place them in the appropriate folder above and update this index.

## Related Docs

- See `/docs/CENTRALIZED-TESTING-PLAN.md` and `/docs/WORKFLOW-OVERVIEW.md` for testing and workflow details.
