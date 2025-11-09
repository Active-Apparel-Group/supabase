# DBA Interview Package - README

## Overview

This package contains a comprehensive interview assessment for Senior Database Administrators with expertise in PostgreSQL, Supabase, and multi-tenant SaaS architectures.

---

## What's Included

### 📋 Interview Questions (3 Documents)

1. **Question-1-RLS-Security-Challenge.md**
   - **Focus:** Row-Level Security (RLS) & multi-tenant access control
   - **Duration:** 45 minutes
   - **Topics:** JWT claims, brand-scoped policies, supplier access patterns, audit trails, testing strategies
   - **Difficulty:** Advanced

2. **Question-2-Trigger-Cascade-Challenge.md**
   - **Focus:** Trigger-driven automation & cascade logic
   - **Duration:** 45 minutes
   - **Topics:** Race conditions, locking strategies, cascade optimization, cycle detection, observability
   - **Difficulty:** Advanced

3. **Question-3-ETL-Import-Challenge.md**
   - **Focus:** ETL integration, data validation, webhook handling
   - **Duration:** 45 minutes
   - **Topics:** Pipeline design, deduplication, validation rules, concurrency, monitoring, rollback
   - **Difficulty:** Advanced

### 📊 Evaluation Materials (2 Documents)

4. **ANSWER-SHEET-Scoring-Guide.md** (Detailed)
   - Comprehensive answer guide for each question
   - Expected responses with code examples
   - Detailed scoring rubrics (15-40 points per criterion)
   - Scoring interpretation guide
   - Interview tips for probing deeper

5. **CANDIDATE-SCORECARD.md** (Quick Reference)
   - Real-time scoring table
   - Checklist for candidate evaluation
   - Final assessment summary
   - Strengths/weaknesses tracking
   - Hire/pass decision framework

---

## How to Use This Package

### Before the Interview

1. **Review the questions** — Familiarize yourself with all three challenge scenarios
2. **Read the answer sheet** — Understand what "strong" responses look like
3. **Prepare follow-ups** — Have 5-10 follow-up questions ready for each topic
4. **Set up environment** — Ensure you have whiteboard/Zoom screen sharing ready
5. **Print the scorecard** — Have a physical copy for real-time note-taking

### During the Interview

1. **Introduction (5 min)**
   - Explain the interview format
   - Let candidate know they'll answer 3 technical questions (45 min each, optional breaks)
   - Clarify: Pseudocode/SQL acceptable, production-thinking valued, trade-offs matter

2. **Question Pacing**
   - Allow **45 minutes per question** (or ~30 min if time is limited)
   - Candidate can answer verbally, write SQL, or sketch architecture
   - Probe deeper: "Walk me through your logic," "What if X changes?" "How would you monitor this?"

3. **Real-time Scoring**
   - Use the CANDIDATE-SCORECARD.md to track points
   - Fill in checkboxes as candidate addresses each criterion
   - Take notes on strengths/weaknesses for later discussion

4. **Be Flexible**
   - Allow candidate to choose format (code, pseudocode, architecture diagram)
   - Don't penalize syntax if logic is correct
   - Reward candidates who discuss trade-offs and production concerns

### After the Interview

1. **Complete Scoring**
   - Calculate final scores for each question
   - Reference the Answer Sheet if you need clarification
   - Document strengths/weaknesses

2. **Decision Framework**
   - **70%+:** Strong hire — Senior DBA ready
   - **60-70%:** Good hire — Mid-level DBA with mentoring
   - **50-60%:** Fair candidate — Significant onboarding needed
   - **<50%:** Pass — Not ready for this role

3. **Follow-up Communications**
   - Share scorecards with hiring committee
   - Provide detailed feedback to candidate (both hire and pass)
   - Schedule second interview if "maybe" rating

---

## Scoring Summary

Each question is scored out of 100 points:

### Question 1: RLS Security (100 pts)
- Part A: RLS Policy Design (40 pts)
- Part B: Supplier Access Pattern (30 pts)
- Part C: Audit & Monitoring (20 pts)
- Part D: Testing & Migration (10 pts)

### Question 2: Trigger Cascade (100 pts)
- Part A: Race Condition Analysis (35 pts)
- Part B: Cascade Performance & Correctness (35 pts)
- Part C: Orphaned Record Prevention (15 pts)
- Part D: Consistency & Observability (15 pts)

### Question 3: ETL Integration (100 pts)
- Part A: ETL Pipeline Design (30 pts)
- Part B: Data Validation & Error Handling (25 pts)
- Part C: Concurrency & Referential Integrity (25 pts)
- Part D: Observability & Rollback (20 pts)

**Total: 300 points**

### Rating Scale
- **210-300 (70%):** Strong ✅
- **180-210 (60%):** Good ✅
- **150-180 (50%):** Fair ⚠️
- **<150 (<50%):** Weak ❌

---

## What You're Assessing

This interview evaluates a DBA's expertise in:

✅ **Security & RLS** — Can they design multi-tenant access controls?
✅ **PostgreSQL Advanced Features** — Do they understand triggers, locks, advisories?
✅ **Concurrency & Performance** — Can they spot race conditions and optimize?
✅ **Data Integration** — How would they handle webhooks and ETL pipelines?
✅ **Monitoring & Observability** — Do they think about production ops?
✅ **Disaster Recovery** — Can they design for failure and rollback?
✅ **Communication** — Can they explain complex concepts clearly?

---

## Tips for Interviewers

### Scoring Well
- **Candidates who score high:** Think in layers (security → performance → monitoring), consider edge cases, discuss trade-offs
- **Red flags:** One-size-fits-all answers, no mention of testing/monitoring, dismisses production concerns

### Probing Deeper
- "Walk me through the execution of this trigger step by step"
- "What happens if two webhooks arrive at exactly the same time?"
- "How would you know if this policy is misconfigured in production?"
- "What would you monitor to detect this failure?"
- "Why is this approach better than the alternative?"

### Rewarding Production Thinking
- Give bonus points for candidates who mention:
  - Monitoring and alerting
  - Failure modes and recovery
  - Testing strategies
  - Performance benchmarking
  - Security best practices (deny by default, fail secure)

### Handling Edge Cases
- If candidate says "I'd use X" — ask "What if X isn't available?"
- If candidate gives vague answer — ask "Can you show me SQL/pseudocode?"
- If candidate says "That's a non-issue" — challenge: "Really? What about...?"

---

## Customization Guide

Feel free to customize these questions for your context:

### If your team uses different stack:
- Replace Supabase with CloudSQL/RDS (RLS concepts remain the same)
- Replace Edge Functions with Lambda/Cloud Functions (ETL concepts remain the same)
- Replace PostgreSQL with MySQL (concepts similar, syntax differs)

### If you want shorter interviews:
- Use 1-2 questions instead of 3
- Reduce time to 30 minutes per question
- Focus on the highest-scoring sections

### If you want domain-specific questions:
- Adapt the webhook payloads to your data types
- Change table names to match your schema
- Adjust complexity of dependency graphs

---

## Document Summary

| Document | Purpose | Audience | Length |
| --- | --- | --- | --- |
| Q1-RLS-Security-Challenge.md | Interview question | Candidate | 2-3 pages |
| Q2-Trigger-Cascade-Challenge.md | Interview question | Candidate | 3-4 pages |
| Q3-ETL-Import-Challenge.md | Interview question | Candidate | 4-5 pages |
| ANSWER-SHEET-Scoring-Guide.md | Answer guide + scoring | Interviewer | 30+ pages |
| CANDIDATE-SCORECARD.md | Real-time scoring | Interviewer | 4-5 pages |
| README.md (this file) | Overview + tips | Both | 2-3 pages |

---

## Recommended Interview Flow

```
Total Time: ~3 hours (with breaks)

0:00 - 0:05   — Introduction & interview format
0:05 - 0:50   — Question 1: RLS Security
0:50 - 0:55   — Break
0:55 - 1:40   — Question 2: Trigger Cascade
1:40 - 1:45   — Break
1:45 - 2:30   — Question 3: ETL Integration
2:30 - 2:35   — Break
2:35 - 3:00   — Final Q&A + closing
```

---

## Questions for the Candidate

If they finish early or you want to go deeper:

**RLS Follow-ups:**
- How would you implement column-level security?
- What's the performance impact of complex RLS policies?
- How would you handle cross-brand access (e.g., admin can see all)?

**Trigger Follow-ups:**
- Have you dealt with trigger-induced deadlocks before? How did you fix it?
- How would you version/rollback a broken trigger in production?
- Would you ever use triggers instead of application logic? When?

**ETL Follow-ups:**
- How would you handle data transformations at scale (1M+ events/day)?
- Have you implemented exactly-once semantics? How?
- How would you debug a partially successful import?

---

## Feedback Template

After the interview, share this feedback with candidates:

```
Dear [Candidate],

Thank you for interviewing with us! Here's feedback on your technical assessment:

QUESTION 1: RLS Security
- Strengths: [specific examples of good responses]
- Development Areas: [specific topics to improve]
- Score: [X/100]

QUESTION 2: Trigger Cascade
- Strengths: [specific examples]
- Development Areas: [specific topics]
- Score: [X/100]

QUESTION 3: ETL Integration
- Strengths: [specific examples]
- Development Areas: [specific topics]
- Score: [X/100]

OVERALL: [X/300]
RATING: [Strong/Good/Fair/Weak]

[If pass]: We're excited to move forward to the next round.
[If no pass]: We don't think this is the right fit at this time, but we appreciate your interest.

Best regards,
[Your Name]
```

---

## Version History

- **v1.0** — Initial release (Nov 2025)
  - 3 interview questions
  - Detailed answer sheet with scoring
  - Quick reference scorecard
  - This README

---

## Support & Questions

If you have questions about:
- **Scoring interpretation** — See ANSWER-SHEET-Scoring-Guide.md
- **Real-time tracking** — Use CANDIDATE-SCORECARD.md
- **Question content** — Review the individual question documents
- **Interview flow** — Refer to "Recommended Interview Flow" section above

---

## License & Usage

This interview package is proprietary and intended for internal hiring use only. Do not distribute outside your organization.

**Created for:** Your Company / Team Name
**Date:** November 2025
**Interviewer:** [Your Name]

---

**Good luck with your interview! 🚀**

