//
//  ClassroomStore.swift
//  FieldWise Core
//
//  Observable view-model over SupabaseService for the classroom loop:
//  teachers create classes + tasks and review submissions; students see
//  assigned tasks and record entries. All access is RLS-scoped server
//  side; this store just drives the UI state.
//

import Foundation
import Combine

@MainActor
final class ClassroomStore: ObservableObject {

    private let service = SupabaseService()

    @Published var classes: [SchoolClass] = []      // teacher's classes
    @Published var currentClass: SchoolClass?       // student's class
    @Published var tasks: [FieldworkTask] = []
    @Published var classEntries: [FieldworkEntry] = []   // teacher review
    @Published var myEntries: [FieldworkEntry] = []      // student's own
    @Published var isLoading = false
    @Published var errorText: String?

    // MARK: - Teacher

    func loadTeacherClasses(teacherId: String) async {
        await run { self.classes = try await self.service.fetchClasses(teacherId: teacherId) }
    }

    func createClass(name: String, teacherId: String, schoolId: String, yearLevel: String?) async {
        let code = Self.generateCode()
        let draft = SchoolClass.new(teacherId: teacherId, schoolId: schoolId, name: name, classCode: code, yearLevel: yearLevel)
        await run {
            let created = try await self.service.createClass(draft)
            self.classes.insert(created, at: 0)
        }
    }

    func setClassActive(_ classId: String, active: Bool) async {
        await run {
            try await self.service.setClassActive(classId, active: active)
            if let i = self.classes.firstIndex(where: { $0.id == classId }) {
                self.classes[i] = self.classes[i].with(id: classId) // no-op keep; refresh below
            }
            // simplest: reflect locally
            self.classes = self.classes.map { c in
                guard c.id == classId else { return c }
                var copy = c; copy.active = active; return copy
            }
        }
    }

    func createTask(classId: String, title: String, instructions: String) async {
        let draft = FieldworkTask.new(classId: classId, title: title, instructions: instructions)
        await run {
            let created = try await self.service.createTask(draft)
            self.tasks.insert(created, at: 0)
        }
    }

    func loadClassEntries(classId: String) async {
        await run { self.classEntries = try await self.service.fetchClassEntries(classId: classId) }
    }

    // MARK: - Student

    func loadStudentClass(classId: String) async {
        await run { self.currentClass = try await self.service.fetchClass(id: classId) }
    }

    func loadTasks(classId: String) async {
        await run { self.tasks = try await self.service.fetchTasks(classId: classId) }
    }

    func loadMyEntries(studentUid: String, taskId: String) async {
        await run { self.myEntries = try await self.service.fetchMyEntries(studentUid: studentUid, taskId: taskId) }
    }

    func addEntry(task: FieldworkTask, studentUid: String, studentDisplayName: String, notes: String) async {
        var entry = FieldworkEntry.newDraft(taskId: task.id, classId: task.classId,
                                            studentUid: studentUid, studentDisplayName: studentDisplayName)
        entry.notes = notes
        await service.saveEntry(entry)   // offline-first, never throws
        await loadMyEntries(studentUid: studentUid, taskId: task.id)
    }

    // MARK: - Helpers

    private func run(_ work: @escaping () async throws -> Void) async {
        isLoading = true; errorText = nil
        defer { isLoading = false }
        do { try await work() }
        catch { errorText = error.localizedDescription }
    }

    /// 6-char join code, ambiguous characters removed.
    static func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}

