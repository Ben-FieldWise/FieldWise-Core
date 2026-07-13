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
    @State private var newClassName = ""
    @State private var newClassYearLevel: YearLevel = .year7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeaderView(
                        title: "My Classes",
                        subtitle: "Create a class and share its join code",
                        iconName: "person.2.fill",
                        iconBg: Color("BrandGreen").opacity(0.15),
                        iconColor: Color("BrandGreen"))

                    ForEach(store.classes) { cls in
                        NavigationLink {
                            ClassDetailView(store: store, schoolClass: cls, profile: profile)
                        } label: {
                            GeoCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cls.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        HStack(spacing: 6) {
                                            if let yearLevel = cls.yearLevel, !yearLevel.isEmpty {
                                                Text(yearLevel)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(Color("BrandGreen"))
                                                Text("·").foregroundColor(.secondary)
                                            }
                                            Text("Code: \(cls.classCode)")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    StatusPill(text: cls.active ? "Active" : "Closed",
                                               color: cls.active ? Color("GeoGreen") : .gray)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // New class
                    GeoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            FieldLabel(text: "New class")
                            GeoTextField(placeholder: "e.g. Geography B", text: $newClassName)
                            Picker("Year level", selection: $newClassYearLevel) {
                                ForEach(YearLevel.allCases) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(.menu)
                            PrimaryButton(title: "Create class", iconName: "plus") {
                                let name = newClassName
                                let yearLevel = newClassYearLevel
                                newClassName = ""
                                Task {
                                    await store.createClass(name: name, teacherId: profile.id, schoolId: profile.schoolId, yearLevel: yearLevel.rawValue)
                                }
                            }
                        }
                    }
                    .opacity(newClassName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)

                    if let err = store.errorText {
                        Text(err).font(.system(size: 13)).foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(Color("GeoSurface"))
            .navigationTitle("Classroom")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color("GeoGreen"))
        .task { await store.loadTeacherClasses(teacherId: profile.id) }
    }
}

// MARK: - Teacher: one class (code + tasks)

private struct ClassDetailView: View {
    @ObservedObject var store: ClassroomStore
    let schoolClass: SchoolClass
    let profile: UserProfile
    @State private var newTaskTitle = ""
    @State private var newTaskInstructions = ""

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
                    title: "Fieldwork tasks",
                    subtitle: "What students record on the trip",
                    iconName: "list.clipboard.fill",
                    iconBg: Color("BrandAmber").opacity(0.18),
                    iconColor: Color("BrandAmber"))

                ForEach(store.tasks) { task in
                    NavigationLink {
                        TaskSubmissionsView(store: store, task: task)
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
        .task { await store.loadTasks(classId: schoolClass.id) }
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
