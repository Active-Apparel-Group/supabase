# Timeline Hybrid Schema Redesign - Documentation Index

**Purpose:** Comprehensive documentation for timeline schema migration  
**Status:** Ready for Implementation  
**Date:** October 31, 2025  
**Version:** 1.0

---

## 📋 Quick Start

**Need Quick Reference?** Start with [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md) (comprehensive catalog)  
**For Backend Developers:** Start with [Schema DDL](./schema-ddl.md) and [Migration Plan](./migration-plan.md)  
**For Frontend Developers:** Start with [Frontend Change Guide](./frontend-change-guide.md)  
**For API Implementation:** See [Endpoint Design](./endpoint-design.md) and [Query Examples](./query-examples.md)  
**For QA/Testing:** Review [Testing Plan](./testing-plan-updated.md)  
**For Project Managers:** Read [Hybrid Timeline Schema Redesign](./hybrid-timeline-schema-redesign.md) (overview)

---

## 📚 Document Inventory

### 1. [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md) ⭐ NEW
**Audience:** All Stakeholders  
**Purpose:** Comprehensive reference catalog with all tables, views, functions, endpoints, and ER diagrams

**Contents:**
- Complete table hierarchy (folder → plan → node → detail)
- Table catalog with all columns, types, and constraints
- View catalog with purposes and base tables
- Function catalog with signatures and logic
- Endpoint catalog organized by domain
- Reference data catalog (all ref schema tables)
- Entity relationship diagrams
- System architecture diagrams
- Quick reference cheatsheet (common queries and endpoints)
- Maintenance & operations guide

**When to Read:** Use this as your **go-to reference** when you need to quickly look up:
- Table structures and relationships
- API endpoints and parameters
- Views and functions
- Reference data codes
- ER diagrams

**Why This Exists:** Eliminates the need to bounce between multiple documents for quick lookups. One comprehensive catalog for easy navigation.

---

### 2. [Hybrid Timeline Schema Redesign](./hybrid-timeline-schema-redesign.md)
**Audience:** All Stakeholders  
**Purpose:** Executive summary, high-level architecture, migration overview

**Contents:**
- Business problem and solution
- Hybrid architecture diagram
- High-level schema overview
- Changes to existing schema
- Dependent triggers and functions
- BeProduct API mapping summary
- New unified API endpoints
- Change management plan
- Testing plan overview
- Implementation timeline

**When to Read:** Start here for overview and context

---

### 2. [Schema DDL](./schema-ddl.md)
**Audience:** Backend Developers, Database Administrators  
**Purpose:** Complete table definitions, indexes, constraints

**Contents:**
- Enum definitions
- Table DDL for all new tables
- Index creation scripts
- Constraint definitions
- View definitions
- Table tree structure
- Performance considerations

**When to Read:** Before implementing schema changes

---

### 3. [Triggers & Functions](./triggers-functions.md)
**Audience:** Backend Developers  
**Purpose:** Automated date recalculation, dependency management, audit trail

**Contents:**
- Trigger overview
- Date calculation functions
- Dependency recalculation logic
- Audit trail implementation
- Utility functions (critical path, user workload, bulk update)
- Test suite for triggers

**When to Read:** After schema creation, before data migration

---

### 4. [BeProduct API Mapping](./beproduct-api-mapping.md)
**Audience:** Backend Developers, Integration Team  
**Purpose:** Complete mapping of BeProduct endpoints to Supabase

**Contents:**
- Tested BeProduct endpoints (with real data)
- Data structure mapping (BeProduct → Supabase)
- Field-level mapping table
- Query output comparison (BeProduct vs Supabase)
- Endpoint equivalence table
- Behavioral differences and enhancements

**When to Read:** When implementing API parity with BeProduct

---

### 5. [Endpoint Design](./endpoint-design.md)
**Audience:** Backend & Frontend Developers  
**Purpose:** Unified REST API specification for timeline tracking

**Contents:**
- Design principles
- Base URL structure
- Complete endpoint specifications
- Request/response examples
- HTTP status codes
- Authentication & authorization
- Rate limiting
- Versioning strategy

**When to Read:** Before implementing API endpoints or frontend API client

---

### 6. [Query Examples](./query-examples.md)
**Audience:** Backend Developers, API Implementation  
**Purpose:** SQL queries for common timeline operations

**Contents:**
- Timeline queries (with dependencies, assignments, sharing)
- Progress queries (by plan, entity type, phase)
- Assignment and sharing queries
- Dependency queries (critical path, recursive chains)
- User workload queries
- Performance optimization tips

**When to Read:** When implementing API endpoints or custom reports

---

### 7. [Frontend Change Guide](./frontend-change-guide.md)
**Audience:** Frontend Developers  
**Purpose:** Breaking changes, migration steps, UI implementation guide

**Contents:**
- Breaking changes summary
- Component migration checklist
- API endpoint changes (before/after)
- TypeScript type definitions
- UI component updates
- Testing checklist
- Deployment strategy

**When to Read:** Before starting frontend migration work

---

### 8. [Migration Plan](./migration-plan.md)
**Audience:** Backend Developers, DevOps, Database Administrators  
**Purpose:** Step-by-step migration from old tables to new schema

**Contents:**
- Migration overview (6-11 week timeline)
- Pre-migration checklist
- Phase 1: Schema migration scripts
- Phase 2: Data migration scripts
- Phase 3-8: API, frontend, testing, deployment, cleanup
- Rollback plan
- Monitoring and alerts
- Success criteria

**When to Read:** Before executing migration, as reference during migration

---

### 9. [Testing Plan](./testing-plan.md)
**Audience:** QA Engineers, Backend Developers  
**Purpose:** Comprehensive test coverage for schema, API, and UI

**Contents:**
- BeProduct endpoint baseline testing (completed)
- Hybrid schema testing plan (5 phases)
- Schema & data migration tests
- Trigger & function tests
- API endpoint tests
- Frontend integration tests
- Performance tests
- Test execution order and pass/fail criteria

**When to Read:** Before and during testing phase

---

## 🎯 Use Case → Document Mapping

### I need to quickly look up a table structure or endpoint
→ Use [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md) ⭐

### I need to understand the overall redesign
→ Start with [Hybrid Timeline Schema Redesign](./hybrid-timeline-schema-redesign.md)  
→ Then check [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md) for complete hierarchy

### I need to create the database tables
→ Follow [Schema DDL](./schema-ddl.md)  
→ Then [Triggers & Functions](./triggers-functions.md)  
→ Use [Migration Plan](./migration-plan.md) for step-by-step execution  
→ Reference [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md) for quick lookup

### I need to migrate data from old tables
→ Follow Phase 2 in [Migration Plan](./migration-plan.md)  
→ Reference [BeProduct API Mapping](./beproduct-api-mapping.md) for field mappings  
→ Use [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md) for new table structures

### I need to implement new API endpoints
→ Read [Endpoint Design](./endpoint-design.md) for specifications  
→ Use [Query Examples](./query-examples.md) for SQL implementations  
→ Reference [BeProduct API Mapping](./beproduct-api-mapping.md) for parity validation  
→ Quick lookup: [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md) endpoint section

### I need to update the frontend
→ Read [Frontend Change Guide](./frontend-change-guide.md)  
→ Reference [Endpoint Design](./endpoint-design.md) for new API calls  
→ Use TypeScript types from Frontend Change Guide  
→ Quick endpoint reference: [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md)

### I need to test the migration
→ Follow [Testing Plan](./testing-plan.md)  
→ Use [Query Examples](./query-examples.md) for validation queries  
→ Reference [BeProduct API Mapping](./beproduct-api-mapping.md) for expected outputs  
→ Check expected schema: [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md)

### I need to understand BeProduct differences
→ Read [BeProduct API Mapping](./beproduct-api-mapping.md)  
→ See "Behavioral Differences" section for enhancements

### I need to see all relationships and ER diagrams
→ Go directly to [Timeline Schema Reference Catalog](./timeline-schema-reference-catalog.md) ER diagrams section

---

## 🔑 Key Concepts

### Hybrid Architecture
**What:** Unified timeline graph (`timeline_node`) + entity-specific detail tables (`timeline_style`, `timeline_material`)  
**Why:** Enables cross-entity dependencies while preserving business logic  
**Benefit:** Single source of truth, easier to extend

### Four-Date System
**Fields:** `plan_date`, `rev_date`, `due_date`, `final_date`  
**Logic:** `due_date = COALESCE(final_date, rev_date, plan_date)`  
**Behavior:** Auto-calculated via trigger

### Dependency Recalculation
**Trigger:** Changes to `rev_date` or `final_date`  
**Logic:** Calculate delta, cascade to all downstream milestones  
**Enhancement:** Fixes BeProduct gap (revision changes now cascade!)

### Normalized Assignments/Sharing
**Old:** JSONB arrays in timeline records  
**New:** Separate tables (`tracking_timeline_assignment`, `tracking_timeline_share`)  
**Benefit:** Better query performance, indexable

### Start Dates (NEW)
**Fields:** `start_date_plan`, `start_date_due`  
**Purpose:** Gantt chart rendering with proper duration bars  
**Benefit:** BeProduct only tracks end dates, this is an enhancement

---

## 📊 Data Flow Diagrams

### Timeline Query Flow
```
User Request
    ↓
API Endpoint (/v1/tracking/timeline/style/{id})
    ↓
SQL Query (timeline_node JOIN timeline_style)
    ↓
Aggregate assignments/sharing (json_agg)
    ↓
Return JSON response
```

### Date Recalculation Flow
```
User updates rev_date or final_date
    ↓
BEFORE trigger: Calculate new due_date
    ↓
UPDATE timeline_node
    ↓
AFTER trigger: Calculate delta
    ↓
Recursive CTE: Find all downstream nodes
    ↓
Bulk UPDATE: Shift downstream dates
    ↓
AFTER trigger: Log changes to audit_log
```

### Progress Query Flow
```
User Request
    ↓
API Endpoint (/v1/tracking/plans/{id}/progress)
    ↓
Fetch Risk Thresholds (tracking_setting_health)
    ↓
SQL Query (CTEs: base_metrics → calculate days late → aggregate)
    ↓
Calculate Health Metrics:
  - Entity-specific late counts
  - Max/avg days late (from due_date and plan_date)
  - Dynamic risk level (based on custom thresholds)
  - Recovery opportunities
    ↓
Group by entity_type/phase (if requested)
    ↓
Return JSON response with:
  - Status breakdown
  - Health metrics
  - Entity/phase breakdowns
```

---

## 🚀 Implementation Checklist

### Week 1: Schema Migration
- [ ] Create enums
- [ ] Create core tables (timeline_node, timeline_style, timeline_material)
- [ ] Create supporting tables (dependency, assignment, share, audit)
- [ ] Create triggers and functions
- [ ] Create views
- [ ] Backup old tables
- [ ] Migrate data (styles, materials, assignments, sharing, dependencies)
- [ ] Validate migration

### Weeks 2-3: API Development
- [ ] Implement new endpoint routes
- [ ] Write SQL query functions
- [ ] Add validation and error handling
- [ ] Add authentication/authorization
- [ ] Write unit tests
- [ ] Deploy to staging

### Weeks 3-4: Frontend Migration
- [ ] Update API client library
- [ ] Update TypeScript types
- [ ] Migrate Timeline List component
- [ ] Migrate Gantt Chart component (add start dates!)
- [ ] Migrate Progress Dashboard component
- [ ] Migrate Milestone Edit Modal
- [ ] Implement User Workload component (new)
- [ ] Write component tests

### Week 5: Testing & QA
- [ ] Run schema validation tests
- [ ] Run trigger/function tests
- [ ] Run API endpoint tests
- [ ] Run frontend integration tests
- [ ] Run performance benchmarks
- [ ] User acceptance testing
- [ ] Bug fixes

### Week 6: Deployment
- [ ] Deploy backend to production
- [ ] Deploy frontend behind feature flag
- [ ] Gradual rollout (10% → 50% → 100%)
- [ ] Monitor error rates and performance
- [ ] Address any issues

### Weeks 7-10: Grace Period
- [ ] Support old and new endpoints
- [ ] Collect user feedback
- [ ] Monitor adoption
- [ ] Prepare deprecation notice

### Week 11: Cleanup
- [ ] Deprecate old endpoints
- [ ] Archive old tables (30-day retention)
- [ ] Drop old tables (after approval)
- [ ] Update documentation

---

## ✅ Success Metrics

### Technical
- ✅ All data migrated (zero data loss)
- ✅ Query performance < 500ms (timeline queries)
- ✅ Query performance < 50ms (progress queries)
- ✅ All triggers executing correctly
- ✅ All API endpoints returning correct data
- ✅ All frontend components rendering correctly

### Business
- ✅ Cross-entity dependencies enabled
- ✅ Gantt chart improvements visible
- ✅ User workload feature adopted
- ✅ No production incidents
- ✅ Frontend migration completed in 2 weeks
- ✅ Stakeholder sign-off received

---

## 📞 Support & Resources

### Contacts
- **Backend Team:** [Backend lead]
- **Frontend Team:** [Frontend lead]
- **QA Team:** [QA lead]
- **DevOps Team:** [DevOps lead]
- **Product/PM:** [Product owner]

### Communication Channels
- **Slack:** #timeline-migration
- **Email:** timeline-migration@yourcompany.com
- **Weekly Sync:** Tuesdays 2pm

### Resources
- **Staging API:** https://staging-api.yourcompany.com/api/v1
- **Staging DB:** [Connection string]
- **Test Plan ID:** 162eedf3-0230-4e4c-88e1-6db332e3707b (GREYSON 2026 SPRING DROP 1)
- **Documentation:** This folder

---

## 🔄 Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Oct 31, 2025 | System | Initial comprehensive documentation suite |

---

## 📝 Glossary

**Timeline Node:** Universal timeline record in the graph layer (entity-agnostic)  
**Detail Table:** Entity-specific table (timeline_style, timeline_material) with business logic  
**Hybrid Architecture:** Combination of universal graph + entity-specific details  
**Four-Date System:** plan_date, rev_date, due_date, final_date  
**Dependency Recalculation:** Auto-update downstream milestones when date changes  
**Critical Path:** Longest dependency chain in a plan  
**Entity Type:** Style, material, order, or production  
**Milestone Template:** Timeline milestone definition (no dates/status)  
**Milestone Instance:** Actual timeline record for specific entity (has dates/status)  
**BeProduct Parity:** Matching functionality with BeProduct API  

---

**Last Updated:** October 31, 2025  
**Maintained By:** Backend Team  
**Review Cycle:** Quarterly or after major changes
