# Forecasting Stage Overview

This stage covers demand forecasting for styles and products.

## Key Artifacts
- Table: `forecasting_demand`
- Triggers: `trg_forecasting_insert_demand`, ...
- Functions: `fn_forecasting_calculate`, ...

## Mermaid Diagram
```mermaid
erDiagram
    forecasting_demand {
        uuid id PK
        uuid style_id FK
        int forecast_qty
        date forecast_date
        ...
    }
```


All SQL migrations and Edge Function code/scripts are now centralized in the canonical `supabase/` folders. See [Migration and Function Index](../../../../supabase/MIGRATION_FUNCTION_INDEX.md) for the single source of truth.

[Back to Workflow Overview](../../supabase/docs/WORKFLOW-OVERVIEW.md)
