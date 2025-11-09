# Tracking & Timeline Documentation Index

This directory contains comprehensive documentation for the Supabase queries, functions, and database schema used in the tracking and timeline sections of the AAG Customer Portal.

## Documentation Files

### 📘 [TRACKING_SUPABASE_DOCUMENTATION.md](./TRACKING_SUPABASE_DOCUMENTATION.md)
**Main comprehensive documentation** (1,521 lines)

Complete reference for all Supabase operations in the tracking/timeline system:
- **Database Tables & Views**: Detailed descriptions of all 8 base tables and 3 views
- **Server-Side API Functions**: 3 functions from `lib/tracking-api.ts`
- **Client-Side API Functions**: 21 functions from `lib/tracking-api-client.ts`
- **Server Actions**: 3 Next.js server actions from `app/(portal)/tracking/actions.ts`
- **PostgreSQL Query Equivalents**: Direct SQL translations of every Supabase query
- **Database Relationships**: Complete relationship mapping with foreign keys
- **Complex Queries**: Real-world query examples with joins and aggregations
- **JSONB Usage**: Patterns for working with flexible JSON data

**Best for**: Deep dive into specific functions, understanding query patterns, PostgreSQL equivalents

---

### 🔍 [TRACKING_QUICK_REFERENCE.md](./TRACKING_QUICK_REFERENCE.md)
**Quick reference guide** (469 lines)

Fast lookup for common operations and patterns:
- **Tables at a Glance**: Quick reference table with relationships
- **Common Queries**: Top 10 most-used SQL queries with examples
- **API Endpoints**: Summary table of all read/write operations
- **Data Flow Diagrams**: Visual flow from folder → plan → style → timeline
- **Field Reference**: Enumerated values and constants
- **Performance Tips**: Indexing recommendations and optimization patterns
- **Common Patterns**: Code snippets for frequent operations
- **Troubleshooting**: Quick fixes for common issues

**Best for**: Quick lookups, common patterns, troubleshooting, new developers

---

### 🗂️ [TRACKING_DATABASE_SCHEMA.md](./TRACKING_DATABASE_SCHEMA.md)
**Database schema documentation** (777 lines)

Visual and structural documentation of the database:
- **Visual Schema Diagram**: ASCII art ER diagram showing all relationships
- **Detailed Table Schemas**: Complete CREATE TABLE statements with constraints
- **View Definitions**: CREATE VIEW statements for all aggregate views
- **Relationship Summary**: Tables showing foreign key relationships
- **Data Integrity Rules**: Business rules and constraints
- **Triggers**: Recommended trigger implementations
- **Migration Order**: Proper sequence for creating tables
- **Sample Data Flow**: Complete example of creating a plan with styles
- **Performance Monitoring**: Useful queries for monitoring and analytics

**Best for**: Database administrators, schema understanding, migrations, data modeling

---

## Quick Start

### For Developers
1. Start with [TRACKING_QUICK_REFERENCE.md](./TRACKING_QUICK_REFERENCE.md) for common patterns
2. Reference [TRACKING_SUPABASE_DOCUMENTATION.md](./TRACKING_SUPABASE_DOCUMENTATION.md) for specific functions
3. Use [TRACKING_DATABASE_SCHEMA.md](./TRACKING_DATABASE_SCHEMA.md) when working with database structure

### For Database Administrators
1. Start with [TRACKING_DATABASE_SCHEMA.md](./TRACKING_DATABASE_SCHEMA.md) for schema overview
2. Reference [TRACKING_SUPABASE_DOCUMENTATION.md](./TRACKING_SUPABASE_DOCUMENTATION.md) for query patterns
3. Use performance tips from [TRACKING_QUICK_REFERENCE.md](./TRACKING_QUICK_REFERENCE.md)

### For New Team Members
1. Read the overview in [TRACKING_SUPABASE_DOCUMENTATION.md](./TRACKING_SUPABASE_DOCUMENTATION.md)
2. Study the visual diagram in [TRACKING_DATABASE_SCHEMA.md](./TRACKING_DATABASE_SCHEMA.md)
3. Practice with examples from [TRACKING_QUICK_REFERENCE.md](./TRACKING_QUICK_REFERENCE.md)

---

## System Overview

### What is the Tracking System?

The tracking system manages production timelines for apparel products. It allows users to:
- Organize products into **folders** by brand
- Create **plans** for different seasons/drops
- Apply reusable **timeline templates** with milestones
- Track **styles** and **materials** through production phases
- Assign team members to specific milestones
- Monitor late items and progress

### Key Concepts

#### 1. Folders
- Organizational containers for plans
- Typically one per brand
- Example: "GREYSON MENS", "VUORI WOMENS"

#### 2. Plans
- Represents a season, drop, or collection
- Contains multiple styles and materials
- Uses a timeline template for milestone structure
- Example: "GREYSON 2026 SPRING DROP 1"

#### 3. Timeline Templates
- Reusable milestone structures
- Contains ordered milestones with dependencies
- Can be versioned and shared across brands
- Example: "GREYSON MASTER 2026" with 20 milestones

#### 4. Template Items (Milestones)
- Individual checkpoints in production
- Can depend on other milestones
- Have offsets (e.g., "7 days after Sample Submission")
- Types: ANCHOR, TASK, MILESTONE, PHASE
- Example: "Sample Approval" depends on "Sample Submission" + 7 days

#### 5. Styles
- Individual products being tracked
- Each style goes through all applicable milestones
- Progress tracked in timeline instances
- Example: "GRY-001 Polo Shirt - Navy"

#### 6. Timeline Instances
- Actual milestone progress for each style
- Tracks dates: plan, due, completed
- Tracks status: NOT_STARTED, IN_PROGRESS, COMPLETE, etc.
- Calculates if milestone is late

#### 7. Assignments
- Team members assigned to milestones
- One milestone can have multiple assignees
- Tracks who's responsible for what

---

## Architecture

### Schema Organization

```
ops schema (current/active)
├── tracking_folder
├── tracking_plan
├── tracking_timeline_template
├── tracking_timeline_template_item
├── tracking_plan_style
├── tracking_plan_style_timeline
├── tracking_timeline_assignment
└── tracking_plan_material

tracking schema (legacy)
├── brand_folders
└── tracking_plans
```

### API Structure

```
Server-Side API (/lib/tracking-api.ts)
└── Uses default 'tracking' schema
└── Used for server-side rendering

Client-Side API (/lib/tracking-api-client.ts)
└── Uses 'ops' schema explicitly
└── Used for client-side data fetching

Server Actions (/app/(portal)/tracking/actions.ts)
└── Uses default 'tracking' schema
└── Used for form submissions and mutations
```

### Data Flow

```
User Interface
    ↓
Client-Side API Functions
    ↓
Supabase Client
    ↓
Database Views (for reads)
    OR
Base Tables (for writes)
    ↓
PostgreSQL Database
```

---

## Key Statistics

### Coverage
- **8 base tables** documented
- **3 aggregate views** documented
- **21 client-side functions** with PostgreSQL equivalents
- **3 server-side functions** with PostgreSQL equivalents
- **3 server actions** with PostgreSQL equivalents
- **27 total API functions** fully documented

### Relationships
- **6 one-to-many** relationships
- **2 many-to-one** relationships
- **1 self-referencing** relationship (template item dependencies)

### Data Types
- **2 JSONB fields** for flexible data (status_summary, style_timeline)
- **17 foreign keys** maintaining referential integrity
- **5 check constraints** for enumerated values

---

## Important Notes

### Schema Differences
⚠️ The codebase uses **two different schemas**:
- `ops` schema: Current/active schema for most operations
- `tracking` schema: Legacy schema used by some server actions

When writing queries, always check which schema is being used!

### JSONB Fields
Two tables use JSONB for flexible data storage:
1. `tracking_plan_style.status_summary` - Milestone progress per style
2. `tracking_plan_style.style_timeline` - Alternative timeline storage (development)

These fields can be updated using application logic (fetch-modify-update) or direct PostgreSQL JSONB operators.

### View vs Table
Most read operations use **views** for performance:
- `tracking_folder_summary` instead of joining folder + plan
- `tracking_plan_summary` instead of complex multi-table join
- `tracking_timeline_template_detail` instead of template + item join

Some views referenced in code may need to be created (e.g., `tracking_plan_style_timeline_detail`).

---

## Common Tasks

### Adding a New Milestone to a Template
```typescript
await createTemplateItem({
  template_id: "template-uuid",
  name: "New Milestone",
  short_name: "New MS",
  node_type: "MILESTONE",
  phase: "PRODUCTION",
  department: "Quality",
  display_order: 15,
  depends_on_template_item_id: "previous-milestone-uuid",
  offset_relation: "AFTER",
  offset_value: 7,
  offset_unit: "DAYS",
  applies_to_style: true,
  applies_to_material: false,
  required: true,
  supplier_visible: false
});
```

### Updating a Style's Milestone Status
```typescript
await updateStyleMilestone(
  styleId,
  "Sample Approval",
  {
    status: "APPROVED",
    completed_date: "2025-02-20",
    notes: "Approved with minor color adjustment"
  }
);
```

### Fetching Plan with All Details
```typescript
const [plan, styles, timelines, assignments] = await Promise.all([
  getPlanById(planId),
  getPlanStyles(planId),
  getPlanStyleTimelinesEnriched(planId),
  getTimelineAssignments(timelineIds)
]);
```

---

## Performance Considerations

### Indexes
All foreign keys and frequently filtered fields should be indexed. See [TRACKING_DATABASE_SCHEMA.md](./TRACKING_DATABASE_SCHEMA.md#detailed-table-schemas) for recommended indexes.

### Pagination
Always use pagination for large result sets:
```typescript
const { data } = await supabase
  .from("tracking_plan_style")
  .select("*")
  .eq("plan_id", planId)
  .range(0, 99); // First 100 records
```

### Avoiding N+1 Queries
Fetch related data in bulk:
```typescript
// ❌ Bad: N+1 queries
for (const style of styles) {
  const timelines = await getPlanStyleMilestones(style.id);
}

// ✅ Good: Single bulk query
const allTimelines = await getPlanStyleTimelines(planId);
```

---

## Maintenance

### Documentation Updates
When adding new tables, views, or functions:
1. Update the main documentation in `TRACKING_SUPABASE_DOCUMENTATION.md`
2. Add quick reference entries to `TRACKING_QUICK_REFERENCE.md`
3. Update schema diagrams in `TRACKING_DATABASE_SCHEMA.md` if needed
4. Update this README with statistics and overview changes

### Version History
- **v1.0.0** (2025-01-08): Initial comprehensive documentation
  - 3 documentation files created
  - 27 API functions documented
  - 8 tables and 3 views documented
  - Complete PostgreSQL equivalents provided

---

## Support

For questions or clarifications:
1. Check the appropriate documentation file
2. Search for the function/table name in the docs
3. Review the PostgreSQL equivalent for understanding
4. Check the troubleshooting section in the Quick Reference

---

## Related Files in Repository

### API Implementation Files
- `/lib/tracking-api.ts` - Server-side API functions
- `/lib/tracking-api-client.ts` - Client-side API functions
- `/app/(portal)/tracking/actions.ts` - Next.js server actions

### Type Definitions
- `/types/tracking.ts` - TypeScript interfaces for all data structures

### Supabase Configuration
- `/lib/supabase/server.ts` - Server-side Supabase client
- `/lib/supabase/client.ts` - Client-side Supabase client

### UI Components
- `/app/tracking/page.tsx` - Folders list page
- `/app/tracking/[folderId]/page.tsx` - Plans list page
- `/app/tracking/[folderId]/[planId]/page.tsx` - Plan detail with timeline grid

---

## License

Internal documentation for Active Apparel Group. Not for public distribution.

---

**Last Updated**: 2025-01-08  
**Version**: 1.0.0  
**Maintained By**: AAG Development Team
