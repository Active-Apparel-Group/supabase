
# Supabase Garment Tracking Documentation Index

## Quick Links
- [Schema Documentation](./schema/)
- [Migration & Function Index](./migration/MIGRATION_FUNCTION_INDEX.md)
- [API Reference (Edge Functions & Webhooks)](./api/)
- [Integration Guides](./integration/)
- [Testing Plans](./testing/)
- [Onboarding & Scorecards](./onboarding/DBA-ONBOARDING.md)
- [Archive](./_archive/)

---

## Document Inventory

| Domain        | Canonical Doc(s)                                      | Audience         | Purpose/Notes                                      |
|--------------|-------------------------------------------------------|------------------|----------------------------------------------------|
| Schema       | [PIM Schema](./schema/pim-schema.md), [OPS Schema](./schema/ops-schema.md) | DBA, Dev, Analyst | Data model, table/column reference                  |
| Migration    | [Migration & Function Index](./migration/MIGRATION_FUNCTION_INDEX.md)      | DBA, Dev          | Canonical list of migrations, edge functions        |
| API          | [Edge Functions](./api/edge-functions.md), [Webhooks](./api/webhooks.md)   | Dev, Integrator   | API endpoints, payloads, diagrams                   |
| Integration  | [Tracking Webhook Sync Plan](./integration/TRACKING-WEBHOOK-SYNC-PLAN.md)  | Dev, Analyst      | BeProduct integration, mapping, sync strategy       |
| Testing      | [Centralized Testing Plan](./testing/CENTRALIZED-TESTING-PLAN.md)          | QA, Dev           | Test plans, reference data, phase test plans        |
| Onboarding   | [DBA Onboarding & Scorecard](./onboarding/DBA-ONBOARDING.md)               | DBA, HR           | Onboarding, scorecard, process                      |
| Workflow     | [Workflow Overview](./integration/WORKFLOW-OVERVIEW.md)                    | All               | End-to-end workflow, milestones, navigation         |

---

## Archive
Outdated and duplicate docs are moved to [`/docs/_archive/`](./_archive/). See the Archive section below for a full list and references.

---

## Backlink Policy
All documentation should link back to this index and to the canonical doc for its domain. Update backlinks in all docs when moving or merging content.

---

## Archive Section

| Doc/Folders Moved to Archive                | Reason/Notes                                 |
|---------------------------------------------|----------------------------------------------|
| `supabase-beproduct-migration/02a-tracking/README.md` | Superseded by canonical API & integration docs |
| `agent-docs/MISSING-DATA-ANALYSIS.md`       | Incorporated into API/webhook documentation   |
| `agent-docs/MIGRATION_FUNCTION_INDEX.md`    | Merged into migration index                   |
| ...                                         | ...                                          |

---

## How to Use This Index
- Start here for navigation and canonical references.
- Use quick links and inventory table to find the right doc for your needs.
- For technical details, see the canonical doc for each domain.
- For onboarding, use the unified DBA onboarding doc.
- For API and integration, use the edge function and webhook docs.
- For testing, use the centralized testing plan and phase test plans.
- For schema, use the PIM and OPS schema docs.
- For workflow, use the overview and milestone navigation.

---

## Update Policy
- When adding or updating docs, update this index and backlinks.
- Move outdated/duplicate docs to `/docs/_archive/` and reference here.
- Ensure each domain has a single canonical doc.

---

*For questions, contact the documentation owner or project lead.*
