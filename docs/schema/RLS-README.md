# RLS Schema Documentation Index

## Overview

This directory contains comprehensive documentation for the Row-Level Security (RLS) implementation in the Supabase PLM backend.

## Documents

### 1. [RLS Implementation Guide](./RLS-IMPLEMENTATION-GUIDE.md)
**Audience**: Database Administrators, Backend Developers, Architects

**Contents**:
- Complete architecture overview
- Entity Relationship Diagrams (ERD)
- Access control patterns (customer, factory, internal)
- Implementation details and migration files
- Helper functions reference
- Testing guide
- Security considerations

**Use this when**:
- Setting up RLS for the first time
- Understanding the overall architecture
- Troubleshooting access control issues
- Training new team members

### 2. [RLS Quick Reference](./RLS-QUICK-REFERENCE.md)
**Audience**: Frontend Developers, Application Developers

**Contents**:
- Code examples for common patterns
- React hooks for RLS
- Page-level filtering examples
- Real-time subscriptions with RLS
- Best practices
- Debugging tips

**Use this when**:
- Building frontend applications
- Implementing data filtering in UI
- Creating user-type-specific views
- Quick code snippets needed

## Migration Files

The RLS implementation consists of 4 migration files:

1. **`014_create_mdm_schema.sql`**
   - Creates MDM (Master Data Management) schema
   - Defines company, factory, and brand tables
   - Establishes ownership relationships

2. **`015_create_user_management_tables.sql`**
   - Creates user_profile table (extends auth.users)
   - Links users to companies/factories
   - Implements user brand access grants
   - Defines helper functions for access control

3. **`016_create_factory_tracking_access.sql`**
   - Creates factory allocation tables
   - Implements auto-grant triggers on allocation
   - Defines factory access helper functions

4. **`017_apply_rls_policies.sql`**
   - Applies RLS policies to PIM tables
   - Applies RLS policies to tracking tables
   - Implements brand-based filtering
   - Implements factory-based filtering

## Seed Data

**File**: `seed_rls_test_data.sql`

Contains sample data for testing:
- Test companies (Nike, Adidas, Puma, AAG)
- Test factories
- Test brands
- Test user profiles (internal, customer, factory)
- Test styles
- Test tracking plans and allocations

## Key Concepts

### User Types
- **Internal**: AAG staff, full access to all data
- **Customer**: Brand owners, access data by brand ownership
- **Factory**: Suppliers, access data by allocation

### Access Patterns
1. **Customer Access**: Via brand ownership (company → brands → data)
2. **Factory Access**: Via allocations (allocation → plan/folder access)
3. **Internal Access**: Full access to all data

### Automatic Access Management
- Factory allocation triggers auto-grant access to plans/folders
- De-allocation triggers auto-revoke access (if no other allocations)
- Access tracked with audit trails

## ERD Diagrams

All diagrams are in Mermaid format and included in the Implementation Guide:

1. User and Company Relationships
2. PIM Schema with Brand Access
3. Factory Access to Tracking Data
4. Complete Access Control Flow

## Quick Start

### For Developers
1. Read [RLS Quick Reference](./RLS-QUICK-REFERENCE.md)
2. Use code examples for your use case
3. Test with seed data

### For Database Admins
1. Read [RLS Implementation Guide](./RLS-IMPLEMENTATION-GUIDE.md)
2. Run migrations 014-017
3. Load seed data for testing
4. Verify policies with test queries

### For Project Managers
1. Review architecture diagrams in Implementation Guide
2. Understand user types and access patterns
3. Review security considerations

## Testing

### Sample Test Queries

```sql
-- Test as internal user (sees all)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claim.sub = '40000000-0000-0000-0000-000000000001';
SELECT COUNT(*) FROM pim.style; -- Should see all

-- Test as customer user (sees only Nike)
SET LOCAL request.jwt.claim.sub = '40000000-0000-0000-0000-000000000004';
SELECT COUNT(*) FROM pim.style; -- Should see only Nike brands

-- Test as factory user (sees only allocated)
SET LOCAL request.jwt.claim.sub = '40000000-0000-0000-0000-000000000008';
SELECT COUNT(*) FROM tracking.plan_styles; -- Should see only allocated styles
```

## Helper Functions

### For Brand Access
- `public.get_accessible_brands(p_user_id)` - Returns brands with details
- `public.get_accessible_brand_codes(p_user_id)` - Returns array of brand codes
- `public.can_access_brand(p_brand_code, p_user_id)` - Boolean check

### For Factory Access
- `public.get_factory_accessible_plans(p_user_id)` - Returns accessible plans
- `public.get_factory_accessible_folders(p_user_id)` - Returns accessible folders

## Related Documentation

- [PIM Schema](./pim-schema.md) - Product Information Management schema
- [OPS Schema](./ops-schema.md) - Operations and tracking schema
- [DBA Onboarding](../dba-docs/DBA-ONBOARDING.md) - Database administrator guide
- [Question 1: RLS Security Challenge](../dba-docs/Question-1-RLS-Security-Challenge.md) - RLS design challenge

## Support

For questions or issues:
1. Check [RLS Quick Reference](./RLS-QUICK-REFERENCE.md) debugging section
2. Review [RLS Implementation Guide](./RLS-IMPLEMENTATION-GUIDE.md) troubleshooting section
3. Contact database team

---

*Last Updated: 2025-11-15*
*Version: 1.0*
