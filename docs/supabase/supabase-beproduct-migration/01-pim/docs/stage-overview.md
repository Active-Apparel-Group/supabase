# PIM Stage Overview

This stage covers Product Information Management (PIM), where styles and core product data are ingested and synchronized from BeProduct.

## Key Artifacts
- Table: `pim_style`
- Triggers: `trg_pim_insert_style`, ...
- Functions: `fn_pim_upsert_style`, ...
- Edge Function: `ef_pim_webhook_handler`

## Mermaid Diagram
```mermaid
erDiagram
    pim_style {
        uuid id PK
        text style_code
        text description
        ...
    }
```


## Integration
- BeProduct sends webhooks to the canonical Edge Function (see [Migration and Function Index](../../../../supabase/MIGRATION_FUNCTION_INDEX.md)).
- Edge function processes and upserts data into `pim_style`.

[Back to Workflow Overview](../../supabase/docs/WORKFLOW-OVERVIEW.md)
