//
//  AuthService.swift
//  FieldWise Core
//
//  Supabase-backed auth (migrated off Firebase). Two sign-in paths:
//    • students authenticate anonymously (device = identity) then join a
//      class by code, writing a `users` row with their first name;
//    • teachers authenticate with a real email + password.
//
//  Row access is enforced by the RLS policies deployed on the project;
//  this class only owns who is signed in and the verbs to become signed
//  in (or out). It talks to Supabase directly via SupabaseManager.
//
//  NOTE (uid casing): Postgres `auth.uid()::text` is lowercase, so we
//  ALWAYS lowercase the Swift UUID string when reading/writing `users.id`
//  — otherwise RLS `id = auth.uid()::text` checks would silently fail.
//

import Foundation
import Supabase
import Combine

enum AuthError: LocalizedError {
    case notSignedIn
    case profileNotFound
    case classCodeNotFound
    case classInactive

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You're not signed in."
        case .profileNotFound: return "Couldn't find your account details. Try signing in again."
        case .classCodeNotFound: return "That class code doesn't match any active class. Double-check it with your teacher."
        case .classInactive: return "That class code is no longer active. Ask your teacher for a current code."
        }
    }
}

@MainActor
final class AuthService: ObservableObject {

    /// The raw Supabase auth user, if any. Prefer `currentUserProfile`
    /// for anything app-specific (role, classId, displayName).
    @Published var authUser: Supabase.User?

    /// The matching `users` row for whoever's signed in. nil while
    /// loading, or if sign-in succeeded but the profile row hasn't been
    /// created/fetched yet (normal mid-join).
    @Published var currentUserProfile: UserProfile?

    @Published var isLoading = false
    @Published var lastError: String?

    private let client = SupabaseManager.shared.client
    private var authListener: Task<Void, Never>?

    var uid: String? { authUser?.id.uuidString.lowercased() }
    var isSignedIn: Bool { authUser != nil }

    init() {
        authUser = client.auth.currentUser
        if let uid { Task { await refreshProfile(uid: uid) } }

        // Mirror Firebase's addStateDidChangeListener.
        authListener = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in client.auth.authStateChanges {
                self.authUser = session?.user
                if let user = session?.user {
                    await self.refreshProfile(uid: user.id.uuidString.lowercased())
                } else {
                    self.currentUserProfile = nil
                }
            }
        }
    }

    deinit { authListener?.cancel() }

    @discardableResult
    private func refreshProfile(uid: String) async -> Bool {
        do {
            let profile: UserProfile = try await client
                .from("users").select().eq("id", value: uid).single().execute().value
            currentUserProfile = profile.with(id: uid)
            return true
        } catch {
            // No profile row yet is normal mid-join (a student who has
            // authenticated but not been inserted). For a teacher sign-in
            // it means the lookup was blocked (RLS) or the row is missing
            // — the caller decides whether to surface that.
            currentUserProfile = nil
            #if DEBUG
            print("[AuthService] refreshProfile(\(uid)) failed: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Teacher sign-up / sign-in

    func teacherSignUp(email: String, password: String, displayName: String, schoolName: String) async {
        isLoading = true; lastError = nil
        defer { isLoading = false }
        do {
            let res = try await client.auth.signUp(email: email, password: password)
            // If email confirmation is enabled, there's no session yet.
            guard let session = res.session else {
                lastError = "Check your email to confirm your account, then sign in."
                return
            }
            let uid = session.user.id.uuidString.lowercased()
            let schoolId = try await findOrCreateSchool(named: schoolName)
            try await insertUser(id: uid, role: "teacher", schoolId: schoolId, displayName: displayName, classId: nil)
            currentUserProfile = UserProfile.newTeacher(displayName: displayName, schoolId: schoolId).with(id: uid)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func teacherSignIn(email: String, password: String) async {
        isLoading = true; lastError = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            let loaded = await refreshProfile(uid: session.user.id.uuidString.lowercased())
            if !loaded {
                lastError = "Signed in, but your profile couldn’t be loaded. If you just created this account, confirm your email first — otherwise check the users table and its select policy in Supabase."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Student join-by-class-code

    func studentJoin(classCode: String, firstName: String) async {
        isLoading = true; lastError = nil
        defer { isLoading = false }
        do {
            let trimmedCode = classCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedCode.isEmpty, !trimmedName.isEmpty else { return }

            let cls = try await findActiveClass(byCode: trimmedCode)

            let uid: String
            if let existing = client.auth.currentUser {
                uid = existing.id.uuidString.lowercased()
            } else {
                let session = try await client.auth.signInAnonymously()
                uid = session.user.id.uuidString.lowercased()
            }

            try await insertUser(id: uid, role: "student", schoolId: cls.schoolId, displayName: trimmedName, classId: cls.id)
            currentUserProfile = UserProfile.newStudent(displayName: trimmedName, schoolId: cls.schoolId, classId: cls.id).with(id: uid)
        } catch {
            lastError = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Sign out

    func signOut() {
        Task {
            do {
                try await client.auth.signOut()
                authUser = nil
                currentUserProfile = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Supabase data helpers (auth-adjacent; full data layer lands in Phase 3)

    private struct SchoolRow: Decodable { let id: String }
    private struct ClassLite: Decodable { let id: String; let name: String; let schoolId: String }
    private struct UserInsert: Encodable { let id: String; let role: String; let schoolId: String; let displayName: String; let classId: String? }
    private struct SchoolInsert: Encodable { let name: String }
    private struct CodeParam: Encodable { let code: String }

    private func insertUser(id: String, role: String, schoolId: String, displayName: String, classId: String?) async throws {
        try await client.from("users")
            .insert(UserInsert(id: id, role: role, schoolId: schoolId, displayName: displayName, classId: classId))
            .execute()
    }

    private func findOrCreateSchool(named name: String) async throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing: [SchoolRow] = try await client
            .from("schools").select("id").eq("name", value: trimmed).limit(1).execute().value
        if let first = existing.first { return first.id }
        let created: SchoolRow = try await client
            .from("schools").insert(SchoolInsert(name: trimmed)).select("id").single().execute().value
        return created.id
    }

    /// Uses the `join_class_by_code` RPC (SECURITY DEFINER) so a student
    /// can resolve a code without reading the whole classes table.
    private func findActiveClass(byCode code: String) async throws -> ClassLite {
        let rows: [ClassLite] = try await client
            .rpc("join_class_by_code", params: CodeParam(code: code)).execute().value
        guard let cls = rows.first else { throw AuthError.classCodeNotFound }
        return cls
    }
}

