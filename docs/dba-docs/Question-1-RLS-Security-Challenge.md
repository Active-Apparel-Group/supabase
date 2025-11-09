# DBA Interview Question #1: Row-Level Security (RLS) & Multi-Tenant Access Control

## Question Overview
Your company uses Supabase with PostgreSQL and manages a complex tracking schema for apparel production timelines and material management. Currently, all RLS policies use permissive defaults (`USING (true)` for all operations). You need to implement brand-scoped access control for a multi-tenant environment.

---

## The Scenario

### Current State
- 15+ tables with RLS enabled but currently using permissive `USING (true)` policies
- Users authenticate via Supabase Auth and receive JWT tokens
- Each plan, folder, and style belongs to a specific brand
- Suppliers should only see their own materials and assigned work (partial visibility)
- Internal team members can access brand-restricted content based on JWT custom claims

### The Challenge
Design and implement a **brand-scoped RLS policy** that:

1. **Restricts SELECT access** so users only see data belonging to brands in their `brand_ids` JWT claim
2. **Secures INSERT/UPDATE/DELETE** operations so users can only modify data they own
3. **Allows suppliers** to view only materials/timelines assigned to them via the `shared_with` JSONB field
4. **Maintains performance** with proper indexing and query optimization
5. **Provides an audit trail** when policies deny access

### Sample JWT Custom Claims
```json
{
  "sub": "user-uuid-123",
  "user_name": "john.doe@company.com",
  "brand_ids": ["AAG_CORE", "AAG_PREMIUM"],
  "role": "manager",
  "company_id": "company-uuid-456"
}
```

### Sample Data Structure
The `tracking_plan` table includes:
```sql
CREATE TABLE tracking.tracking_plan (
    id uuid PRIMARY KEY,
    folder_id uuid REFERENCES tracking_folder(id),
    name text,
    brand text,  -- e.g., 'AAG_CORE'
    active boolean,
    suppliers jsonb DEFAULT '[]'::jsonb,
    created_at timestamptz DEFAULT now(),
    ...
);
```

The `tracking_plan_material` table includes:
```sql
CREATE TABLE tracking.tracking_plan_material (
    id uuid PRIMARY KEY,
    plan_id uuid REFERENCES tracking_plan(id),
    supplier_id uuid,
    supplier_name text,
    suppliers jsonb DEFAULT '[]'::jsonb,
    ...
);
```

---

## Questions to Answer

### Part A: RLS Policy Design (40%)
1. Write the SQL to create a restrictive SELECT policy for `tracking_plan` that respects brand-scoped access
2. Explain how you would handle the `brand_ids` JWT claim (array vs. string considerations)
3. What happens if a user has no `brand_ids` claim? How would you handle this edge case?
4. Would you use a single policy or multiple policies? Why?

### Part B: Supplier Access Pattern (30%)
1. Design a policy for `tracking_plan_material` that allows suppliers to see only materials in the `shared_with` array
2. How would you handle the case where a supplier is not explicitly listed but is mentioned in the parent plan's `suppliers` field?
3. Would this require a JOIN to `tracking_plan`? Explain the performance implications

### Part C: Audit & Monitoring (20%)
1. How would you log or audit when an RLS policy denies access?
2. What metrics would you monitor to detect policy misconfiguration?
3. Should denied-access events raise alerts? Under what conditions?

### Part D: Testing & Migration (10%)
1. How would you test this policy transition without breaking production access?
2. What would a safe migration strategy look like for moving from permissive to restrictive policies?

---

## Evaluation Criteria

See the **Answer Sheet** for scoring details.

---

## Time Limit
**45 minutes** for a verbal/written response

---

## Resources Provided to Candidate
- Sample webhook payload showing `brand` field structure
- Current RLS policy definitions (permissive)
- JWT token example (if needed)
- Schema reference document (see section 3.1 & 3.2 in blueprint)

