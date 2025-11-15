# RLS Implementation Deployment Checklist

## Pre-Deployment

### 1. Backup Current Database
```bash
# Create backup before running migrations
npx supabase db dump -f backup-before-rls-$(date +%Y%m%d).sql

# Or use Supabase dashboard backup feature
```

### 2. Review Migration Files
- [ ] Read through all 4 migration files (014-017)
- [ ] Understand what each migration does
- [ ] Note any dependencies on existing tables
- [ ] Check for naming conflicts

### 3. Check Existing Schema
```sql
-- Check if MDM schema already exists
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name = 'mdm';

-- Check if ops schema exists
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name = 'ops';

-- Check if tracking schema exists
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name = 'tracking';

-- Check if user_profile table exists
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name = 'user_profile';
```

---

## Deployment Steps

### Step 1: Apply Migrations

#### Option A: Using Supabase CLI (Recommended)
```bash
# Ensure you're in the project directory
cd /path/to/supabase

# Check migration status
npx supabase migration list

# Apply migrations
npx supabase db push

# Verify migrations applied
npx supabase migration list
```

#### Option B: Manual SQL Execution
```sql
-- Run each migration in order
-- Migration 014
\i supabase/migrations/014_create_mdm_schema.sql

-- Migration 015
\i supabase/migrations/015_create_user_management_tables.sql

-- Migration 016
\i supabase/migrations/016_create_factory_tracking_access.sql

-- Migration 017
\i supabase/migrations/017_apply_rls_policies.sql
```

### Step 2: Verify Migration Success

```sql
-- Check schemas created
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name IN ('mdm', 'ops');

-- Check MDM tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'mdm'
ORDER BY table_name;
-- Expected: brand, brand_contact, company, factory

-- Check public tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_profile', 'user_brand_access');

-- Check ops tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'ops'
AND table_name LIKE '%factory%'
ORDER BY table_name;
-- Expected: factory_tracking_folder_access, factory_tracking_plan_access, style_factory_allocation

-- Check RLS enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname IN ('mdm', 'public', 'pim', 'tracking', 'ops')
AND rowsecurity = true
ORDER BY schemaname, tablename;
```

### Step 3: Load Test Data (Development/Staging Only)

```bash
# Load seed data
psql -h your-host -U postgres -d postgres -f supabase/seed_rls_test_data.sql

# Or using Supabase CLI
npx supabase db execute -f supabase/seed_rls_test_data.sql
```

### Step 4: Verify Test Data

```sql
-- Count records in each table
SELECT 
  'Companies' as table_name, COUNT(*) as count FROM mdm.company
UNION ALL
SELECT 'Factories', COUNT(*) FROM mdm.factory
UNION ALL
SELECT 'Brands', COUNT(*) FROM mdm.brand
UNION ALL
SELECT 'User Profiles', COUNT(*) FROM public.user_profile
UNION ALL
SELECT 'Styles', COUNT(*) FROM pim.style
UNION ALL
SELECT 'Factory Allocations', COUNT(*) FROM ops.style_factory_allocation;
```

---

## Testing

### Test 1: Helper Functions

```sql
-- Test get_accessible_brands (should work)
SELECT * FROM public.get_accessible_brands('40000000-0000-0000-0000-000000000004');

-- Test get_accessible_brand_codes
SELECT * FROM public.get_accessible_brand_codes('40000000-0000-0000-0000-000000000004');

-- Test can_access_brand
SELECT public.can_access_brand('NIKE_SPORT', '40000000-0000-0000-0000-000000000004');

-- Test factory functions
SELECT * FROM public.get_factory_accessible_plans('40000000-0000-0000-0000-000000000008');
SELECT * FROM public.get_factory_accessible_folders('40000000-0000-0000-0000-000000000008');
```

### Test 2: RLS Policies (Internal User)

```sql
-- Set as internal user
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claim.sub = '40000000-0000-0000-0000-000000000001';

-- Should see all styles
SELECT COUNT(*) as total_styles FROM pim.style;
-- Expected: 8 (if using seed data)

-- Should see all plans
SELECT COUNT(*) as total_plans FROM tracking.plans;

-- Reset
RESET role;
```

### Test 3: RLS Policies (Customer User - Nike)

```sql
-- Set as Nike customer user
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claim.sub = '40000000-0000-0000-0000-000000000004';

-- Should see only Nike styles
SELECT brand, COUNT(*) as count 
FROM pim.style 
GROUP BY brand;
-- Expected: Only NIKE_SPORT, NIKE_CASUAL, JORDAN brands

-- Check accessible brands
SELECT * FROM public.get_accessible_brands();
-- Expected: 3 Nike brands

-- Reset
RESET role;
```

### Test 4: RLS Policies (Factory User)

```sql
-- Set as factory user
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claim.sub = '40000000-0000-0000-0000-000000000008';

-- Should see only allocated styles
SELECT COUNT(*) as allocated_styles 
FROM tracking.plan_styles;
-- Expected: 1 (China_01 allocated to Nike Air Max)

-- Check accessible plans
SELECT * FROM public.get_factory_accessible_plans();
-- Expected: 1 plan

-- Reset
RESET role;
```

### Test 5: Factory Allocation Trigger

```sql
-- Create a new allocation
INSERT INTO ops.style_factory_allocation (
  tracking_plan_id,
  plan_style_id,
  factory_id,
  brand,
  allocated_quantity,
  active
) VALUES (
  '70000000-0000-0000-0000-000000000004',
  '80000000-0000-0000-0000-000000000004',
  '20000000-0000-0000-0000-000000000004',
  'AAG_CORE',
  1000,
  true
);

-- Verify plan access was auto-created
SELECT * FROM ops.factory_tracking_plan_access
WHERE factory_id = '20000000-0000-0000-0000-000000000004'
AND tracking_plan_id = '70000000-0000-0000-0000-000000000004';
-- Expected: 1 row with active = true

-- Verify folder access was auto-created
SELECT * FROM ops.factory_tracking_folder_access
WHERE factory_id = '20000000-0000-0000-0000-000000000004';
-- Expected: 1 row with active = true
```

---

## Post-Deployment

### 1. Monitor Errors

```sql
-- Check for RLS policy violations (if logging enabled)
-- This would be in your application logs

-- Check for trigger errors
SELECT * FROM pg_stat_user_functions
WHERE schemaname IN ('ops', 'public', 'mdm')
ORDER BY calls DESC;
```

### 2. Performance Check

```sql
-- Check slow queries
SELECT 
  query,
  calls,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
WHERE query LIKE '%pim.style%' OR query LIKE '%tracking.plan%'
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Add missing indexes if needed
-- Example:
-- CREATE INDEX IF NOT EXISTS idx_style_brand ON pim.style(brand) WHERE deleted = false;
```

### 3. Create Additional Indexes (If Needed)

```sql
-- Recommended indexes for performance
CREATE INDEX IF NOT EXISTS idx_style_brand ON pim.style(brand) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_plan_brand ON tracking.plans(brand) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_plan_styles_brand ON tracking.plan_styles(brand);
```

---

## Data Migration (If Existing Data)

### Migrate from public.directory to mdm.factory

```sql
-- Check if public.directory exists
SELECT * FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name = 'directory';

-- If exists, migrate data
INSERT INTO mdm.factory (code, name, factory_type, active)
SELECT 
  code,
  name,
  'manufacturing'::mdm.factory_type_enum,
  active
FROM public.directory
WHERE type = 'factory'
ON CONFLICT (code) DO NOTHING;

-- Verify
SELECT COUNT(*) FROM mdm.factory;
```

### Migrate from public.company to mdm.company

```sql
-- Check if public.company exists
SELECT * FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name = 'company';

-- If exists, migrate data
INSERT INTO mdm.company (code, name, company_type, active)
SELECT 
  code,
  name,
  CASE 
    WHEN type = 'customer' THEN 'customer'::mdm.company_type_enum
    WHEN type = 'supplier' THEN 'supplier'::mdm.company_type_enum
    ELSE 'partner'::mdm.company_type_enum
  END,
  active
FROM public.company
ON CONFLICT (code) DO NOTHING;

-- Verify
SELECT COUNT(*) FROM mdm.company;
```

### Create Brands from Existing Data

```sql
-- Extract unique brands from pim.style
INSERT INTO mdm.brand (code, name, owner_company_id, active)
SELECT DISTINCT
  brand as code,
  brand as name,
  (SELECT id FROM mdm.company WHERE is_internal = true LIMIT 1) as owner_company_id,
  true as active
FROM pim.style
WHERE brand IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM mdm.brand WHERE code = pim.style.brand)
ON CONFLICT (code) DO NOTHING;

-- Manually assign correct owners
UPDATE mdm.brand 
SET owner_company_id = (SELECT id FROM mdm.company WHERE code = 'NIKE')
WHERE code LIKE 'NIKE%';

UPDATE mdm.brand 
SET owner_company_id = (SELECT id FROM mdm.company WHERE code = 'ADIDAS')
WHERE code LIKE 'ADIDAS%';

-- Verify
SELECT b.code, b.name, c.name as owner
FROM mdm.brand b
JOIN mdm.company c ON c.id = b.owner_company_id;
```

---

## Integration with Frontend

### 1. Update Environment Variables

```bash
# .env.local
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key # Backend only!
```

### 2. Update Supabase Client

No changes needed! RLS is transparent to the client.

```typescript
// This already works with RLS
const { data: styles } = await supabase
  .from('style')
  .select('*');
// Automatically filtered based on authenticated user
```

### 3. Add User Profile Management

```typescript
// Add to your auth flow
const { data: { user } } = await supabase.auth.getUser();

// Get user profile
const { data: profile } = await supabase
  .from('user_profile')
  .select('*, company:company_id(*), factory:factory_id(*)')
  .eq('id', user.id)
  .single();
```

---

## Rollback Plan

### If Issues Arise

```sql
-- Drop RLS policies (keeps data)
DROP POLICY IF EXISTS "Internal users can view all styles" ON pim.style;
DROP POLICY IF EXISTS "Customer users can view styles for their brands" ON pim.style;
-- ... (drop all policies)

-- Or disable RLS temporarily
ALTER TABLE pim.style DISABLE ROW LEVEL SECURITY;
ALTER TABLE tracking.plans DISABLE ROW LEVEL SECURITY;
-- ... (disable on all tables)

-- Full rollback (removes all RLS tables)
DROP SCHEMA mdm CASCADE;
DROP TABLE public.user_profile CASCADE;
DROP TABLE public.user_brand_access CASCADE;
DROP SCHEMA ops CASCADE; -- Only if ops didn't exist before
```

### Restore from Backup

```bash
# Restore from backup
psql -h your-host -U postgres -d postgres < backup-before-rls-20251115.sql
```

---

## Success Criteria

- [ ] All 4 migrations applied successfully
- [ ] All tables created in correct schemas
- [ ] RLS enabled on all required tables
- [ ] Helper functions working correctly
- [ ] Test data loaded (dev/staging)
- [ ] All test queries passing
- [ ] Triggers firing correctly on allocations
- [ ] No errors in application logs
- [ ] Performance acceptable (queries < 2s)
- [ ] Frontend integration working
- [ ] Documentation accessible to team

---

## Support Contacts

- **Database Team**: [contact info]
- **Backend Team**: [contact info]
- **Frontend Team**: [contact info]

---

## Additional Resources

- [RLS Implementation Guide](./RLS-IMPLEMENTATION-GUIDE.md)
- [RLS Quick Reference](./RLS-QUICK-REFERENCE.md)
- [RLS Visual Overview](./RLS-VISUAL-OVERVIEW.md)
- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)

---

*Deployment Date: ________________*
*Deployed By: ________________*
*Status: ________________*
