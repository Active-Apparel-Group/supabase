# Timeline Template Data Migration Guide

**Purpose:** Prepare timeline template data for import into Supabase tracking schema.

**Date:** 2025-10-23  
**Target Tables:** `tracking.timeline_templates`, `tracking.timeline_template_items`, `tracking.timeline_template_visibility`

---

## 📋 Overview

Timeline templates define the milestone structure for tracking plans. Each template contains:
- **Template Header:** Brand, season, version metadata
- **Template Items:** Individual milestones/phases with dependencies
- **Visibility Rules:** Per-view visibility configuration

---

## 🗂️ Table 1: timeline_templates

### Schema Reference

```sql
CREATE TABLE tracking.timeline_templates (
    id uuid PRIMARY KEY,
    name text NOT NULL,
    brand text,
    season text,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    timezone text,
    anchor_strategy text,
    conflict_policy text,
    business_days_calendar jsonb,
    created_at timestamptz DEFAULT now(),
    created_by uuid,
    updated_at timestamptz DEFAULT now(),
    updated_by uuid
);
```

### JSON Template

```json
{
  "templates": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "name": "GREYSON 2026 Spring Standard Template",
      "brand": "GREYSON",
      "season": "2026 Spring",
      "version": 1,
      "is_active": true,
      "timezone": "America/Los_Angeles",
      "anchor_strategy": "FIRST_MILESTONE",
      "conflict_policy": "SKIP_WEEKENDS",
      "business_days_calendar": {
        "weekends": ["Saturday", "Sunday"],
        "holidays": ["2025-12-25", "2026-01-01"]
      },
      "created_at": "2025-10-23T00:00:00Z",
      "created_by": null,
      "updated_at": "2025-10-23T00:00:00Z",
      "updated_by": null
    }
  ]
}
```

### SQL Insert Template

```sql
INSERT INTO tracking.timeline_templates (
    id, name, brand, season, version, is_active, 
    timezone, anchor_strategy, conflict_policy, business_days_calendar
) VALUES (
    '550e8400-e29b-41d4-a716-446655440001',
    'GREYSON 2026 Spring Standard Template',
    'GREYSON',
    '2026 Spring',
    1,
    true,
    'America/Los_Angeles',
    'FIRST_MILESTONE',
    'SKIP_WEEKENDS',
    '{"weekends": ["Saturday", "Sunday"], "holidays": ["2025-12-25", "2026-01-01"]}'::jsonb
);
```

---

## 🗂️ Table 2: timeline_template_items

### Schema Reference

```sql
CREATE TABLE tracking.timeline_template_items (
    id uuid PRIMARY KEY,
    template_id uuid NOT NULL REFERENCES tracking.timeline_templates(id),
    node_type text NOT NULL, -- 'MILESTONE' | 'PHASE'
    name text NOT NULL,
    short_name text,
    phase text,
    department text,
    display_order integer NOT NULL,
    depends_on_template_item_id uuid,
    depends_on_action text,
    offset_relation text, -- 'AFTER' | 'BEFORE'
    offset_value integer,
    offset_unit text, -- 'DAYS' | 'WEEKS'
    page_type text,
    page_label text,
    applies_to_style boolean DEFAULT true,
    applies_to_material boolean DEFAULT false,
    timeline_type text DEFAULT 'MASTER',
    required boolean DEFAULT true,
    notes text
);
```

### JSON Template (Example Milestones)

```json
{
  "template_items": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440101",
      "template_id": "550e8400-e29b-41d4-a716-446655440001",
      "node_type": "MILESTONE",
      "name": "Proto Submit",
      "short_name": "Proto",
      "phase": "DEVELOPMENT",
      "department": "DESIGN",
      "display_order": 1,
      "depends_on_template_item_id": null,
      "depends_on_action": null,
      "offset_relation": null,
      "offset_value": null,
      "offset_unit": null,
      "page_type": "FORM",
      "page_label": "Proto Details",
      "applies_to_style": true,
      "applies_to_material": false,
      "timeline_type": "MASTER",
      "required": true,
      "notes": "Initial prototype submission"
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440102",
      "template_id": "550e8400-e29b-41d4-a716-446655440001",
      "node_type": "MILESTONE",
      "name": "Proto Approval",
      "short_name": "Proto OK",
      "phase": "DEVELOPMENT",
      "department": "DESIGN",
      "display_order": 2,
      "depends_on_template_item_id": "660e8400-e29b-41d4-a716-446655440101",
      "depends_on_action": "COMPLETE",
      "offset_relation": "AFTER",
      "offset_value": 7,
      "offset_unit": "DAYS",
      "page_type": "FORM",
      "page_label": "Approval Form",
      "applies_to_style": true,
      "applies_to_material": false,
      "timeline_type": "MASTER",
      "required": true,
      "notes": "Approval within 7 days of proto submit"
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440103",
      "template_id": "550e8400-e29b-41d4-a716-446655440001",
      "node_type": "MILESTONE",
      "name": "Material Submit",
      "short_name": "Mat Submit",
      "phase": "SOURCING",
      "department": "PRODUCTION",
      "display_order": 3,
      "depends_on_template_item_id": null,
      "depends_on_action": null,
      "offset_relation": null,
      "offset_value": null,
      "offset_unit": null,
      "page_type": "FORM",
      "page_label": "Material Submission",
      "applies_to_style": false,
      "applies_to_material": true,
      "timeline_type": "MASTER",
      "required": true,
      "notes": "Material submission for approval"
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440104",
      "template_id": "550e8400-e29b-41d4-a716-446655440001",
      "node_type": "MILESTONE",
      "name": "Bulk Fabric Order",
      "short_name": "Bulk Order",
      "phase": "PRODUCTION",
      "department": "PRODUCTION",
      "display_order": 4,
      "depends_on_template_item_id": "660e8400-e29b-41d4-a716-446655440103",
      "depends_on_action": "COMPLETE",
      "offset_relation": "AFTER",
      "offset_value": 14,
      "offset_unit": "DAYS",
      "page_type": "GRID",
      "page_label": "Bulk Orders",
      "applies_to_style": false,
      "applies_to_material": true,
      "timeline_type": "MASTER",
      "required": true,
      "notes": "Bulk order 2 weeks after material approval"
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440105",
      "template_id": "550e8400-e29b-41d4-a716-446655440001",
      "node_type": "PHASE",
      "name": "Production Phase",
      "short_name": "Production",
      "phase": "PRODUCTION",
      "department": "PRODUCTION",
      "display_order": 5,
      "depends_on_template_item_id": null,
      "depends_on_action": null,
      "offset_relation": null,
      "offset_value": null,
      "offset_unit": null,
      "page_type": null,
      "page_label": null,
      "applies_to_style": true,
      "applies_to_material": true,
      "timeline_type": "MASTER",
      "required": false,
      "notes": "Grouping phase for production milestones"
    }
  ]
}
```

### SQL Insert Template

```sql
INSERT INTO tracking.timeline_template_items (
    id, template_id, node_type, name, short_name, phase, department,
    display_order, depends_on_template_item_id, depends_on_action,
    offset_relation, offset_value, offset_unit, page_type, page_label,
    applies_to_style, applies_to_material, timeline_type, required, notes
) VALUES 
(
    '660e8400-e29b-41d4-a716-446655440101',
    '550e8400-e29b-41d4-a716-446655440001',
    'MILESTONE',
    'Proto Submit',
    'Proto',
    'DEVELOPMENT',
    'DESIGN',
    1,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'FORM',
    'Proto Details',
    true,
    false,
    'MASTER',
    true,
    'Initial prototype submission'
),
(
    '660e8400-e29b-41d4-a716-446655440102',
    '550e8400-e29b-41d4-a716-446655440001',
    'MILESTONE',
    'Proto Approval',
    'Proto OK',
    'DEVELOPMENT',
    'DESIGN',
    2,
    '660e8400-e29b-41d4-a716-446655440101',
    'COMPLETE',
    'AFTER',
    7,
    'DAYS',
    'FORM',
    'Approval Form',
    true,
    false,
    'MASTER',
    true,
    'Approval within 7 days of proto submit'
);
-- Add remaining items...
```

---

## 🗂️ Table 3: timeline_template_visibility

### Schema Reference

```sql
CREATE TABLE tracking.timeline_template_visibility (
    template_item_id uuid REFERENCES tracking.timeline_template_items(id),
    view_type text NOT NULL, -- 'DETAIL' | 'GRID' | 'TIMELINE' | 'CALENDAR'
    is_visible boolean DEFAULT true,
    PRIMARY KEY (template_item_id, view_type)
);
```

### JSON Template

```json
{
  "visibility_rules": [
    {
      "template_item_id": "660e8400-e29b-41d4-a716-446655440101",
      "view_type": "GRID",
      "is_visible": true
    },
    {
      "template_item_id": "660e8400-e29b-41d4-a716-446655440101",
      "view_type": "TIMELINE",
      "is_visible": true
    },
    {
      "template_item_id": "660e8400-e29b-41d4-a716-446655440101",
      "view_type": "CALENDAR",
      "is_visible": false
    },
    {
      "template_item_id": "660e8400-e29b-41d4-a716-446655440102",
      "view_type": "GRID",
      "is_visible": true
    },
    {
      "template_item_id": "660e8400-e29b-41d4-a716-446655440102",
      "view_type": "TIMELINE",
      "is_visible": true
    }
  ]
}
```

### SQL Insert Template

```sql
INSERT INTO tracking.timeline_template_visibility (
    template_item_id, view_type, is_visible
) VALUES 
    ('660e8400-e29b-41d4-a716-446655440101', 'GRID', true),
    ('660e8400-e29b-41d4-a716-446655440101', 'TIMELINE', true),
    ('660e8400-e29b-41d4-a716-446655440101', 'CALENDAR', false),
    ('660e8400-e29b-41d4-a716-446655440102', 'GRID', true),
    ('660e8400-e29b-41d4-a716-446655440102', 'TIMELINE', true);
```

---

## 📦 Complete Example: GREYSON 2026 Spring Template

```sql
BEGIN;

-- 1. Insert template
INSERT INTO tracking.timeline_templates (
    id, name, brand, season, version, is_active, timezone
) VALUES (
    '550e8400-e29b-41d4-a716-446655440001',
    'GREYSON 2026 Spring Standard',
    'GREYSON',
    '2026 Spring',
    1,
    true,
    'America/Los_Angeles'
);

-- 2. Insert template items
INSERT INTO tracking.timeline_template_items (
    id, template_id, node_type, name, short_name, phase, department,
    display_order, applies_to_style, applies_to_material, required
) VALUES 
    ('660e8400-e29b-41d4-a716-446655440101', '550e8400-e29b-41d4-a716-446655440001', 
     'MILESTONE', 'Proto Submit', 'Proto', 'DEVELOPMENT', 'DESIGN', 1, true, false, true),
    ('660e8400-e29b-41d4-a716-446655440102', '550e8400-e29b-41d4-a716-446655440001', 
     'MILESTONE', 'Proto Approval', 'Proto OK', 'DEVELOPMENT', 'DESIGN', 2, true, false, true),
    ('660e8400-e29b-41d4-a716-446655440103', '550e8400-e29b-41d4-a716-446655440001', 
     'MILESTONE', 'SMS Submit', 'SMS', 'PRODUCTION', 'PRODUCTION', 3, true, false, true),
    ('660e8400-e29b-41d4-a716-446655440104', '550e8400-e29b-41d4-a716-446655440001', 
     'MILESTONE', 'Material Submit', 'Mat Submit', 'SOURCING', 'PRODUCTION', 4, false, true, true),
    ('660e8400-e29b-41d4-a716-446655440105', '550e8400-e29b-41d4-a716-446655440001', 
     'MILESTONE', 'Bulk Fabric Order', 'Bulk Order', 'PRODUCTION', 'PRODUCTION', 5, false, true, true),
    ('660e8400-e29b-41d4-a716-446655440106', '550e8400-e29b-41d4-a716-446655440001', 
     'MILESTONE', 'Ex-Factory', 'Ex-Fty', 'SHIPPING', 'LOGISTICS', 6, true, false, true);

-- 3. Insert visibility rules (all visible in grid and timeline)
INSERT INTO tracking.timeline_template_visibility (template_item_id, view_type, is_visible)
SELECT id, 'GRID', true FROM tracking.timeline_template_items WHERE template_id = '550e8400-e29b-41d4-a716-446655440001'
UNION ALL
SELECT id, 'TIMELINE', true FROM tracking.timeline_template_items WHERE template_id = '550e8400-e29b-41d4-a716-446655440001';

COMMIT;
```

---

## 🔗 Linking Templates to Plans

After importing templates, update your plans to reference them:

```sql
UPDATE tracking.plans
SET template_id = '550e8400-e29b-41d4-a716-446655440001'
WHERE folder_id = '82a698e1-9103-4bab-98af-a0ec423332a2' -- GREYSON MENS
  AND season = '2026 Spring';
```

---

## ✅ Verification Queries

### Check template is loaded
```sql
SELECT * FROM public.v_timeline_template 
WHERE brand = 'GREYSON';
```

### Check template items
```sql
SELECT template_name, item_name, phase, display_order, applies_to_style, applies_to_material
FROM public.v_timeline_template_item
WHERE brand = 'GREYSON'
ORDER BY display_order;
```

### Check plans now show template_name
```sql
SELECT folder_name, plan_name, template_name
FROM public.v_folder_plan
WHERE brand = 'GREYSON';
```

---

## 📝 Notes

- **UUIDs:** Generate consistent UUIDs for templates across environments (use deterministic approach or shared seed data).
- **Dependencies:** `depends_on_template_item_id` creates milestone chains (e.g., "Proto Approval" depends on "Proto Submit").
- **Offsets:** `offset_relation`, `offset_value`, `offset_unit` auto-calculate dependent dates.
- **Visibility:** Default to visible in GRID and TIMELINE views; hide rarely-used items in CALENDAR view.

---

**Next Steps:**
1. Prepare your template data using this template
2. Run migration 0011 to create views/endpoints
3. Import template data via SQL or Edge Function
4. Link templates to plans
5. Verify via `/rest/v1/v_timeline_template` and `/rest/v1/v_folder_plan`
