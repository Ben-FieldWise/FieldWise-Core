# Getting Prisma Working with the FieldWise Supabase DB

The tables, seed data, auth and RLS already exist in Supabase
(project `yhhvkvacykksopurzpmj`, region ap-southeast-2). So we **introspect** the live
database rather than migrate into it. Work through these in order.

---

## 1. Install Prisma (in your app project root)
```
npm install prisma --save-dev
npm install @prisma/client
```

## 2. Get your two connection strings from Supabase
Dashboard → Project Settings → Database → Connection string. You need BOTH:
- **Pooled** (port 6543) → runtime `DATABASE_URL`
- **Direct** (port 5432) → migrations `DIRECT_URL`

For your project they look like this (swap in your DB password):
```
# DATABASE_URL (pooled, port 6543)
postgresql://postgres.yhhvkvacykksopurzpmj:[PASSWORD]@aws-0-ap-southeast-2.pooler.supabase.com:6543/postgres?pgbouncer=true

# DIRECT_URL (direct, port 5432)
postgresql://postgres.yhhvkvacykksopurzpmj:[PASSWORD]@aws-0-ap-southeast-2.pooler.supabase.com:5432/postgres
```
`[PASSWORD]` = the database password you set when creating the project.
(Reset it under Settings → Database → Database password if you've lost it.)

## 3. Create `.env` in the project root
```
DATABASE_URL="...pooled string from step 2..."
DIRECT_URL="...direct string from step 2..."
```
Add `.env` to `.gitignore` — never commit it.

## 4. Create `prisma/schema.prisma` with the datasource + generator
If you don't already have the file, create `prisma/schema.prisma`:
```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}
```
(Leave the models out — the next step fills them in from the live DB.)

## 5. Introspect the live database
```
npx prisma db pull
```
This reads the 12 existing tables + enums from Supabase and writes all the `model`
and `enum` blocks into `prisma/schema.prisma` automatically. You now have a schema
that exactly matches what's deployed — no hand-copying.

## 6. Generate the typed client
```
npx prisma generate
```
Your app can now `import { PrismaClient } from "@prisma/client"` with full types.

## 7. Sanity-check the connection
```
npx prisma studio
```
Opens http://localhost:5555 — you should see School, User, Template, StudySite,
Section, QuestionBlock, Assignment, FieldworkInstance, Response, MediaAsset, Report,
Invite, with the Phillip Island booklet and demo data in them.

## 8. Use it in code
```ts
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

// Load the whole booklet with sites + sections + blocks:
const template = await prisma.template.findFirst({
  include: {
    sites: { orderBy: { order: "asc" } },
    sections: {
      orderBy: { order: "asc" },
      include: { blocks: { orderBy: { order: "asc" } } },
    },
  },
});
```

---

## Important: Prisma vs. Row Level Security
RLS is ON for the per-student tables. Prisma connects with the Postgres role in your
connection string, which **bypasses RLS**. That matters for how you architect:

- **Server-side code (trusted)** — use Prisma with the pooled connection. It sees all
  rows; enforce access in your own code. Fine for API routes / server actions.
- **Client-side / per-user access** — do NOT ship the Prisma connection string to the
  browser. For user-scoped reads/writes from the client, use the **supabase-js** client
  with the user's auth token, so RLS applies. Common pattern: Prisma for admin/teacher
  server logic + supabase-js for student-facing reads/writes.

## Optional: bring migrations under Prisma control later
Introspection gives you the schema but no migration history. When you want Prisma to
own future changes, baseline the current state once:
```
mkdir -p prisma/migrations/0_init
npx prisma migrate diff --from-empty \
  --to-schema-datamodel prisma/schema.prisma --script > prisma/migrations/0_init/migration.sql
npx prisma migrate resolve --applied 0_init
```
After that, `npx prisma migrate dev --name <change>` works normally.
⚠️ Note: future Prisma migrations won't recreate the RLS policies / auth trigger
(Prisma doesn't manage those) — keep those as separate SQL you apply via Supabase.

---

## Quick checklist
- [ ] `npm install prisma @prisma/client`
- [ ] Copy pooled + direct connection strings
- [ ] `.env` with `DATABASE_URL` + `DIRECT_URL`
- [ ] `prisma/schema.prisma` with datasource (directUrl) + generator
- [ ] `npx prisma db pull`
- [ ] `npx prisma generate`
- [ ] `npx prisma studio` to verify
