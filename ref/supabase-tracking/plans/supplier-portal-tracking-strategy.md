# Supplier portal tracking strategy – consolidated summary

**Date:** October 24, 2025  
**Status:** Strategy documented in canonical sources (see below)

The detailed strategy, architecture diagrams, and API call matrices now live in:

- `docs/03-import-and-api-plan.md` — Sections **4.3–4.4** (Supabase vendor snapshot architecture) and **5** (fallback BeProduct flow).
- `docs/05-frontend-implementation-plan.md` — Sections **6–8** (supplier gating model, UX tasks).

This file is retained as a lightweight index so historical links continue to work.

---

## Strategy highlights

1. **Supabase-first snapshot** — Build `tracking.vendor_memberships`, vendor summary/feed views, and the `tracking-vendor-portal` Edge Function to serve supplier dashboards in a single call.
2. **Fallback parity** — Keep the direct-to-BeProduct three-tier flow documented (supplier filters ➝ timeline ➝ tasks) for QA and contingency.
3. **Supplier gating** — Follow the three-gate model described in 05-frontend-implementation-plan (§6): plan access, style/material assignments, milestone sharing.

---

## Action tracker

| Workstream | Owner | Status | Source |
| --- | --- | --- | --- |
| Snapshot views & Edge Function | Backend | ⏳ Designing | See 03-import-and-api-plan §4.3. |
| Vendor portal integration | Frontend | ⏳ Pending snapshot | See 05-frontend-implementation-plan §8. |
| Legacy fallback docs | Ops | ✅ Archived | Git history prior to 2025-10-24. |

---

For implementation details, refer directly to the sections noted above.
