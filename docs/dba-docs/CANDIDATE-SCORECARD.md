# DBA Interview Quick Reference - Candidate Scorecard

Use this document during the interview to track scores in real-time. Fill in points as the candidate answers each section.

---

## Candidate Information

**Name:** _________________________ **Date:** __________ **Interviewer:** _________________

---

## QUESTION 1: Row-Level Security (RLS) & Multi-Tenant Access Control (100 points)

| Criterion | Max Points | Candidate Score | Notes |
| --- | --- | --- | --- |
| **Part A: RLS Policy Design** | | | |
| 1.A.1 SELECT Policy Implementation | 15 | ___ | ☐ Uses `auth.jwt()` ☐ Handles array ☐ Has admin bypass |
| 1.A.2 JWT Claim Handling | 10 | ___ | ☐ Discusses type coercion ☐ Mentions performance |
| 1.A.3 Missing Claim Edge Case | 10 | ___ | ☐ Denies by default ☐ Good security rationale |
| 1.A.4 Single vs. Multiple Policies | 5 | ___ | ☐ Recommends multiple ☐ Good reasoning |
| **Part A Subtotal** | **40** | **___** | |
| **Part B: Supplier Access Pattern** | | | |
| 1.B.1 Supplier SELECT Policy | 15 | ___ | ☐ Handles all 3 patterns ☐ Correct JSONB |
| 1.B.2 Implicit vs. Explicit Access | 10 | ___ | ☐ Distinguishes both ☐ Proposes optimization |
| 1.B.3 JOIN Performance Impact | 5 | ___ | ☐ Acknowledges cost ☐ Suggests fix |
| **Part B Subtotal** | **30** | **___** | |
| **Part C: Audit & Monitoring** | | | |
| 1.C.1 Denial Logging | 10 | ___ | ☐ Custom audit approach ☐ Explains why needed |
| 1.C.2 Monitoring Metrics | 7 | ___ | ☐ 3+ relevant metrics |
| 1.C.3 Alert Conditions | 3 | ___ | ☐ 2+ smart alerts |
| **Part C Subtotal** | **20** | **___** | |
| **Part D: Testing & Migration** | | | |
| 1.D.1 Testing Strategy | 5 | ___ | ☐ Concrete tool + test matrix |
| 1.D.2 Migration Strategy | 5 | ___ | ☐ Phased + rollback plan |
| **Part D Subtotal** | **10** | **___** | |
| | | | |
| **QUESTION 1 TOTAL** | **100** | **___** | **Goal: 70+** |

### Notes & Comments:
_____________________________________________________________________________
_____________________________________________________________________________

---

## QUESTION 2: Trigger-Driven Automation & Cascade Logic (100 points)

| Criterion | Max Points | Candidate Score | Notes |
| --- | --- | --- | --- |
| **Part A: Race Condition Analysis** | | | |
| 2.A.1 Race Condition Description | 10 | ___ | ☐ Clear scenario ☐ Identifies shared data |
| 2.A.2 Locking Strategy | 12 | ___ | ☐ Advisory or FOR UPDATE ☐ Correct syntax |
| 2.A.3 Pseudocode with Lock | 8 | ___ | ☐ Clear logic ☐ Includes idempotency |
| 2.A.4 Testing Strategy | 5 | ___ | ☐ Concrete tool (pgbench) ☐ Validation query |
| **Part A Subtotal** | **35** | **___** | |
| **Part B: Cascade Performance & Correctness** | | | |
| 2.B.1 Cascade Logic Analysis | 10 | ___ | ☐ Recommends 1-level ☐ Explains why |
| 2.B.2 Cascade Optimization | 12 | ___ | ☐ 2+ approaches ☐ Discusses trade-offs |
| 2.B.3 Infinite Loop Prevention | 8 | ___ | ☐ Correct recursive CTE |
| 2.B.4 Query to Flag Cycles | 5 | ___ | ☐ Monitoring/alerting query |
| **Part B Subtotal** | **35** | **___** | |
| **Part C: Orphaned Record Prevention** | | | |
| 2.C.1 Cascade Delete Strategy | 8 | ___ | ☐ Recommends soft delete ☐ Rationale |
| 2.C.2 Soft vs. Hard Justification | 4 | ___ | ☐ Clear argument |
| 2.C.3 Audit Trail | 3 | ___ | ☐ Tracking table proposed |
| **Part C Subtotal** | **15** | **___** | |
| **Part D: Consistency & Observability** | | | |
| 2.D.1 Different Query Values | 7 | ___ | ☐ Identifies multiple causes ☐ Isolates trigger issue |
| 2.D.2 Trigger Failure Observability | 5 | ___ | ☐ Detailed logging table |
| 2.D.3 Trigger Failure Handling | 3 | ___ | ☐ Recommends rollback on fail |
| **Part D Subtotal** | **15** | **___** | |
| | | | |
| **QUESTION 2 TOTAL** | **100** | **___** | **Goal: 70+** |

### Notes & Comments:
_____________________________________________________________________________
_____________________________________________________________________________

---

## QUESTION 3: ETL Integration, Data Validation & Import Strategy (100 points)

| Criterion | Max Points | Candidate Score | Notes |
| --- | --- | --- | --- |
| **Part A: ETL Pipeline Design** | | | |
| 3.A.1 ETL Workflow | 10 | ___ | ☐ Multi-stage (E-T-L) ☐ Clear responsibilities |
| 3.A.2 Deduplication Strategy | 12 | ___ | ☐ Natural key or event-based ☐ Discusses retention |
| 3.A.3 Before/After Change Detection | 8 | ___ | ☐ Delta logic ☐ Efficient storage |
| **Part A Subtotal** | **30** | **___** | |
| **Part B: Data Validation & Error Handling** | | | |
| 3.B.1 Validation Rules | 10 | ___ | ☐ All rule types covered ☐ Structured errors |
| 3.B.2 Partial Success Handling | 7 | ___ | ☐ Error logging ☐ Batch status |
| 3.B.3 Validation Function Pseudocode | 5 | ___ | ☐ Multiple validation types |
| 3.B.4 Retry Strategy | 3 | ___ | ☐ Per-error-type logic |
| **Part B Subtotal** | **25** | **___** | |
| **Part C: Concurrency & Referential Integrity** | | | |
| 3.C.1 Concurrent Update Scenario | 10 | ___ | ☐ ON CONFLICT logic ☐ Field-level merge |
| 3.C.2 Foreign Key Challenge | 10 | ___ | ☐ Deferred queue ☐ Compares options |
| 3.C.3 Upsert Strategy | 5 | ___ | ☐ ON CONFLICT recommended ☐ With rationale |
| **Part C Subtotal** | **25** | **___** | |
| **Part D: Observability & Rollback** | | | |
| 3.D.1 Monitoring Metrics | 7 | ___ | ☐ 4+ specific metrics |
| 3.D.2 Slow/Failed Detection | 8 | ___ | ☐ 3+ specific alerts w/ thresholds |
| 3.D.3 Alert Aggregation | 5 | ___ | ☐ Escalation policy |
| 3.D.4 Rollback Mechanism | 10 | ___ | ☐ Partial + full ☐ Upstream comms |
| 3.D.5 Audit Trail | 5 | ___ | ☐ Source tracking |
| **Part D Subtotal** | **20** | **___** | |
| | | | |
| **QUESTION 3 TOTAL** | **100** | **___** | **Goal: 70+** |

### Notes & Comments:
_____________________________________________________________________________
_____________________________________________________________________________

---

## FINAL SCORE SUMMARY

| Question | Score | Out of | % | Rating |
| --- | --- | --- | --- | --- |
| Q1: RLS Security | ___ | 100 | __% | ☐ Strong ☐ Good ☐ Fair ☐ Weak |
| Q2: Trigger Cascade | ___ | 100 | __% | ☐ Strong ☐ Good ☐ Fair ☐ Weak |
| Q3: ETL Integration | ___ | 100 | __% | ☐ Strong ☐ Good ☐ Fair ☐ Weak |
| | | | | |
| **TOTAL SCORE** | **___** | **300** | **__% ** | |

---

## OVERALL ASSESSMENT

### Scoring Interpretation

- **210-300 (70%+):** ✅ **STRONG CANDIDATE** — Ready for senior DBA role
- **180-210 (60-70%):** ✅ **GOOD CANDIDATE** — Mid-level DBA, may need mentorship
- **150-180 (50-60%):** ⚠️ **FAIR CANDIDATE** — Fundamentals present, significant onboarding needed
- **<150 (<50%):** ❌ **WEAK CANDIDATE** — Does not meet technical requirements

---

## Strengths Demonstrated

Check areas where candidate excelled:

☐ RLS & security design
☐ PostgreSQL trigger mechanics
☐ Concurrency & locking strategies
☐ Data validation & error handling
☐ ETL/webhook architecture
☐ Performance optimization
☐ Observability & monitoring
☐ Disaster recovery & rollback planning
☐ Production-ready thinking
☐ Clear communication & explanation

---

## Areas for Development

Check areas where candidate needs improvement:

☐ RLS policies & JWT integration
☐ Trigger race conditions & locks
☐ Cascade update optimization
☐ Data validation patterns
☐ Webhook deduplication
☐ Concurrent update handling
☐ Monitoring & alerting strategy
☐ ETL error handling
☐ Database performance tuning
☐ Unfamiliar with Supabase/PostgreSQL specifics

---

## Interview Notes

**Strengths:**
_____________________________________________________________________________
_____________________________________________________________________________

**Weaknesses:**
_____________________________________________________________________________
_____________________________________________________________________________

**Follow-up Questions to Ask:**
_____________________________________________________________________________
_____________________________________________________________________________

**Recommendation:**
- ☐ **HIRE** — Proceed to offer
- ☐ **MAYBE** — Schedule second interview / technical assignment
- ☐ **PASS** — Candidate not ready for this role

**Next Steps:**
_____________________________________________________________________________
_____________________________________________________________________________

---

## Interviewer Sign-off

**Interviewer Name:** _________________________ **Date:** __________

**Signature:** _________________________ **Time Spent:** __________ min

