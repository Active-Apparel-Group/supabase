# DBA Interview Answer Sheet & Scoring Guide

## Overview
Use this guide to evaluate candidate responses to the three interview questions. Each question is scored out of 100 points, broken down into subsections. A candidate should achieve **70+ points per question** to be considered "strong" and ready for the role.

---

# QUESTION 1: Row-Level Security (RLS) & Multi-Tenant Access Control

**Total Points: 100**

## Part A: RLS Policy Design (40 points)

### Criterion 1.A.1: SELECT Policy Implementation (15 points)

**Expected Response:**
The candidate should write SQL similar to the following:

```sql
CREATE POLICY "brand_scoped_select" ON tracking.tracking_plan FOR SELECT
USING (
  brand = ANY(current_setting('jwt.claims.brand_ids', true)::text[])
  OR auth.jwt() ->> 'role' = 'admin'
);
```

**Alternative acceptable approach:**
```sql
CREATE POLICY "brand_scoped_select" ON tracking.tracking_plan FOR SELECT
USING (
  CASE 
    WHEN auth.jwt() ->> 'role' = 'admin' THEN true
    WHEN brand IS NOT NULL THEN brand = ANY(
      string_to_array(auth.jwt() ->> 'brand_ids', ',')
    )
    ELSE false
  END
);
```

**Scoring:**
- **15 pts:** Correct use of `current_setting('jwt.claims')` or `auth.jwt()`, handles array/string type coercion, includes admin bypass
- **12 pts:** Correct policy logic but inefficient type coercion (e.g., lacks string_to_array)
- **9 pts:** Basic policy structure correct but missing admin bypass or type handling
- **6 pts:** Policy exists but has security flaws (e.g., allows all users)
- **0 pts:** No policy or fundamentally incorrect

### Criterion 1.A.2: JWT Claim Handling (10 points)

**Expected Response:**
The candidate should discuss:
1. **Array vs. String:** Explain that `brand_ids` is best transmitted as a JSON array in JWT, but PostgreSQL stores as `text[]`
   - If transmitted as string, use `string_to_array()` for splitting
   - If transmitted as JSON array, use `jsonb_array_elements_text()`
2. **Null safety:** Check if claim exists before using: `COALESCE(auth.jwt() ->> 'brand_ids', '[]')`
3. **Performance:** Cache the decoded claim in a session variable to avoid re-parsing on each query

**Scoring:**
- **10 pts:** Discusses both array representation and performance optimization
- **8 pts:** Correctly identifies type coercion but doesn't mention performance
- **6 pts:** Identifies the issue but vague on implementation
- **3 pts:** Recognizes problem but no clear solution
- **0 pts:** No answer or completely wrong

### Criterion 1.A.3: Missing Claim Edge Case (10 points)

**Expected Response:**
The candidate should suggest:
1. **Default to deny:** If `brand_ids` claim is missing, deny all access
   ```sql
   USING (
     CASE 
       WHEN auth.jwt() ->> 'brand_ids' IS NULL THEN false
       ELSE brand = ANY(string_to_array(auth.jwt() ->> 'brand_ids', ','))
     END
   );
   ```
2. **Rationale:** This is a "deny by default" security posture
3. **Alternative:** Create a role mapping table that provides default brands if claim is missing, but require explicit configuration

**Scoring:**
- **10 pts:** Correctly implements deny-by-default; explains security rationale
- **8 pts:** Correct logic but doesn't explain why deny-by-default is better than allow
- **6 pts:** Recognizes edge case but proposes questionable solution (e.g., allow all if missing)
- **3 pts:** Mentions the edge case but no clear handling
- **0 pts:** No answer or suggests insecure default (allow all)

### Criterion 1.A.4: Single vs. Multiple Policies (5 points)

**Expected Response:**
The candidate should recommend:
- **Multiple policies recommended** for clarity and maintainability:
  - One for brand-scoped users
  - One for admins (bypass)
  - One for public data (if applicable)
- **Reason:** Makes it easier to audit, test, and modify individual policies without affecting others
- **Trade-off:** Slight performance overhead (PostgreSQL evaluates all policies), but negligible for <5 policies

**Scoring:**
- **5 pts:** Recommends multiple policies with clear rationale
- **4 pts:** Recommends multiple policies but weak justification
- **3 pts:** Says either works but doesn't clearly prefer one
- **2 pts:** Proposes single policy without considering maintainability
- **0 pts:** No answer or conflicting reasoning

---

## Part B: Supplier Access Pattern (30 points)

### Criterion 1.B.1: Supplier SELECT Policy (15 points)

**Expected Response:**
```sql
CREATE POLICY "supplier_material_visibility" ON tracking.tracking_plan_material FOR SELECT
USING (
  -- User is the assigned supplier
  supplier_id = auth.uid()
  OR
  -- Supplier is listed in shared_with array
  supplier_id = ANY(
    SELECT jsonb_array_elements(shared_with)->>'id'
    FROM tracking.tracking_plan_material t
    WHERE t.id = tracking_plan_material.id
  )
  OR
  -- Check parent plan's suppliers list
  plan_id IN (
    SELECT id FROM tracking.tracking_plan tp
    WHERE tp.suppliers @> jsonb_build_array(jsonb_build_object('id', auth.uid()::text))
  )
);
```

**Acceptable simpler approach:**
```sql
CREATE POLICY "supplier_material_visibility" ON tracking.tracking_plan_material FOR SELECT
USING (
  shared_with @> jsonb_build_array(jsonb_build_object('supplier_id', auth.uid()::text))
);
```

**Scoring:**
- **15 pts:** Handles all three access patterns (direct supplier_id, shared_with array, parent plan); uses appropriate JSONB operators
- **12 pts:** Handles 2/3 access patterns; correct JSONB logic
- **9 pts:** Handles 1/2 access patterns; JSONB logic mostly correct but not optimized
- **6 pts:** Attempts to write policy but has logical errors (e.g., missing type coercion)
- **0 pts:** No policy or fundamentally flawed

### Criterion 1.B.2: Handling Implicit vs. Explicit Access (10 points)

**Expected Response:**
The candidate should discuss:
1. **Parent plan suppliers:** If a supplier is listed in `tracking_plan.suppliers`, they should see all materials for that plan
   - Implement via JOIN to parent table in the policy
   - OR precompute and denormalize in `tracking_plan_material`
2. **Performance consideration:** JOINs in policies can be slow; consider materialized view approach instead
3. **Explicit vs. implicit:** Should explicit `shared_with` on material override plan-level access? (Answer: likely no, union both)

**Scoring:**
- **10 pts:** Clearly distinguishes implicit vs. explicit; proposes optimization (materialized view, denormalization)
- **8 pts:** Correct logic but doesn't address performance implications
- **6 pts:** Recognizes both cases but vague on implementation
- **3 pts:** Mentions one case; missing the other
- **0 pts:** No answer or incorrect reasoning

### Criterion 1.B.3: JOIN Performance Impact (5 points)

**Expected Response:**
The candidate should state:
1. **Yes, JOINs in RLS policies have performance cost** — PostgreSQL evaluates policies for every row
2. **Better approaches:**
   - Use materialized view that pre-joins and denormalizes supplier access
   - Use `EXISTS` subquery instead of `IN` (more efficient)
   - Index the JSONB column: `CREATE INDEX idx_plan_material_shared_with ON tracking_plan_material USING GIN(shared_with)`
3. **Benchmark:** Test with 10k+ rows to see real impact

**Scoring:**
- **5 pts:** Acknowledges performance cost and proposes optimization (index, materialized view, or better query)
- **4 pts:** Acknowledges cost but proposes weak optimization
- **3 pts:** Mentions performance but doesn't propose solution
- **0 pts:** No answer or claims there's no performance impact

---

## Part C: Audit & Monitoring (20 points)

### Criterion 1.C.1: Denial Logging (10 points)

**Expected Response:**
The candidate should propose:
1. **RLS denial logging:** PostgreSQL doesn't automatically log denied access; must implement manually
   - Use `log_statement = 'all'` and parse PostgreSQL logs for denied queries (brittle)
   - Better: Create a custom audit trigger that fires on policy deny (requires function)
2. **Application-level logging:** Call Supabase function to log attempted access; check RLS policy result
3. **Recommended approach:** Create a logging table outside RLS:
   ```sql
   CREATE TABLE audit.access_denials (
     id bigint PRIMARY KEY,
     user_id uuid,
     table_name text,
     action text, -- SELECT, INSERT, UPDATE, DELETE
     entity_id uuid,
     denied_at timestamptz,
     reason text
   );
   ```
   Query it periodically to detect denials.

**Scoring:**
- **10 pts:** Proposes custom audit logging + suggests why PostgreSQL doesn't log denials natively; discusses trade-offs
- **8 pts:** Proposes custom logging but doesn't fully explain implementation
- **6 pts:** Mentions logging table idea but vague on how to trigger it
- **3 pts:** Suggests generic monitoring but no clear approach for RLS denials
- **0 pts:** No answer

### Criterion 1.C.2: Monitoring Metrics (7 points)

**Expected Response:**
The candidate should suggest:
1. **Metrics to track:**
   - Ratio of denied vs. successful queries per user
   - Users attempting to access brands not in their `brand_ids` claim
   - Users with empty `brand_ids` (potentially misconfigured)
   - Policy evaluation time (slow policies indicate missing indexes)
2. **Dashboards:** Build in Grafana or Datadog to visualize trends

**Scoring:**
- **7 pts:** Lists 3+ specific metrics relevant to RLS
- **5 pts:** Lists 2-3 metrics with decent rationale
- **3 pts:** Lists generic metrics (e.g., "query count") without RLS focus
- **0 pts:** No answer

### Criterion 1.C.3: Alert Conditions (3 points)

**Expected Response:**
The candidate should recommend alerts for:
1. **High denial rate:** >10% of queries denied per user per hour
2. **Policy misconfiguration:** Sudden drop in rows returned (policy too restrictive)
3. **Privilege escalation attempt:** User attempts to access brand outside their list 5+ times

**Scoring:**
- **3 pts:** Proposes 2+ smart alert conditions
- **2 pts:** Proposes 1 reasonable alert
- **0 pts:** No answer or vague alerts

---

## Part D: Testing & Migration (10 points)

### Criterion 1.D.1: Testing Strategy (5 points)

**Expected Response:**
The candidate should propose:
1. **Test environment:** Clone production schema (use Supabase branch feature)
2. **Test matrix:**
   - User with single brand in claim vs. multiple brands
   - User with empty/missing `brand_ids`
   - Admin users (should bypass policy)
   - Supplier users (should only see `shared_with` materials)
3. **Queries to test:**
   ```sql
   SET jwt.claims.brand_ids = '["AAG_CORE", "AAG_PREMIUM"]';
   SELECT COUNT(*) FROM tracking_plan; -- Should only return AAG_CORE and AAG_PREMIUM
   ```

**Scoring:**
- **5 pts:** Proposes comprehensive test matrix with specific test cases
- **3 pts:** Mentions testing but vague on specific cases
- **0 pts:** No answer

### Criterion 1.D.2: Migration Strategy (5 points)

**Expected Response:**
The candidate should outline:
1. **Phase 1:** Deploy new permissive policies alongside old ones (no effect yet)
2. **Phase 2:** Gradually enable restrictive policies on 10% of users; monitor errors
3. **Phase 3:** Full rollout with kill switch (rollback migration if needed)
4. **Communication:** Notify teams about access changes; prepare support for access questions

**Scoring:**
- **5 pts:** Proposes phased rollout with rollback plan; discusses communication
- **3 pts:** Mentions phases but lacks detail on rollback
- **0 pts:** No answer or proposes direct cutover (risky)

---

## **Part A Total: 40 | Part B Total: 30 | Part C Total: 20 | Part D Total: 10**
## **QUESTION 1 TOTAL: 100 points**

---

# QUESTION 2: Trigger-Driven Automation & Cascade Logic

**Total Points: 100**

## Part A: Race Condition Analysis (35 points)

### Criterion 2.A.1: Race Condition Description (10 points)

**Expected Response:**
The candidate should explain:
1. **The race:** Two concurrent `INSERT` statements hit `trg_instantiate_style_timeline` simultaneously
   - Both read template items at the same time
   - Both create timeline rows, potentially creating duplicates or missing rows
2. **Example scenario:**
   ```
   INSERT INTO tracking_plan_style (plan_id, style_id, ...) VALUES ('plan-1', 'style-1');  -- Process A
   INSERT INTO tracking_plan_style (plan_id, style_id, ...) VALUES ('plan-1', 'style-2');  -- Process B
   
   Both trigger fires → both read template items → both insert timelines
   Possible outcome: Timeline rows created twice or in wrong order
   ```
3. **Root cause:** Trigger doesn't acquire lock; concurrent reads/writes on shared data

**Scoring:**
- **10 pts:** Clearly explains race with scenario; identifies shared data and lock requirement
- **8 pts:** Explains race but scenario could be more detailed
- **6 pts:** Identifies there's a race but explanation is vague
- **0 pts:** No answer or incorrect diagnosis

### Criterion 2.A.2: Locking Strategy (12 points)

**Expected Response:**
The candidate should propose:

**Option 1: Advisory Locks (recommended)**
```sql
CREATE OR REPLACE FUNCTION trg_instantiate_style_timeline()
RETURNS TRIGGER AS $$
BEGIN
  -- Acquire advisory lock for this plan
  PERFORM pg_advisory_lock(hashtext(NEW.plan_id::text));
  
  -- Insert timeline rows from template
  INSERT INTO tracking_plan_style_timeline (plan_style_id, template_item_id, ...)
  SELECT NEW.id, ti.id, ...
  FROM tracking_timeline_template_item ti
  WHERE ti.template_id = (SELECT template_id FROM tracking_plan WHERE id = NEW.plan_id);
  
  -- Release lock
  PERFORM pg_advisory_unlock(hashtext(NEW.plan_id::text));
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    PERFORM pg_advisory_unlock_all();
    RAISE;
END;
$$ LANGUAGE plpgsql;
```

**Option 2: FOR UPDATE Lock**
```sql
CREATE OR REPLACE FUNCTION trg_instantiate_style_timeline()
RETURNS TRIGGER AS $$
BEGIN
  -- Lock the plan row to ensure single instantiation
  PERFORM 1 FROM tracking_plan WHERE id = NEW.plan_id FOR UPDATE;
  
  -- Insert template timelines...
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Scoring:**
- **12 pts:** Proposes advisory or FOR UPDATE lock with correct syntax; explains why this prevents race
- **10 pts:** Correct lock approach but minor syntax issues
- **8 pts:** Proposes locking but doesn't fully explain mechanism
- **6 pts:** Mentions locking idea but implementation is incomplete
- **0 pts:** No answer or suggests incorrect locking

### Criterion 2.A.3: Pseudocode with Lock (8 points)

**Expected Response:**
```
FUNCTION trg_instantiate_style_timeline():
  1. Acquire lock on plan_id
  2. Check if timelines already exist for this style_id
     IF exist:
       Release lock
       RETURN NEW (skip duplicate instantiation)
  3. Fetch template items for this plan's template
  4. FOR EACH template item:
       CREATE new timeline row with:
         plan_style_id = NEW.id
         template_item_id = item.id
         status = 'NOT_STARTED'
         dates calculated by subsequent trigger
  5. Release lock
  6. RETURN NEW
```

**Scoring:**
- **8 pts:** Clear pseudocode with lock, idempotency check, and loop logic
- **6 pts:** Pseudocode mostly correct but missing idempotency check
- **4 pts:** Pseudocode present but doesn't include lock
- **0 pts:** No answer

### Criterion 2.A.4: Testing Strategy (5 points)

**Expected Response:**
The candidate should suggest:
1. **Concurrency test:** Use `pgbench` or custom script to insert 100 styles into same plan simultaneously
   ```bash
   pgbench -c 10 -j 5 -T 30 -f insert_styles.sql
   ```
2. **Validation:** Check that timeline count = style_count × template_item_count (no duplicates)
3. **Load test:** Repeat with 1000s of styles to stress the locking mechanism

**Scoring:**
- **5 pts:** Proposes concrete test tool (pgbench, concurrent clients) with validation query
- **3 pts:** Mentions concurrent testing but vague on implementation
- **0 pts:** No answer

---

## Part B: Cascade Performance & Correctness (35 points)

### Criterion 2.B.1: Cascade Logic Analysis (10 points)

**Expected Response:**
The candidate should discuss:
1. **Should cascades trigger cascades?**
   - Generally NO; only propagate one level to direct dependents
   - Reason: Prevents infinite loops, keeps performance predictable
   - Exception: If dependency chain is guaranteed to be acyclic, allow N levels
2. **Depth limit:** Recommend 1-2 levels max
   - Direct dependents: 1 level
   - Dependents of dependents: 2 levels (risky)

**Scoring:**
- **10 pts:** Recommends 1-level cascade with clear reasoning about performance and loop risk
- **8 pts:** Recommends limited cascade but reasoning could be stronger
- **5 pts:** Addresses question but no clear depth recommendation
- **0 pts:** No answer

### Criterion 2.B.2: Cascade Performance Optimization (12 points)

**Expected Response:**
The candidate should propose multiple options:

**Option 1: Recursive CTE (Most Common)**
```sql
WITH RECURSIVE dependents AS (
  SELECT successor_id FROM tracking_plan_style_dependency 
  WHERE predecessor_id = p_updated_timeline_id
  UNION ALL
  SELECT tpsd.successor_id 
  FROM tracking_plan_style_dependency tpsd
  JOIN dependents d ON d.successor_id = tpsd.predecessor_id
  LIMIT 1000 -- Depth limit
)
UPDATE tracking_plan_style_timeline 
SET status = 'IN_PROGRESS', updated_at = NOW()
WHERE id IN (SELECT successor_id FROM dependents);
```

**Option 2: Temporary Table (Fastest for large cascades)**
```sql
CREATE TEMP TABLE cascade_targets AS
SELECT successor_id FROM tracking_plan_style_dependency 
WHERE predecessor_id = p_updated_timeline_id;

UPDATE tracking_plan_style_timeline 
SET status = 'IN_PROGRESS', updated_at = NOW()
WHERE id IN (SELECT successor_id FROM cascade_targets);

DROP TABLE cascade_targets;
```

**Option 3: Batch processing (Best for production scalability)**
- Break cascade into batches of 100 rows
- Process asynchronously via background job queue
- Log progress to audit table

**Scoring:**
- **12 pts:** Proposes 2+ optimization strategies; discusses trade-offs (performance vs. simplicity)
- **10 pts:** Proposes solid approach (recursive CTE) with reasoning
- **8 pts:** Mentions optimization idea but doesn't compare options
- **5 pts:** Vague on optimization strategy
- **0 pts:** No answer

### Criterion 2.B.3: Infinite Loop Prevention (8 points)

**Expected Response:**
The candidate should write a query to detect cycles:
```sql
-- Detect cycles in dependency graph
WITH RECURSIVE cycle_check AS (
  SELECT successor_id as current, predecessor_id as target, 1 as depth, 
         ARRAY[successor_id, predecessor_id] as path
  FROM tracking_plan_style_dependency
  
  UNION ALL
  
  SELECT cc.current, tpsd.predecessor_id, cc.depth + 1, 
         cc.path || tpsd.predecessor_id
  FROM cycle_check cc
  JOIN tracking_plan_style_dependency tpsd ON tpsd.successor_id = cc.target
  WHERE NOT tpsd.predecessor_id = ANY(cc.path) AND cc.depth < 100
)
SELECT * FROM cycle_check 
WHERE target = ANY(path) AND path[1] = target; -- Cycle detected
```

**Scoring:**
- **8 pts:** Correct recursive CTE that detects cycles; explains how it works
- **6 pts:** Mostly correct CTE with minor issues
- **4 pts:** Attempts detection but query has significant flaws
- **0 pts:** No answer

### Criterion 2.B.4: Query to Flag Cycles (5 points)

**Expected Response:**
Create a periodic check:
```sql
-- Run nightly as background job
INSERT INTO audit.data_quality_issues (issue_type, description, entity_id, created_at)
SELECT 'CYCLE_DETECTED', 
       'Dependency cycle found in plan ' || current::text,
       current, NOW()
FROM cycle_check 
WHERE target = ANY(path);
```

**Scoring:**
- **5 pts:** Proposes monitoring/alerting query
- **3 pts:** Mentions checking but no implementation
- **0 pts:** No answer

---

## Part C: Orphaned Record Prevention (15 points)

### Criterion 2.C.1: Cascade Delete Strategy (8 points)

**Expected Response:**
The candidate should propose:
1. **Soft delete approach (recommended):**
   - Mark template items as `is_active = false`
   - Modify triggers to filter on `is_active = true`
   - Keep orphaned timelines but mark them as stale

2. **Hard delete with cascade:**
   - Delete timeline rows when template item is deleted
   - Pros: Cleaner data
   - Cons: Data loss, harder to audit

3. **Hybrid:** Soft delete template item, archive timelines to history table

**Scoring:**
- **8 pts:** Recommends soft delete with clear rationale; discusses alternatives
- **6 pts:** Recommends one approach but doesn't compare trade-offs
- **4 pts:** Mentions cascade delete but vague on strategy
- **0 pts:** No answer

### Criterion 2.C.2: Soft vs. Hard Delete Justification (4 points)

**Expected Response:**
The candidate should argue for soft delete because:
1. **Auditability:** Keep historical record of when template was active
2. **Reversibility:** Can re-activate template if deleted by mistake
3. **Data integrity:** No orphaned timeline records
4. **Compliance:** Regulatory requirement to retain records

**Scoring:**
- **4 pts:** Clear, well-reasoned argument for soft delete
- **2 pts:** Mentions soft delete benefits but weak justification
- **0 pts:** Argues for hard delete or no clear position

### Criterion 2.C.3: Audit Trail for Orphaned Records (3 points)

**Expected Response:**
Create a tracking table:
```sql
CREATE TABLE audit.orphaned_timelines (
  id bigint PRIMARY KEY,
  timeline_id uuid,
  orphaned_reason text, -- 'template_item_deleted', 'plan_deleted', etc.
  orphaned_at timestamptz,
  resolution text -- 'archived', 'restored', etc.
);
```

**Scoring:**
- **3 pts:** Proposes tracking table with clear fields
- **1 pt:** Mentions audit but no implementation
- **0 pts:** No answer

---

## Part D: Consistency & Observability (15 points)

### Criterion 2.D.1: Why Queries Return Different Values (7 points)

**Expected Response:**
The candidate should explain that this could be due to:
1. **Trigger execution order:** One query reads before trigger completes, another after
   - Solution: Use `AFTER` triggers; ensure trigger completes before `COMMIT`
2. **Read consistency issue:** Not related to triggers; likely application-level caching
3. **Timestamp precision:** Two queries reading different `updated_at` values due to `NOW()` function
   - Solution: Use UTC time from application instead of DB
4. **Trigger didn't fire:** Second query hits row before trigger completes
   - Solution: Explicit transaction control in application

**Scoring:**
- **7 pts:** Identifies multiple potential causes; correctly isolates trigger issue
- **5 pts:** Identifies one plausible cause with good reasoning
- **3 pts:** Mentions trigger or consistency but vague
- **0 pts:** No answer

### Criterion 2.D.2: Observability for Trigger Failures (5 points)

**Expected Response:**
The candidate should propose:
1. **Logging within trigger:**
   ```sql
   INSERT INTO audit.trigger_execution_log (trigger_name, entity_id, status, error_message, executed_at)
   VALUES ('calculate_timeline_dates_trigger', NEW.id, 'SUCCESS'|'FAIL', error_msg, NOW());
   ```
2. **Monitor for silent failures** (triggers fail but parent INSERT/UPDATE succeeds)
3. **Alert on slow triggers** (>100ms execution time)

**Scoring:**
- **5 pts:** Proposes detailed logging table with error tracking
- **3 pts:** Mentions logging but vague on implementation
- **0 pts:** No answer

### Criterion 2.D.3: Trigger Failure Handling (3 points)

**Expected Response:**
The candidate should recommend:
- **Default: Fail the transaction** (rollback parent INSERT/UPDATE)
- Rationale: Better to fail loudly than silently skip trigger logic
- Exception: If trigger is truly optional, log and continue with warning

**Scoring:**
- **3 pts:** Recommends transaction rollback on trigger failure; good rationale
- **1 pt:** Mentions failure handling but unclear policy
- **0 pts:** No answer

---

## **Part A Total: 35 | Part B Total: 35 | Part C Total: 15 | Part D Total: 15**
## **QUESTION 2 TOTAL: 100 points**

---

# QUESTION 3: ETL Integration, Data Validation & Import Strategy

**Total Points: 100**

## Part A: ETL Pipeline Design (30 points)

### Criterion 3.A.1: ETL Workflow Outline (10 points)

**Expected Response:**
The candidate should propose a complete workflow:

```
Webhook arrives at Edge Function
  ↓
1. EXTRACT: Parse JSON payload, flatten nested structure
2. VALIDATE: Check required fields, types, ranges, foreign keys
3. DEDUPLICATE: Check if event_id + headerId already processed
4. LOAD (if valid):
   - Transform data to table schema
   - INSERT ... ON CONFLICT ... DO UPDATE
   - Log successful sync to beproduct_sync_log
5. ERROR HANDLING (if invalid):
   - Insert error record to import_errors
   - Increment error_count in import_batches
   - (Optional) Retry or queue for manual review

Architecture:
- Edge Function: Fast parsing + basic validation
- Database Function: Complex validation + upserts
- Async Job: Retry logic + monitoring
```

**Scoring:**
- **10 pts:** Clear multi-stage workflow (extract, validate, load, error handling); discusses where each stage runs
- **8 pts:** Good workflow but doesn't clearly separate Edge Function vs. DB Function responsibilities
- **6 pts:** Basic workflow present but missing error handling or logging
- **4 pts:** Vague on workflow stages
- **0 pts:** No answer

### Criterion 3.A.2: Deduplication Strategy (12 points)

**Expected Response:**
The candidate should propose:

**Option 1: Natural key (Recommended)**
```sql
-- Create composite unique constraint
ALTER TABLE tracking_plan_material 
ADD CONSTRAINT unique_beproduct_material 
UNIQUE (header_id, header_number); -- Assuming these come from BeProduct

-- Deduplicate via INSERT ... ON CONFLICT
INSERT INTO tracking_plan_material (header_id, header_number, ...)
VALUES ('b07fbed9-...', 'VVSIS01', ...)
ON CONFLICT (header_id, header_number) 
DO UPDATE SET 
  updated_at = NOW(),
  material_name = EXCLUDED.material_name
  -- Only update changed fields
WHERE tracking_plan_material != EXCLUDED;
```

**Option 2: Event-based dedup (Preferred for webhooks)**
```sql
-- Deduplicate table with short retention (24 hours)
CREATE TABLE tracking.webhook_dedup (
  webhook_id text PRIMARY KEY,
  event_type text,
  object_id uuid,
  processed_at timestamptz,
  UNIQUE (event_type, object_id, processed_at)
);

-- Check before processing
SELECT 1 FROM webhook_dedup 
WHERE webhook_id = incoming_webhook_id 
AND processed_at > NOW() - INTERVAL '24 hours';
-- If exists, skip processing
```

**Scoring:**
- **12 pts:** Proposes natural key + ON CONFLICT; discusses retention window; explains why webhook_id approach is better
- **10 pts:** Proposes correct dedup approach but doesn't compare options
- **8 pts:** Basic dedup logic correct but missing retention discussion
- **5 pts:** Mentions dedup but implementation is incomplete
- **0 pts:** No answer

### Criterion 3.A.3: Before/After Change Detection (8 points)

**Expected Response:**
The candidate should propose:

```javascript
// In Edge Function
function extractChanges(webhook) {
  const before = webhook.data.before || {};
  const after = webhook.data.after || {};
  const changes = {};

  for (const key in after) {
    if (JSON.stringify(before[key]) !== JSON.stringify(after[key])) {
      changes[key] = {
        old: before[key]?.value,
        new: after[key]?.value
      };
    }
  }
  return changes;
}

// Store in beproduct_sync_log
INSERT INTO beproduct_sync_log (entity_type, entity_id, action, payload)
VALUES ('material', headerId, 'UPDATE', jsonb_build_object('changes', changes));
```

**Scoring:**
- **8 pts:** Shows delta detection logic; explains how to store efficiently in sync_log
- **6 pts:** Correct logic but doesn't discuss efficiency
- **4 pts:** Basic approach but incomplete
- **0 pts:** No answer

---

## Part B: Data Validation & Error Handling (25 points)

### Criterion 3.B.1: Validation Rules (10 points)

**Expected Response:**
The candidate should write validation logic:

```typescript
interface ValidationResult {
  valid: boolean;
  errors: string[];
}

function validateMaterial(data): ValidationResult {
  const errors: string[] = [];
  
  // Required fields
  if (!data.header_number?.value?.trim()) {
    errors.push("header_number is required");
  }
  if (!data.header_name?.value?.trim()) {
    errors.push("header_name is required");
  }
  if (!data.brand_1?.value) {
    errors.push("brand_1 is required");
  }
  
  // Type validation
  if (data.composition?.type !== "CompositeControl") {
    errors.push("composition must be CompositeControl type");
  }
  if (!Array.isArray(data.composition?.value)) {
    errors.push("composition must be an array");
  } else {
    data.composition.value.forEach((item, idx) => {
      if (!item.code || !item.value) {
        errors.push(`composition[${idx}] missing code or value`);
      }
    });
  }
  
  // Range validation
  if (data.material_weight?.value && data.material_weight.value <= 0) {
    errors.push("material_weight must be > 0");
  }
  if (data.material_width?.value && data.material_width.value <= 0) {
    errors.push("material_width must be > 0");
  }
  
  // Reference validation (async, done separately)
  // Check if supplier_id exists or is null
  
  return {
    valid: errors.length === 0,
    errors
  };
}
```

**Scoring:**
- **10 pts:** Comprehensive validation covering all rule types (required, type, range, reference); structured error return
- **8 pts:** Good validation rules but missing one category (e.g., reference validation)
- **6 pts:** Basic validation present but incomplete
- **4 pts:** Validation logic present but significant gaps
- **0 pts:** No answer

### Criterion 3.B.2: Partial Success Handling (7 points)

**Expected Response:**
The candidate should explain:
1. **Insert individual error records** for each failed row:
   ```sql
   INSERT INTO tracking.import_errors (batch_id, entity_type, entity_id, error_code, error_message)
   VALUES (batch_id, 'material', entity_id, 'VALIDATION_FAILED', error_message);
   ```
2. **Increment error count** in batch without failing entire batch:
   ```sql
   UPDATE import_batches SET error_count = error_count + 1 WHERE id = batch_id;
   ```
3. **Mark batch as `partial` or `success_with_warnings`** if some rows succeed
4. **Don't rollback successful rows** — only insert failed rows to error table

**Scoring:**
- **7 pts:** Clearly explains partial success strategy; shows error logging + batch status update
- **5 pts:** Correct approach but doesn't show implementation details
- **3 pts:** Mentions partial success but vague on handling
- **0 pts:** No answer

### Criterion 3.B.3: Validation Function Pseudocode (5 points)

**Expected Response:**
```
FUNCTION validate_material_payload(payload JSONB) RETURNS TABLE(valid boolean, errors text[])
  errors = []
  
  IF payload ->> 'header_number' IS NULL:
    errors.append("header_number required")
  
  IF payload -> 'composition' ->> 'type' != 'CompositeControl':
    errors.append("composition must be CompositeControl")
  
  -- Check reference
  IF payload -> 'supplier_id' IS NOT NULL:
    IF NOT EXISTS (SELECT 1 FROM suppliers WHERE id = payload ->> 'supplier_id'):
      errors.append("supplier_id does not exist")
  
  RETURN (errors.length == 0, errors)
```

**Scoring:**
- **5 pts:** Clear pseudocode covering multiple validation types
- **3 pts:** Basic pseudocode structure but incomplete
- **0 pts:** No answer

### Criterion 3.B.4: Retry Strategy (3 points)

**Expected Response:**
The candidate should recommend:
1. **Transient errors (timeout, connection):** Retry up to 3 times with exponential backoff (1s, 2s, 4s)
2. **Validation errors:** Don't retry; mark as failed and require manual intervention
3. **Reference errors (foreign key not found):** Retry with longer backoff (up to 24 hours) in case upstream data is still syncing

**Scoring:**
- **3 pts:** Proposes clear retry logic with different handling per error type
- **1 pt:** Mentions retry but no strategy
- **0 pts:** No answer

---

## Part C: Concurrency & Referential Integrity (25 points)

### Criterion 3.C.1: Concurrent Update Scenario (10 points)

**Expected Response:**
The candidate should propose:

```sql
-- Use ON CONFLICT with field-level update logic
INSERT INTO tracking_plan_material (
  id, header_id, material_number, supplier_id, brand, updated_at, raw_payload
)
VALUES (id_a, 'b07fbed9-...', 'VVSIS01', 's1', 'AAG_PREMIUM', NOW(), payload_a)
ON CONFLICT (header_id) DO UPDATE SET
  supplier_id = CASE 
    WHEN EXCLUDED.supplier_id IS NOT NULL THEN EXCLUDED.supplier_id
    ELSE tracking_plan_material.supplier_id
  END,
  brand = CASE 
    WHEN EXCLUDED.brand IS NOT NULL THEN EXCLUDED.brand
    ELSE tracking_plan_material.brand
  END,
  updated_at = NOW(),
  raw_payload = EXCLUDED.raw_payload
WHERE (
  tracking_plan_material.supplier_id != EXCLUDED.supplier_id
  OR tracking_plan_material.brand != EXCLUDED.brand
);
```

**Key points:**
1. Use `ON CONFLICT` with selective field updates
2. Preserve existing values if new value is NULL (merge, don't overwrite)
3. Add `WHERE` clause to avoid unnecessary updates (performance)

**Scoring:**
- **10 pts:** Shows ON CONFLICT logic with field-level merge; explains how it prevents overwrites
- **8 pts:** Correct SQL but doesn't explain merge strategy
- **6 pts:** Attempts solution but has logical gaps
- **0 pts:** No answer

### Criterion 3.C.2: Foreign Key Challenge (10 points)

**Expected Response:**
The candidate should discuss:

**Option 1: Deferred Import (Recommended)**
- Queue the style import if folder doesn't exist
- Retry every 5 minutes for up to 24 hours
- After 24 hours, mark as failed + alert

```sql
INSERT INTO import_queue (entity_type, entity_id, payload, retry_count, next_retry_at, source_batch_id)
VALUES ('style', style_id, payload, 0, NOW() + INTERVAL '5 minutes', batch_id);
```

**Option 2: Create Placeholder**
- Insert placeholder folder if it doesn't exist
- Risk: May create orphaned folders
- Only acceptable if upstream is guaranteed to populate it later

**Option 3: Fail Import**
- Reject style import if folder missing
- Requires upstream to import in order (brittle)

**Ranking:** Deferred > Placeholder > Fail

**Scoring:**
- **10 pts:** Proposes deferred queue with retry logic; explains why it's better than other options
- **8 pts:** Deferred approach correct but doesn't discuss alternatives
- **6 pts:** Mentions issue but solution is incomplete
- **0 pts:** No answer or proposes risky approach (placeholder)

### Criterion 3.C.3: Upsert Strategy (5 points)

**Expected Response:**
Compare PostgreSQL ON CONFLICT vs. application-level logic:

**PostgreSQL ON CONFLICT:**
- Pros: Atomic, simple, fast
- Cons: Harder to log granular changes; less flexibility for business logic

**Application-level (SELECT then INSERT/UPDATE):**
- Pros: Can implement complex logic; easier to audit
- Cons: Race condition between SELECT and INSERT; slower

**Recommendation:** Use PostgreSQL ON CONFLICT for performance; log granular changes separately

**Scoring:**
- **5 pts:** Compares both approaches; recommends ON CONFLICT with rationale
- **3 pts:** Mentions both but doesn't compare clearly
- **0 pts:** No answer

---

## Part D: Observability & Rollback (20 points)

### Criterion 3.D.1: Monitoring Strategy (7 points)

**Expected Response:**
The candidate should propose:

**Metrics:**
1. **Import rate:** Events/hour by entity type (material, style, plan)
2. **Error rate:** Failed validations / total events
3. **Latency:** P50, P95, P99 time from webhook to database
4. **Reference errors:** % of imports failing due to missing foreign keys
5. **Dedup rate:** % of events rejected as duplicates

**Dashboards:**
- Real-time import health (Grafana)
- Daily error breakdown by category
- Latency distribution (heatmap)

**Scoring:**
- **7 pts:** Lists 4+ specific metrics with rationale; mentions observability platform
- **5 pts:** Lists 3 metrics but could be more specific
- **3 pts:** Generic metrics without ETL focus
- **0 pts:** No answer

### Criterion 3.D.2: Slow/Failed Detection (8 points)

**Expected Response:**
The candidate should propose:

```sql
-- Alert if import latency > 30 seconds
CREATE ALERT "import_latency_high" ON beproduct_sync_log
WHERE processed_at - created_at > INTERVAL '30 seconds'
FOR DURATION 5 MINUTES;

-- Alert if error rate > 10% in last hour
CREATE ALERT "import_error_rate_high"
WHERE (
  SELECT error_count::float / total_events
  FROM import_batch_stats(NOW() - INTERVAL '1 hour')
) > 0.1;

-- Alert if no imports in last 10 minutes
CREATE ALERT "import_stalled"
WHERE NOT EXISTS (
  SELECT 1 FROM import_batches
  WHERE completed_at > NOW() - INTERVAL '10 minutes'
);
```

**Scoring:**
- **8 pts:** Proposes 3+ specific alerts with thresholds; explains how to trigger them
- **6 pts:** Proposes good alerts but vague on implementation
- **4 pts:** Mentions monitoring but no concrete alerts
- **0 pts:** No answer

### Criterion 3.D.3: Alert Aggregation (5 points)

**Expected Response:**
The candidate should recommend:
1. **Single row failures:** Don't alert; log to error table
2. **5+ failures in 1 minute:** Alert to Slack/PagerDuty
3. **>20% error rate:** Critical alert (wake on-call)
4. **Upstream system down (0 events):** Critical alert

**Scoring:**
- **5 pts:** Clear alert escalation policy by failure type/volume
- **3 pts:** Mentions escalation but rules are vague
- **0 pts:** No answer

---

### Criterion 3.D.4: Rollback Mechanism (10 points)

**Expected Response:**
The candidate should design:

**Partial Rollback (95 ok, 5 failed):**
```sql
-- Option 1: Keep successful rows (most common)
INSERT INTO import_batches (source, status, error_count, payload)
VALUES ('beproduct', 'partial_success', 5, payload);

-- Option 2: Atomic all-or-nothing (safest)
BEGIN;
  INSERT INTO tracking_plan_material (...) VALUES (...);
  -- If ANY validation fails, entire batch rolls back
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    INSERT INTO import_batches (..., status, error_count) 
    VALUES (..., 'failed', -1); -- Negative count signals unknown
END;
```

**Full Rollback (if batch corrupted):**
```sql
-- Identify affected rows from batch
SELECT * FROM beproduct_sync_log WHERE batch_id = bad_batch_id;

-- Soft delete or revert to previous version
UPDATE tracking_plan_material 
SET active = false, is_deleted = true
WHERE id IN (SELECT entity_id FROM beproduct_sync_log WHERE batch_id = bad_batch_id);
```

**Upstream Communication:**
- Send webhook acknowledgment: `{ status: "success" | "partial" | "failed", batch_id }`
- If failed, BeProduct retries automatically (check for replay handling)

**Scoring:**
- **10 pts:** Proposes partial + full rollback strategies; discusses atomic vs. lenient; mentions upstream communication
- **8 pts:** Good rollback design but missing upstream communication
- **6 pts:** Rollback logic present but incomplete
- **0 pts:** No answer

### Criterion 3.D.5: Audit Trail for Auto-Generated Records (5 points)

**Expected Response:**
The candidate should recommend:
1. **Yes, track auto-generated records** in `tracking_timeline_status_history` with `source = 'import'`
2. **Distinguish from user changes:**
   ```sql
   INSERT INTO tracking_timeline_status_history (
     timeline_id, previous_status, new_status, changed_by, source
   )
   VALUES (id, 'NOT_STARTED', 'IN_PROGRESS', NULL, 'import:batch-id-123');
   ```
3. **Filter in UI:** Show user changes separately from auto-import changes

**Scoring:**
- **5 pts:** Recommends audit tracking with clear source field
- **3 pts:** Mentions audit but vague on implementation
- **0 pts:** No answer

---

## **Part A Total: 30 | Part B Total: 25 | Part C Total: 25 | Part D Total: 20**
## **QUESTION 3 TOTAL: 100 points**

---

# Scoring Summary

| Question | Points | Expected Score | Rating |
| --- | --- | --- | --- |
| Q1: RLS Security | 100 | 70+ | Strong |
| Q2: Trigger Cascade | 100 | 70+ | Strong |
| Q3: ETL Integration | 100 | 70+ | Strong |

## Overall Candidate Rating

**Strong Candidate: 210+ / 300 (70%+)**
- Demonstrates deep knowledge of RLS, triggers, and ETL pipelines
- Understands production considerations (performance, observability, rollback)
- Can design for concurrency and failure modes
- Ready for senior DBA role

**Good Candidate: 180-210 / 300 (60-70%)**
- Solid fundamentals in 2/3 areas
- May need guidance on specific technologies or production patterns
- Good fit for mid-level DBA role with mentorship

**Fair Candidate: 150-180 / 300 (50-60%)**
- Understands concepts but lacks depth
- Would require significant onboarding
- Recommend continued evaluation

**Weak Candidate: <150 / 300 (<50%)**
- Does not meet technical requirements
- Not recommended for role

---

# Interview Tips

1. **Allow pseudocode or SQL:** Don't penalize syntax errors if logic is correct
2. **Probe deeper:** Ask follow-up questions if candidate gives vague answers
3. **Discuss trade-offs:** Candidates who weigh pros/cons score higher than those with one-size-fits-all solutions
4. **Production experience:** Candidates who mention monitoring, observability, or failure modes score higher
5. **Ask them to explain:** Have them walk through a scenario step-by-step

