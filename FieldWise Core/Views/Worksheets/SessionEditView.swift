//
//  SessionEditView.swift
//  FieldWise Core
//
//  Teacher-facing: edit an existing session — reassign its class, change
//  its join code, toggle active/closed, or delete it outright. Pushed
//  from a session row's edit action in SessionsView / AllSessionsView.
//
//  Also hosts ClassPickerSheet (non-private, shared with SessionsView's
//  "create a session" flow) since both screens need the same "pick one
//  of my classes" picker.
//

import SwiftUI

struct SessionEditView: View {
    let session: FieldworkSession
    @ObservedObject var store: SessionStore
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @StateObject private var classroomStore = ClassroomStore()

    @State private var selectedClass: SchoolClass?
    @State private var sessionCode: String
    @State private var showingClassPicker = false
    @State private var confirmDelete = false
    @State private var responseCountForDelete: Int?
    @State private var isCheckingResponses = false
    @State private var isSaving = false

    init(session: FieldworkSession, store: SessionStore) {
        self.session = session
        self.store = store
        _sessionCode = State(initialValue: session.sessionCode)
    }

    var body: some View {
        Form {
            Section("Class") {
                Button {
                    showingClassPicker = true
                } label: {
                    HStack {
                        Text("Class")
                        Spacer()
                        Text(selectedClass?.name ?? "Choose a class")
                            .foregroundColor(selectedClass == nil ? .secondary : .primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .foregroundColor(.primary)
            }

            Section("Join code") {
                TextField("Session code", text: $sessionCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            }

            Section("Status") {
                HStack {
                    Text(session.isActive ? "Active" : "Closed")
                    Spacer()
                    Button(session.isActive ? "Close session" : "Reopen session") {
                        Task {
                            if session.isActive { await store.closeSession(session) }
                            else { await store.reopenSession(session) }
                            dismiss()
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await prepareDelete() }
                } label: {
                    if isCheckingResponses {
                        ProgressView()
                    } else {
                        Text("Delete session")
                    }
                }
                .disabled(isCheckingResponses)
            }
        }
        .navigationTitle("Edit Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { Task { await save() } }
                    .fontWeight(.semibold)
                    .disabled(selectedClass == nil || sessionCode.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .task {
            if let uid = authService.uid { await classroomStore.loadTeacherClasses(teacherId: uid) }
            if let classId = session.classId {
                selectedClass = classroomStore.classes.first { $0.id == classId }
            }
        }
        .sheet(isPresented: $showingClassPicker) {
            ClassPickerSheet(classes: classroomStore.classes) { cls in
                selectedClass = cls
                showingClassPicker = false
            }
        }
        .confirmationDialog(
            deleteWarningText,
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete session", role: .destructive) {
                Task {
                    await store.deleteSession(session)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var deleteWarningText: String {
        guard let count = responseCountForDelete, count > 0 else {
            return "Delete this session? This can't be undone."
        }
        return "This session has \(count) student response\(count == 1 ? "" : "s"). Deleting it will permanently delete \(count == 1 ? "that response" : "all of them") too. This can't be undone."
    }

    private func prepareDelete() async {
        isCheckingResponses = true
        responseCountForDelete = await store.responseCount(for: session)
        isCheckingResponses = false
        confirmDelete = true
    }

    private func save() async {
        guard let selectedClass else { return }
        isSaving = true
        defer { isSaving = false }
        let trimmedCode = sessionCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        await store.updateSession(session, classId: selectedClass.id, sessionCode: trimmedCode)
        dismiss()
    }
}

// MARK: - Class picker (shared with SessionsView's create-session flow)

struct ClassPickerSheet: View {
    let classes: [SchoolClass]
    var onSelect: (SchoolClass) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if classes.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("No classes yet")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Create a class first (Classes tab), then come back to start a session.")
                            .font(.system(size: 14)).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(classes) { cls in
                        Button {
                            onSelect(cls)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(cls.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    if let yearLevel = cls.yearLevel, !yearLevel.isEmpty {
                                        Text(yearLevel)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Which class?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
