# Centralized Testing Plan & Reference Data

This document is the single source of truth for the overall testing workflow, reference data, and links to all milestone/phase-specific test plans. All test SQL/scripts are now centralized in the canonical location: `supabase/migrations/` (see [Migration and Function Index](../migration/MIGRATION_FUNCTION_INDEX.md)).

## Milestones & Phase Test Plans
| Milestone/Phase                | Test Plan Link                                   | Status         |
|--------------------------------|--------------------------------------------------|----------------|
| PIM: Product Information Mgmt  | [PIM Testing Plan](../schema/pim-schema.md)      | In Progress    |
| Timeline/Time & Action Plan    | [OPS Testing Plan](../schema/ops-schema.md)      | In Progress    |
| ...                            | ...                                              | ...            |

## Reference Data
- See [PIM Schema](../schema/pim-schema.md) and [OPS Schema](../schema/ops-schema.md) for test data tables.

## Checklist
- [ ] Schema documented
- [ ] Migration scripts validated
- [ ] Edge functions tested
- [ ] Webhook payloads mapped
- [ ] API endpoints verified

---

*For questions, contact the documentation owner or project lead.*
