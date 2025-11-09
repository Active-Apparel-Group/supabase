# 🚀 Migration 0005 Deployment Summary

**Date:** October 23, 2025  
**Status:** ✅ DEPLOYED SUCCESSFULLY  
**Migration:** `0005_add_sharing_and_visibility`

---

## What Changed

We **simplified** the original complex design based on your feedback that "the schema was getting too complicated." The new approach matches BeProduct's structure using JSONB arrays instead of junction tables.

---

## Added Columns

### Template Configuration (timeline_template_items)
```sql
supplier_visible      BOOLEAN DEFAULT false
default_assigned_to   JSONB DEFAULT '[]'::jsonb
default_shared_with   JSONB DEFAULT '[]'::jsonb
```

**Purpose:** Configure default assignments and sharing when templates are applied to new plans.

---

### Plan-Level Supplier Access (plans) — GATE 1
```sql
suppliers  JSONB DEFAULT '[]'::jsonb
```

**Structure:**
```json
[
  {
    "companyId": "uuid",
    "companyName": "ABC Mfg Co",
    "accessLevel": "view|edit",
    "canUpdateTimelines": true|false
  }
]
```

**Purpose:** Control which suppliers can access this tracking plan (first gate).

---

### Style/Material Supplier Assignments — GATE 2
```sql
plan_styles.suppliers    JSONB DEFAULT '[]'::jsonb
plan_materials.suppliers JSONB DEFAULT '[]'::jsonb
```

**Structure:**
```json
[
  {
    "companyId": "uuid",
    "companyName": "ABC Mfg Co",
    "role": "quote|production"
  }
]
```

**Purpose:** Assign suppliers to specific styles/materials for quoting or manufacturing (second gate).

---

### Timeline Milestone Sharing — GATE 3
```sql
plan_style_timelines.shared_with    JSONB DEFAULT '[]'::jsonb
plan_material_timelines.shared_with JSONB DEFAULT '[]'::jsonb
```

**Structure:**
```json
["companyId1", "companyId2"]
```

**Purpose:** Control which suppliers can see specific milestones (third gate).

---

## Performance Indexes

Added GIN indexes for efficient JSONB queries:
- `idx_plans_suppliers`
- `idx_plan_styles_suppliers`
- `idx_plan_materials_suppliers`
- `idx_style_timelines_shared_with`
- `idx_material_timelines_shared_with`

**What this means:** Fast queries like:
```sql
-- Find all plans where supplier has access
SELECT * FROM tracking.plans 
WHERE suppliers @> '[{"companyId": "uuid"}]'::jsonb;

-- Find all styles assigned to supplier
SELECT * FROM tracking.plan_styles
WHERE suppliers @> '[{"companyId": "uuid"}]'::jsonb;
```

---

## Design Decisions

### ❌ What We Removed (Compared to Initial Draft)

1. **`timeline_template_default_assignments` table** → Replaced with `default_assigned_to` JSONB column
2. **`timeline_template_default_sharing` table** → Replaced with `default_shared_with` JSONB column
3. **`plan_suppliers` table** → Replaced with `suppliers` JSONB column on plans
4. **`timeline_sharing` table** → Replaced with `shared_with` JSONB column on timelines
5. **`mv_vendor_access` materialized view** → Premature optimization; can add later if needed

### ✅ Why This Is Better

1. **Matches BeProduct structure:** BeProduct uses `assignedTo` and `shareWith` arrays
2. **Simpler data model:** Fewer tables = easier to understand and maintain
3. **Easier queries:** JSONB contains operators vs complex joins
4. **Flexible:** Can add/change fields in JSONB without migrations
5. **Performant:** GIN indexes make JSONB queries fast

### When Would We Need the Complex Approach?

Only if:
- We need to query "all plans for supplier X" across 10,000+ plans (scale issue)
- We need referential integrity (foreign keys to supplier table)
- We need separate audit logs per assignment

**Current verdict:** JSONB arrays are fine for now. Can migrate to junction tables later if needed.

---

## Three-Gate Supplier Access Model

### Gate 1: Plan-Level Access
**Question:** Can this supplier access this plan?  
**Storage:** `plans.suppliers`  
**UI:** Plan Settings → Supplier Access tab

### Gate 2: Style-Level Assignment
**Question:** Can this supplier see this style?  
**Storage:** `plan_styles.suppliers`  
**UI:** Style Detail → Suppliers section  
**Rule:** Must be in Gate 1 first

### Gate 3: Milestone-Level Sharing
**Question:** Can this supplier see this milestone?  
**Storage:** `plan_style_timelines.shared_with`  
**UI:** Timeline milestone → Share icon  
**Rule:** Only matters if in Gate 2

**All three must be "yes" for a supplier to see a milestone in the supplier portal.**

---

## Example Data Flow

### 1. Create Plan with Supplier Access
```typescript
const plan = {
  name: "GREYSON 2026 SPRING DROP 1",
  folder_id: "folder-uuid",
  suppliers: [
    {
      companyId: "abc-mfg-uuid",
      companyName: "ABC Mfg Co",
      accessLevel: "view",
      canUpdateTimelines: false
    }
  ]
};
```

### 2. Add Style and Assign Supplier
```typescript
const style = {
  plan_id: "plan-uuid",
  style_number: "MSP26B26",
  style_name: "Navy Polo",
  suppliers: [
    {
      companyId: "abc-mfg-uuid",
      companyName: "ABC Mfg Co",
      role: "production"
    }
  ]
};
```

### 3. Apply Template → Inherit Defaults
```typescript
// Template item has:
{
  name: "Submit to Factory",
  supplier_visible: true,
  default_assigned_to: ["sourcing-manager-uuid"],
  default_shared_with: []  // Empty - share per-style
}

// Creates timeline milestone:
{
  name: "Submit to Factory",
  plan_id: "plan-uuid",
  style_id: "style-uuid",
  template_item_id: "template-item-uuid",
  shared_with: []  // Initially empty
}

// And assignment:
INSERT INTO timeline_assignments (timeline_id, assignee_id)
VALUES ('timeline-uuid', 'sourcing-manager-uuid');
```

### 4. User Shares Milestone
```typescript
// User clicks share icon → selects "ABC Mfg Co"
UPDATE plan_style_timelines
SET shared_with = '["abc-mfg-uuid"]'::jsonb
WHERE id = 'timeline-uuid';
```

---

## Frontend Implementation Guidance

**See comprehensive documentation:**
1. **`05-frontend-implementation-plan.md`** — Complete UI specs with mockups
2. **`SUPPLIER-ACCESS-QUICK-REFERENCE.md`** — Quick reference guide

**Key implementation phases:**
- **Phase 3:** Build plan supplier access management UI (Gate 1)
- **Phase 4:** Build style supplier assignment + milestone sharing UI (Gates 2 & 3)
- **Phase 5:** Build template defaults configuration + personal assignments

**Build with mock data first!** Backend integration comes later.

---

## Testing Queries

### Check Plan Access
```sql
-- Does supplier "abc-mfg-uuid" have access to plan?
SELECT EXISTS (
  SELECT 1 FROM tracking.plans
  WHERE id = 'plan-uuid'
  AND suppliers @> '[{"companyId": "abc-mfg-uuid"}]'::jsonb
);
```

### Get Supplier's Accessible Styles
```sql
-- Find all styles assigned to supplier in a plan
SELECT ps.*
FROM tracking.plan_styles ps
WHERE ps.plan_id = 'plan-uuid'
AND ps.suppliers @> '[{"companyId": "abc-mfg-uuid"}]'::jsonb;
```

### Get Shared Milestones
```sql
-- Find all milestones shared with supplier for a style
SELECT pst.*
FROM tracking.plan_style_timelines pst
WHERE pst.style_id = 'style-uuid'
AND pst.shared_with @> '["abc-mfg-uuid"]'::jsonb;
```

### Complete Supplier Access Query
```sql
-- Get all milestones visible to supplier (all 3 gates)
SELECT 
  pst.id,
  pst.name,
  pst.status,
  pst.plan_date,
  ps.style_number,
  ps.style_name
FROM tracking.plan_style_timelines pst
JOIN tracking.plan_styles ps ON ps.id = pst.style_id
JOIN tracking.plans p ON p.id = ps.plan_id
WHERE 
  -- Gate 1: Supplier has plan access
  p.suppliers @> '[{"companyId": "abc-mfg-uuid"}]'::jsonb
  -- Gate 2: Supplier is assigned to style
  AND ps.suppliers @> '[{"companyId": "abc-mfg-uuid"}]'::jsonb
  -- Gate 3: Milestone is shared with supplier
  AND pst.shared_with @> '["abc-mfg-uuid"]'::jsonb
ORDER BY pst.display_order;
```

---

## Next Steps

### Immediate (This Week)
1. ✅ Migration 0005 deployed
2. ⏭️ Update frontend documentation (DONE)
3. ⏭️ Create supplier access quick reference (DONE)
4. 🔜 Frontend team reviews and starts Phase 3 UI work

### Short-Term (Next 2 Weeks)
1. 🔜 Build template seed script
2. 🔜 Build SQL upsert functions for import pipeline
3. 🔜 Frontend implements supplier access management UI (Gate 1)
4. 🔜 Frontend implements style assignments + milestone sharing (Gates 2 & 3)

### Medium-Term (Weeks 3-4)
1. 🔜 Build Edge Functions for BeProduct import
2. 🔜 Wire frontend to backend APIs
3. 🔜 Build supplier portal views (filtering based on 3 gates)
4. 🔜 Test end-to-end: Add supplier → assign to style → share milestone → view in portal

---

## Success Criteria

✅ **Schema is simplified:** JSONB arrays instead of junction tables  
✅ **Matches BeProduct structure:** assignedTo and shareWith arrays  
✅ **Frontend can start building:** Complete UI specs provided  
✅ **Three-gate model is clear:** Documentation explains access control  
✅ **Performance is good:** GIN indexes for fast JSONB queries  

---

## Questions?

**For schema questions:** Review `SUPPLIER-ACCESS-QUICK-REFERENCE.md`  
**For UI questions:** Review `05-frontend-implementation-plan.md` section on supplier management  
**For backend questions:** Check `PROJECT-PLAN.md` Phase 2-3 roadmap  

**Migration 0005 is deployed and ready for frontend implementation!** 🎉
