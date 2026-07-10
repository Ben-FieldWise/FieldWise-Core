//
//  SupabaseManager.swift
//  FieldWise Core
//
//  Central Supabase client for the app — replaces the Firebase stack.
//  Add the SDK first: in Xcode → File → Add Package Dependencies →
//  https://github.com/supabase/supabase-swift  (product: "Supabase").
//
//  Uses the PUBLISHABLE key (safe to ship in the app). All row access is
//  gated server-side by the RLS policies already deployed on the project,
//  so the client only ever sees data the signed-in user is allowed to see.
//

import Foundation
import Supabase

nonisolated enum SupabaseConfig {
    static let url = URL(string: "https://yhhvkvacykksopurzpmj.supabase.co")!
    // Publishable (client-safe) key. NOT the service_role key — never ship that.
    static let publishableKey = "sb_publishable_eI8UPkGYeoO2-gobQI8lvQ_q7YN6_Zs"
}

/// App-wide singleton. Access the client with `SupabaseManager.shared.client`.
/// `nonisolated` so the immutable, Sendable client can be reached from any
/// actor (e.g. `EntrySync`) as well as the main actor.
nonisolated final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }

    /// Completes an auth redirect that deep-links back into the app via the
    /// `fieldwisecore://` URL scheme — e.g. tapping the confirmation link in a
    /// sign-up email. Exchanges the code in the URL for a session and stores
    /// it; supabase-swift then emits an auth-state change that AuthService
    /// observes to load the profile and show the signed-in tabs.
    func handleOpenURL(_ url: URL) async {
        do {
            _ = try await client.auth.session(from: url)
        } catch {
            #if DEBUG
            print("[SupabaseManager] deep-link auth failed for \(url): \(error)")
            #endif
        }
    }
}
