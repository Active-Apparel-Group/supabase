# Supabase Developer Reference

This document provides a comprehensive overview of Supabase, its platform features, and developer usage patterns. It includes code snippets, SQL examples, and best practices for authentication, database operations, storage, realtime, edge functions, and AI/vector search.

---


## Contents
- Introduction
- Client Initialization (Browser & Server)
- Authentication (Email/Password, OAuth)
- Database Operations (CRUD, RLS)
- Storage (File Upload, Access Policies)
- Realtime (Subscriptions, Broadcast, Presence)
- Edge Functions (Basic, Auth Context, OpenAI Integration)
- Vector Search & AI
- Configuration & Environment
- Local Development & CLI
- Summary
- [Canonical Migration/Function Index](../../supabase/MIGRATION_FUNCTION_INDEX.md)

---


---

## Introduction
Supabase is an open-source backend-as-a-service platform built on PostgreSQL. It provides:
- Managed Postgres database
- Auth (JWT, OAuth, SSO)
- Auto-generated REST & GraphQL APIs
- Realtime subscriptions
- File storage (S3-compatible)
- Edge Functions (serverless, Deno)
- Vector/AI search

Supabase is designed for developer productivity, with a local-first workflow and full control over your data.

---

## Client Initialization (Browser & Server)

**JavaScript/TypeScript:**
```js
import { createClient } from '@supabase/supabase-js'
const supabase = createClient('https://your-project.supabase.co', 'public-anon-key')
```

**TypeScript with Types:**
```ts
import { Database } from './database.types'
const supabase = createClient<Database>(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY)
```

**Next.js (Server/Client):**
Use `@supabase/ssr` for cookie-based auth in server components.

---

## Authentication (Email/Password, OAuth)

**Email/Password:**
```js
const { data, error } = await supabase.auth.signUp({ email, password })
```
**OAuth:**
```js
const { data, error } = await supabase.auth.signInWithOAuth({ provider: 'github' })
```
**RLS Policies:**
Enable Row Level Security and write policies for fine-grained access control.
```sql
alter table profiles enable row level security;
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);
```

---

## Database Operations (CRUD, RLS)

**Select:**
```js
const { data, error } = await supabase.from('posts').select('*').eq('published', true)
```
**Insert:**
```js
const { data, error } = await supabase.from('posts').insert({ title: 'Hello', content: 'World' })
```
**Update:**
```js
const { data, error } = await supabase.from('posts').update({ published: true }).eq('id', 1)
```
**Delete:**
```js
const { error } = await supabase.from('posts').delete().eq('id', 1)
```

---

## Storage (File Upload, Access Policies)

**Upload:**
```js
const { data, error } = await supabase.storage.from('avatars').upload('public/avatar1.png', file)
```
**Get Public URL:**
```js
const { data } = supabase.storage.from('avatars').getPublicUrl('public/avatar1.png')
```
**Policies:**
```sql
create policy "Avatar images are publicly accessible" on storage.objects for select using (bucket_id = 'avatars');
```

---

## Realtime (Subscriptions, Broadcast, Presence)

**Subscribe to changes:**
```js
const channel = supabase.channel('posts').on('postgres_changes', { event: '*', schema: 'public', table: 'posts' }, (payload) => console.log(payload)).subscribe()
```
**Broadcast:**
```js
channel.send({ type: 'broadcast', event: 'message', payload: { text: 'Hello' } })
```
**Presence:**
```js
channel.track({ user_id: '123', status: 'online' })
```

---

## Edge Functions (Basic, Auth Context, OpenAI Integration)

**Basic Function:**
```ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
serve((req) => new Response('Hello from Edge!'))
```
**With Supabase Client:**
```ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_ANON_KEY'))
```
**OpenAI Integration:**
Call OpenAI API from Edge Function using fetch and secrets.

---

## Vector Search & AI

**Enable pgvector:**
```sql
create extension if not exists vector;
```
**Table with vector column:**
```sql
create table documents (id bigserial primary key, content text, embedding vector(1536));
```
**Semantic search:**
```js
const { data, error } = await supabase.rpc('match_documents', { query_embedding, match_count: 5 })
```

---

## Configuration & Environment

**.env Example:**
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```
**config.toml:**
Reference env vars for secrets (e.g., OAuth keys).
```toml
[auth.external.github]
enabled = true
client_id = "env(GITHUB_CLIENT_ID)"
secret = "env(GITHUB_SECRET)"
```

---

## Local Development & CLI

**Install CLI:**
```sh
npm install -g supabase
```
**Initialize project:**
```sh
supabase init
```
**Start local stack:**
```sh
supabase start
```
**Create migration:**
```sh
supabase migration new create_posts_table
```
**Apply migrations:**
```sh
supabase db push
```
**Generate types:**
```sh
supabase gen types typescript --local > types/database.ts
```
**Run Edge Functions locally:**
```sh
supabase functions serve
```
**Deploy to production:**
```sh
supabase link --project-ref your-project-ref
supabase db push
supabase functions deploy function-name
```
**Stop local Supabase:**
```sh
supabase stop
```

---

## Summary

Supabase provides a modern, open-source backend platform with a local-first workflow, strong type safety, and a developer-friendly CLI. It is ideal for teams who want to move fast, iterate locally, and deploy confidently to production.

---


## Canonical Migration/Function Index

All SQL migrations and Edge Function code/scripts are centralized in the main `supabase/` folder. See the [Migration and Function Index](../../supabase/MIGRATION_FUNCTION_INDEX.md) for a complete, up-to-date list of canonical code/script locations. Documentation and planning files reference these canonical locations to ensure a single source of truth.

**Best Practices:**
- Use GitHub for version control and CI/CD.
- Keep all schema and migrations in version control.
- Use `.env` for secrets, never commit real keys.
- Use the Supabase CLI for all DB and function changes.
- Document onboarding and workflows in `/docs`.
- Use branches and PRs for all changes.

For more, see: https://supabase.com/docs/guides/local-development
