# Tracking & Timeline Supabase Documentation

## Overview
This document provides a comprehensive summary of all Supabase queries, functions, endpoints, tables, and database relationships used in the tracking and timeline sections of the AAG Customer Portal.

## Table of Contents
1. [Database Tables & Views](#database-tables--views)
2. [Server-Side API Functions](#server-side-api-functions)
3. [Client-Side API Functions](#client-side-api-functions)
4. [Server Actions](#server-actions)
5. [PostgreSQL Query Equivalents](#postgresql-query-equivalents)
6. [Database Relationships](#database-relationships)

---

## Database Tables & Views

### Tables (ops schema)

#### 1. `tracking_folder` (base table)
**Purpose**: Stores brand folders for organizing tracking plans  
**Key Columns**:
- `id` (uuid, PK)
- `name` (text)
- `brand` (text)
- `active` (boolean)
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### 2. `tracking_plan` (base table)
**Purpose**: Stores tracking plans within folders  
**Key Columns**:
- `id` (uuid, PK)
- `folder_id` (uuid, FK → tracking_folder)
- `name` (text)
- `season` (text)
- `start_date` (date)
- `end_date` (date)
- `active` (boolean)
- `template_id` (uuid, FK → tracking_timeline_template)
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### 3. `tracking_timeline_template` (base table)
**Purpose**: Defines reusable timeline templates with milestones  
**Key Columns**:
- `id` (uuid, PK)
- `name` (text)
- `brand` (text)
- `season` (text)
- `version` (integer)
- `is_active` (boolean)
- `timezone` (text)
- `anchor_strategy` (text)
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### 4. `tracking_timeline_template_item` (base table)
**Purpose**: Individual milestones/tasks within a timeline template  
**Key Columns**:
- `id` (uuid, PK)
- `template_id` (uuid, FK → tracking_timeline_template)
- `node_type` (text) - Values: 'ANCHOR', 'TASK', 'MILESTONE', 'PHASE'
- `name` (text)
- `short_name` (text)
- `phase` (text)
- `department` (text)
- `display_order` (integer)
- `depends_on_template_item_id` (uuid, FK → tracking_timeline_template_item)
- `depends_on_action` (text)
- `offset_relation` (text) - Values: 'AFTER', 'BEFORE'
- `offset_value` (integer)
- `offset_unit` (text) - Values: 'DAYS', 'BUSINESS_DAYS', 'WEEKS'
- `page_type` (text)
- `page_label` (text)
- `applies_to_style` (boolean)
- `applies_to_material` (boolean)
- `timeline_type` (text) - Values: 'MASTER', 'STYLE', 'MATERIAL'
- `required` (boolean)
- `notes` (text)
- `supplier_visible` (boolean)

#### 5. `tracking_plan_style` (base table)
**Purpose**: Styles linked to a tracking plan  
**Key Columns**:
- `id` (uuid, PK) - also called `plan_style_id`
- `plan_id` (uuid, FK → tracking_plan)
- `view_id` (uuid)
- `style_id` (uuid)
- `style_header_id` (uuid)
- `color_id` (uuid)
- `style_number` (text)
- `style_name` (text)
- `color_name` (text)
- `season` (text)
- `delivery` (text)
- `factory` (text)
- `supplier_id` (uuid)
- `supplier_name` (text)
- `brand` (text)
- `status_summary` (jsonb) - Contains milestone progress
- `active` (boolean)
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### 6. `tracking_plan_style_timeline` (base table)
**Purpose**: Timeline milestones for each style  
**Key Columns**:
- `id` (uuid, PK)
- `plan_style_id` (uuid, FK → tracking_plan_style)
- `template_item_id` (uuid, FK → tracking_timeline_template_item)
- `status` (text) - Values: 'NOT_STARTED', 'IN_PROGRESS', 'APPROVED', 'REJECTED', 'COMPLETE', 'BLOCKED'
- `plan_date` (date)
- `rev_date` (date)
- `final_date` (date)
- `due_date` (date)
- `completed_date` (date)
- `start_date_plan` (date)
- `start_date_due` (date)
- `duration_value` (integer)
- `duration_unit` (text)
- `late` (boolean)
- `page_type` (text)
- `page_name` (text)
- `page_id` (uuid)
- `request_code` (text)
- `request_id` (uuid)
- `request_status` (text)
- `notes` (text)
- `shared_with` (text[])
- `timeline_type` (text)
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### 7. `tracking_timeline_assignment` (base table)
**Purpose**: User assignments to timeline milestones  
**Key Columns**:
- `id` (integer, PK, auto-increment)
- `timeline_id` (uuid, FK → tracking_plan_style_timeline)
- `assignee_id` (text)
- `role_name` (text)
- `role_id` (text)
- `assigned_at` (timestamp)
- `source_user_id` (text)

#### 8. `tracking_plan_material` (base table)
**Purpose**: Materials/components linked to a tracking plan  
**Key Columns**:
- `id` (uuid, PK)
- `plan_id` (uuid, FK → tracking_plan)
- `view_id` (uuid)
- `material_id` (uuid)
- `material_name` (text)
- `material_type` (text)
- `supplier_id` (uuid)
- `supplier_name` (text)
- `status_summary` (jsonb)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### Views (ops schema)

#### 1. `tracking_folder_summary` (view)
**Purpose**: Aggregated folder data with plan counts  
**Columns**:
- `id` (uuid) - folder_id
- `name` (text)
- `brand` (text)
- `active` (boolean)
- `created_at` (timestamp)
- `updated_at` (timestamp)
- `active_plan_count` (bigint) - Count of active plans
- `total_plan_count` (bigint) - Count of all plans

**Equivalent SQL**:
```sql
SELECT 
  f.id,
  f.name,
  f.brand,
  f.active,
  f.created_at,
  f.updated_at,
  COUNT(CASE WHEN p.active = true THEN 1 END) as active_plan_count,
  COUNT(p.id) as total_plan_count
FROM ops.tracking_folder f
LEFT JOIN ops.tracking_plan p ON f.id = p.folder_id
GROUP BY f.id, f.name, f.brand, f.active, f.created_at, f.updated_at
ORDER BY f.name;
```

#### 2. `tracking_plan_summary` (view)
**Purpose**: Aggregated plan data with style/material counts  
**Columns**:
- `id` (uuid) - plan_id
- `folder_id` (uuid)
- `folder_name` (text)
- `folder_brand` (text)
- `name` (text) - plan name
- `season` (text)
- `start_date` (date)
- `end_date` (date)
- `active` (boolean)
- `template_id` (uuid)
- `template_name` (text)
- `style_count` (bigint)
- `material_count` (bigint)
- `created_at` (timestamp)
- `updated_at` (timestamp)

**Equivalent SQL**:
```sql
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
  COUNT(DISTINCT ps.id) as style_count,
  COUNT(DISTINCT pm.id) as material_count,
  p.created_at,
  p.updated_at
FROM ops.tracking_plan p
LEFT JOIN ops.tracking_folder f ON p.folder_id = f.id
LEFT JOIN ops.tracking_timeline_template t ON p.template_id = t.id
LEFT JOIN ops.tracking_plan_style ps ON p.id = ps.plan_id AND ps.active = true
LEFT JOIN ops.tracking_plan_material pm ON p.id = pm.plan_id
GROUP BY p.id, f.name, f.brand, t.name
ORDER BY p.name;
```

#### 3. `tracking_timeline_template_detail` (view)
**Purpose**: Template data with item counts  
**Columns**:
- `id` (uuid) - template_id
- `name` (text)
- `brand` (text)
- `season` (text)
- `version` (integer)
- `is_active` (boolean)
- `timezone` (text)
- `anchor_strategy` (text)
- `total_items` (bigint) - Count of all template items
- `style_items` (bigint) - Count of items applying to styles
- `material_items` (bigint) - Count of items applying to materials
- `anchor_count` (bigint) - Count of anchor/milestone items
- `created_at` (timestamp)
- `updated_at` (timestamp)

**Equivalent SQL**:
```sql
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
  COUNT(CASE WHEN ti.applies_to_style = true THEN 1 END) as style_items,
  COUNT(CASE WHEN ti.applies_to_material = true THEN 1 END) as material_items,
  COUNT(CASE WHEN ti.node_type IN ('ANCHOR', 'MILESTONE') THEN 1 END) as anchor_count,
  t.created_at,
  t.updated_at
FROM ops.tracking_timeline_template t
LEFT JOIN ops.tracking_timeline_template_item ti ON t.id = ti.template_id
GROUP BY t.id, t.name, t.brand, t.season, t.version, t.is_active, 
         t.timezone, t.anchor_strategy, t.created_at, t.updated_at
ORDER BY t.name;
```

#### 4. `tracking_plan_style_summary` (view)
**Purpose**: Style data with timeline counts (if view exists)  
**Note**: Referenced in code but may not be implemented yet

#### 5. `tracking_plan_style_timeline_detail` (view)
**Purpose**: Enriched timeline data with template metadata  
**Note**: Referenced in code but may not be implemented yet

### Tables (public schema)

#### 1. `brand_folders` (legacy/alternative table)
**Purpose**: Alternative folder storage (used in server actions)  
**Note**: May be legacy or different schema version

#### 2. `tracking_plans` (legacy/alternative table)
**Purpose**: Alternative plan storage (used in server actions)  
**Note**: May be legacy or different schema version

---

## Server-Side API Functions

### File: `/lib/tracking-api.ts`
Uses: `@/lib/supabase/server` (server-side Supabase client)  
Schema: Default schema (tracking)

### 1. `getFolders()`
**Purpose**: Fetch all folders with plan counts  
**Returns**: `Promise<FolderView[]>`

**Query**:
```typescript
await supabase
  .from("tracking_folder_summary")
  .select("*")
  .order("name", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM tracking.tracking_folder_summary
ORDER BY name ASC;
```

**Response Mapping**:
```typescript
{
  folder_id: folder.id,
  folder_name: folder.name,
  brand: folder.brand,
  style_folder_id: null,
  style_folder_name: null,
  active: true,
  created_at: folder.created_at,
  updated_at: folder.updated_at,
  active_plan_count: folder.active_plan_count || 0,
  total_plan_count: folder.total_plan_count || 0,
  latest_plan_date: null,
  active_seasons: null
}
```

### 2. `getFolderPlans(folderId: string)`
**Purpose**: Fetch all plans for a specific folder  
**Parameters**: `folderId` - UUID of the folder  
**Returns**: `Promise<FolderPlanView[]>`

**Query**:
```typescript
await supabase
  .from("tracking_plan_summary")
  .select("*")
  .eq("folder_id", folderId)
  .order("name", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM tracking.tracking_plan_summary
WHERE folder_id = $1
ORDER BY name ASC;
```

**Response Mapping**:
```typescript
{
  folder_id: plan.folder_id,
  folder_name: plan.folder_name,
  brand: plan.folder_brand,
  plan_id: plan.id,
  plan_name: plan.name,
  plan_season: null,
  start_date: null,
  end_date: null,
  plan_active: plan.active,
  template_id: plan.template_id,
  template_name: plan.template_name,
  default_view_id: null,
  default_view_name: null,
  style_count: plan.style_count || 0,
  material_count: plan.material_count || 0,
  style_milestone_count: 0,
  material_milestone_count: 0
}
```

### 3. `getPlanById(planId: string)`
**Purpose**: Fetch a single plan by ID  
**Parameters**: `planId` - UUID of the plan  
**Returns**: `Promise<FolderPlanView | null>`

**Query**:
```typescript
await supabase
  .from("tracking_plan_summary")
  .select("*")
  .eq("id", planId)
  .single()
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM tracking.tracking_plan_summary
WHERE id = $1
LIMIT 1;
```

---

## Client-Side API Functions

### File: `/lib/tracking-api-client.ts`
Uses: `@/lib/supabase/client` (client-side Supabase client)  
Schema: `ops`

### 1. `getFolders()`
**Purpose**: Fetch all folders with plan counts (client-side)  
**Returns**: `Promise<FolderView[]>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_folder_summary")
  .select("*")
  .order("name", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_folder_summary
ORDER BY name ASC;
```

### 2. `getFolderById(folderId: string)`
**Purpose**: Fetch a single folder by ID  
**Parameters**: `folderId` - UUID of the folder  
**Returns**: `Promise<FolderView | null>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_folder_summary")
  .select("*")
  .eq("id", folderId)
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_folder_summary
WHERE id = $1;
```

### 3. `getFolderPlans(folderId: string)`
**Purpose**: Fetch plans for a folder (client-side)  
**Parameters**: `folderId` - UUID of the folder  
**Returns**: `Promise<FolderPlanView[]>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_plan_summary")
  .select("*")
  .eq("folder_id", folderId)
  .order("name", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_plan_summary
WHERE folder_id = $1
ORDER BY name ASC;
```

### 4. `getPlanById(planId: string)`
**Purpose**: Fetch a single plan by ID (client-side)  
**Parameters**: `planId` - UUID of the plan  
**Returns**: `Promise<FolderPlanView | null>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_plan_summary")
  .select("*")
  .eq("id", planId)
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_plan_summary
WHERE id = $1;
```

### 5. `getTemplates()`
**Purpose**: Fetch all timeline templates with counts  
**Returns**: `Promise<TimelineTemplateView[]>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_template_detail")
  .select("*")
  .order("name", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_timeline_template_detail
ORDER BY name ASC;
```

### 6. `getTemplateItems(templateId: string)`
**Purpose**: Fetch template items (milestones) for a specific template  
**Parameters**: `templateId` - UUID of the template  
**Returns**: `Promise<TimelineTemplateItemView[]>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_template_item")
  .select("*")
  .eq("template_id", templateId)
  .order("display_order", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_timeline_template_item
WHERE template_id = $1
ORDER BY display_order ASC;
```

### 7. `getTemplateById(templateId: string)`
**Purpose**: Fetch a single template by ID  
**Parameters**: `templateId` - UUID of the template  
**Returns**: `Promise<TimelineTemplateView | null>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_template_detail")
  .select("*")
  .eq("id", templateId)
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_timeline_template_detail
WHERE id = $1;
```

### 8. `getPlanMilestones(planId: string, templateId: string)`
**Purpose**: Fetch milestones for a plan (inherited from template)  
**Parameters**: 
- `planId` - UUID of the plan
- `templateId` - UUID of the template  
**Returns**: `Promise<TimelineTemplateItemView[]>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_template_item")
  .select("*")
  .eq("template_id", templateId)
  .order("display_order", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_timeline_template_item
WHERE template_id = $1
ORDER BY display_order ASC;
```

### 9. `getPlanStyles(planId: string)`
**Purpose**: Fetch all styles for a specific plan  
**Parameters**: `planId` - UUID of the plan  
**Returns**: `Promise<any[]>`

**Primary Query** (tries first):
```typescript
await supabase
  .schema("ops")
  .from("tracking_plan_style_summary")
  .select("*")
  .eq("plan_id", planId)
  .order("style_number", { ascending: true })
```

**Fallback Query** (if view doesn't exist):
```typescript
await supabase
  .schema("ops")
  .from("tracking_plan_style")
  .select("*")
  .eq("plan_id", planId)
  .eq("active", true)
  .order("style_number", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
-- Primary query
SELECT *
FROM ops.tracking_plan_style_summary
WHERE plan_id = $1
ORDER BY style_number ASC;

-- Fallback query
SELECT *
FROM ops.tracking_plan_style
WHERE plan_id = $1 AND active = true
ORDER BY style_number ASC;
```

### 10. `getPlanStyleMilestones(planStyleId: string)`
**Purpose**: Fetch timeline milestones for a specific style  
**Parameters**: `planStyleId` - UUID of the plan style  
**Returns**: `Promise<any[]>`

**Query** (with joins):
```typescript
const selectQuery = `
  *,
  template_item:tracking_timeline_template_item!tracking_plan_style_timeline_template_item_id_fkey(
    id, name, short_name, phase, department, node_type, timeline_type,
    page_type, page_label, offset_relation, offset_unit, offset_value,
    depends_on_template_item_id, depends_on_action, required, notes,
    applies_to_style, applies_to_material, display_order
  )
`

await supabase
  .schema("ops")
  .from("tracking_plan_style_timeline")
  .select(selectQuery)
  .eq("plan_style_id", planStyleId)
  .order("template_item.display_order", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT 
  t.*,
  ti.id as template_item_id,
  ti.name as template_item_name,
  ti.short_name,
  ti.phase,
  ti.department,
  ti.node_type,
  ti.timeline_type,
  ti.page_type,
  ti.page_label,
  ti.offset_relation,
  ti.offset_unit,
  ti.offset_value,
  ti.depends_on_template_item_id,
  ti.depends_on_action,
  ti.required,
  ti.notes,
  ti.applies_to_style,
  ti.applies_to_material,
  ti.display_order
FROM ops.tracking_plan_style_timeline t
JOIN ops.tracking_timeline_template_item ti ON t.template_item_id = ti.id
WHERE t.plan_style_id = $1
ORDER BY ti.display_order ASC;
```

### 11. `getPlanStyleTimelinesEnriched(planId: string)`
**Purpose**: Fetch enriched timeline data for all styles in a plan  
**Parameters**: `planId` - UUID of the plan  
**Returns**: `Promise<any[]>`

**Query** (multi-step):
```typescript
// Step 1: Get all plan style IDs
await supabase
  .schema("ops")
  .from("tracking_plan_style")
  .select("id")
  .eq("plan_id", planId)

// Step 2: Try enriched view first
await supabase
  .schema("ops")
  .from("tracking_plan_style_timeline_detail")
  .select("*, start_date_plan, start_date_due, duration_value, duration_unit")
  .in("plan_style_id", planStyleIds)
  .order("style_number", { ascending: true })
  .order("display_order", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
-- Step 1: Get plan style IDs
SELECT id
FROM ops.tracking_plan_style
WHERE plan_id = $1;

-- Step 2: Get enriched timeline data
SELECT *
FROM ops.tracking_plan_style_timeline_detail
WHERE plan_style_id = ANY($1::uuid[])
ORDER BY style_number ASC, display_order ASC;
```

### 12. `getPlanStyleTimelines(planId: string)`
**Purpose**: Fetch timelines with joins (fallback for enriched query)  
**Parameters**: `planId` - UUID of the plan  
**Returns**: `Promise<any[]>`

**Query** (complex join):
```typescript
const selectQuery = `
  *,
  plan_style:tracking_plan_style!tracking_plan_style_timeline_plan_style_id_fkey(
    id, plan_id, style_id, style_header_id, color_id, style_number,
    style_name, color_name, season, delivery, factory,
    supplier_id, supplier_name, brand
  ),
  template_item:tracking_timeline_template_item!tracking_plan_style_timeline_template_item_id_fkey(
    id, name, short_name, phase, department, node_type, timeline_type,
    page_type, page_label, offset_relation, offset_unit, offset_value,
    depends_on_template_item_id, depends_on_action, required, notes,
    applies_to_style, applies_to_material, display_order
  )
`

await supabase
  .schema("ops")
  .from("tracking_plan_style_timeline")
  .select(selectQuery)
  .in("plan_style_id", planStyleIds)
  .order("plan_style.style_number", { ascending: true })
  .order("template_item.display_order", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT 
  t.*,
  ps.id as plan_style_id,
  ps.plan_id,
  ps.style_id,
  ps.style_header_id,
  ps.color_id,
  ps.style_number,
  ps.style_name,
  ps.color_name,
  ps.season,
  ps.delivery,
  ps.factory,
  ps.supplier_id,
  ps.supplier_name,
  ps.brand,
  ti.id as template_item_id,
  ti.name as template_item_name,
  ti.short_name,
  ti.phase,
  ti.department,
  ti.node_type,
  ti.timeline_type,
  ti.page_type,
  ti.page_label,
  ti.offset_relation,
  ti.offset_unit,
  ti.offset_value,
  ti.depends_on_template_item_id,
  ti.depends_on_action,
  ti.required,
  ti.notes,
  ti.applies_to_style,
  ti.applies_to_material,
  ti.display_order
FROM ops.tracking_plan_style_timeline t
JOIN ops.tracking_plan_style ps ON t.plan_style_id = ps.id
JOIN ops.tracking_timeline_template_item ti ON t.template_item_id = ti.id
WHERE t.plan_style_id = ANY($1::uuid[])
ORDER BY ps.style_number ASC, ti.display_order ASC;
```

### 13. `updateTemplate(templateId, updates)`
**Purpose**: Update a timeline template  
**Parameters**: 
- `templateId` - UUID of the template
- `updates` - Object with fields to update  
**Returns**: `Promise<void>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_template")
  .update(updates)
  .eq("id", templateId)
```

**PostgreSQL Equivalent**:
```sql
UPDATE ops.tracking_timeline_template
SET 
  name = COALESCE($2, name),
  is_active = COALESCE($3, is_active),
  brand = COALESCE($4, brand),
  season = COALESCE($5, season),
  timezone = COALESCE($6, timezone),
  anchor_strategy = COALESCE($7, anchor_strategy),
  conflict_policy = COALESCE($8, conflict_policy),
  updated_at = NOW()
WHERE id = $1;
```

### 14. `createTemplateItem(item)`
**Purpose**: Create a new template item (milestone)  
**Parameters**: `item` - Object with template item data  
**Returns**: `Promise<{ id: string }>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_template_item")
  .insert([item])
  .select()
```

**PostgreSQL Equivalent**:
```sql
INSERT INTO ops.tracking_timeline_template_item (
  template_id, name, short_name, phase, department, node_type,
  timeline_type, page_type, page_label, offset_relation, offset_unit,
  offset_value, depends_on_template_item_id, depends_on_action,
  display_order, applies_to_style, applies_to_material, required,
  supplier_visible, notes
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
RETURNING id;
```

### 15. `updateTemplateItem(itemId, updates)`
**Purpose**: Update a template item  
**Parameters**: 
- `itemId` - UUID of the template item
- `updates` - Object with fields to update  
**Returns**: `Promise<void>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_template_item")
  .update(updates)
  .eq("id", itemId)
```

**PostgreSQL Equivalent**:
```sql
UPDATE ops.tracking_timeline_template_item
SET 
  name = COALESCE($2, name),
  short_name = COALESCE($3, short_name),
  phase = COALESCE($4, phase),
  department = COALESCE($5, department),
  -- ... other fields ...
  updated_at = NOW()
WHERE id = $1;
```

### 16. `deleteTemplateItem(itemId)`
**Purpose**: Delete a template item  
**Parameters**: `itemId` - UUID of the template item  
**Returns**: `Promise<void>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_template_item")
  .delete()
  .eq("id", itemId)
```

**PostgreSQL Equivalent**:
```sql
DELETE FROM ops.tracking_timeline_template_item
WHERE id = $1;
```

### 17. `updatePlan(planId, updates)`
**Purpose**: Update a tracking plan  
**Parameters**: 
- `planId` - UUID of the plan
- `updates` - Object with fields to update  
**Returns**: `Promise<void>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_plan")
  .update(updates)
  .eq("id", planId)
```

**PostgreSQL Equivalent**:
```sql
UPDATE ops.tracking_plan
SET 
  name = COALESCE($2, name),
  season = COALESCE($3, season),
  start_date = COALESCE($4, start_date),
  end_date = COALESCE($5, end_date),
  active = COALESCE($6, active),
  template_id = COALESCE($7, template_id),
  updated_at = NOW()
WHERE id = $1;
```

### 18. `getTimelineAssignments(timelineIds)`
**Purpose**: Fetch user assignments for timeline milestones  
**Parameters**: `timelineIds` - Array of timeline UUIDs  
**Returns**: `Promise<Record<string, TimelineAssignment[]>>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_timeline_assignment")
  .select("*")
  .in("timeline_id", timelineIds)
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM ops.tracking_timeline_assignment
WHERE timeline_id = ANY($1::uuid[]);
```

**Response Structure**:
```typescript
{
  [timeline_id]: [
    {
      id: number,
      timeline_id: uuid,
      assignee_id: string,
      role_name: string,
      role_id: string,
      assigned_at: timestamp,
      source_user_id: string
    }
  ]
}
```

### 19. `getTestAllocations()`
**Purpose**: Fetch test allocation data (development/testing)  
**Returns**: `Promise<any[]>`

**Query**:
```typescript
await supabase
  .from("public.test_allocation")
  .select("*")
  .order("style_number", { ascending: true })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM public.test_allocation
ORDER BY style_number ASC;
```

### 20. `updateStyleMilestone(styleId, milestoneName, updates)`
**Purpose**: Update a specific milestone in a style's status_summary JSONB  
**Parameters**: 
- `styleId` - UUID of the plan style
- `milestoneName` - Name of the milestone to update
- `updates` - Partial milestone object with updates  
**Returns**: `Promise<void>`

**Query** (multi-step):
```typescript
// Step 1: Fetch current status_summary
await supabase
  .schema("ops")
  .from("tracking_plan_style")
  .select("status_summary")
  .eq("id", styleId)
  .single()

// Step 2: Update status_summary (JSONB manipulation in application)
await supabase
  .schema("ops")
  .from("tracking_plan_style")
  .update({
    status_summary: { ...statusSummary, milestones },
    updated_at: new Date().toISOString()
  })
  .eq("id", styleId)
```

**PostgreSQL Equivalent**:
```sql
-- Direct JSONB update (more efficient)
UPDATE ops.tracking_plan_style
SET 
  status_summary = jsonb_set(
    status_summary,
    '{milestones}',
    (
      SELECT jsonb_agg(
        CASE 
          WHEN milestone->>'name' = $2 
          THEN milestone || $3::jsonb
          ELSE milestone
        END
      )
      FROM jsonb_array_elements(status_summary->'milestones') AS milestone
    )
  ),
  updated_at = NOW()
WHERE id = $1;
```

### 21. `updateStyleMilestones(styleId, milestones)`
**Purpose**: Replace all milestones in a style's status_summary  
**Parameters**: 
- `styleId` - UUID of the plan style
- `milestones` - Array of milestone objects  
**Returns**: `Promise<void>`

**Query**:
```typescript
await supabase
  .schema("ops")
  .from("tracking_plan_style")
  .update({
    status_summary: { milestones },
    updated_at: new Date().toISOString()
  })
  .eq("id", styleId)
```

**PostgreSQL Equivalent**:
```sql
UPDATE ops.tracking_plan_style
SET 
  status_summary = jsonb_build_object('milestones', $2::jsonb),
  updated_at = NOW()
WHERE id = $1;
```

---

## Server Actions

### File: `/app/(portal)/tracking/actions.ts`
Uses: `@/lib/supabase/server` (server-side Supabase client)  
Schema: Default schema (tracking) - uses legacy table names

### 1. `getFoldersAction()`
**Purpose**: Server action to fetch folders  
**Returns**: `Promise<{ data: any[] | null, error: string | null }>`

**Query**:
```typescript
await supabase
  .from("brand_folders")
  .select("*")
  .order("name")
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM tracking.brand_folders
ORDER BY name;
```

### 2. `getFolderPlansAction(folderId)`
**Purpose**: Server action to fetch plans for a folder  
**Parameters**: `folderId` - UUID of the folder  
**Returns**: `Promise<{ data: any[] | null, error: string | null }>`

**Query**:
```typescript
await supabase
  .from("tracking_plans")
  .select("*")
  .eq("folder_id", folderId)
  .order("season", { ascending: false })
```

**PostgreSQL Equivalent**:
```sql
SELECT *
FROM tracking.tracking_plans
WHERE folder_id = $1
ORDER BY season DESC;
```

### 3. `createFolderAction(name, description?)`
**Purpose**: Server action to create a new folder  
**Parameters**: 
- `name` - Folder name
- `description` - Optional description  
**Returns**: `Promise<{ data: any | null, error: string | null }>`

**Query**:
```typescript
await supabase
  .from("brand_folders")
  .insert({ name, description })
  .select()
  .single()
```

**PostgreSQL Equivalent**:
```sql
INSERT INTO tracking.brand_folders (name, description)
VALUES ($1, $2)
RETURNING *;
```

---

## PostgreSQL Query Equivalents

### Complex Queries Used in Application

#### 1. Get All Folders with Plan Statistics
```sql
SELECT 
  f.id as folder_id,
  f.name as folder_name,
  f.brand,
  f.active,
  f.created_at,
  f.updated_at,
  COUNT(CASE WHEN p.active = true THEN 1 END) as active_plan_count,
  COUNT(p.id) as total_plan_count,
  MAX(p.updated_at) as latest_plan_date,
  STRING_AGG(DISTINCT p.season, ', ' ORDER BY p.season) as active_seasons
FROM ops.tracking_folder f
LEFT JOIN ops.tracking_plan p ON f.id = p.folder_id
WHERE f.active = true
GROUP BY f.id, f.name, f.brand, f.active, f.created_at, f.updated_at
ORDER BY f.name ASC;
```

#### 2. Get Plan with Full Details (Styles, Materials, Template)
```sql
SELECT 
  p.*,
  f.name as folder_name,
  f.brand as folder_brand,
  t.name as template_name,
  t.version as template_version,
  COUNT(DISTINCT ps.id) FILTER (WHERE ps.active = true) as active_style_count,
  COUNT(DISTINCT pm.id) as material_count,
  COUNT(DISTINCT pst.id) FILTER (WHERE pst.late = true) as late_milestone_count
FROM ops.tracking_plan p
LEFT JOIN ops.tracking_folder f ON p.folder_id = f.id
LEFT JOIN ops.tracking_timeline_template t ON p.template_id = t.id
LEFT JOIN ops.tracking_plan_style ps ON p.id = ps.plan_id
LEFT JOIN ops.tracking_plan_material pm ON p.id = pm.plan_id
LEFT JOIN ops.tracking_plan_style_timeline pst ON ps.id = pst.plan_style_id
WHERE p.id = $1
GROUP BY p.id, f.name, f.brand, t.name, t.version;
```

#### 3. Get Style Timeline Status Summary
```sql
SELECT 
  ps.id as plan_style_id,
  ps.style_number,
  ps.style_name,
  ps.color_name,
  ps.supplier_name,
  jsonb_agg(
    jsonb_build_object(
      'milestone_name', ti.name,
      'milestone_id', pst.id,
      'phase', ti.phase,
      'department', ti.department,
      'status', pst.status,
      'plan_date', pst.plan_date,
      'due_date', pst.due_date,
      'completed_date', pst.completed_date,
      'late', pst.late,
      'assigned_to', (
        SELECT jsonb_agg(assignee_id)
        FROM ops.tracking_timeline_assignment
        WHERE timeline_id = pst.id
      )
    ) ORDER BY ti.display_order
  ) as milestones
FROM ops.tracking_plan_style ps
JOIN ops.tracking_plan_style_timeline pst ON ps.id = pst.plan_style_id
JOIN ops.tracking_timeline_template_item ti ON pst.template_item_id = ti.id
WHERE ps.plan_id = $1 AND ps.active = true
GROUP BY ps.id, ps.style_number, ps.style_name, ps.color_name, ps.supplier_name
ORDER BY ps.style_number;
```

#### 4. Get Timeline Template with Dependencies
```sql
WITH RECURSIVE template_dependencies AS (
  -- Anchor nodes (no dependencies)
  SELECT 
    ti.id,
    ti.template_id,
    ti.name,
    ti.node_type,
    ti.phase,
    ti.display_order,
    ti.depends_on_template_item_id,
    ti.offset_value,
    ti.offset_unit,
    ti.offset_relation,
    0 as depth,
    ARRAY[ti.id] as path
  FROM ops.tracking_timeline_template_item ti
  WHERE ti.template_id = $1 
    AND ti.depends_on_template_item_id IS NULL
  
  UNION ALL
  
  -- Items that depend on previous items
  SELECT 
    ti.id,
    ti.template_id,
    ti.name,
    ti.node_type,
    ti.phase,
    ti.display_order,
    ti.depends_on_template_item_id,
    ti.offset_value,
    ti.offset_unit,
    ti.offset_relation,
    td.depth + 1,
    td.path || ti.id
  FROM ops.tracking_timeline_template_item ti
  JOIN template_dependencies td ON ti.depends_on_template_item_id = td.id
  WHERE ti.template_id = $1
    AND NOT ti.id = ANY(td.path) -- Prevent circular dependencies
)
SELECT 
  td.*,
  parent.name as depends_on_name
FROM template_dependencies td
LEFT JOIN ops.tracking_timeline_template_item parent 
  ON td.depends_on_template_item_id = parent.id
ORDER BY td.depth, td.display_order;
```

#### 5. Calculate Late Milestones by Phase
```sql
SELECT 
  ti.phase,
  ti.name as milestone_name,
  COUNT(*) as total_styles,
  COUNT(CASE WHEN pst.late = true AND pst.status != 'COMPLETE' THEN 1 END) as late_count,
  COUNT(CASE WHEN pst.status = 'COMPLETE' THEN 1 END) as completed_count,
  ROUND(
    100.0 * COUNT(CASE WHEN pst.status = 'COMPLETE' THEN 1 END) / COUNT(*), 
    2
  ) as completion_percentage
FROM ops.tracking_plan_style_timeline pst
JOIN ops.tracking_timeline_template_item ti ON pst.template_item_id = ti.id
JOIN ops.tracking_plan_style ps ON pst.plan_style_id = ps.id
WHERE ps.plan_id = $1 AND ps.active = true
GROUP BY ti.phase, ti.name, ti.display_order
ORDER BY ti.phase, ti.display_order;
```

---

## Database Relationships

### Entity Relationship Diagram (Text Format)

```
tracking_folder (1) ──< (N) tracking_plan
                                │
                                │ (1)
                                │
                                ├─< (N) tracking_plan_style
                                │        │
                                │        │ (1)
                                │        │
                                │        └─< (N) tracking_plan_style_timeline
                                │                 │
                                │                 │ (N)
                                │                 │
                                │                 └─> (1) tracking_timeline_template_item
                                │                        │
                                │                        │ (N)
                                │                        │
                                │                        └─< (1) tracking_timeline_template
                                │
                                ├─< (N) tracking_plan_material
                                │
                                └─> (1) tracking_timeline_template

tracking_plan_style_timeline (1) ──< (N) tracking_timeline_assignment
```

### Key Relationships

#### 1. Folder → Plan (One-to-Many)
```sql
tracking_folder.id (PK) = tracking_plan.folder_id (FK)
```
- Each folder can contain multiple plans
- Each plan belongs to one folder

#### 2. Plan → Template (Many-to-One)
```sql
tracking_plan.template_id (FK) = tracking_timeline_template.id (PK)
```
- Each plan uses one template
- Templates can be reused across multiple plans

#### 3. Template → Template Items (One-to-Many)
```sql
tracking_timeline_template.id (PK) = tracking_timeline_template_item.template_id (FK)
```
- Each template contains multiple milestones/tasks
- Each milestone belongs to one template

#### 4. Template Item → Template Item (Self-Referencing)
```sql
tracking_timeline_template_item.id (PK) = 
  tracking_timeline_template_item.depends_on_template_item_id (FK)
```
- Milestones can depend on other milestones
- Creates a dependency chain for timeline calculation
- **Example**: "Sample Approval" depends on "Sample Submission"

#### 5. Plan → Plan Style (One-to-Many)
```sql
tracking_plan.id (PK) = tracking_plan_style.plan_id (FK)
```
- Each plan contains multiple styles
- Each style belongs to one plan

#### 6. Plan Style → Plan Style Timeline (One-to-Many)
```sql
tracking_plan_style.id (PK) = tracking_plan_style_timeline.plan_style_id (FK)
```
- Each style has multiple timeline milestones
- Each timeline milestone belongs to one style

#### 7. Plan Style Timeline → Template Item (Many-to-One)
```sql
tracking_plan_style_timeline.template_item_id (FK) = 
  tracking_timeline_template_item.id (PK)
```
- Each timeline milestone is based on a template item
- Template items can be instantiated for multiple styles

#### 8. Plan Style Timeline → Timeline Assignment (One-to-Many)
```sql
tracking_plan_style_timeline.id (PK) = tracking_timeline_assignment.timeline_id (FK)
```
- Each timeline milestone can have multiple assignees
- Each assignment belongs to one timeline milestone

#### 9. Plan → Plan Material (One-to-Many)
```sql
tracking_plan.id (PK) = tracking_plan_material.plan_id (FK)
```
- Each plan can track multiple materials/components
- Each material belongs to one plan

### Join Examples

#### Get All Styles with Timeline Status for a Plan
```sql
SELECT 
  ps.style_number,
  ps.style_name,
  pst.status,
  pst.due_date,
  pst.late,
  ti.name as milestone_name,
  ti.phase
FROM tracking_plan_style ps
LEFT JOIN tracking_plan_style_timeline pst ON ps.id = pst.plan_style_id
LEFT JOIN tracking_timeline_template_item ti ON pst.template_item_id = ti.id
WHERE ps.plan_id = $1 AND ps.active = true
ORDER BY ps.style_number, ti.display_order;
```

#### Get Template with All Dependencies Resolved
```sql
SELECT 
  ti.id,
  ti.name,
  ti.phase,
  ti.offset_value,
  ti.offset_unit,
  ti.offset_relation,
  dep.name as depends_on_name,
  dep.phase as depends_on_phase
FROM tracking_timeline_template_item ti
LEFT JOIN tracking_timeline_template_item dep 
  ON ti.depends_on_template_item_id = dep.id
WHERE ti.template_id = $1
ORDER BY ti.display_order;
```

---

## Summary Tables

### Tables Used
| Table Name | Schema | Type | Primary Use |
|------------|--------|------|-------------|
| `tracking_folder` | ops | table | Store brand folders |
| `tracking_plan` | ops | table | Store tracking plans |
| `tracking_timeline_template` | ops | table | Store timeline templates |
| `tracking_timeline_template_item` | ops | table | Store template milestones |
| `tracking_plan_style` | ops | table | Link styles to plans |
| `tracking_plan_style_timeline` | ops | table | Track milestone progress per style |
| `tracking_timeline_assignment` | ops | table | Assign users to milestones |
| `tracking_plan_material` | ops | table | Link materials to plans |
| `tracking_folder_summary` | ops | view | Aggregated folder data |
| `tracking_plan_summary` | ops | view | Aggregated plan data |
| `tracking_timeline_template_detail` | ops | view | Aggregated template data |
| `brand_folders` | tracking | table | Legacy folder storage |
| `tracking_plans` | tracking | table | Legacy plan storage |

### API Functions Summary
| Function | File | Purpose | Tables Used |
|----------|------|---------|-------------|
| `getFolders()` | tracking-api.ts, tracking-api-client.ts | List all folders | tracking_folder_summary |
| `getFolderPlans()` | tracking-api.ts, tracking-api-client.ts | List plans in folder | tracking_plan_summary |
| `getPlanById()` | tracking-api.ts, tracking-api-client.ts | Get single plan | tracking_plan_summary |
| `getTemplates()` | tracking-api-client.ts | List all templates | tracking_timeline_template_detail |
| `getTemplateItems()` | tracking-api-client.ts | List template milestones | tracking_timeline_template_item |
| `getPlanStyles()` | tracking-api-client.ts | List styles in plan | tracking_plan_style(_summary) |
| `getPlanStyleTimelines()` | tracking-api-client.ts | Get style timelines | tracking_plan_style_timeline + joins |
| `getTimelineAssignments()` | tracking-api-client.ts | Get milestone assignees | tracking_timeline_assignment |
| `updateTemplate()` | tracking-api-client.ts | Update template | tracking_timeline_template |
| `updatePlan()` | tracking-api-client.ts | Update plan | tracking_plan |
| `createTemplateItem()` | tracking-api-client.ts | Create milestone | tracking_timeline_template_item |
| `updateTemplateItem()` | tracking-api-client.ts | Update milestone | tracking_timeline_template_item |
| `deleteTemplateItem()` | tracking-api-client.ts | Delete milestone | tracking_timeline_template_item |
| `updateStyleMilestone()` | tracking-api-client.ts | Update style milestone | tracking_plan_style (JSONB update) |

### Query Patterns
| Pattern | Count | Example |
|---------|-------|---------|
| Simple SELECT with filter | 8 | `select("*").eq("id", id)` |
| SELECT with ORDER BY | 12 | `select("*").order("name", { ascending: true })` |
| SELECT with JOIN (embedded) | 3 | `select("*, template_item:tracking_timeline_template_item!fkey()")` |
| SELECT with IN clause | 3 | `select("*").in("plan_style_id", ids)` |
| UPDATE with filter | 5 | `update(data).eq("id", id)` |
| INSERT with RETURNING | 2 | `insert([data]).select()` |
| DELETE with filter | 1 | `delete().eq("id", id)` |
| JSONB manipulation | 2 | Update `status_summary` field |

---

## Notes

### Schema Differences
- **Server-side API** (`tracking-api.ts`): Uses default schema `tracking`
- **Client-side API** (`tracking-api-client.ts`): Explicitly uses `ops` schema
- **Legacy tables**: `brand_folders` and `tracking_plans` in `tracking` schema
- **New tables**: All `tracking_*` tables in `ops` schema

### View Dependencies
Some views referenced in code may not be implemented yet:
- `tracking_plan_style_summary` - Has fallback to base table
- `tracking_plan_style_timeline_detail` - Has fallback to complex join

### JSONB Fields
Two tables use JSONB for flexible data:
1. `tracking_plan_style.status_summary` - Stores milestone progress
2. `tracking_plan_style.style_timeline` - Alternative timeline storage (test/development)

### Performance Considerations
- Views pre-aggregate data for faster queries
- Complex joins can be expensive for large datasets
- JSONB updates require fetch-modify-update pattern (could use direct JSONB operators)
- Consider indexing:
  - Foreign keys (folder_id, plan_id, template_id, etc.)
  - Frequently filtered fields (active, status, late)
  - JSONB paths if querying nested data

---

## Generated On
2025-01-08

## Version
1.0.0
