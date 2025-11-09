# Supabase API Reference Digest

_Last reviewed: 2025-10-23_

Curated notes from official Supabase documentation covering the REST Data API, GraphQL preview, Edge Functions, realtime messaging, and security controls. Use this as the canonical quick-reference when designing migrations, endpoints, or integration flows for the tracking project.

## Quick links

| Topic | Purpose | Documentation |
| --- | --- | --- |
| GraphQL preview | Field selection, pagination, limitations | <https://supabase.com/docs/guides/graphql>
| REST Data API basics | Verb semantics, headers, filtering | <https://supabase.com/docs/guides/api/quickstart>
| SQL-to-REST translator | Map SQL queries to PostgREST syntax | <https://supabase.com/docs/guides/api/sql-to-rest>
| HTTP method routing for Edge Functions | Implement multi-route REST handlers | <https://supabase.com/docs/guides/functions/http-methods>
| Invoking PostgreSQL functions via REST | RPC payload format and endpoints | <https://supabase.com/docs/guides/api/sql-to-rest#calling-postgresql-functions>
| Realtime broadcast RPC | Publish messages over REST | <https://supabase.com/docs/guides/realtime/broadcast>
| RLS with `auth.uid()` | Enforce per-user access in REST/GraphQL | <https://supabase.com/docs/guides/ai/rag-with-permissions>
| Additional API hardening (rate limits, custom keys) | Pre-request hooks, rate limiting | <https://supabase.com/docs/guides/api/securing-your-api>
| Management API | Project automation & metadata access | <https://supabase.com/docs/docs/ref/api>

## GraphQL essentials

- Supabase GraphQL is generated from tables/views; ensure we expose only vetted analytics views.
- Default queries return scalar JSON for nested objects—normalize `json` columns client-side.
- Always specify ordering (`order_by`) plus `limit`/`offset` for deterministic pagination.
- Mutations against base tables respect RLS; restrict write access to service accounts when using GraphQL.
- Realtime subscriptions are table-only—subscribe to `tracking.plan_style_timelines` / `tracking.plan_material_timelines` when dashboards need live updates, then recompute aggregates locally.

## REST (PostgREST) patterns

- All endpoints live under `/rest/v1/<table-or-view>` with filtering via query parameters (`?plan_id=eq.<uuid>`).
- Include both `apikey` and `Authorization: Bearer` headers on every request, even for server-to-server integrations.
- Inserts/updates: send `Prefer: return=representation` to receive updated rows; combine with `Prefer: resolution=merge-duplicates` on upserts.
- Bulk updates work by filtering the collection and issuing `PATCH` with a JSON body (merges columns by default).
- Expect error payloads containing `code`, `message`, `details`; Edge Functions should translate these into user-facing messages.
- Use range headers for pagination (`Range: 0-99`) and `Prefer: count=exact` (or `estimated`) based on performance needs.
- ETag headers allow conditional requests (`If-None-Match`) when polling high-volume grids.

## RPC invocation via REST

- Call functions through `/rest/v1/rpc/<function_name>` with a `POST` request containing a JSON body whose keys match function parameters.
- Prefer parameter prefixes (`p_`) inside SQL definitions to avoid collisions with reserved words.
- Functions returning composite data should emit `jsonb` for the smoothest serialization back to clients.
- For heavy payloads (e.g., UUID arrays), use RPCs to bypass PostgREST URL-length constraints.

## Edge Function routing & gateways

- Edge Functions can fan out based on HTTP method/path, enabling a single deployment to serve multiple REST endpoints.
- Be mindful of cold starts: consolidate related routes into a single handler when possible, as shown in the Supabase `http-methods` guide.
- Proxying to PostgREST (`fetch('http://rest:3000/rest/v1/...')`) allows custom auth or payload auditing before data reaches the client.

## Realtime messaging

- Publish broadcast events via the `rpc/broadcast` endpoint with a service-role key when server-side systems need to notify subscribers.
- Payloads are arbitrary JSON; include metadata (plan/style identifiers) so clients can scope updates efficiently.

## Security & hardening

- Enable RLS on every exposed table/view and rely on `auth.uid()` to scope data by user or brand claims.
- Use PostgREST pre-request hooks (`pgrst.db_pre_request`) to enforce custom API keys or rate-limiting logic for `anon` role traffic.
- Capture IP-based throttling data in a dedicated schema (e.g., `private.rate_limits`) and raise `PGRST` exceptions when thresholds exceed limits.
- Maintain separate service-role credentials for imports, template management, and analytics batch jobs.

## Management & automation notes

- Management API calls (project list, deployment automation) require a personal access token in the `Authorization: Bearer` header.
- Treat management tasks as out-of-band workflows; never embed management tokens in client applications.

---
Document steward: **Tracking Platform Team**. Update alongside migration design or when Supabase documentation evolves.
