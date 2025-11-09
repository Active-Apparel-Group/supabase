# Testing Plan: PIM (Product Information Management)

Status: In Progress

## Overview
This testing plan validates the PIM schema and BeProduct integration for styles, colorways, size classes, and color palettes. All test SQL/scripts are centralized in the canonical location: `supabase/migrations/` (see [Migration and Function Index](../../../../../supabase/MIGRATION_FUNCTION_INDEX.md)).

**Test Approach:**
- Validate schema structure and constraints
- Test BeProduct webhook/Edge Function integration
- Verify data integrity and FK relationships
- Test CRUD operations via Supabase client

---

## 1. Schema Validation

### 1.1 Table Structure
**Objective:** Confirm all PIM tables match the documented schema.

**Reference:** [PIM Schema Documentation](../../../../schema/pim-schema.md)

**Tables to Validate:**
- `pim.style`
- `pim.style_colorway`
- `pim.style_size_class`
- `pim.color_folder`
- `pim.color_palette`
- `pim.color_palette_color`

**Validation Query:**
```sql
-- List all tables in pim schema
SELECT 
  schemaname,
  tablename,
  tableowner
FROM pg_tables
WHERE schemaname = 'pim'
ORDER BY tablename;
```

**Pass Criteria:** All 6 tables present with correct structure.

---

### 1.2 Foreign Key Relationships
**Objective:** Validate all FK constraints are in place.

**Validation Query:**
```sql
-- List all FK constraints in pim schema
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'pim'
ORDER BY tc.table_name;
```

**Expected FK Relationships:**
- `style_colorway.style_id` → `style.id`
- `style_size_class.style_id` → `style.id`
- `color_palette.folder_id` → `color_folder.id`
- `color_palette_color.palette_id` → `color_palette.id`

**Pass Criteria:** All 4 FK constraints present and correct.

---

### 1.3 Unique Constraints
**Objective:** Validate BeProduct ID columns are unique where expected.

**Validation Query:**
```sql
-- Check unique constraints on BeProduct ID columns
SELECT
  conname AS constraint_name,
  conrelid::regclass AS table_name,
  a.attname AS column_name
FROM pg_constraint c
JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
WHERE c.contype = 'u'
  AND connamespace = 'pim'::regnamespace
ORDER BY table_name, column_name;
```

**Expected Unique Constraints:**
- `style.beproduct_style_id`
- `color_folder.beproduct_folder_id`
- `color_palette.beproduct_palette_id`

**Pass Criteria:** All 3 unique constraints present.

---

## 2. Reference Data Validation

### 2.1 Test Style and Colorways
**Objective:** Validate that test style "MONTAUK SHORT - 8\" INSEAM (testing)" exists with all 3 colorways.

**Validation Query:**
```sql
SELECT 
  s.id AS style_id,
  s.beproduct_style_id,
  s.header_number,
  s.header_name,
  s.brand,
  s.season,
  s.year,
  COUNT(sc.id) AS colorway_count
FROM pim.style s
LEFT JOIN pim.style_colorway sc ON s.id = sc.style_id
WHERE s.header_number = 'MSP26B26'
GROUP BY s.id, s.beproduct_style_id, s.header_number, s.header_name, s.brand, s.season, s.year;
```

**Expected Result:**
- Style: MSP26B26, "MONTAUK SHORT - 8\" INSEAM (testing)"
- Brand: GREYSON, Season: Spring 1, Year: 2026
- Colorway Count: 3

**Pass Criteria:** 1 style with 3 colorways.

---

### 2.2 Colorway Details
**Objective:** Validate all 3 colorways with correct BeProduct IDs and color data.

**Validation Query:**
```sql
SELECT 
  sc.id AS colorway_id,
  sc.beproduct_colorway_id,
  sc.color_name,
  sc.color_number,
  sc.primary_hex,
  s.header_number AS style
FROM pim.style_colorway sc
JOIN pim.style s ON sc.style_id = s.id
WHERE s.header_number = 'MSP26B26'
ORDER BY sc.color_name;
```

**Expected Colorways:**
1. 220 - GROVE (19-4038 TCX, #133951)
2. 359 - PINK SKY (13-3207 TCX, #f7cfe1)
3. 947 - ZION (19-2620 TCX, #47253c)

**Pass Criteria:** All 3 colorways present with correct data.

---

### 2.3 Color Palette Validation
**Objective:** Validate "GREYSON MENS 2026 SPRING" palette with 6 colors.

**Validation Query:**
```sql
SELECT 
  cp.id AS palette_id,
  cp.beproduct_palette_id,
  cp.palette_name,
  cf.name AS folder_name,
  COUNT(cpc.id) AS color_count
FROM pim.color_palette cp
JOIN pim.color_folder cf ON cp.folder_id = cf.id
LEFT JOIN pim.color_palette_color cpc ON cp.id = cpc.palette_id
WHERE cp.palette_name = 'GREYSON MENS 2026 SPRING'
GROUP BY cp.id, cp.beproduct_palette_id, cp.palette_name, cf.name;
```

**Expected Result:**
- Palette: "GREYSON MENS 2026 SPRING"
- Folder: "GREYSON MENS"
- Color Count: 6

**Pass Criteria:** 1 palette with 6 colors.

---

### 2.4 BeProduct ID Coverage
**Objective:** Validate all records have BeProduct IDs populated.

**Validation Query:**
```sql
SELECT 
  'style' AS table_name,
  COUNT(*) AS total_rows,
  COUNT(beproduct_style_id) AS with_beproduct_id,
  COUNT(*) - COUNT(beproduct_style_id) AS missing_beproduct_id
FROM pim.style

UNION ALL

SELECT 
  'style_colorway',
  COUNT(*),
  COUNT(beproduct_colorway_id),
  COUNT(*) - COUNT(beproduct_colorway_id)
FROM pim.style_colorway

UNION ALL

SELECT 
  'style_size_class',
  COUNT(*),
  COUNT(beproduct_size_class_id),
  COUNT(*) - COUNT(beproduct_size_class_id)
FROM pim.style_size_class

UNION ALL

SELECT 
  'color_folder',
  COUNT(*),
  COUNT(beproduct_folder_id),
  COUNT(*) - COUNT(beproduct_folder_id)
FROM pim.color_folder

UNION ALL

SELECT 
  'color_palette',
  COUNT(*),
  COUNT(beproduct_palette_id),
  COUNT(*) - COUNT(beproduct_palette_id)
FROM pim.color_palette

UNION ALL

SELECT 
  'color_palette_color',
  COUNT(*),
  COUNT(beproduct_color_id),
  COUNT(*) - COUNT(beproduct_color_id)
FROM pim.color_palette_color;
```

**Pass Criteria:** `missing_beproduct_id = 0` for all tables.

---

## 3. BeProduct Integration Testing

### 3.1 Edge Function Deployment
**Objective:** Confirm BeProduct webhook Edge Function is deployed and accessible.

**Reference:** [Edge Function: beproduct-webhook](../../../../../supabase/functions/beproduct-webhook/index.ts)

**Manual Test:**
- Deploy function: `supabase functions deploy beproduct-webhook`
- Verify function appears in Supabase dashboard
- Test with sample webhook payload

**Pass Criteria:** Function deployed, returns 200 OK for valid payloads.

---

### 3.2 Style Upsert Test
**Objective:** Validate that style upserts correctly handle new and existing styles.

**Test Case 1: New Style**
- Send webhook payload with new style (new `beproduct_style_id`)
- Verify style inserted into `pim.style`
- Verify all header fields populated correctly

**Test Case 2: Existing Style Update**
- Send webhook payload with existing `beproduct_style_id`
- Verify style updated (not duplicated)
- Verify `updated_at` timestamp updated

**Pass Criteria:** Both insert and update work correctly, no duplicates.

---

### 3.3 Colorway Upsert Test
**Objective:** Validate that colorway upserts handle new and existing colorways, and link to correct style.

**Test Case 1: New Colorway**
- Send webhook payload with new colorway for existing style
- Verify colorway inserted into `pim.style_colorway`
- Verify `style_id` FK points to correct style (internal UUID)

**Test Case 2: Existing Colorway Update**
- Send webhook payload with existing `beproduct_colorway_id`
- Verify colorway updated (not duplicated)

**Pass Criteria:** Colorways correctly linked to styles, no FK violations.

---

### 3.4 Deletion Handling
**Objective:** Validate soft delete logic for styles and colorways.

**Test Case:**
- Send webhook payload with `isDeleted: true`
- Verify `deleted = true` in Supabase
- Verify related colorways also marked as deleted

**Pass Criteria:** Soft deletes work, related records updated.

---

## 4. CRUD Operations via Supabase Client

### 4.1 Query All Styles
**Objective:** Test Supabase client query for all styles.

**Query:**
```typescript
const { data, error } = await supabase
  .from('style')
  .select('*')
  .eq('deleted', false);
```

**Pass Criteria:** Returns all non-deleted styles.

---

### 4.2 Query Style with Colorways
**Objective:** Test join query for style with related colorways.

**Query:**
```typescript
const { data, error } = await supabase
  .from('style')
  .select(`
    *,
    style_colorway (*)
  `)
  .eq('header_number', 'MSP26B26')
  .single();
```

**Pass Criteria:** Returns style with nested colorways array.

---

### 4.3 Query Color Palette with Colors
**Objective:** Test join query for palette with related colors.

**Query:**
```typescript
const { data, error } = await supabase
  .from('color_palette')
  .select(`
    *,
    color_palette_color (*)
  `)
  .eq('palette_name', 'GREYSON MENS 2026 SPRING')
  .single();
```

**Pass Criteria:** Returns palette with nested colors array.

---

## 5. Performance & Index Testing

### 5.1 Query Performance
**Objective:** Validate queries execute efficiently with proper indexes.

**Test Queries:**
```sql
-- Query by beproduct_style_id (should use unique index)
EXPLAIN ANALYZE
SELECT * FROM pim.style WHERE beproduct_style_id = 'db0c4180-3922-4122-b7e9-4fb88958beab';

-- Query colorways by style_id (should use FK index)
EXPLAIN ANALYZE
SELECT * FROM pim.style_colorway WHERE style_id = '6a5af076-c9bd-4f7e-8ca4-bdf21621b67f';
```

**Pass Criteria:** Queries use indexes, execution time < 10ms.

---

## 6. Next Steps

- [ ] Execute all validation queries and record results
- [ ] Deploy and test BeProduct webhook Edge Function
- [ ] Run CRUD operation tests via Supabase client
- [ ] Document any issues or failures
- [ ] Update this plan with test results and outcomes
- [ ] Present findings for review

---

*This document is a living artifact. Update after each test cycle with results and lessons learned.*
