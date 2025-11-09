# Timeline Template Application Workflow

## Current State ✅

### What We Have:
1. **Template System** (READ-ONLY Phase 1)
   - `tracking.timeline_templates` - 1 template: "Garment Tracking Timeline"
   - `tracking.timeline_template_items` - 27 nodes (2 ANCHOR + 25 TASK)
   - Views: `v_timeline_template`, `v_timeline_template_item`
   - Dependencies properly linked by UUID (not names)

2. **Tracking Plan System** (EXISTING)
   - `tracking.plan` - holds plan metadata with `template_id` column
   - `tracking.plan_styles` - styles added to plans
   - `tracking.plan_style_timelines` - actual timeline instances per style
   - `tracking.plan_style_dependencies` - dependency relationships
   
3. **MCP Tools Available**:
   - ✅ `planAddStyle` - Add style by styleId
   - ✅ `planAddStyleByColorway` - Bulk add styles by colorway entries
   - ✅ `planGet` - Get plan details
   - ✅ `planStyleTimeline` - Get style's timeline

## The Data Flow 🔄

```
1. CREATE PLAN (assign template)
   tracking.plan
   └── template_id = <our garment template UUID>

2. ADD STYLES TO PLAN (existing tool works!)
   POST /api/{company}/Tracking/Plan/{planId}/Style/Add
   └── Creates: tracking.plan_styles record
   
3. ⚠️ MISSING: INSTANTIATE TEMPLATE → TIMELINE
   ❌ NO FUNCTION/ENDPOINT EXISTS YET
   Need to create: tracking.plan_style_timelines records
   - One row per template_item for this style
   - Copy from timeline_template_items
   - Calculate initial dates based on anchor strategy
   
4. VIEW/UPDATE TIMELINE (existing tools work)
   GET /Tracking/Plan/{planId}/Style/{styleId}/Timeline
   PATCH /Tracking/Plan/{planId}/Style/Timeline (planUpdateStyleTimelines)
```

## The Problem ⚠️

**When you add a style to a plan (step 2), the timeline is NOT automatically created.**

The `planAddStyle` endpoint only creates the `plan_styles` record. It does NOT:
- Read the template
- Create 27 `plan_style_timelines` rows
- Copy the template structure
- Calculate dates based on anchors
- Set up dependencies

## Solution Options 🛠️

### Option A: Database Trigger (RECOMMENDED)
**Create a PostgreSQL trigger on `tracking.plan_styles` INSERT**

```sql
-- When plan_style is inserted, auto-generate timeline from template
CREATE OR REPLACE FUNCTION tracking.instantiate_timeline_from_template()
RETURNS TRIGGER AS $$
DECLARE
    v_template_id uuid;
    v_plan_start_date date;
    v_plan_end_date date;
BEGIN
    -- Get plan's template and anchor dates
    SELECT template_id, start_date, end_date 
    INTO v_template_id, v_plan_start_date, v_plan_end_date
    FROM tracking.plan 
    WHERE id = NEW.plan_id;
    
    -- Only proceed if plan has a template assigned
    IF v_template_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Insert timeline records from template
    INSERT INTO tracking.plan_style_timelines (
        id, plan_style_id, template_item_id, status,
        timeline_type, page_type, page_name, late, created_at, updated_at
    )
    SELECT 
        gen_random_uuid(),
        NEW.id,
        ti.id,
        'NOT_STARTED',
        ti.timeline_type,
        ti.page_type,
        ti.page_label,
        false,
        NOW(),
        NOW()
    FROM tracking.timeline_template_items ti
    WHERE ti.template_id = v_template_id
        AND (ti.applies_to_style = true OR ti.timeline_type = 'STYLE');
    
    -- Insert dependencies
    INSERT INTO tracking.plan_style_dependencies (
        successor_id, predecessor_id, offset_relation, offset_value, offset_unit
    )
    SELECT 
        succ.id,
        pred.id,
        ti.offset_relation,
        ti.offset_value,
        ti.offset_unit
    FROM tracking.timeline_template_items ti
    JOIN tracking.plan_style_timelines succ ON succ.template_item_id = ti.id AND succ.plan_style_id = NEW.id
    JOIN tracking.plan_style_timelines pred ON pred.template_item_id = ti.depends_on_template_item_id AND pred.plan_style_id = NEW.id
    WHERE ti.depends_on_template_item_id IS NOT NULL;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_instantiate_style_timeline
    AFTER INSERT ON tracking.plan_styles
    FOR EACH ROW
    EXECUTE FUNCTION tracking.instantiate_timeline_from_template();
```

**Pros:**
- ✅ Automatic - no code changes needed
- ✅ Works with existing `planAddStyle` MCP tool
- ✅ Guaranteed consistency
- ✅ No API changes

**Cons:**
- ⚠️ Hidden logic - developers might not know it's happening
- ⚠️ Can't easily test/debug timeline generation

### Option B: Dedicated MCP Tool
**Add new operation: `planInstantiateTimeline`**

```typescript
// New tool: beproduct-tracking planInstantiateTimeline
{
  operation: 'planInstantiateTimeline',
  payload: {
    planId: 'uuid',
    planStyleId: 'uuid',  // or styleId to find it
    calculateDates: true  // calculate from anchors vs leave null
  }
}
```

**Pros:**
- ✅ Explicit control
- ✅ Can be called on-demand
- ✅ Easy to test
- ✅ Frontend can show progress

**Cons:**
- ❌ Requires BeProduct API endpoint (you can't edit their backend)
- ❌ Extra step after adding style

### Option C: Application-Level Function (Supabase)
**Create a Supabase stored procedure that can be called via RPC**

```sql
CREATE OR REPLACE FUNCTION tracking.instantiate_style_timeline(
    p_plan_style_id uuid,
    p_calculate_dates boolean DEFAULT true
)
RETURNS TABLE(timeline_id uuid, template_item_id uuid, status text) AS $$
-- Implementation similar to trigger above
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Call via PostgREST:
-- POST /rest/v1/rpc/instantiate_style_timeline
-- { "p_plan_style_id": "uuid", "p_calculate_dates": true }
```

**Pros:**
- ✅ Explicit call from frontend/MCP
- ✅ Can be invoked directly via Supabase client
- ✅ Returns results for confirmation
- ✅ No BeProduct API needed

**Cons:**
- ⚠️ Must remember to call it after adding style

## Date Calculation Strategy 📅

Once timeline records exist, dates need to be calculated:

1. **Anchor Strategy** (from template):
   - `bookend`: Use plan's `start_date` and `end_date` as anchors
   
2. **Calculate Dates**:
   ```
   For each timeline node:
   - If node is ANCHOR "START DATE" → use plan.start_date
   - If node is ANCHOR "END DATE" → use plan.end_date
   - If node has dependency:
     - Get predecessor's date
     - Apply offset: predecessor_date + (offset_value * offset_unit)
     - Handle AFTER/BEFORE relation
     - Handle BUSINESS_DAYS (skip weekends/holidays from template.business_days_calendar)
   ```

3. **Update Timeline Records**:
   ```sql
   UPDATE tracking.plan_style_timelines
   SET plan_date = <calculated_date>
   WHERE plan_style_id = ?
   ```

This calculation could be:
- Part of the trigger (Option A)
- A separate function called after instantiation
- Handled by frontend/MCP after getting timeline

## Recommended Next Steps 🎯

### Phase 1: AUTO-INSTANTIATE (RECOMMENDED)
1. **Create trigger function** (Option A above)
2. **Test**: Add style to plan, verify 27 timeline records created
3. **Verify**: Check dependencies are properly linked

### Phase 2: DATE CALCULATION
1. **Create date calculation function**:
   ```sql
   CREATE FUNCTION tracking.calculate_timeline_dates(
       p_plan_style_id uuid
   ) RETURNS void
   ```
2. **Call from trigger** OR **expose as RPC** for on-demand recalculation

### Phase 3: EXPOSE TO MCP (Optional)
1. **Add RPC wrapper** in MCP tool for manual recalculation:
   ```typescript
   {
     operation: 'planRecalculateTimeline',
     payload: { planStyleId: 'uuid' }
   }
   ```

## Testing Checklist ✓

Once implemented:

```powershell
# 1. Get a plan ID
$planId = "..." # from planSearch

# 2. Get template ID  
$templateId = "..." # from v_timeline_template

# 3. Verify plan has template assigned
# UPDATE tracking.plan SET template_id = $templateId WHERE id = $planId

# 4. Add a style
mcp-tool beproduct-tracking planAddStyle --planId $planId --styleId "..."

# 5. Verify timeline created
SELECT COUNT(*) FROM tracking.plan_style_timelines 
WHERE plan_style_id = (
    SELECT id FROM tracking.plan_styles 
    WHERE plan_id = $planId AND style_id = '...'
);
# Expected: 27 rows (or 25 if only STYLE nodes, not all 27)

# 6. Check dependencies created
SELECT COUNT(*) FROM tracking.plan_style_dependencies;
```

## ✅ COMPLETE - Current Status Summary

- ✅ Template exists (27 nodes: 2 ANCHOR + 25 TASK)
- ✅ Dependencies fixed (UUID-based via `depends_on_template_item_id`)
- ✅ Views working (`v_timeline_template`, `v_timeline_template_item`)
- ✅ `planAddStyle` MCP tool working
- ✅ **Timeline AUTO-CREATED when style added** (trigger implemented)
- ✅ **Date calculation implemented** (`calculate_timeline_dates` function)
- ✅ **Trigger deployed and tested**

## When You Add a Style from BeProduct

**Automatic Process:**
```typescript
// Call existing MCP tool
mcp-tool beproduct-tracking planAddStyle --planId <uuid> --styleId <uuid>

// Behind the scenes:
// 1. POST to BeProduct API /Tracking/Plan/{planId}/Style/Add
// 2. BeProduct creates tracking.plan_styles record
// 3. 🔥 TRIGGER FIRES: trg_instantiate_style_timeline
// 4. 27 tracking.plan_style_timelines records created
// 5. 25 tracking.plan_style_dependencies records created
// 6. Timeline structure ready!
```

**Manual Date Calculation:**
```sql
-- Call this function to calculate dates based on plan start/end dates
SELECT * FROM tracking.calculate_timeline_dates('<plan_style_id>');

-- This updates:
-- - plan_date (initial planned date)
-- - due_date (current due date)
-- Based on dependencies and anchors
```

## Prerequisites for Full Functionality

**Plan Setup Required:**
1. ✅ Plan must have `template_id` assigned
2. ✅ Plan should have `start_date` and `end_date` set
3. ✅ Use BeProduct's `planAddStyle` tool

**Example:**
```sql
-- Assign template to plan
UPDATE tracking.plan 
SET 
    template_id = (SELECT id FROM tracking.timeline_templates WHERE name = 'Garment Tracking Timeline'),
    start_date = '2025-11-01',
    end_date = '2026-03-15'
WHERE id = '<your-plan-id>';

-- Then add styles via MCP (timelines auto-created)
-- Then calculate dates: SELECT * FROM tracking.calculate_timeline_dates('<plan_style_id>');
```

## Test Results (Verified Working)

✅ **Test Plan:** GREYSON 2026 SPRING DROP 3
- Plan dates: 2025-11-01 to 2026-03-15
- Template: Garment Tracking Timeline

✅ **Test Style:** TEST-001
- 27 timeline records created ✓
- 25 dependencies created ✓
- Dates calculated ✓
- Date range: 2025-08-03 to 2026-03-15

**Sample Timeline Output:**
```
BULK PO                    → 2025-08-03 (74 days before CUT DATE)
Issue allocations          → 2025-08-05 (AFTER BULK PO +2 days)
Download Tech Packs        → 2025-08-07 (AFTER BULK PO +4 days)
START DATE (ANCHOR)        → 2025-11-01
TECHPACKS PASS OFF         → 2025-11-01 (AFTER START DATE +0 days)
PROTO PRODUCTION           → 2025-11-05 (AFTER TECHPACKS +4 days)
PROTO EX-FCTY             → 2025-11-19 (AFTER PROTO PROD +14 days)
CUT DATE                   → 2025-12-15 (60 days before EX-FTY)
EX-FTY DATE               → 2026-02-13 (30 days before END DATE)
END DATE (ANCHOR)          → 2026-03-15
IN WAREHOUSE               → 2026-03-15 (AFTER END DATE +0 days)
```

## Database Objects Created

**Migration 0013:** `create_timeline_instantiation_trigger`
- Function: `tracking.instantiate_timeline_from_template()`
- Trigger: `trg_instantiate_style_timeline` on `tracking.plan_styles` INSERT

**Migration 0014:** `fix_timeline_date_calculation`
- Function: `tracking.calculate_timeline_dates(uuid)` 
- Returns: Table of calculated dates
- Updates: `plan_date` and `due_date` in `tracking.plan_style_timelines`

## Next Steps (Optional Enhancements)

### Auto-Calculate Dates in Trigger
Currently dates need manual calculation. To auto-calculate on style insert:

```sql
-- Uncomment this at end of trigger function:
IF v_plan_start_date IS NOT NULL OR v_plan_end_date IS NOT NULL THEN
    PERFORM tracking.calculate_timeline_dates(NEW.id);
    RAISE NOTICE 'Auto-calculated timeline dates for plan_style %', NEW.id;
END IF;
```

### Handle Business Days Calendar
Currently uses simple day offsets. To respect weekends/holidays:
- Read `template.business_days_calendar` 
- Skip dates in `weekends` and `holidays` arrays
- Apply when `offset_unit = 'BUSINESS_DAYS'`

### Add Recalculation Triggers
Recalculate dates when:
- Plan `start_date` or `end_date` changes
- Individual timeline dates are manually adjusted
- Dependencies are modified
