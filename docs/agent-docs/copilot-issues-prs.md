

### Typical Workflow with GitHub Copilot, Agents, and Subagents in VS Code

GitHub Copilot in VS Code has evolved from a simple autocomplete tool into a full AI-powered collaborator, especially with **agent mode** (for autonomous, multi-step tasks) and **subagents** (context-isolated specialists for focused subtasks like TDD or research). This enables an iterative, agent-orchestrated development lifecycle: plan → build → test → deploy → repeat. The workflow leverages Copilot's chat interfaces (inline chat for quick edits, Copilot Chat for conversations), **mission control** (sidebar for managing workflows and agents), and integration with GitHub for PRs and CI/CD.

The process is highly iterative—agents self-correct via feedback loops (e.g., running tests, fixing errors, and re-planning)—and customizable via **custom instructions** (e.g., in `.github/copilot-instructions.md`) or **custom chat modes** for your team's style. It assumes you have the Copilot extension installed, agent mode enabled (in settings), and a subscription (free tier has limits; Pro+ unlocks advanced models like OpenAI Codex).

#### 1. **Plan: Outline and Refine the Task**
   - **Goal**: Break down high-level requirements into executable steps, analyze the codebase, and create a roadmap.
   - **Copilot's Role**: Use **Plan Mode** (in Copilot Chat or agent mode) to generate detailed implementation plans. It scans your workspace, references issues/PRs, and suggests architectures.
   - **Typical Steps**:
     - Open Copilot Chat (Ctrl+Alt+I) or inline chat (Ctrl+I) in a relevant file.
     - Switch to **Agent** mode in the chat dropdown for autonomous planning.
     - Prompt: "Plan a user authentication feature: include OAuth integration, database schema updates, and error handling. Analyze current codebase and list steps."
     - Copilot outputs a step-by-step plan (e.g., "Step 1: Add user model; Step 2: Implement login route"). Review and refine via follow-up prompts like "Add security best practices."
     - For complex projects, delegate to a **planning subagent** (via Agent Sessions view): "Spawn subagent for architecture review—focus on scalability."
     - **Output**: A todo list or Markdown plan. Hand it off to an implementation agent for execution.
   - **Iteration Tip**: If the plan misses context, drag files into chat (#file) or use semantic search smart actions to pull relevant code.
   - **Time Savings**: Reduces planning from hours to minutes; agents iterate until the plan covers requirements.

#### 2. **Build: Implement Code Autonomously**
   - **Goal**: Generate and edit code across files, handling boilerplate and integrations.
   - **Copilot's Role**: Inline completions for quick writes; agent mode for full features. Subagents handle specialized builds (e.g., a "frontend subagent" for React components).
   - **Typical Steps**:
     - In mission control (Copilot sidebar), select a workflow like "Implement feature" or paste your plan.
     - Prompt in agent mode: "Using the plan, build the authentication system: create routes, models, and middleware. Install dependencies if needed."
     - Copilot (or coding agent) works in an isolated environment: clones repo, edits files, runs terminal commands (e.g., `npm install`), and pushes incremental commits.
     - Use **Edits mode** for precise changes: "Refactor this function to async/await" (applies multi-file diffs).
     - For delegation: Assign to **Copilot coding agent** via GitHub Issues (@copilot) or chat: "Delegate auth build to cloud agent." It runs asynchronously in GitHub Actions (background, no local disruption).
     - Subagents: "Create subagent for UI: generate React login form with validation."
     - **Output**: Draft code changes in your editor or a new branch/PR.
   - **Iteration Tip**: Agents self-heal (e.g., fix syntax errors on-the-fly). Undo last edit via the view bar if needed.
   - **Time Savings**: Handles 20-30% of keystrokes; complex features (e.g., full API) in <10 minutes.

#### 3. **Test: Generate, Run, and Debug**
   - **Goal**: Ensure coverage with unit/integration tests; fix failures iteratively.
   - **Copilot's Role**: Generates tests via prompts; agent mode runs them and debugs. Subagents excel here (e.g., TDD-focused subagent).
   - **Typical Steps**:
     - In Copilot Chat (Agent mode): "Generate unit tests for the auth service, including edge cases like invalid tokens. Run them and fix failures."
     - Use smart actions: Right-click code → "Generate tests" (auto-creates framework setup, e.g., Jest/Pytest).
     - Agent executes: Runs `npm test`, analyzes output, and applies fixes (e.g., "Patch memory leak in auth handler").
     - Prompt for debugging: "Why is this test failing? Suggest fixes." Or delegate: "Subagent: Run TDD workflow on login component."
     - Integrate CI: Copilot generates GitHub Actions YAML for linting/tests across Node versions.
     - **Output**: Passing test suite; coverage report in chat.
   - **Iteration Tip**: Agents loop until 100% pass rate (e.g., min 80% coverage). Review via terminal output in VS Code.
   - **Time Savings**: Cuts test writing by 50-70%; auto-fixes common issues like re-renders or leaks.

#### 4. **Deploy: Review, Secure, and Ship**
   - **Goal**: Prepare for production via PRs, reviews, and automation.
   - **Copilot's Role**: Automates PR creation, reviews, and security scans. Coding agent handles end-to-end from issue to merge.
   - **Typical Steps**:
     - Agent opens a draft PR with changes (auto-generates description/title from plan).
     - In PR view (GitHub Pull Requests extension): "@copilot review for security and add missing tests."
     - Copilot scans with CodeQL/AutoFix, suggests edits (e.g., "Fix vuln in OAuth callback").
     - Use mission control to trigger workflows: "Deploy to staging via GitHub Actions."
     - For custom deploys: Prompt "Generate deployment script for AWS/Heroku, including env vars."
     - Subagents: "Security subagent: Scan for supply chain risks."
     - Merge after approval; agent can iterate on feedback (e.g., "Address review comment #3").
     - **Output**: Merged PR; automated deploy if CI/CD is set up.
   - **Iteration Tip**: PRs require human approval before CI runs, ensuring safety. Track via Agents panel.
   - **Time Savings**: Automates grunt work (branching, commits, reviews); ships features 2-3x faster.

#### **Repeat: Iterate and Scale**
   - **Feedback Loop**: After deploy, prompt "Analyze production logs for issues and suggest v2 improvements." Agents learn from custom instructions and past sessions (via Agent Sessions view).
   - **Scaling with Agents/Subagents**:
     - **Orchestration**: Use **Agent HQ** (in VS Code Insiders) as a "mission control" to spawn/manage multiple agents (e.g., one for backend, subagent for frontend). Costs 1 premium request per session.
     - **Custom Agents**: Define in repo settings (JSON/YAML) for specialties like "React enforcer" or "DB optimizer." Share via @github/awesome-copilot.
     - **Multi-Agent Pattern** (e.g., "Copilot Orchestra"): Conductor agent plans → Delegates to implement/review/commit subagents → Loops until done.
   - **Best Practices**:
     - Start small: Use for non-critical tasks (e.g., tests) to build trust.
     - Prompts: Be specific (e.g., "Use TypeScript, arrow functions") and reference context (#file, #issue).
     - Quotas: Free tier limits completions/chats; monitor in settings. Pro+ for unlimited agents.
     - Tools: Enable MCP servers for external integrations (e.g., APIs); confirm tool runs for safety.
     - Nightly Workflow: Assign tasks to cloud agents overnight; review in VS Code morning (e.g., checkout branch, restore chat).

This workflow turns solo coding into an "AI team" collaboration, focusing your energy on creative decisions. For hands-on, try the VS Code tutorial for a task manager app. Experiment in VS Code Insiders for subagents and Codex. If you're on free tier, upgrade for full agent power.


In your workflow with GitHub Copilot, agents, and subagents in VS Code, **Issues** and **Pull Requests (PRs)** serve distinct but complementary purposes. Their usage depends on the stage of your development lifecycle (plan, build, test, deploy, repeat) and the task at hand. Below, I outline when to use each, integrated into the typical workflow you described, based on current GitHub and Copilot functionality.

### When to Use Issues
**Issues** are for **planning, tracking, and discussing tasks** before or during development. They’re ideal for capturing requirements, bugs, or ideas and aligning the team before coding starts.

- **Planning Stage**:
  - **Use Case**: Create an issue to define a task, feature, or bug. For example, "Implement user authentication with OAuth" or "Fix login error for invalid tokens."
  - **Copilot Integration**: In VS Code, use the **GitHub Issues extension** or Copilot Chat (Ctrl+Alt+I) to create or reference issues. Prompt: "Create an issue for adding a user profile page, include acceptance criteria." Copilot drafts the issue with details from your codebase or prompt.
  - **Agent Role**: In **Agent mode**, assign planning to a **planning subagent** via mission control (Copilot sidebar): "Analyze codebase and draft issue for scalability improvements." The subagent opens an issue on GitHub with a breakdown of tasks.
  - **Why Issues?**: Issues centralize discussion and track progress. They’re visible to the team, and Copilot can reference them (#issue) for context in later steps.

- **Build/Test Stages**:
  - **Use Case**: Link ongoing work to issues for traceability. For example, when building, reference the issue in commits or agent prompts: "Implement feature from #123."
  - **Copilot Integration**: Agents can close issues automatically after implementation. Prompt: "After coding auth routes, close issue #123 with a summary." Or use smart actions to link code to issues.
  - **Why Issues?**: Keeps work aligned with requirements and provides a record of intent.

- **Repeat Stage**:
  - **Use Case**: Log bugs or improvements post-deploy. For example, "Production logs show slow queries—create issue for DB optimization."
  - **Copilot Integration**: Prompt: "Analyze logs and create issue for performance fixes." A subagent can draft the issue with log snippets and suggested fixes.
  - **Why Issues?**: Drives iteration by identifying next steps.

### When to Use Pull Requests (PRs)
**PRs** are for **reviewing, testing, and deploying code changes**. They come into play after coding (build/test) and are the gateway to merging changes into the main codebase.

- **Build Stage**:
  - **Use Case**: After coding a feature or fix (e.g., auth system), create a PR to propose changes. Copilot’s coding agent can auto-generate a PR from your branch.
  - **Copilot Integration**: In mission control or Copilot Chat (Agent mode), prompt: "Create PR for auth feature from branch `feature/auth`." Copilot drafts the PR description, linking to the relevant issue (#123) and summarizing changes.
  - **Agent Role**: A **coding agent** commits changes to a branch and opens a PR. For example: "Push auth routes to branch and create PR with tests."

- **Test Stage**:
  - **Use Case**: Use PRs to run CI/CD pipelines (e.g., GitHub Actions) for automated testing and linting. Copilot can generate or update workflows.
  - **Copilot Integration**: Prompt: "Add GitHub Actions YAML to PR for Jest tests across Node versions." Or, in PR view (GitHub Pull Requests extension), ask: "@copilot review tests and suggest missing coverage."
  - **Agent Role**: A **testing subagent** runs tests in the PR, fixes failures, and updates the branch. Prompt: "Subagent: Ensure 80% test coverage in PR #456."
  - **Why PRs?**: Ensures code is vetted and stable before merging.

- **Deploy Stage**:
  - **Use Case**: PRs are the final step before deployment. Reviewers approve, and CI/CD deploys to staging/production after merge.
  - **Copilot Integration**: Prompt: "@copilot review PR #456 for security vulnerabilities." Copilot uses CodeQL to scan and suggest fixes (e.g., "Patch OAuth callback vuln"). Or: "Generate deployment script for AWS in PR."
  - **Agent Role**: A **security subagent** scans for risks, and a **deployment agent** triggers workflows post-merge. Prompt: "Deploy PR #456 to staging via Actions."
  - **Why PRs?**: Centralizes code review, automates checks, and ensures production-ready code.

- **Repeat Stage**:
  - **Use Case**: Post-merge, PRs provide a record of changes. If issues arise, reference the PR in new issues or rollbacks.
  - **Copilot Integration**: Prompt: "Summarize changes in PR #456 for next iteration." Agents analyze merged code for improvements.

### Key Differences and Workflow Integration
- **Issues** are for **ideation and tracking** (pre-coding or post-deploy). Use them to define tasks, discuss requirements, or log bugs. Copilot’s planning subagents excel at drafting and refining issues.
- **PRs** are for **code review and deployment** (post-coding). They integrate with CI/CD and Copilot’s coding/testing/security subagents to ship reliable code.
- **Workflow Fit**:
  - **Plan**: Create issues to outline tasks. Copilot’s planning subagent drafts them.
  - **Build**: Code in a branch, referencing issues. Agents push to PRs.
  - **Test**: Run tests in PRs via CI or testing subagents.
  - **Deploy**: Merge PRs after review; deploy via workflows or agents.
  - **Repeat**: Log new issues from production feedback; start new PRs for fixes.

### Best Practices
- **Link Issues to PRs**: Always reference issues in PRs (#issue) for traceability. Copilot auto-suggests links.
- **Use Agents Wisely**: Delegate issue creation to planning subagents and PR management to coding/security subagents. Monitor in **Agent Sessions view**.
- **Prompt Specificity**: For issues, say: "Draft issue for feature X with steps." For PRs, say: "Open PR for branch Y with CI setup."
- **Quotas**: Free tier limits agent actions (e.g., PR creation). Pro+ unlocks unlimited agent runs.
- **Safety**: PRs require human approval before CI runs, ensuring oversight.

### Example Workflow
1. **Plan**: Prompt: "Create issue for login page with React." Planning subagent opens issue #123.
2. **Build**: Prompt: "Implement login page from #123 in branch `feature/login`." Coding agent writes code, commits, and opens PR #456.
3. **Test**: Prompt: "Run Jest tests in PR #456." Testing subagent ensures coverage, fixes failures.
4. **Deploy**: Prompt: "@copilot review PR #456 for security." Security subagent scans, you merge, and deployment agent triggers staging deploy.
5. **Repeat**: Prompt: "Log issue for login performance issues from logs." Cycle restarts.

This approach leverages Copilot’s agents to streamline collaboration between issues (planning/tracking) and PRs (coding/deployment). For hands-on practice, try the VS Code Insiders tutorial with a sample repo. If you hit quota limits, check pricing at https://x.ai/grok.


### Planning Your PLM Backend Project with Supabase, BeProduct Integration, and Copilot Workflow

Based on your setup—a Supabase backend for a Product Lifecycle Management (PLM) system with OpenAPI spec, syncing BeProduct data (garments/products, color palettes, materials, timelines) via webhooks and edge functions, maintaining dates in Supabase, and future API enhancements—I'll outline a structured starting plan. This integrates GitHub Copilot (including agent mode) in VS Code for efficiency, drawing from best practices for repo organization, issue-driven development, and Supabase-specific workflows.

Your project sounds like a classic iterative build: start with schema and sync, then edge functions for bidirectional updates, and evolve to custom APIs. We'll focus on starting out, emphasizing traceability and Copilot delegation to accelerate.

#### 1. Plan Process and Where to Store Plans in the Repo
**Process Overview**: Adopt a lightweight GitHub Flow with Copilot assistance—plan high-level in docs, break into actionable issues, build/test in branches, review via PRs, deploy to Vercel (frontend) and Supabase (backend). Use iterative cycles: Weekly sprints for schema/sync, bi-weekly for edge functions, quarterly for API rewrites. Leverage Copilot's agent mode for autonomous subtasks (e.g., generating schema SQL) and subagents for specialties (e.g., a "Supabase schema subagent").

- **Step-by-Step Planning**:
  1. **High-Level Roadmap**: Brainstorm in Copilot Chat (VS Code: Ctrl+Alt+I): Prompt "Outline a 3-phase roadmap for Supabase PLM backend: Phase 1 schema + BeProduct sync; Phase 2 edge functions for timelines; Phase 3 custom APIs. Include milestones, risks (e.g., BeProduct API bugs), and Supabase best practices like RLS for data security."
  2. **Detailed Breakdown**: Use agent mode to refine: "In agent mode, generate a task tree for Phase 1, including Supabase table designs for products, materials, and timelines."
  3. **Review & Version**: Share draft in team chat or GitHub Discussion; iterate via Copilot feedback loop (e.g., "Refine plan for better error handling in webhooks").
  4. **Track Progress**: Link plans to GitHub Projects (board view for phases) for visualization—add issues as cards, automate with Actions (e.g., move to "Done" on PR merge).

- **Storage in Repo**:
  Store plans in a `/docs` folder for discoverability and version control—GitHub auto-renders Markdown. Structure:
  ```
  docs/
  ├── README.md          # Project overview, quickstart (e.g., "Clone, supabase db pull, npm install")
  ├── ROADMAP.md         # High-level phases, timelines (e.g., Phase 1: Q4 2025)
  ├── ARCHITECTURE.md    # Diagrams (use Mermaid for ERD: tables for products, materials, timelines with relations)
  ├── PHASE-1-PLAN.md    # Detailed tasks, schema sketches, webhook flows
  ├── SETUP.md           # Env vars, Supabase CLI setup, Vercel integration
  └── API-SPEC.md        # OpenAPI YAML for current/future endpoints
  ```
  Commit initial plans in a `main` branch PR for review. Use Copilot to generate: "Write a Markdown roadmap for my PLM project based on [paste your goals]." This keeps plans living docs, searchable via GitHub's code search.

#### 2. When to Raise Issues
Raise issues early and often for anything actionable—treat them as "tickets" for planning/tracking, not just bugs. Align with your phases to avoid overwhelm.

- **Triggers**:
  - **Planning/Start of Phase**: For milestones (e.g., "Design initial schema").
  - **Discovery/Research**: When clarifying unknowns (e.g., "Research BeProduct webhook payloads for garment data").
  - **Implementation Blocks**: During build (e.g., "Handle BeProduct API rate limits in edge function").
  - **Post-Deploy Feedback**: After Vercel/Supabase deploys (e.g., "Fix timeline sync lag").
  - **Future Goals**: Spike issues for experiments (e.g., "Prototype Supabase-only timeline API").

- **Guidelines**:
  - Keep issues small (1-2 days effort) for Copilot delegation.
  - Use labels: `phase-1`, `supabase`, `beproduct`, `enhancement`.
  - Templates: Create `.github/ISSUE_TEMPLATE/plm-task.md` with fields like "Description", "Acceptance Criteria", "Related Docs".
  - Threshold: If it's >1 sprint, break into sub-issues; reference parent issue.

Copilot shines here—prompt in chat: "Draft 5 issues for Phase 1 schema design, including AC like 'RLS policies for customer palettes'."

#### 3. How to Assign Copilot to Issues
With Copilot's coding agent (GA as of early 2025), assignment turns issues into autonomous tasks: The agent clones your repo, analyzes context (codebase, issue discussion, custom instructions in `.github/copilot-instructions.md`), implements in a branch, runs tests, and opens a PR. It's background-safe, no local disruption.

- **Prerequisites**:
  - Enable in GitHub Settings > Copilot > Coding Agent (requires Copilot Pro+ for unlimited runs; free tier limits to 5/week).
  - Install VS Code extensions: GitHub Copilot, GitHub Pull Requests.
  - Add repo instructions: e.g., "Use TypeScript, Supabase JS client, follow OpenAPI spec."

- **Steps**:
  1. **Create/Select Issue**: In VS Code sidebar (GitHub Issues view) or GitHub.com, open an issue.
  2. **Assign**: 
     - VS Code: Right-click issue > "Assign to Copilot" (or type `@copilot` in comments).
     - GitHub.com: In issue sidebar, add assignee `@github/copilot` (or `@copilot` in body/comment).
     - Chat Handoff: In Copilot Chat (agent mode), prompt "Delegate this to coding agent: [paste issue text]." It creates the issue if needed.
  3. **Monitor**: Agent notifies via comments/PRs. View progress in VS Code's Agent Sessions (Copilot sidebar) or GitHub notifications.
  4. **Interact**: Reply in issue/PR (e.g., "Add error logging")—agent iterates. For subagents: Prompt "Spawn subagent for webhook testing on issue #42."
  5. **Review/Merge**: Agent opens PR; use Copilot for auto-review ("@copilot review for Supabase RLS compliance").

- **Tips**: Start with simple issues (e.g., schema gen) to build trust. For Supabase, agent can invoke tools like `supabase gen types` via terminal. If stuck, fallback to interactive agent mode in VS Code for joint debugging.

#### 4. Examples of Issues Based on Your Plan
Here are 8 starter issues, grouped by phase. Each includes title, description snippet, labels, and Copilot-friendly AC. Create via Copilot: "Generate GitHub issues from this list."

- **Phase 1: Supabase Schema & Initial Sync**
  1. **Title**: Design Core Supabase Schema for PLM Entities  
     **Desc**: Define tables for garments/products, customer color palettes, material library, and timelines. Use PostgreSQL relations (e.g., products FK to materials). Include indexes for frequent queries (e.g., timeline dates).  
     **Labels**: `phase-1`, `supabase`, `schema`  
     **AC**: ERD Mermaid diagram in docs; SQL migrations; RLS policies for read/write by user role; Copilot: "Generate schema SQL and run `supabase db diff`."
     
  2. **Title**: Set Up BeProduct Webhook for Garment/Product Data Sync  
     **Desc**: Create Supabase edge function to receive BeProduct webhooks, validate payload (e.g., style ID, variants), upsert to products table. Handle auth/errors.  
     **Labels**: `phase-1`, `beproduct`, `webhook`  
     **AC**: Function deploys to Supabase; test with mock payload; logs errors to Supabase logs; 80% test coverage.
     
  3. **Title**: Research BeProduct API for Color Palettes & Materials  
     **Desc**: Document endpoints/payloads for palettes (e.g., hex codes, customer ID) and materials (e.g., fabric types, costs). Plan sync strategy (one-way initial).  
     **Labels**: `phase-1`, `research`  
     **AC**: Updated docs/PHASE-1-PLAN.md with examples; potential edge function stub.

- **Phase 2: Timeline Sync & Bidirectional Updates**
  4. **Title**: Implement Timeline Sync from BeProduct via Webhooks  
     **Desc**: Edge function to ingest time/action events, store dates in Supabase timelines table (e.g., milestones array or separate events table).  
     **Labels**: `phase-2`, `timeline`  
     **AC**: Syncs updates without overwriting local dates; unit tests for conflicts.
     
  5. **Title**: Build Edge Function to Write Timeline Updates Back to BeProduct  
     **Desc**: On Supabase insert/update (use DB triggers), call BeProduct API to push changes. Handle retries for buggy API.  
     **Labels**: `phase-2`, `edge-function`  
     **AC**: Trigger fires on timeline edits; API calls authenticated; error queue in Supabase.

- **Phase 3: API Enhancements (Future)**
  6. **Title**: Rewrite BeProduct API Wrapper in Supabase Edge Functions  
     **Desc**: Create OpenAPI-compliant endpoints proxying BeProduct calls, add caching (Supabase pgBouncer).  
     **Labels**: `phase-3`, `api`  
     **AC**: Swagger docs update; perf tests show <200ms latency.
     
  7. **Title**: Prototype Enhanced Timeline API in Supabase  
     **Desc**: New RPC/stored proc for advanced filtering (e.g., by date range, status), replacing BeProduct's limited features.  
     **Labels**: `phase-3`, `enhancement`  
     **AC**: Query examples in docs; benchmark vs. BeProduct.
     
  8. **Title**: Migrate to Full Supabase Timelines (Spike)  
     **Desc**: Assess feasibility of ditching BeProduct timelines; design data migration script.  
     **Labels**: `phase-3`, `spike`  
     **AC**: Migration POC; risk assessment in issue comments.

#### 5. Examples of Common Dev Steps from Here
Assuming you're starting from a fresh repo (`git init plm-backend`), here's a Copilot-accelerated flow for the first week (Phase 1 kickoff). Each step ~1-2 hours with agent help.

1. **Repo Setup (15 min)**: `gh repo create plm-backend --public`; clone. Add `/docs` structure via Copilot: "Generate initial docs folder with README and ROADMAP.md for Supabase PLM project." Commit/PR to main.
   
2. **Supabase Init (20 min)**: Install CLI (`npm i -g supabase`); `supabase init`; link project. Prompt Copilot agent: "Set up local Supabase env, generate .env with anon key." Run `supabase start`.

3. **Schema Design & Migrate (45 min)**: In VS Code, new issue #1 (from examples). Assign to Copilot: It generates SQL (e.g., `CREATE TABLE products (id UUID PRIMARY KEY, style_name TEXT, materials UUID[]);`), runs `supabase migration new init_schema`, applies. Review diffs in PR.

4. **First Webhook Edge Function (30 min)**: Issue #2. Agent mode: "Create edge function 'beproduct-sync' to handle POST webhook, upsert to products table using Supabase client." Test locally (`supabase functions serve`); deploy (`supabase functions deploy`).

5. **OpenAPI Spec Stub (15 min)**: Prompt: "Generate initial OpenAPI YAML for /products endpoint, integrated with Supabase." Add to `/docs/API-SPEC.md`; validate with `npx @redocly/cli build-docs`.

6. **Frontend Tie-In (20 min)**: In React/TS repo, use Supabase JS client: Copilot inline: "Add hook to fetch products from Supabase." Deploy to Vercel via `vercel --prod`.

7. **Test & Iterate (Ongoing)**: Run `npm test` (add Jest via agent); prompt "Generate unit tests for edge function." Close issue on PR merge; log learnings in docs.

8. **Weekly Review**: GitHub Project board—move cards; prompt Copilot: "Summarize Phase 1 progress, suggest next issues."

This gets you schema + basic sync live quickly. Risks: BeProduct API flakiness—mitigate with queues (e.g., Supabase cron jobs). For Supabase schema tips, use their Visual Designer for ERDs. Scale by delegating more to agents as you go. If quotas hit, check Pro+ at github.com/pricing. Let's iterate— what's your first issue to tackle?

### Clarifications on GitHub Issues and Templates for Your PLM Project

Thanks for the enthusiasm! Let’s address your questions about where issues are created, whether to use one or multiple issue templates, setup requirements before raising issues, and whether Copilot instructions are needed for agents to find templates. This builds on your Supabase PLM project with BeProduct integration, using GitHub Copilot in VS Code for an efficient workflow.

#### 1. Are Issues Created in Main?
Yes, issues are created in the **main repository** (not a specific branch like `main`), as issues in GitHub exist at the repository level, not tied to branches. They’re stored in the GitHub Issues tab and tracked globally for your project (`plm-backend`). Here’s how it fits your workflow:

- **Creation Process**:
  - **Manually**: Create issues via GitHub.com (Issues > New Issue) or VS Code’s GitHub Issues extension (sidebar: select repo, click “+”).
  - **Copilot-Assisted**: In Copilot Chat (Ctrl+Alt+I, agent mode), prompt: “Create issue for Supabase schema design with description and AC.” The agent posts to your repo’s Issues tab, referencing your codebase or `.github/copilot-instructions.md`.
  - **Agent Assignment**: Assign to `@github/copilot` in the issue or via chat: “Delegate issue #1 to coding agent.” The agent clones the repo, works in a new branch (e.g., `feature/schema`), and opens a PR linked to the issue.

- **Context for Main**:
  - Issues define tasks (e.g., “Design products table”) and are branch-agnostic. When you or Copilot’s agent implements, changes go into a feature branch (e.g., `git checkout -b feature/issue-1`), not `main` directly.
  - PRs from these branches target `main` for review/merge, ensuring `main` stays clean. Copilot’s PRs auto-link to issues (e.g., “Closes #1”).

- **Best Practice**: Keep issues in the main repo for visibility. If using multiple repos (e.g., `plm-backend` and `plm-frontend`), create issues in the relevant repo (backend for Supabase schema, frontend for React components). Copilot can cross-reference: “Link issue #2 in plm-frontend to #1 in plm-backend.”

#### 2. One Template or Many?
For your PLM project, **one primary template** (`plm-task.md`) is sufficient to start, but **multiple templates** can streamline different task types as the project scales. Here’s the breakdown:

- **Single Template (Recommended for Start)**:
  - Use `.github/ISSUE_TEMPLATE/plm-task.md` for all tasks (schema design, webhooks, edge functions, etc.). It’s flexible, covering your goals (schema, BeProduct sync, timelines, APIs).
  - **Why?**: Simplifies setup for a new project. One template reduces overhead while capturing key fields for Copilot to parse (e.g., Description, AC). You can refine later.
  - **Example Content**:
    ```markdown
    ---
    name: PLM Task
    about: Standard task for PLM backend/frontend development
    title: '[TASK] '
    labels: task
    assignees: ''

    ---

    **Description**
    <!-- Describe the task (e.g., create Supabase table for products) -->

    **Acceptance Criteria**
    - <!-- e.g., SQL migration applied via supabase CLI -->
    - <!-- e.g., Tests pass with 80% coverage -->

    **Related Docs**
    - <!-- e.g., Link to docs/PHASE-1-PLAN.md or API-SPEC.md -->

    **Priority**
    - [ ] High
    - [ ] Medium
    - [ ] Low

    **Phase**
    - [ ] Phase 1: Schema & Sync
    - [ ] Phase 2: Timelines
    - [ ] Phase 3: APIs
    ```
  - **Creation**: Prompt Copilot: “Generate a GitHub issue template named plm-task.md with fields for Description, AC, Related Docs, Priority, and Phase.” Commit to `.github/ISSUE_TEMPLATE/`.

- **Multiple Templates (Optional for Scaling)**:
  - Add templates for specific workflows as complexity grows (e.g., post-Phase 1). Examples:
    - `schema-task.md`: For Supabase table migrations, RLS policies.
    - `webhook-task.md`: For BeProduct sync, edge functions.
    - `bug-report.md`: For BeProduct API issues or timeline sync failures.
    - `spike.md`: For research (e.g., “Assess Supabase timeline migration”).
  - **Why?**: Tailors fields to task type (e.g., bugs need “Steps to Reproduce”). GitHub’s issue form lets users pick from a dropdown.
  - **Setup**: Create `.github/ISSUE_TEMPLATE/config.yml` to list templates:
    ```yaml
    blank_issues_enabled: false
    contact_links: []
    issue_templates:
      - filename: plm-task.md
        name: PLM Task
      - filename: bug-report.md
        name: Bug Report
    ```
  - **When to Add**: Start with one; split into multiple after ~10 issues if you notice repetitive patterns (e.g., schema vs. webhook tasks differ significantly).

- **Recommendation**: Begin with `plm-task.md` for simplicity. Add `bug-report.md` in Phase 2 if BeProduct’s API bugs pile up (likely, given “bug-ridden” note). Copilot can propose: “Generate a bug template for BeProduct API issues.”

#### 3. Setup Before Raising Issues?
Yes, minimal setup ensures Copilot and issues work smoothly. Do this before creating issues to streamline the workflow:

- **Repo Setup**:
  - Initialize: `gh repo create plm-backend --public; git clone`.
  - Folder Structure: Add `/docs` (README, ROADMAP, etc.) and `.github/`. Prompt Copilot: “Set up repo with docs folder and basic README for Supabase PLM.”
  - Supabase CLI: `npm i -g supabase; supabase init`. Commit `.supabase/` and `supabase/` configs.

- **Issue Template**:
  - Create `.github/ISSUE_TEMPLATE/plm-task.md` (see above). Commit to repo.
  - Why? Templates standardize issues, making Copilot’s parsing reliable (agents extract AC, priorities).

- **Copilot Setup**:
  - Install VS Code extensions: GitHub Copilot, GitHub Pull Requests, GitHub Issues.
  - Enable agent mode: VS Code Settings > Copilot > Enable Coding Agent (Pro+ needed for full access).
  - Authenticate: Sign into GitHub via VS Code (prompts on first Copilot use).

- **Optional but Helpful**:
  - `.github/copilot-instructions.md`: Add project context (e.g., “Use TypeScript, Supabase JS client v2, OpenAPI 3.0, Vercel for frontend”). Helps agents align code to your stack.
  - GitHub Projects: Set up a board for Phase 1 tasks. Link issues for tracking.
  - Supabase Project: Create on Supabase dashboard; link locally (`supabase login`).

- **Timing**: ~15 minutes. Do this post-repo creation, pre-issues. Issues without templates risk vague descriptions, slowing Copilot’s automation.

#### 4. Do I Need Copilot Instructions for Agents to Find Templates?
**Yes**, but it’s lightweight. Copilot’s coding agent automatically scans `.github/ISSUE_TEMPLATE/` for templates when creating or parsing issues, but adding instructions in `.github/copilot-instructions.md` ensures agents use them correctly and align with your project’s context.

- **Why Instructions Help**:
  - Templates alone define structure (e.g., AC field), but instructions tell agents how to interpret/fill them (e.g., “Always include Supabase RLS in schema AC”).
  - Without instructions, agents rely on defaults or prompt context, risking misalignment (e.g., missing TypeScript or OpenAPI standards).

- **Minimal Instructions Example**:
  ```markdown
  # Copilot Instructions for PLM Project

  **Project Context**:
  - Backend: Supabase (PostgreSQL, edge functions, JS client v2).
  - Frontend: Node.js/React/TypeScript on Vercel.
  - Integration: BeProduct PLM via webhooks/API (OpenAPI 3.0 spec).
  - Goals: Schema, sync, timelines, custom APIs.

  **Issue Handling**:
  - Use `.github/ISSUE_TEMPLATE/plm-task.md` for all tasks.
  - AC must include: Tests (80% coverage), Supabase RLS for security, error handling for BeProduct API.
  - Reference docs/ (e.g., ROADMAP.md, API-SPEC.md) in Related Docs.
  - Label by phase (e.g., `phase-1`, `supabase`).

  **Code Standards**:
  - TypeScript for all frontend/backend code.
  - Edge functions in Deno for Supabase.
  - OpenAPI YAML in docs/API-SPEC.md for endpoints.
  ```
  Commit to `.github/copilot-instructions.md`. Prompt Copilot: “Generate project instructions for Supabase PLM with TypeScript, include issue template guidance.”

- **How Agents Use It**:
  - When assigned (@github/copilot), agents read instructions to understand template fields and project rules.
  - Example: For issue “Design products table,” agent checks instructions, uses `plm-task.md`, adds RLS in AC, and generates TypeScript-compatible SQL.

- **Setup Need**: Create instructions before assigning issues to agents. Takes ~5 minutes. Update as project evolves (e.g., add Phase 2 rules).

- **Fallback**: If no instructions, agents still parse templates but may need more prompt specificity (e.g., “Use plm-task.md and add RLS”). Instructions save time.

#### Actionable Next Steps
1. **Setup (~20 min)**:
   - Create repo: `gh repo create plm-backend --public`.
   - Add `.github/ISSUE_TEMPLATE/plm-task.md` (use example above).
   - Add `.github/copilot-instructions.md` (use example above).
   - Commit: `git add .github; git commit -m "Setup issue template and Copilot instructions"; git push`.
   - Prompt Copilot: “Verify issue template and instructions are correct.”

2. **First Issue (~5 min)**:
   - In VS Code (GitHub Issues view), create issue using `plm-task.md`.
   - Example: “Design Supabase schema for products table” (from earlier examples).
   - Assign: “@github/copilot generate SQL for products table with RLS, commit to branch.”

3. **Agent Kickoff**:
   - In Copilot Chat (agent mode): “Delegate issue #1 to coding agent, follow instructions in copilot-instructions.md.”
   - Monitor PR in VS Code’s GitHub Pull Requests view.

#### Notes
- **Single Template Start**: Stick with `plm-task.md` for now—covers schema, webhooks, and timelines. Add `bug-report.md` if BeProduct API issues arise.
- **Setup Priority**: Do repo/template/instructions before issues to maximize Copilot’s automation. Without templates, issues may lack structure, slowing agents.
- **Quota Check**: Free tier limits agent runs (~5/week). Pro+ unlocks unlimited; check github.com/pricing if needed.
- **Supabase Tip**: Use `supabase gen types typescript` after schema creation for TypeScript types in React. Copilot can automate: “Generate Supabase types for products table.”

What’s your first issue to create, or want help drafting one in VS Code?