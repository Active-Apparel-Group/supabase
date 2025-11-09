# DBA Interview Question #3: ETL Integration, Data Validation & Import Strategy

## Question Overview
Your system integrates webhook payloads from BeProduct (upstream content management system) into Supabase. You must design an ETL strategy that validates data, handles duplicates, manages failures gracefully, and maintains referential integrity without breaking the live import pipeline.

---

## The Scenario

### Current State
- **Source:** BeProduct webhooks (`OnChange` events) for materials, styles, and templates
- **Endpoint:** Supabase Edge Functions trigger on incoming webhooks
- **Current logging:** Import events logged to `import_batches`, `import_errors`, `beproduct_sync_log` (RLS disabled for logging)
- **Frequency:** 100s of events per day across 3-5 concurrent webhook processes
- **Data volume:** Each webhook payload contains nested JSON with 10-100 fields (see sample `change_material.json`)

### Sample Webhook Payload (Materials)
```json
{
  "eventType": "OnChange",
  "objectType": "Header",
  "headerId": "b07fbed9-...",
  "headerNumber": "VVSIS01",
  "headerName": "STRETCHED SILK WOVEN",
  "data": {
    "after": {
      "header_number": { "value": "VVSIS01", "type": "Text" },
      "material_type": { "value": "Woven", "type": "DropDown" },
      "composition": { 
        "value": [
          { "code": "VISCOSE", "value": 59 },
          { "code": "SILK", "value": 30 }
        ],
        "type": "CompositeControl"
      },
      "supplier": { "value": null, "type": "PartnerDropDown" },
      "brand_1": { "value": "AAG CORE", "type": "DropDown" }
    },
    "before": { ... }
  },
  "date": "2025-11-04T01:32:29.756Z"
}
```

### Current Challenges
1. **Duplicate handling:** Same webhook can arrive twice; must detect and skip second insert
2. **Referential integrity:** A style webhook references a folder that may not exist yet
3. **Type coercion:** BeProduct sends `{ "value": X, "type": Y }` objects; must extract and validate
4. **Partial updates:** Some payloads have `"before"` and `"after"` data; only changed fields should update
5. **Missing upstream data:** A supplier_id is null; should we skip the row or insert with NULL?
6. **Concurrent imports:** Same entity updated twice within 1 second by different webhook processes
7. **Audit trail:** Must track which fields changed, who made the change, and when

### Tables Involved
```sql
-- Main tracking tables
tracking.tracking_folder          -- Brand-scoped folder
tracking.tracking_plan_material   -- Material link to plan
tracking.tracking_timeline_template
tracking.tracking_timeline_template_item

-- Logging tables (RLS disabled)
tracking.import_batches           -- Batch metadata
tracking.import_errors            -- Individual error records
tracking.beproduct_sync_log       -- Detailed action log
```

---

## Questions to Answer

### Part A: ETL Pipeline Design (30%)
1. **Outline the ETL workflow** for a webhook to become a database row
   - Where would you extract, validate, and load?
   - Would you use Edge Functions, database functions, or both?
2. **Design a deduplication strategy:**
   - What would you use as a unique key? (hint: consider `eventType`, `objectType`, `date`, `headerId`)
   - Should you check for duplicates before inserting or use database constraints (UNIQUE, ON CONFLICT)?
   - How long should you retain the dedup check (24 hours? 7 days?)?
3. **How would you handle the `"before"` and `"after"` structure** to detect what actually changed?
   - Should you track all field changes or only certain fields?
   - How would you store the delta in `beproduct_sync_log`?

### Part B: Data Validation & Error Handling (25%)
1. **Design validation rules** for the material import:
   - Required fields: `headerNumber`, `headerName`, `brand_1` (must not be null)
   - Type validation: `composition` must be an array of objects with `code` and `value` keys
   - Range validation: `material_weight`, `material_width` must be > 0
   - Reference validation: `supplier_id` must exist in a suppliers table OR be null
2. **What should happen if validation fails?**
   - Should the entire batch fail or just the offending row?
   - How would you allow partial success with detailed error reporting?
3. **Write pseudocode** for a validation function that returns `{ valid: bool, errors: [...] }`
4. **Should you retry failed imports?** If so, how many times and with what backoff?

### Part C: Concurrency & Referential Integrity (25%)
1. **Handle this scenario:** Two webhooks arrive simultaneously:
   - Webhook A: Update material M1's supplier (supplier_id = S1)
   - Webhook B: Update material M1's brand (brand = AAG_PREMIUM)
   
   How would you ensure both updates apply without one overwriting the other?

2. **Foreign key challenge:** A style webhook references a folder that doesn't exist yet
   - Would you fail the import or create a placeholder folder?
   - How long would you wait for the folder to appear before giving up?
   - Should you implement a "deferred import" queue?

3. **Upsert strategy:** Should you use PostgreSQL `INSERT ... ON CONFLICT ... DO UPDATE` or application-level logic?
   - What are the pros/cons of each?
   - Write the SQL for an upsert that preserves existing timestamps and only updates changed fields

### Part D: Observability & Rollback (20%)
1. **Design a monitoring strategy:**
   - What metrics would you track? (import rate, error rate, lag, data quality)
   - How would you detect when imports are slow or failing?
   - Should you alert on a single failed row or aggregate errors?

2. **Implement a rollback mechanism:**
   - If a batch of 100 imports is partially successful (95 ok, 5 fail), should you roll back all 100 or keep the 95?
   - How would you design the `import_batches` table to support partial rollback?
   - How would you communicate rollback to upstream (BeProduct)?

3. **Audit trail question:**
   - Should `tracking_timeline_status_history` include entries for auto-generated records from imports?
   - How would you distinguish between user-initiated changes and import-driven changes?

---

## Evaluation Criteria

See the **Answer Sheet** for scoring details.

---

## Time Limit
**45 minutes** for a verbal/written response

---

## Resources Provided to Candidate
- Sample webhook payload (`change_material.json`)
- Current import logging schema (section 3.6 in blueprint)
- List of recent import failures (if available)
- Schema reference for all tables

