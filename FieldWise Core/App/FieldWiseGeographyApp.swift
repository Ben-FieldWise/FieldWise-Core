import SwiftUI

@main
struct FieldWiseGeographyApp: App {
    init() {
        // Supabase is initialised lazily via SupabaseManager.shared on
        // first use — no explicit configure() step needed at launch.
        // Start the offline sync engine: monitors connectivity and
        // flushes any fieldwork entries queued while offline.
        EntrySync.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}
