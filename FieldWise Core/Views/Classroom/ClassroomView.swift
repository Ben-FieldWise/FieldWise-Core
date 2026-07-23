//
//  ClassroomView.swift
//  FieldWise Core
//
//  The teacher ↔ student classroom loop, branched by role:
//    • Teacher: create classes (with join codes), add fieldwork tasks,
//      review student submissions.
//    • Student: see tasks assigned to their class and record entries.
//
//  Data flows through ClassroomStore → SupabaseService (RLS-scoped).
//  Student entry saves go through the offline queue (EntrySync).
//

import SwiftUI

// MARK: - Root (role branch)

struct ClassroomView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = ClassroomStore()

    var body: some View {
        Group {
            if let profile = authService.currentUserProfile {
                if profile.role == .teacher {
                    TeacherClassroomView(store: store, profile: profile)
                } else {
                    StudentClassroomView(store: store, profile: profile)
                }
            } else {
                ProgressView()
            }
        }
    }
}

// MARK: - Teacher: class list

private struct TeacherClassroomView: View {
    @ObservedObject var store: ClassroomStore
    let profile: UserProfile
    @State private var showingCreateClass = false
    @State private var newClassName = ""
    @State private var newClassYearLevel: YearLevel = .year7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 15) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundStyle(Color("BrandGreen"))
                            .frame(width: 56, height: 56)
                            .background(Color("BrandGreen").opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("My Classes").font(.title.bold())
                            Text("Manage students, activities, fieldwork and submissions.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(20)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))

                    if store.classes.isEmpty {
                        ContentUnavailableView(
                            "No classes yet",
                            systemImage: "person.3",
                            description: Text("Create your first class, then share its code or QR code with students.")
                        )
                        .padding(.vertical, 50)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                            ForEach(store.classes) { cls in
                                NavigationLink {
                                    ClassDetailView(store: store, schoolClass: cls, profile: profile)
                                } label: {
                                    ClassDashboardCard(schoolClass: cls)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let err = store.errorText {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Color("GeoSurface").ignoresSafeArea())
            .navigationTitle("Classes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreateClass = true } label: {
                        Label("New Class", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateClass) {
                NavigationStack {
                    Form {
                        Section("Class details") {
                            TextField("Class name, e.g. Geography B", text: $newClassName)
                            Picker("Year level", selection: $newClassYearLevel) {
                                ForEach(YearLevel.allCases) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                        }
                    }
                    .navigationTitle("New Class")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingCreateClass = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                let name = newClassName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                let year = newClassYearLevel
                                newClassName = ""
                                showingCreateClass = false
                                Task {
                                    await store.createClass(name: name, teacherId: profile.id, schoolId: profile.schoolId, yearLevel: year.rawValue)
                                }
                            }
                            .disabled(newClassName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .tint(Color("BrandGreen"))
        .task { await store.loadTeacherClasses(teacherId: profile.id) }
    }
}

private struct ClassDashboardCard: View {
    let schoolClass: SchoolClass

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color("BrandGreen"))
                    .frame(width: 44, height: 44)
                    .background(Color("BrandGreen").opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                StatusPill(text: schoolClass.active ? "Active" : "Closed", color: schoolClass.active ? Color("GeoGreen") : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(schoolClass.name.isEmpty ? "Untitled Class" : schoolClass.name)
                    .font(.title3.bold()).foregroundStyle(.primary)
                Text(schoolClass.yearLevel ?? "Year level not set")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("JOIN CODE").font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(schoolClass.classCode)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(Color("BrandGreen"))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.05)))
    }
}

// MARK: - Teacher: one class (code + tasks)

private struct ClassDetailView: View {
    @ObservedObject var store: ClassroomStore
    let schoolClass: SchoolClass
    let profile: UserProfile
    @State private var newTaskTitle = ""
    @State private var newTaskInstructions = ""
    @State private var taskPendingDelete: FieldworkTask?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GeoCard {
                    VStack(spacing: 6) {
                        Text("Join code")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                        Text(schoolClass.classCode)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(4)
                            .foregroundColor(Color("BrandGreen"))
                        Text("Students enter this code to join \(schoolClass.name).")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }

                SectionHeaderView(
                    title: "Worksheets",
                    subtitle: "Sessions assigned to this class",
                    iconName: "doc.text.fill",
                    iconBg: Color("GeoBlue").opacity(0.18),
                    iconColor: Color("GeoBlue"))

                if store.classSessions.isEmpty {
                    Text("No worksheets assigned yet. Open a worksheet's Sessions screen and create one for this class.")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                } else {
                    ForEach(store.classSessions) { session in
                        NavigationLink {
                            SessionResponsesView(session: session)
                        } label: {
                            GeoCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.sheetTitlesBySheetId[session.sheetId] ?? "Untitled worksheet")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        HStack(spacing: 6) {
                                            Text(session.sessionCode)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundColor(Color("BrandGreen"))
                                            Text("·").foregroundColor(.secondary)
                                            Text(session.isActive ? "Active" : "Closed")
                                                .font(.system(size: 12)).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                SectionHeaderView(
                    title: "Fieldwork tasks",
                    subtitle: "What students record on the trip",
                    iconName: "list.clipboard.fill",
                    iconBg: Color("BrandAmber").opacity(0.18),
                    iconColor: Color("BrandAmber"))

                ForEach(store.tasks) { task in
                    GeoCard {
                        HStack {
                            NavigationLink {
                                TaskSubmissionsView(store: store, task: task)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        if !task.instructions.isEmpty {
                                            Text(task.instructions)
                                                .font(.system(size: 12)).foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            // Deliberately a sibling of the NavigationLink,
                            // not layered on top of it. An earlier version
                            // put this in a ZStack overlaid on the card,
                            // and SwiftUI's NavigationLink still claimed
                            // the tap underneath regardless of
                            // .buttonStyle(.plain) on the button — the
                            // link's hit-testing isn't actually blocked
                            // by an overlapping sibling view, only by not
                            // overlapping it at all. Living beside the
                            // link's label inside the same HStack (as
                            // SectionCard's menu button does in
                            // SheetEditorView) is the pattern that
                            // reliably works.
                            Button {
                                taskPendingDelete = task
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                    }
                }

                GeoCard {
                    VStack(alignment: .leading, spacing: 10) {
                        FieldLabel(text: "New task")
                        GeoTextField(placeholder: "Title, e.g. Phillip Island Fieldwork", text: $newTaskTitle)
                        GeoTextField(placeholder: "Instructions (optional)", text: $newTaskInstructions, axis: .vertical)
                        PrimaryButton(title: "Add task", iconName: "plus") {
                            let t = newTaskTitle; let ins = newTaskInstructions
                            newTaskTitle = ""; newTaskInstructions = ""
                            Task { await store.createTask(classId: schoolClass.id, title: t, instructions: ins) }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color("GeoSurface"))
        .navigationTitle(schoolClass.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadTasks(classId: schoolClass.id)
            await store.loadClassSessions(classId: schoolClass.id)
        }
        .confirmationDialog(
            "Delete this task? Student entries already recorded against it won't be shown here anymore, but aren't deleted.",
            isPresented: Binding(
                get: { taskPendingDelete != nil },
                set: { if !$0 { taskPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete task", role: .destructive) {
                if let task = taskPendingDelete {
                    Task { await store.deleteTask(task) }
                }
                taskPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { taskPendingDelete = nil }
        }
    }
}

// MARK: - Teacher: submissions for a task

private struct TaskSubmissionsView: View {
    @ObservedObject var store: ClassroomStore
    let task: FieldworkTask

    private var entries: [FieldworkEntry] {
        store.classEntries.filter { $0.taskId == task.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SectionHeaderView(
                    title: "Submissions",
                    subtitle: task.title,
                    iconName: "tray.full.fill",
                    iconBg: Color("GeoGreen").opacity(0.15),
                    iconColor: Color("GeoGreen"))

                if entries.isEmpty {
                    Text("No student entries yet.")
                        .font(.system(size: 14)).foregroundColor(.secondary)
                        .padding(.top, 24)
                }

                ForEach(entries) { entry in
                    GeoCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.studentDisplayName)
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                StatusPill(text: entry.status.rawValue.capitalized,
                                           color: entry.status == .submitted ? Color("GeoGreen") : Color("BrandAmber"))
                            }
                            if !entry.notes.isEmpty {
                                Text(entry.notes)
                                    .font(.system(size: 13)).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color("GeoSurface"))
        .navigationTitle("Submissions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadClassEntries(classId: task.classId) }
    }
}

// MARK: - Student: tasks for their class

private struct StudentClassroomView: View {
    @ObservedObject var store: ClassroomStore
    let profile: UserProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeaderView(
                        title: store.currentClass?.name ?? "Your class",
                        subtitle: "Tasks from your teacher",
                        iconName: "graduationcap.fill",
                        iconBg: Color("BrandAmber").opacity(0.18),
                        iconColor: Color("BrandAmber"))

                    if profile.classId == nil {
                        Text("You're not in a class yet. Ask your teacher for a join code.")
                            .font(.system(size: 14)).foregroundColor(.secondary)
                            .padding(.top, 24)
                    } else if store.tasks.isEmpty {
                        Text("No tasks yet — your teacher hasn't set any.")
                            .font(.system(size: 14)).foregroundColor(.secondary)
                            .padding(.top, 24)
                    }

                    ForEach(store.tasks) { task in
                        NavigationLink {
                            StudentTaskView(store: store, task: task, profile: profile)
                        } label: {
                            GeoCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        if !task.instructions.isEmpty {
                                            Text(task.instructions)
                                                .font(.system(size: 12)).foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color("GeoSurface"))
            .navigationTitle("Classroom")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color("GeoGreen"))
        .task {
            if let classId = profile.classId {
                await store.loadStudentClass(classId: classId)
                await store.loadTasks(classId: classId)
            }
        }
    }
}

// MARK: - Student: record entries for a task

private struct StudentTaskView: View {
    @ObservedObject var store: ClassroomStore
    let task: FieldworkTask
    let profile: UserProfile
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !task.instructions.isEmpty {
                    GeoCard {
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Instructions")
                            Text(task.instructions).font(.system(size: 14))
                        }
                    }
                }

                if task.isBooklet {
                    // Structured booklet — open the guided fill view.
                    NavigationLink {
                        BookletFillView(task: task, studentUid: profile.id)
                    } label: {
                        GeoCard {
                            HStack(spacing: 12) {
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color("BrandGreen"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Open fieldwork booklet")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("Answer each section as you visit the sites.")
                                        .font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    // Plain free-form entry task.
                    GeoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            FieldLabel(text: "New entry")
                            GeoTextField(placeholder: "What did you observe?", text: $notes, axis: .vertical)
                            PrimaryButton(title: "Save entry", iconName: "square.and.arrow.down") {
                                let text = notes
                                notes = ""
                                Task {
                                    await store.addEntry(task: task, studentUid: profile.id,
                                                         studentDisplayName: profile.displayName, notes: text)
                                }
                            }
                        }
                    }

                    SectionHeaderView(
                        title: "My entries",
                        subtitle: "Saved on this device, synced when online",
                        iconName: "doc.text.fill",
                        iconBg: Color("GeoGreen").opacity(0.15),
                        iconColor: Color("GeoGreen"))

                    if store.myEntries.isEmpty {
                        Text("Nothing recorded yet.")
                            .font(.system(size: 14)).foregroundColor(.secondary)
                    }

                    ForEach(store.myEntries) { entry in
                        GeoCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    StatusPill(text: entry.status.rawValue.capitalized,
                                               color: entry.status == .submitted ? Color("GeoGreen") : Color("BrandAmber"))
                                    Spacer()
                                }
                                if !entry.notes.isEmpty {
                                    Text(entry.notes).font(.system(size: 14))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color("GeoSurface"))
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadMyEntries(studentUid: profile.id, taskId: task.id) }
    }
}

// MARK: - Small status pill

private struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
