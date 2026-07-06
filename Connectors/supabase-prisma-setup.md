# Supabase + Prisma — Step-by-Step Setup

Follow top to bottom. Assumes Node.js is installed.

---

## 1. Create the Supabase project
1. Go to https://supabase.com → sign in → **New project**.
2. Name it (e.g. `fieldwise`), set a **database password** (save it — you'll need it), pick a region close to your users (Sydney for AU).
3. Wait for it to finish provisioning (~2 min).

## 2. Get your two connection strings
Supabase → **Project Settings → Database → Connection string**. You need **both**:

- **Pooled** (Transaction mode, port `6543`) — for the app at runtime.
- **Direct** (Session mode, port `5432`) — for running migrations.

They look like:
```
# Pooled  → DATABASE_URL
postgresql://postgres.[ref]:[PASSWORD]@aws-0-[region].pooler.supabase.com:6543/postgres?pgbouncer=true

# Direct  → DIRECT_URL
postgresql://postgres.[ref]:[PASSWORD]@aws-0-[region].pooler.supabase.com:5432/postgres
```

## 3. Install Prisma (if not already)
In your project folder:
```
npm install prisma --save-dev
npm install @prisma/client
```

## 4. Add your `.env`
Create `.env` in the project root (never commit it — add to `.gitignore`):
```
DATABASE_URL="...your POOLED string, port 6543..."
DIRECT_URL="...your DIRECT string, port 5432..."
```

## 5. Point the datasource at both URLs
In `schema.prisma`, update the datasource block to use the direct URL for migrations:
```prisma
datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")   // pooled — app runtime
  directUrl = env("DIRECT_URL")     // direct — migrations
}
```
(Put the `schema.prisma` we built into `prisma/schema.prisma`.)

## 6. Create the tables
```
npx prisma migrate dev --name init_fieldwork
```
This reads the models, generates a migration, and creates every table in Supabase.
Check it worked: Supabase → **Table Editor** — you should see School, User, Template,
StudySite, Section, QuestionBlock, Assignment, FieldworkInstance, Response, MediaAsset, Report.

## 7. Generate the typed client
```
npx prisma generate
```
Now your app code can `import { PrismaClient }` with full type-safety.

## 8. Seed the first booklet (Phillip Island)
1. Create `prisma/seed.ts` (I can generate this for you — it inserts the whole booklet).
2. Register it in `package.json`:
```json
"prisma": { "seed": "ts-node prisma/seed.ts" }
```
   (install the runner: `npm install -D ts-node typescript @types/node`)
3. Run it:
```
npx prisma db seed
```

## 9. Use it in your app
```ts
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

const template = await prisma.template.findFirst({
  include: { sites: true, sections: { include: { blocks: true } } },
});
```

## 10. Handy checks
- `npx prisma studio` → visual browser of your data at http://localhost:5555
- Changed the schema? → `npx prisma migrate dev --name <change>` again.

---

## What Supabase gives you beyond the database (wire up later)
- **Auth** — teacher/student login. Map Supabase `auth.users` → your `User` row.
- **Storage** — buckets for site photos & sketch-map exports (`MediaAsset.bucketKey`).
- **Row Level Security** — so a student only sees their own instance. Turn RLS on per table in the dashboard once auth is in.

## Still to decide
- **Client framework** (React Native / Flutter / web) → picks the offline-sync library (PowerSync or WatermelonDB). Everything above is identical regardless.
