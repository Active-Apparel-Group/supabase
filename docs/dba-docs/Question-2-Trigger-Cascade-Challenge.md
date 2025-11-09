# DBA Interview Question #2: Trigger-Driven Automation & Cascade Logic

## Question Overview
Your tracking system uses Postgres triggers to automatically manage timeline dates, cascade updates across dependencies, and instantiate milestones. You've encountered race conditions and cascading deletes that leave orphaned records. You need to audit the trigger logic and propose improvements.

---

## The Scenario

### Current State
Your schema includes the following triggers:

1. **`trg_instantiate_style_timeline`** — When a new style is added to a plan, automatically create milestone timeline rows from a template
2. **`calculate_timeline_dates_trigger`** — Before INSERT/UPDATE on `tracking_plan_style_timeline`, calculate `start_date_plan` and `start_date_due` based on anchor dates and dependencies
3. **`cascade_timeline_updates_trigger`** — After UPDATE on `tracking_plan_style_timeline`, propagate status/date changes to dependent timelines
4. **`calculate_material_timeline_dates_trigger`** — Similar to timeline trigger, but for materials
5. **`cascade_material_timeline_updates_trigger`** — Similar cascade, but for materials
6. **`recalculate_plan_timelines_trigger`** — When a plan's `start_date` or `template_id` is updated, recalculate all child timelines

### The Problem
Your team reports:
- **Race condition:** Two simultaneous INSERTs of styles into the same plan sometimes create duplicate or missing timelines
- **Cascade delays:** Updates to a single milestone take 5+ seconds when there are 100+ dependent rows
- **Orphaned records:** Deleting a template leaves timeline records pointing to non-existent template items
- **Deadlocks:** Concurrent updates trigger PostgreSQL deadlock errors
- **Data inconsistency:** Two queries run 1 second apart return different `start_date_plan` values for the same row

### Data Dependencies
```
tracking_timeline_template
    ↓ (template_id)
tracking_plan
    ↓
tracking_plan_style → trigger instantiates → tracking_plan_style_timeline
                                                    ↓ (template_item_id)
                                            tracking_timeline_template_item
                                                    ↓ (depends_on_template_item_id)
                                            tracking_timeline_template_item (self-ref)

Dependencies:
    tracking_plan_style_timeline → (successor/predecessor) → tracking_plan_style_dependency
```

---

## Questions to Answer

### Part A: Race Condition Analysis (35%)
1. **Describe the race condition** that could occur when two styles are inserted simultaneously into the same plan with `trg_instantiate_style_timeline`
2. **What table locks or advisory locks** would you use to prevent this?
3. **Write pseudocode** for a corrected version of the trigger using `FOR UPDATE` or `pg_advisory_lock()`
4. **How would you test this fix** without access to a production-scale dataset?

### Part B: Cascade Performance & Correctness (35%)
1. **Analyze the cascade trigger logic:**
   - Should a cascade update trigger additional cascades (cascading cascades)?
   - How deep should cascades propagate before stopping?
2. **Propose an optimization** for the cascade when there are 100+ dependent rows
   - Would you use recursive CTEs? Temporary tables? Materialized views?
   - What are the trade-offs of each approach?
3. **How would you prevent infinite loops** if a dependency chain accidentally forms a cycle?
4. **Write a query** to detect cycles in the dependency graph and flag them

### Part C: Orphaned Record Prevention (15%)
1. **Design a strategy** to handle cascade deletes when a template item is deleted or a template is marked inactive
2. **Should timeline records be soft-deleted or hard-deleted?** Justify your answer
3. **How would you handle the audit trail** if timelines are orphaned but not deleted?

### Part D: Consistency & Observability (15%)
1. **Why might two identical queries return different `start_date_plan` values** if run 1 second apart?
   - Is this a trigger execution order issue? A read consistency issue? Something else?
2. **How would you add observability** to detect when triggers skip or fail silently?
3. **What should happen if a trigger fails?** Should the parent operation (INSERT/UPDATE) roll back or continue with a warning?

---

## Evaluation Criteria

See the **Answer Sheet** for scoring details.

---

## Time Limit
**45 minutes** for a verbal/written response

---

## Resources Provided to Candidate
- Current trigger definitions (see section 1.3 in blueprint)
- Sample dependency graph (visual or SQL result set)
- List of reported issues from your team
- Schema reference for tables and relationships

