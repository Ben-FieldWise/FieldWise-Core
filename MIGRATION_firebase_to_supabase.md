# FieldWise: Firebase → Supabase Migration Plan

Goal: move the SwiftUI app off Firebase (Auth + Firestore) onto Supabase, using the
`supabase-swift` SDK and the RLS-protected Postgres database. Reuse the app's existing
data model rather than forcing it onto the booklet schema.

## Guiding decision
**Supabase mirrors the app's current Firestore model**, so the Swift changes stay small:
`schools`, `users`, `classes`, `fieldworkTasks`, `fieldworkEntries`. The booklet tables
(Template/Section/QuestionBlock/Response) become a *later* feature that maps a
FieldworkTask to a structured booklet — that's the original "integrate the teacher's
booklet" goal, done after the app is stable on Supabase.

---

## Phase 0 — Align the database to the app's models  *(DB work, I can do this)*
Create Supabase tables that match the Swift `Codable` structs so PostgREST decodes
straight into them:
- `schools(id, name, created_at)`
- `users(id = auth uid, role, school_id, display_name, class_id, created_at)`
- `classes(id, teacher_id, school_id, name, class_code UNIQUE, active, created_at)`
- `fieldwork_tasks(id, class_id, title, instructions, created_at)`
- `fieldwork_entries(id = client UUID, task_id, class_id, student_uid, student_display_name,
  status, gps jsonb, notes, soil_colour jsonb, weather jsonb, photo_storage_paths text[],
  client_created_at, server_created_at, updated_at)`
- RLS: student reads/writes only their own entries + their class's tasks; teacher manages
  their classes. (Same pattern as the policies already written.)
- A `join_class_by_code(code)` RPC so students join without reading the whole classes table.
> Note: the earlier booklet tables can stay in the DB unused for now, or be dropped and
> reintroduced in the booklet phase. They don't conflict.

## Phase 1 — Add the SDK & client  *(you in Xcode + done)*
- Xcode → Add Package Dependencies → `https://github.com/supabase/supabase-swift`.
- `SupabaseManager.swift` is already added (client wired with your URL + publishable key).
- Remove the Firebase packages once Phases 2–3 compile.

## Phase 2 — Rewrite AuthService against Supabase Auth
- Teacher email/password → `client.auth.signUp/signIn(email:password:)`.
- Student anonymous join → `client.auth.signInAnonymously()` then call the
  `join_class_by_code` RPC and insert the `users` row (role=student, display_name, class_id).
- Replace the Firebase `addStateDidChangeListener` with `client.auth.authStateChanges`.
- `currentUserProfile` now loads from the `users` table.

## Phase 3 — Replace FirestoreService with SupabaseService
- Swap each Firestore call for a PostgREST call: `client.from("users").select()...`,
  `.insert(...)`, `.update(...)`, `.eq("id", ...)`.
- Keep the same method signatures (`fetchUserProfile`, `createUserProfile`,
  `findOrCreateSchool`, task/entry CRUD) so the rest of the app is untouched.

## Phase 4 — Offline capture  *(the one real gap vs Firestore)*
Firestore gave offline for free; Supabase does not out of the box. Options:
- Ship Phase 1–3 online-only first (fine for demos), OR
- Add a local store (GRDB / SwiftData) as a write queue that syncs on reconnect, OR
- Adopt PowerSync's Swift SDK for automatic offline sync.
Decide this after the online path works.

## Phase 5 — Storage & cleanup
- Field photos → Supabase Storage buckets (replace `photoStoragePaths` semantics).
- Remove Firebase SDK, `GoogleService-Info.plist`, `FIRESTORE_RULES.md`.

---

## What only you can do
I can write Swift and run all the Supabase/DB changes, but I can't compile or run the app —
that's Xcode on your Mac. So the rhythm is: I make a phase's changes → you build & run →
we fix what the compiler/sim surfaces → next phase.

## Recommended order to start
Phase 0 (I align the DB now) → Phase 1 (you add the SPM package) → Phase 2 (I rewrite Auth) →
you build and test the teacher + student login → continue.
