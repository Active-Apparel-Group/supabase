# Tracking Schema Analysis Summary

**Date:** November 6, 2025  
**Purpose:** Document critical schema details for webhook implementation

---

## Key Findings

### 1. ✅ PK/FK Relationships Documented

Complete foreign key hierarchy validated:

```
tracking_folder (brand/category grouping)
└── tracking_plan (production timeline for season)
    ├── tracking_plan_style (style/colorway in plan)
    │   └── tracking_plan_style_timeline (24 milestones per style)
    │       ├── tracking_timeline_assignment (who's assigned)
    │       └── tracking_plan_style_dependency (predecessor/successor)
    └── tracking_timeline_template (milestone template)
        └── tracking_timeline_template_item (template milestones)
```

**Critical insight:** `tracking_plan_style_timeline.template_item_id` links to template, which defines the milestone structure (name, department, default dependencies).

---

### 2. ✅ Dependency Table Discovered (⚠️ Disabled for Phase 1)

**Table:** `tracking_plan_style_dependency`

**Structure:**
```sql
CREATE TABLE ops.tracking_plan_style_dependency (
  successor_id uuid NOT NULL,
  predecessor_id uuid NOT NULL,  
  offset_relation offset_relation_enum NOT NULL,  -- BEFORE | AFTER
  offset_value integer NOT NULL,      -- Days to offset
  offset_unit offset_unit_enum NOT NULL  -- DAYS | BUSINESS_DAYS
);
-- Note: FK constraints to tracking_plan_style_timeline REMOVED for Phase 1
```

**Purpose:**  
Defines predecessor → successor relationships for Gantt chart calculations.

**Example:**
- Milestone "Sample Approval" (successor)
- Must occur AFTER milestone "Sample Submission" (predecessor)  
- With offset: 5 BUSINESS_DAYS after predecessor completes

**Phase 1 Status:**  
⚠️ **Dependency functionality is DISABLED for Phase 1.** Foreign key constraints have been removed. The webhook function does NOT populate dependency records. Dependency implementation (including FK constraints and webhook population logic) will be added in Phase 2.

---

### 3. ✅ START DATE / END DATE Bookends

**Discovery:** When a style is instantiated, **two special anchor milestones** are created:

1. **START DATE** milestone
   - Anchored to `tracking_plan.start_date`
   - All other milestones chain from this anchor via dependencies
   - Acts as the "beginning" of the timeline

2. **END DATE** milestone
   - Anchored to `tracking_plan.end_date`
   - Final milestone in the chain
   - Acts as the "end" of the timeline

**Implementation:**
```typescript
// From instantiate_timeline_from_template() function
INSERT INTO ops.tracking_plan_style_timeline (...)
SELECT ...
FROM ops.tracking_timeline_template_item ti
WHERE ti.template_id = v_template_id
  AND (ti.applies_to_style = true OR ti.name IN ('START DATE', 'END DATE'));
```

**Why this matters:**
- Creates a bounded timeline for each style/colorway
- All milestones are transitively connected via dependency chain
- Plan start/end dates propagate to all milestones through dependencies

---

### 4. ⚠️ Trigger Conflicts Identified

**Discovered 5 active triggers that CONFLICT with webhook data:**

#### Trigger 1: `calculate_timeline_dates_trigger`
- **On:** `tracking_plan_style_timeline` (BEFORE INSERT/UPDATE)
- **Does:** Auto-calculates `start_date_plan` and `plan_date` from predecessor dates
- **Conflict:** Webhooks provide pre-calculated dates from BeProduct
- **Result:** Trigger overwrites webhook dates with local calculations
- **Status:** ❌ Must be dropped

#### Trigger 2: `cascade_timeline_updates_trigger`
- **On:** `tracking_plan_style_timeline` (AFTER UPDATE)
- **Does:** When a milestone date changes, recalculates all successor dates
- **Conflict:** Creates cascade of recalculations after webhook update
- **Result:** Entire dependency chain gets recalculated, diverging from BeProduct
- **Status:** ❌ Must be dropped

#### Trigger 3: `recalculate_plan_timelines_trigger`
- **On:** `tracking_plan` (AFTER UPDATE)
- **Does:** When plan start/end dates change, recalculates all milestone dates
- **Conflict:** Would recalculate after plan updates
- **Result:** All webhook dates get overwritten
- **Status:** ❌ Must be dropped

#### Trigger 4: `calculate_material_timeline_dates_trigger`
- **On:** `tracking_plan_material_timeline` (BEFORE INSERT/UPDATE)
- **Does:** Same as #1 but for material timelines
- **Conflict:** Same issue (though materials not in Phase 1 scope)
- **Status:** ❌ Dropped for consistency

#### Trigger 5: `cascade_material_timeline_updates_trigger`
- **On:** `tracking_plan_material_timeline` (AFTER UPDATE)
- **Does:** Same as #2 but for material timelines
- **Conflict:** Same issue
- **Status:** ❌ Dropped for consistency

#### Trigger 6: `trg_instantiate_style_timeline` ✅ KEEP THIS ONE
- **On:** `tracking_plan_style` (AFTER INSERT)
- **Does:** Creates timeline structure from template when style added to plan
  - Inserts 24+ timeline milestone records
  - Creates dependency records from template
  - Creates START DATE and END DATE anchors
- **Conflict:** None - this is essential infrastructure
- **Result:** Creates the skeleton; webhook fills in the dates
- **Status:** ✅ Must be kept

---

## Resolution: Migration 009

**Created:** `009_disable_timeline_date_calculation_triggers.sql`

**Actions:**
```sql
-- Drop date calculation triggers (conflicts with webhooks)
DROP TRIGGER IF EXISTS calculate_timeline_dates_trigger ON ops.tracking_plan_style_timeline;
DROP TRIGGER IF EXISTS cascade_timeline_updates_trigger ON ops.tracking_plan_style_timeline;
DROP TRIGGER IF EXISTS recalculate_plan_timelines_trigger ON ops.tracking_plan;
DROP TRIGGER IF EXISTS calculate_material_timeline_dates_trigger ON ops.tracking_plan_material_timeline;
DROP TRIGGER IF EXISTS cascade_material_timeline_updates_trigger ON ops.tracking_plan_material_timeline;

-- Keep instantiation trigger (essential for template expansion)
-- trg_instantiate_style_timeline remains active
```

**Deployment requirement:** This migration **MUST** run before deploying the webhook edge function, otherwise webhook data will be immediately overwritten by triggers.

---

## Data Flow After Migration

### Scenario: User adds style to tracking plan in BeProduct

**Step 1: Instantiation (Supabase side)**
```
User action in BeProduct
  ↓
trg_instantiate_style_timeline fires
  ↓
Creates 24 timeline_style_timeline records (dates = NULL)
Creates ~20 dependency records (from template)
Creates START DATE and END DATE anchors
```

**Step 2: Calculation (BeProduct side)**
```
BeProduct calculates dates based on:
  - Plan start_date/end_date
  - Template dependencies (offset_relation, offset_value)
  - Business days calendar
  ↓
Generates DueDate and ProjectDate for all 24 milestones
```

**Step 3: Webhook Sync (BeProduct → Supabase)**
```
BeProduct sends OnCreate webhook
  ↓
Edge function receives payload
  ↓
Updates tracking_plan_style_timeline records with BeProduct dates
  ↓
NO TRIGGERS FIRE (they've been dropped)
  ↓
Data remains in sync with BeProduct (source of truth)
```

---

## Updated Todo List

Based on schema analysis findings:

- [x] Document PK/FK relationships
- [x] Document dependency table structure  
- [x] Document START DATE / END DATE bookends
- [x] Identify trigger conflicts
- [x] Create migration to drop conflicting triggers
- [x] Update webhook function documentation
- [x] Update deployment checklist with migration requirement
- [x] Update implementation plan with schema details
- [ ] Test migration on staging environment
- [ ] Deploy webhook function after migration
- [ ] Validate webhook data is not overwritten by triggers

---

## Questions for User

1. **Dependency population:** Should the webhook function also populate `tracking_plan_style_dependency` records, or rely solely on the instantiation trigger?
   - Current approach: Let trigger handle dependencies (from template)
   - Alternative: Webhook could also fetch dependency data from API

2. **Date field priority:** When BeProduct sends multiple dates (DueDate, ProjectDate, Rev, Final), which should populate which columns?
   - Current mapping:
     - `plan_date` ← `ProjectDate`
     - `due_date` ← `DueDate`
     - `rev_date` ← `Rev`
     - `final_date` ← `Final`
   - Is this correct?

3. **Start date fields:** Should webhook populate `start_date_plan` and `start_date_due` columns?
   - These exist in schema but are not in webhook payload
   - May need to derive from: `due_date - duration_value`

---

## Next Steps

1. **Immediate:** Apply migration 009 to staging/dev environment
2. **Validation:** Confirm triggers are dropped but instantiation trigger remains
3. **Testing:** Add test style to plan, verify timeline created with NULL dates
4. **Webhook test:** Trigger webhook, verify dates populate without being overwritten
5. **Production:** Apply migration, deploy webhook function, monitor sync logs
