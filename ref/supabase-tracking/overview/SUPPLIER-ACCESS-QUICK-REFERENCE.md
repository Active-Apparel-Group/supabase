# Supplier Access Control - Quick Reference

**Document version:** 1.0 • **Last updated:** 2025-10-23  
**Target audience:** Frontend Developer

---

## The Three-Gate Model

Supplier portal access uses a **three-level gating system**. Think of it like building security:
1. **Gate 1:** Building access (plan-level)
2. **Gate 2:** Floor access (style/material-level)
3. **Gate 3:** Room access (milestone-level)

---

## Gate 1: Plan-Level Access

**"Which suppliers can access this tracking plan at all?"**

### Location
- **UI:** Plan Settings → Supplier Access Tab
- **DB:** `plans.suppliers` (JSONB array)

### Data Structure
```typescript
// plans.suppliers column
[
  {
    companyId: "uuid",
    companyName: "ABC Mfg Co",
    accessLevel: "view" | "edit",
    canUpdateTimelines: true | false
  },
  // ... more suppliers
]
```

### What It Controls
- If a supplier is NOT in this array, they cannot see this plan at all in the supplier portal
- `accessLevel`: "view" = read-only, "edit" = can update certain fields
- `canUpdateTimelines`: Whether supplier can mark milestones as complete

### User Actions
- Add/remove suppliers from plan
- Set access level and permissions per supplier
- **Validation:** Check if company exists in directory before adding

---

## Gate 2: Style/Material Assignment

**"Within an accessible plan, which styles/materials can each supplier see?"**

### Location
- **UI:** Style Detail Page → Suppliers Tab
- **DB:** `plan_styles.suppliers` / `plan_materials.suppliers` (JSONB arrays)

### Data Structure
```typescript
// plan_styles.suppliers column
[
  {
    companyId: "uuid",
    companyName: "ABC Mfg Co",
    role: "quote" | "production"
  },
  // ... more suppliers
]
```

### What It Controls
- Which suppliers can see this specific style/material
- What they're doing with it (quoting vs manufacturing)
- **Rule:** Supplier MUST be in Gate 1 (plan access) to be assigned here

### User Actions
- Assign suppliers to styles with role (quote/production)
- Remove supplier assignments
- **Validation:** Only show suppliers who have plan access (Gate 1)

### Roles Explained
- **Quote:** Supplier can view style details and submit price quotes
- **Production:** Supplier is manufacturing this style and needs full access

---

## Gate 3: Milestone Sharing

**"Which specific milestones can each supplier see?"**

### Location
- **UI:** Timeline View → Share icon on each milestone row
- **DB:** `plan_style_timelines.shared_with` / `plan_material_timelines.shared_with` (JSONB arrays)

### Data Structure
```typescript
// plan_style_timelines.shared_with column
["companyId1", "companyId2", ...]  // Simple array of company IDs
```

### What It Controls
- Fine-grained per-milestone visibility
- Example: Share "Submit to Factory" but NOT "Internal Design Review"
- **Rule:** Supplier MUST be in Gate 2 (style assignment) for this to matter

### User Actions
- Click share icon on milestone row
- Multi-select suppliers to share with
- **Validation:** Only show suppliers assigned to this style (Gate 2)

---

## Template Defaults (Inheritance)

Templates can define defaults that are copied to timelines when a plan is created.

### Template Item Configuration

**Location:** Template Item Form → Defaults Tab

#### Supplier Visible
```typescript
supplier_visible: boolean  // default false
```
- Controls whether this milestone TYPE can be shown to suppliers
- Example: "Submit to Factory" = true, "Internal Design Review" = false
- **UI:** Checkbox in template item form

#### Default Assigned To
```typescript
default_assigned_to: string[]  // Array of user IDs
```
- Pre-populate assignees when template is applied to a plan
- Optional; can be overridden per-milestone
- **UI:** Multi-select user dropdown

#### Default Shared With
```typescript
default_shared_with: string[]  // Array of company IDs
```
- Pre-populate shared suppliers when template is applied
- Rarely used (usually sharing is configured per-plan/style)
- **UI:** Multi-select company dropdown

---

## Personal Assignment (assignedTo)

**"Who is responsible for completing this milestone?"**

### Location
- **UI:** Timeline milestone row → Assigned users avatar group
- **DB:** `timeline_assignments` table (existing from migration 0004)

### Data Structure
```sql
timeline_assignments (
  timeline_id uuid,
  timeline_type enum ('style' | 'material'),
  assignee_id uuid,  -- User ID
  role_name text,
  role_id uuid
)
```

### What It Controls
- Internal team member assignments
- Drives "My Work" views (show only milestones assigned to me)
- Separate from supplier sharing (Gate 3)

### User Actions
- Click avatar group on milestone row
- Multi-select users to assign
- Remove user assignments

---

## Validation Rules

### Adding Suppliers to Plan (Gate 1)
```typescript
// ✅ Valid
- Select any company from directory
- Set access level: view or edit
- Set canUpdateTimelines: true or false

// ❌ Invalid
- Duplicate company (already in plan)
- Company doesn't exist in directory
```

### Assigning Suppliers to Styles (Gate 2)
```typescript
// ✅ Valid
- Supplier is in plan.suppliers (Gate 1)
- Role is "quote" or "production"

// ❌ Invalid
- Supplier NOT in plan.suppliers → Show error: "Add supplier to plan first"
- Duplicate assignment (same supplier, same role)
```

### Sharing Milestones (Gate 3)
```typescript
// ✅ Valid
- Supplier is in plan_styles.suppliers (Gate 2)
- Milestone has supplier_visible = true (from template)

// ⚠️ Allowed but not recommended
- Supplier in plan.suppliers (Gate 1) but NOT in plan_styles.suppliers (Gate 2)
- Show warning: "This supplier is not assigned to this style"

// ❌ Invalid
- Supplier not in plan at all (Gate 1) → Filter out from UI
```

---

## Query Patterns

### Check if Supplier Can See Style
```typescript
function canSupplierSeeStyle(
  supplierId: string,
  planId: string,
  styleId: string
): boolean {
  // Gate 1: Check plan access
  const plan = await db.plans.findById(planId);
  const hasPlantAccess = plan.suppliers?.some(
    s => s.companyId === supplierId
  );
  if (!hasPlantAccess) return false;
  
  // Gate 2: Check style assignment
  const style = await db.plan_styles.findById(styleId);
  const hasStyleAccess = style.suppliers?.some(
    s => s.companyId === supplierId
  );
  
  return hasStyleAccess;
}
```

### Check if Supplier Can See Milestone
```typescript
function canSupplierSeeMilestone(
  supplierId: string,
  milestoneId: string
): boolean {
  const milestone = await db.plan_style_timelines.findById(milestoneId);
  
  // Gate 3: Check shared_with array
  return milestone.shared_with?.includes(supplierId) ?? false;
}
```

### Get Supplier's Accessible Styles
```typescript
async function getSupplierStyles(
  supplierId: string,
  planId: string
): Promise<PlanStyle[]> {
  return db.plan_styles.findAll({
    where: {
      plan_id: planId,
      suppliers: {
        contains: [{ companyId: supplierId }]  // JSONB contains
      }
    }
  });
}
```

---

## UI Component Checklist

### Gate 1: Plan Supplier Access
- [ ] Supplier access tab in plan settings
- [ ] "Add Supplier" button
- [ ] Supplier list table (company, access level, permissions, actions)
- [ ] Add supplier modal (company search, access level radio, permissions checkbox)
- [ ] Edit supplier modal (same as add)
- [ ] Remove supplier confirmation dialog
- [ ] Validation: Check for duplicates, verify company exists

### Gate 2: Style Supplier Assignment
- [ ] Suppliers tab/section on style detail page
- [ ] "Assign Supplier" button
- [ ] Assigned suppliers table (company, role, actions)
- [ ] Assign supplier modal (dropdown showing ONLY Gate 1 suppliers, role radio)
- [ ] Edit assignment modal (change role)
- [ ] Remove assignment confirmation dialog
- [ ] Validation: Ensure supplier has plan access (Gate 1)
- [ ] Warning message when no Gate 1 suppliers available

### Gate 3: Milestone Sharing
- [ ] Share icon/button on each timeline milestone row
- [ ] Visual indicator showing shared status (🔒 none, 🌐 N shared)
- [ ] Share milestone modal (multi-select checkboxes, show Gate 2 suppliers)
- [ ] "Share with all assigned suppliers" quick action
- [ ] "Clear all" quick action
- [ ] Info message explaining Gate 1/2 context
- [ ] Validation: Disable suppliers not in Gate 2

### Template Defaults
- [ ] "Defaults" tab in template item form
- [ ] "Supplier Visible" checkbox
- [ ] "Default Assigned To" user multi-select
- [ ] "Default Shared With" company multi-select
- [ ] Help text explaining inheritance behavior
- [ ] Examples of when to use each field

---

## Mock Data Examples

### Plan with Suppliers (Gate 1)
```typescript
const mockPlan: Plan = {
  id: "plan-uuid-1",
  name: "GREYSON 2026 SPRING DROP 1",
  folder_id: "folder-uuid-1",
  brand: "GREYSON",
  season: "2026 Spring",
  active: true,
  suppliers: [
    {
      companyId: "company-uuid-abc",
      companyName: "ABC Mfg Co",
      accessLevel: "view",
      canUpdateTimelines: false
    },
    {
      companyId: "company-uuid-xyz",
      companyName: "XYZ Factory Ltd",
      accessLevel: "edit",
      canUpdateTimelines: true
    }
  ],
  // ... other fields
};
```

### Style with Supplier Assignments (Gate 2)
```typescript
const mockStyle: PlanStyle = {
  id: "style-uuid-1",
  plan_id: "plan-uuid-1",
  style_number: "MSP26B26",
  style_name: "Navy Polo",
  color_name: "220",
  suppliers: [
    {
      companyId: "company-uuid-abc",
      companyName: "ABC Mfg Co",
      role: "quote"
    },
    {
      companyId: "company-uuid-xyz",
      companyName: "XYZ Factory Ltd",
      role: "production"
    }
  ],
  // ... other fields
};
```

### Timeline with Shared Suppliers (Gate 3)
```typescript
const mockTimeline: PlanStyleTimeline = {
  id: "timeline-uuid-1",
  plan_id: "plan-uuid-1",
  style_id: "style-uuid-1",
  template_item_id: "template-item-submit-to-factory",
  name: "Submit to Factory",
  status: "pending",
  plan_date: "2026-02-12",
  shared_with: [
    "company-uuid-abc",  // ABC Mfg Co
    "company-uuid-xyz"   // XYZ Factory Ltd
  ],
  // ... other fields
};
```

### Template Item with Defaults
```typescript
const mockTemplateItem: TimelineTemplateItem = {
  id: "template-item-uuid-1",
  template_id: "template-uuid-1",
  name: "Submit to Factory",
  node_type: "TASK",
  phase: "PRODUCTION",
  department: "Sourcing",
  display_order: 10,
  supplier_visible: true,  // Suppliers can see this milestone
  default_assigned_to: ["user-uuid-sourcing-manager"],  // Pre-assign to sourcing manager
  default_shared_with: [],  // Empty - sharing configured per-plan
  // ... other fields
};
```

---

## Common Questions

### Q: Can a supplier be in Gate 2 without being in Gate 1?
**A:** No. The UI should validate this. When assigning a supplier to a style (Gate 2), only show suppliers who already have plan access (Gate 1).

### Q: Can a supplier be in Gate 3 without being in Gate 2?
**A:** Technically yes (no database constraint), but it's not recommended. The UI should warn users if they try to share a milestone with a supplier who's not assigned to the style.

### Q: What happens if I remove a supplier from Gate 1?
**A:** You should also clean up their Gate 2 (style assignments) and Gate 3 (milestone sharing) entries. Show a confirmation dialog: "This supplier is assigned to 5 styles. Remove all assignments?"

### Q: Can I use the same supplier for multiple roles on one style?
**A:** No. Each supplier can only have ONE role per style (quote OR production, not both). If they win the quote, change their role from "quote" to "production".

### Q: What's the difference between `assignedTo` (personal) and `shared_with` (company)?
**A:** `assignedTo` is for **internal team members** (individuals) and controls who's responsible. `shared_with` is for **external companies** (suppliers/factories) and controls visibility in the supplier portal.

---

## Summary

**Three gates, three questions:**
1. **Gate 1 (Plan):** Can this supplier access this plan?
2. **Gate 2 (Style):** Can this supplier see this style?
3. **Gate 3 (Milestone):** Can this supplier see this milestone?

**All three must be "yes" for a milestone to appear in the supplier portal.**

**Build the UI in this order:**
1. Phase 3: Gate 1 (Plan supplier access management)
2. Phase 4: Gate 2 (Style supplier assignments) + Gate 3 (Milestone sharing)
3. Phase 5: Template defaults + Personal assignments

**Validation is key:**
- Gate 2 requires Gate 1
- Gate 3 references Gate 2
- Always filter dropdown options based on parent gates
