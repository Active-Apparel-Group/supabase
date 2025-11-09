# Centralized Testing Plan & Reference Data

## How to Use This Plan


This document is the single source of truth for the overall testing workflow, reference data, and links to all milestone/phase-specific test plans. All test SQL/scripts are now centralized in the canonical location: `supabase/migrations/` (see [Migration and Function Index](../../../supabase/MIGRATION_FUNCTION_INDEX.md)). Start here for every test cycle, and return here to update reference data and track progress.

### Onboarding Steps
1. Review the overall workflow and instructions below.
2. Check the reference data section and update as needed.
3. Use the links to jump to phase/milestone-specific test plans.
4. After each test cycle, update this plan and the relevant phase doc with outcomes and lessons learned.

---

## Overall Testing Approach & Workflow

- **Centralized Plan:** This document describes the end-to-end testing approach, reference data, and links to all detailed test plans.
- **Iterative Cycle:**
  1. Start here: review instructions, reference data, and milestone links.
  2. Go to the phase-specific test plan (see links below).
  3. Execute tests, update results and findings in the phase doc.
  4. If reference data or workflow changes, update this plan.
  5. Return here to review progress and plan next steps.
- **Documentation & Feedback Loop:**
  - After each test cycle, update both this plan and the phase doc with outcomes, issues, and lessons learned.
  - Use checklists and status tables to track what’s done and what’s next.
  - Encourage team feedback and continuous improvement.

---

## Milestones & Phase Test Plans

| Milestone/Phase                | Test Plan Link                                   | Status         |
|--------------------------------|--------------------------------------------------|----------------|
| PIM: Product Information Mgmt  | [01-pim/docs/testing-plan.md](../01-pim/docs/testing-plan.md)         | In Progress    |
| **PIM Schema Reference**       | [../schema/pim-schema.md](../../schema/pim-schema.md)                                | ✅ Complete    |
| Timeline/Time & Action Plan    | [02-timeline/docs/testing-plan.md](../02-timeline/docs/testing-plan.md) | (TBD)          |
| Forecasting                    | [03-forecasting/docs/testing-plan.md](../03-forecasting/docs/testing-plan.md) | (TBD)          |
| ...                            | ...                                              | ...            |

---

## Reference Data (for All Phases)

### Tracking Plans
| Source     | Plan Name                    | Season/Drop         | Plan ID                                 | Notes                |
|------------|------------------------------|---------------------|------------------------------------------|----------------------|
| BeProduct  | GREYSON 2026 SPRING DROP 1   | 2026 Spring Drop 1  | 20fb4a1c-e6ea-46e8-b37b-40ca5e514ef3    | Main test plan       |

### Styles & Colorways
| Source     | Style Name                              | Style ID (Supabase)                      | BeProduct Style ID                      | Colorways            | Notes                |
|------------|-----------------------------------------|------------------------------------------|------------------------------------------|----------------------|----------------------|
| Supabase   | MONTAUK SHORT - 8" INSEAM (testing)    | 6a5af076-c9bd-4f7e-8ca4-bdf21621b67f     | db0c4180-3922-4122-b7e9-4fb88958beab    | 3 colorways          | MSP26B26, GREYSON Spring 1 2026 |

| Colorway Name      | Colorway ID (Supabase)                   | BeProduct Colorway ID                    | Color Number      | Hex Code  |
|--------------------|------------------------------------------|------------------------------------------|-------------------|------------|
| 359 - PINK SKY     | 4d1761c6-03a7-4288-936f-6ff212b3ac23     | 0c728077-5b1f-4a2a-9fbe-183395460077     | 13-3207 TCX       | #f7cfe1   |
| 947 - ZION         | 3f5c30b8-3036-49fb-8bdd-6799bf835e31     | 3af316a7-8e87-4f49-8d93-dc1e78d3d0d5     | 19-2620 TCX       | #47253c   |
| 220 - GROVE        | 15d97619-7dce-48f7-b008-b82b3c4c2db0     | 0ee18021-f552-4190-90ef-c2aba6c70d8a     | 19-4038 TCX       | #133951   |

### Color Palettes
| Source     | Folder Name   | Palette Name                  | Palette ID (Supabase)                    | BeProduct Palette ID                     | Colors   | Notes                |
|------------|---------------|-------------------------------|------------------------------------------|------------------------------------------|----------|----------------------|
| BeProduct  | GREYSON MENS  | GREYSON MENS 2026 SPRING      | 473f7813-2818-425c-91d4-38fc2d457599     | 473f7813-2818-425c-91d4-38fc2d457599     | 6        | S26-GSC00001         |

### Timeline Templates
| Source     | Timeline Template         | Template ID                              | Milestones Included | Notes                |
|------------|--------------------------|------------------------------------------|---------------------|----------------------|
| Supabase   | GREYSON 2026 SPRING CORE | <actual-template-uuid>                   | 27 milestones       | See details below    |

**Milestone Definitions (from ops.tracking_timeline_template_item, 27 rows):**
- Each milestone includes: name, phase, display_order, dependency, offset, duration, applies_to_style/material, etc.
- Example milestones: START DATE, Tech Pack, Proto Sample, END DATE, etc.
- All milestone definitions are present and mapped to the template.

**Note:**
- Assignment data (ops.tracking_timeline_assignment) is currently empty—no explicit user assignments yet. All other tracking data (plans, styles, colorways, milestones, dependencies) is present and available for testing.

---

## Checklist: What to Double-Check Before Testing

### Phase 1: PIM (Product Information Management)
- [x] BeProduct endpoint review and documentation complete
- [x] PIM schema documented (see [pim-schema.md](../../schema/pim-schema.md))
- [x] Test data (style, colorways, color palettes) validated in Supabase
- [x] All BeProduct IDs validated and populated in Supabase tables
- [x] Style "MONTAUK SHORT - 8" INSEAM (testing)" with 3 colorways confirmed
- [x] Color palette "GREYSON MENS 2026 SPRING" with 6 colors confirmed
- [ ] PIM Edge Function for BeProduct sync tested and validated
- [ ] PIM test plan complete with test cases and validation queries

### Phase 2: Timeline/Time & Action Plan (ops schema)
- [x] BeProduct tracking endpoint review and documentation complete
- [x] Retrieve and validate BeProduct planId for test plan (20fb4a1c-e6ea-46e8-b37b-40ca5e514ef3)
- [x] **COMPLETED:** Comprehensive BeProduct timeline behavior baseline testing
  - Tested `planGet`, `planStyleTimeline`, `planUpdateStyleTimelines` operations
  - Documented all date fields (`plan`, `rev`, `due`, `final`) and their behaviors
  - **CRITICAL FINDING:** BeProduct ONLY recalculates downstream dates when `final` is set (milestone completion)
  - **CRITICAL GAP:** `rev` field is passive tracking only; does NOT trigger recalculation (must enhance in Supabase!)
  - **CRITICAL FINDING:** `due` field is auto-calculated and cannot be directly edited
  - Documented status transitions, late flag logic, assignment/sharing
  - Created comprehensive before/after examples with actual test data
  - **VALIDATION:** All findings confirmed via independent GET calls (not POST/PATCH responses)
- [ ] All relevant ops tables (milestones, assignments, sharing, dependencies) documented and mapped to test cases
- [ ] Timeline template configured and documented
- [ ] Test data (plan, style assignments, timelines) exists in Supabase or scripts are ready
- [ ] All triggers/functions (date recalculation, assignment, sharing, dependency updates) listed and covered by test cases
- [ ] Supabase Edge Function for timeline sync deployed and accessible
- [ ] No TODO/TBD sections left in timeline test plan

### Phase 3: Forecasting
- [ ] Forecasting schema documented
- [ ] Test data prepared
- [ ] Forecasting test plan complete

---

## Continuous Improvement
- After each test cycle, update this plan and phase docs with outcomes, issues, and lessons learned.
- Use this plan as the entry and exit point for every test cycle.
- Encourage feedback and keep documentation up to date.

---

*This document is a living artifact. Update as your workflow, schema, and test data evolve.*

---

## BeProduct Tracking Tool & Endpoints for Testing

The BeProduct tracking tool provides unified access to tracking plans, timelines, and progress. It will be used to validate integration and data flow between BeProduct and Supabase throughout all relevant phases.

### Key Operations/Endpoints Used in Testing

| Operation                    | Purpose/Description                                              |
|------------------------------|-----------------------------------------------------------------|
| folderList                   | List all tracking folders (organizational units)                 |
| planSearch                   | Search for tracking plans by criteria                            |
| planGet                      | Retrieve a specific plan and its details                        |
| planAddStyle                 | Add a style to a plan                                           |
| planAddStyleByColorway       | Add a style by colorway to a plan                               |
| planAddMaterial              | Add a material to a plan                                        |
| planStyleTimeline            | Get or update the timeline for a style in a plan                |
| planStyleView                | View style details within a plan                                |
| planMaterialTimeline         | Get or update the timeline for a material in a plan             |
| planMaterialView             | View material details within a plan                             |
| planStyleProgress            | Get progress for a style in a plan                              |
| planMaterialProgress         | Get progress for a material in a plan                           |
| planUpdateStyleTimelines     | Bulk update style timelines                                     |
| planUpdateMaterialTimelines  | Bulk update material timelines                                  |
| planDeleteMaterialTimelines  | Delete material timelines                                       |
| planMaterialRevisions        | View or manage material revisions                               |

**Usage Notes:**
- Use `planSearch` and `planGet` to identify and retrieve plans for testing.
- Use `planStyleTimeline` and `planUpdateStyleTimelines` to validate timeline data and integration with Supabase.
- Use `planAddStyle` and `planAddStyleByColorway` to test style assignment flows.
- Always confirm plan existence with `planSearch` before making timeline or mutation calls.
- Pagination is zero-based; follow `meta.nextPageNumber` while `meta.hasMore` is true in responses.
- Timeline mutations expect arrays of milestone edits; include `planId` and exact row identifiers.

**Integration Guidance:**
- Reference these operations in each phase/milestone test plan where BeProduct integration is required.
- Document any issues, errors, or integration gaps in both the phase doc and this centralized plan.

For more details, see the [BeProduct Tracking Tool Documentation](beproduct://docs/catalog) or API reference.
