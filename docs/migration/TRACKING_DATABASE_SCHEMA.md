# Tracking & Timeline Database Schema

## Visual Schema Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TRACKING SYSTEM SCHEMA                           │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│  tracking_folder     │
│  ================    │
│  id (PK)            │ 1
│  name               │ │
│  brand              │ │
│  active             │ │
│  created_at         │ │
│  updated_at         │ │
└──────────────────────┘ │
                         │
                         │ N
                         ↓
┌──────────────────────────────────────────┐
│  tracking_plan                           │
│  ================                        │
│  id (PK)                                │
│  folder_id (FK) ────────────────────────┘
│  name                                   │
│  season                                 │
│  start_date                             │
│  end_date                               │
│  active                                 │
│  template_id (FK) ──────────────────┐   │
│  created_at                         │   │
│  updated_at                         │   │
└─────────────────────────────────────┘   │
        │                      │           │
        │ N                    │ N         │
        ↓                      ↓           │
┌────────────────────┐  ┌────────────────┐│
│ tracking_plan_     │  │ tracking_plan_ ││
│ style              │  │ material       ││
│ ================   │  │ ============== ││
│ id (PK)           │  │ id (PK)        ││
│ plan_id (FK) ─────┘  │ plan_id (FK) ──┘│
│ style_number      │  │ material_name   │
│ style_name        │  │ material_type   │
│ color_name        │  │ supplier_name   │
│ supplier_name     │  │ status_summary  │
│ status_summary ⓙ │  └─────────────────┘
│ active            │
│ created_at        │
│ updated_at        │
└───────────────────┘
        │
        │ N
        ↓
┌────────────────────────────────────────┐
│ tracking_plan_style_timeline           │
│ ================                       │
│ id (PK)                               │
│ plan_style_id (FK) ────────────────────┘
│ template_item_id (FK) ─────────────┐
│ status                             │
│ plan_date                          │
│ due_date                           │
│ late                               │
│ notes                              │
│ created_at                         │
│ updated_at                         │
└────────────────────────────────────┘
        │                              │
        │ N                            │
        ↓                              │
┌────────────────────────────┐        │
│ tracking_timeline_         │        │
│ assignment                 │        │
│ ================           │        │
│ id (PK)                   │        │
│ timeline_id (FK) ──────────┘        │
│ assignee_id                │        │
│ role_name                  │        │
│ assigned_at                │        │
└────────────────────────────┘        │
                                      │
                                      │
                                      │
┌──────────────────────────────────────┘
│
│ 1
↓
┌────────────────────────────────────────┐
│ tracking_timeline_template             │
│ ================                       │
│ id (PK)                               │
│ name                                  │
│ brand                                 │
│ season                                │
│ version                               │
│ is_active                             │
│ timezone                              │
│ anchor_strategy                       │
│ created_at                            │
│ updated_at                            │
└────────────────────────────────────────┘
        │
        │ N
        ↓
┌────────────────────────────────────────────────────┐
│ tracking_timeline_template_item                    │
│ ================                                   │
│ id (PK)                                           │
│ template_id (FK) ──────────────────────────────────┘
│ name                                              │
│ short_name                                        │
│ node_type (ANCHOR|TASK|MILESTONE|PHASE)         │
│ phase                                             │
│ department                                        │
│ display_order                                     │
│ depends_on_template_item_id (FK) ───────┐        │
│ offset_relation (AFTER|BEFORE)          │        │
│ offset_value                             │        │
│ offset_unit (DAYS|WEEKS)                │        │
│ page_type                                │        │
│ applies_to_style                         │        │
│ applies_to_material                      │        │
│ timeline_type                            │        │
│ required                                 │        │
│ supplier_visible                         │        │
│ notes                                    │        │
└──────────────────────────────────────────┘        │
        ↑                                           │
        └───────────────────────────────────────────┘
                (Self-Referencing)


LEGEND:
═══════  Table name
───────  Foreign key relationship
   N     One-to-Many cardinality
   ⓙ    JSONB field
```

## Detailed Table Schemas

### tracking_folder
```sql
CREATE TABLE ops.tracking_folder (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    brand TEXT,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tracking_folder_active ON ops.tracking_folder(active);
CREATE INDEX idx_tracking_folder_brand ON ops.tracking_folder(brand);
```

### tracking_plan
```sql
CREATE TABLE ops.tracking_plan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    folder_id UUID NOT NULL REFERENCES ops.tracking_folder(id),
    name TEXT NOT NULL,
    season TEXT,
    start_date DATE,
    end_date DATE,
    active BOOLEAN DEFAULT true,
    template_id UUID REFERENCES ops.tracking_timeline_template(id),
    timezone TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tracking_plan_folder_id ON ops.tracking_plan(folder_id);
CREATE INDEX idx_tracking_plan_template_id ON ops.tracking_plan(template_id);
CREATE INDEX idx_tracking_plan_active ON ops.tracking_plan(active);
```

### tracking_timeline_template
```sql
CREATE TABLE ops.tracking_timeline_template (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    brand TEXT,
    season TEXT,
    version INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    timezone TEXT,
    anchor_strategy TEXT,
    conflict_policy TEXT,
    business_days_calendar JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    created_by TEXT,
    updated_at TIMESTAMP DEFAULT NOW(),
    updated_by TEXT
);

CREATE INDEX idx_tracking_timeline_template_active 
    ON ops.tracking_timeline_template(is_active);
CREATE INDEX idx_tracking_timeline_template_brand 
    ON ops.tracking_timeline_template(brand);
```

### tracking_timeline_template_item
```sql
CREATE TABLE ops.tracking_timeline_template_item (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES ops.tracking_timeline_template(id) ON DELETE CASCADE,
    node_type TEXT NOT NULL CHECK (node_type IN ('ANCHOR', 'TASK', 'MILESTONE', 'PHASE')),
    name TEXT NOT NULL,
    short_name TEXT,
    phase TEXT,
    department TEXT,
    display_order INTEGER NOT NULL,
    depends_on_template_item_id UUID REFERENCES ops.tracking_timeline_template_item(id),
    depends_on_action TEXT,
    offset_relation TEXT CHECK (offset_relation IN ('AFTER', 'BEFORE')),
    offset_value INTEGER,
    offset_unit TEXT CHECK (offset_unit IN ('DAYS', 'BUSINESS_DAYS', 'WEEKS')),
    page_type TEXT,
    page_label TEXT,
    applies_to_style BOOLEAN DEFAULT true,
    applies_to_material BOOLEAN DEFAULT false,
    timeline_type TEXT DEFAULT 'MASTER',
    required BOOLEAN DEFAULT false,
    notes TEXT,
    supplier_visible BOOLEAN DEFAULT false,
    default_assigned_to TEXT[],
    default_shared_with TEXT[]
);

CREATE INDEX idx_tracking_timeline_template_item_template_id 
    ON ops.tracking_timeline_template_item(template_id);
CREATE INDEX idx_tracking_timeline_template_item_depends_on 
    ON ops.tracking_timeline_template_item(depends_on_template_item_id);
CREATE INDEX idx_tracking_timeline_template_item_display_order 
    ON ops.tracking_timeline_template_item(template_id, display_order);
```

### tracking_plan_style
```sql
CREATE TABLE ops.tracking_plan_style (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL REFERENCES ops.tracking_plan(id) ON DELETE CASCADE,
    view_id UUID,
    style_id UUID,
    style_header_id UUID,
    color_id UUID,
    style_number TEXT,
    style_name TEXT,
    color_name TEXT,
    season TEXT,
    delivery TEXT,
    factory TEXT,
    supplier_id UUID,
    supplier_name TEXT,
    brand TEXT,
    status_summary JSONB DEFAULT '{"milestones": []}'::jsonb,
    style_timeline JSONB,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tracking_plan_style_plan_id ON ops.tracking_plan_style(plan_id);
CREATE INDEX idx_tracking_plan_style_active ON ops.tracking_plan_style(active);
CREATE INDEX idx_tracking_plan_style_style_number ON ops.tracking_plan_style(style_number);
CREATE INDEX idx_tracking_plan_style_status_summary_gin 
    ON ops.tracking_plan_style USING GIN(status_summary);
```

**JSONB Structure for status_summary**:
```json
{
  "milestones": [
    {
      "name": "Sample Submission",
      "short_name": "Sample Sub",
      "status": "COMPLETE",
      "plan_date": "2025-02-15",
      "due_date": "2025-02-20",
      "completed_date": "2025-02-18",
      "notes": "Submitted on time",
      "department": "Design",
      "phase": "DEVELOPMENT",
      "assigned_to": ["user123", "user456"],
      "shared_with": ["supplier789"],
      "duration_value": 5,
      "duration_unit": "DAYS"
    }
  ]
}
```

### tracking_plan_style_timeline
```sql
CREATE TABLE ops.tracking_plan_style_timeline (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_style_id UUID NOT NULL REFERENCES ops.tracking_plan_style(id) ON DELETE CASCADE,
    template_item_id UUID NOT NULL REFERENCES ops.tracking_timeline_template_item(id),
    status TEXT DEFAULT 'NOT_STARTED' 
        CHECK (status IN ('NOT_STARTED', 'IN_PROGRESS', 'APPROVED', 'REJECTED', 'COMPLETE', 'BLOCKED', 'WAITING_ON')),
    plan_date DATE,
    rev_date DATE,
    final_date DATE,
    due_date DATE,
    completed_date DATE,
    start_date_plan DATE,
    start_date_due DATE,
    duration_value INTEGER,
    duration_unit TEXT,
    late BOOLEAN DEFAULT false,
    page_type TEXT,
    page_name TEXT,
    page_id UUID,
    request_code TEXT,
    request_id UUID,
    request_status TEXT,
    notes TEXT,
    shared_with TEXT[],
    timeline_type TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tracking_plan_style_timeline_plan_style_id 
    ON ops.tracking_plan_style_timeline(plan_style_id);
CREATE INDEX idx_tracking_plan_style_timeline_template_item_id 
    ON ops.tracking_plan_style_timeline(template_item_id);
CREATE INDEX idx_tracking_plan_style_timeline_status 
    ON ops.tracking_plan_style_timeline(status);
CREATE INDEX idx_tracking_plan_style_timeline_late 
    ON ops.tracking_plan_style_timeline(late) WHERE late = true;
CREATE INDEX idx_tracking_plan_style_timeline_due_date 
    ON ops.tracking_plan_style_timeline(due_date);
```

### tracking_timeline_assignment
```sql
CREATE TABLE ops.tracking_timeline_assignment (
    id SERIAL PRIMARY KEY,
    timeline_id UUID NOT NULL REFERENCES ops.tracking_plan_style_timeline(id) ON DELETE CASCADE,
    assignee_id TEXT,
    role_name TEXT,
    role_id TEXT,
    assigned_at TIMESTAMP DEFAULT NOW(),
    source_user_id TEXT
);

CREATE INDEX idx_tracking_timeline_assignment_timeline_id 
    ON ops.tracking_timeline_assignment(timeline_id);
CREATE INDEX idx_tracking_timeline_assignment_assignee_id 
    ON ops.tracking_timeline_assignment(assignee_id);
```

### tracking_plan_material
```sql
CREATE TABLE ops.tracking_plan_material (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL REFERENCES ops.tracking_plan(id) ON DELETE CASCADE,
    view_id UUID,
    material_id UUID,
    material_name TEXT,
    material_type TEXT,
    supplier_id UUID,
    supplier_name TEXT,
    status_summary JSONB DEFAULT '{"milestones": []}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tracking_plan_material_plan_id ON ops.tracking_plan_material(plan_id);
```

## View Definitions

### tracking_folder_summary
```sql
CREATE OR REPLACE VIEW ops.tracking_folder_summary AS
SELECT 
    f.id,
    f.name,
    f.brand,
    f.active,
    f.created_at,
    f.updated_at,
    COUNT(p.id) FILTER (WHERE p.active = true) as active_plan_count,
    COUNT(p.id) as total_plan_count
FROM ops.tracking_folder f
LEFT JOIN ops.tracking_plan p ON f.id = p.folder_id
GROUP BY f.id, f.name, f.brand, f.active, f.created_at, f.updated_at;
```

### tracking_plan_summary
```sql
CREATE OR REPLACE VIEW ops.tracking_plan_summary AS
SELECT 
    p.id,
    p.folder_id,
    f.name as folder_name,
    f.brand as folder_brand,
    p.name,
    p.season,
    p.start_date,
    p.end_date,
    p.active,
    p.template_id,
    t.name as template_name,
    COUNT(DISTINCT ps.id) FILTER (WHERE ps.active = true) as style_count,
    COUNT(DISTINCT pm.id) as material_count,
    p.created_at,
    p.updated_at
FROM ops.tracking_plan p
LEFT JOIN ops.tracking_folder f ON p.folder_id = f.id
LEFT JOIN ops.tracking_timeline_template t ON p.template_id = t.id
LEFT JOIN ops.tracking_plan_style ps ON p.id = ps.plan_id
LEFT JOIN ops.tracking_plan_material pm ON p.id = pm.plan_id
GROUP BY p.id, f.name, f.brand, t.name;
```

### tracking_timeline_template_detail
```sql
CREATE OR REPLACE VIEW ops.tracking_timeline_template_detail AS
SELECT 
    t.id,
    t.name,
    t.brand,
    t.season,
    t.version,
    t.is_active,
    t.timezone,
    t.anchor_strategy,
    COUNT(ti.id) as total_items,
    COUNT(ti.id) FILTER (WHERE ti.applies_to_style = true) as style_items,
    COUNT(ti.id) FILTER (WHERE ti.applies_to_material = true) as material_items,
    COUNT(ti.id) FILTER (WHERE ti.node_type IN ('ANCHOR', 'MILESTONE')) as anchor_count,
    t.created_at,
    t.updated_at
FROM ops.tracking_timeline_template t
LEFT JOIN ops.tracking_timeline_template_item ti ON t.id = ti.template_id
GROUP BY t.id, t.name, t.brand, t.season, t.version, t.is_active, 
         t.timezone, t.anchor_strategy, t.created_at, t.updated_at;
```

### tracking_plan_style_timeline_detail (proposed)
```sql
CREATE OR REPLACE VIEW ops.tracking_plan_style_timeline_detail AS
SELECT 
    pst.id,
    pst.plan_style_id,
    pst.template_item_id,
    pst.status,
    pst.plan_date,
    pst.due_date,
    pst.completed_date,
    pst.start_date_plan,
    pst.start_date_due,
    pst.duration_value,
    pst.duration_unit,
    pst.late,
    ps.style_number,
    ps.style_name,
    ps.color_name,
    ps.supplier_name,
    ti.name as milestone_name,
    ti.short_name as milestone_short_name,
    ti.phase,
    ti.department,
    ti.display_order,
    ti.node_type,
    pst.created_at,
    pst.updated_at
FROM ops.tracking_plan_style_timeline pst
JOIN ops.tracking_plan_style ps ON pst.plan_style_id = ps.id
JOIN ops.tracking_timeline_template_item ti ON pst.template_item_id = ti.id
WHERE ps.active = true;
```

## Relationships Summary

### One-to-Many Relationships

| Parent Table | Child Table | Relationship | Delete Behavior |
|--------------|-------------|--------------|-----------------|
| tracking_folder | tracking_plan | folder → plans | CASCADE |
| tracking_plan | tracking_plan_style | plan → styles | CASCADE |
| tracking_plan | tracking_plan_material | plan → materials | CASCADE |
| tracking_timeline_template | tracking_timeline_template_item | template → items | CASCADE |
| tracking_plan_style | tracking_plan_style_timeline | style → timelines | CASCADE |
| tracking_plan_style_timeline | tracking_timeline_assignment | timeline → assignments | CASCADE |

### Many-to-One Relationships

| Child Table | Parent Table | Purpose |
|-------------|--------------|---------|
| tracking_plan | tracking_timeline_template | Plans use templates |
| tracking_plan_style_timeline | tracking_timeline_template_item | Timeline instances reference template definitions |

### Self-Referencing Relationships

| Table | Purpose |
|-------|---------|
| tracking_timeline_template_item | Dependencies between milestones (e.g., "Sample Approval" depends on "Sample Submission") |

## Data Integrity Rules

### Constraints

1. **Foreign Keys**: All foreign keys use `ON DELETE CASCADE` to maintain referential integrity
2. **Check Constraints**: Enumerated values enforced at database level (status, node_type, etc.)
3. **Not Null**: Critical fields like names and foreign keys are NOT NULL
4. **Defaults**: Boolean flags default to `false` or `true` as appropriate
5. **Timestamps**: Auto-populated `created_at` and `updated_at` fields

### Business Rules

1. **Active Plans**: Only active plans should be displayed in most views
2. **Active Styles**: Only active styles should be counted in summaries
3. **Late Calculation**: `late` flag should be `true` when `due_date < NOW()` and status != 'COMPLETE'
4. **Template Versions**: Multiple versions of the same template can exist
5. **Milestone Dependencies**: Dependencies should not create circular references
6. **Offset Calculations**: When `depends_on_template_item_id` is set, must have valid `offset_value`, `offset_unit`, and `offset_relation`

## Triggers (Recommended)

### Update timestamp trigger
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to all tables with updated_at
CREATE TRIGGER update_tracking_folder_updated_at 
    BEFORE UPDATE ON ops.tracking_folder
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tracking_plan_updated_at 
    BEFORE UPDATE ON ops.tracking_plan
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ... (repeat for other tables)
```

### Calculate late flag trigger
```sql
CREATE OR REPLACE FUNCTION calculate_late_flag()
RETURNS TRIGGER AS $$
BEGIN
    NEW.late = (
        NEW.due_date < CURRENT_DATE 
        AND NEW.status NOT IN ('COMPLETE', 'COMPLETED')
    );
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_tracking_plan_style_timeline_late 
    BEFORE INSERT OR UPDATE ON ops.tracking_plan_style_timeline
    FOR EACH ROW EXECUTE FUNCTION calculate_late_flag();
```

## Migration Order

When creating tables, follow this order to satisfy foreign key dependencies:

1. `tracking_folder`
2. `tracking_timeline_template`
3. `tracking_plan`
4. `tracking_timeline_template_item` (self-referencing, so can be created after template)
5. `tracking_plan_style`
6. `tracking_plan_material`
7. `tracking_plan_style_timeline`
8. `tracking_timeline_assignment`
9. Views (after all base tables)

## Sample Data Flow

### Creating a New Plan with Styles and Timeline

```sql
-- Step 1: Create folder (if needed)
INSERT INTO ops.tracking_folder (name, brand) 
VALUES ('GREYSON MENS', 'GREYSON') 
RETURNING id; -- folder_id = 'abc123'

-- Step 2: Create plan
INSERT INTO ops.tracking_plan (folder_id, name, season, start_date, end_date, template_id)
VALUES (
    'abc123',
    'GREYSON 2026 SPRING DROP 1',
    '2026 Spring',
    '2026-01-15',
    '2026-06-30',
    'template789' -- existing template
)
RETURNING id; -- plan_id = 'def456'

-- Step 3: Add styles to plan
INSERT INTO ops.tracking_plan_style (plan_id, style_number, style_name, color_name)
VALUES 
    ('def456', 'GRY-001', 'Polo Shirt', 'Navy'),
    ('def456', 'GRY-002', 'Golf Pants', 'Khaki')
RETURNING id; -- style_ids = 'style001', 'style002'

-- Step 4: Generate timeline for each style
-- For each style, create timeline entries for each template item
INSERT INTO ops.tracking_plan_style_timeline (
    plan_style_id, 
    template_item_id, 
    plan_date, 
    due_date, 
    status
)
SELECT 
    ps.id,
    ti.id,
    -- Calculate dates based on template offsets
    p.start_date + (ti.offset_value || ' ' || ti.offset_unit)::interval,
    p.start_date + (ti.offset_value || ' ' || ti.offset_unit)::interval + interval '7 days',
    'NOT_STARTED'
FROM ops.tracking_plan_style ps
JOIN ops.tracking_plan p ON ps.plan_id = p.id
JOIN ops.tracking_timeline_template_item ti ON p.template_id = ti.template_id
WHERE ps.plan_id = 'def456' AND ti.applies_to_style = true;

-- Step 5: Assign team members to milestones
INSERT INTO ops.tracking_timeline_assignment (timeline_id, assignee_id)
VALUES 
    ('timeline001', 'user123'),
    ('timeline001', 'user456');
```

## Performance Monitoring

### Useful Queries

#### Count records in each table
```sql
SELECT 
    'tracking_folder' as table_name, COUNT(*) as count FROM ops.tracking_folder
UNION ALL
SELECT 'tracking_plan', COUNT(*) FROM ops.tracking_plan
UNION ALL
SELECT 'tracking_plan_style', COUNT(*) FROM ops.tracking_plan_style
UNION ALL
SELECT 'tracking_plan_style_timeline', COUNT(*) FROM ops.tracking_plan_style_timeline
UNION ALL
SELECT 'tracking_timeline_assignment', COUNT(*) FROM ops.tracking_timeline_assignment;
```

#### Find plans with most styles
```sql
SELECT 
    p.name,
    COUNT(ps.id) as style_count
FROM ops.tracking_plan p
LEFT JOIN ops.tracking_plan_style ps ON p.id = ps.plan_id AND ps.active = true
GROUP BY p.id, p.name
ORDER BY style_count DESC
LIMIT 10;
```

#### Find most late milestones
```sql
SELECT 
    ti.name as milestone_name,
    COUNT(*) FILTER (WHERE pst.late = true) as late_count,
    COUNT(*) as total_count
FROM ops.tracking_plan_style_timeline pst
JOIN ops.tracking_timeline_template_item ti ON pst.template_item_id = ti.id
GROUP BY ti.name
ORDER BY late_count DESC;
```

---

## Generated On
2025-01-08

## Version
1.0.0
