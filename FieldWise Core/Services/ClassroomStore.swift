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
    private let sessionService = SessionService()
    private let worksheetService = WorksheetService()

    @Published var classes: [SchoolClass] = []      // teacher's classes
    @Published var currentClass: SchoolClass?       // student's class
    @Published var tasks: [FieldworkTask] = []
    @Published var classEntries: [FieldworkEntry] = []   // teacher review
    @Published var myEntries: [FieldworkEntry] = []      // student's own
    @Published var isLoading = false
    @Published var errorText: String?

    /// Worksheet sessions assigned to the class currently being viewed
    /// (ClassDetailView's "Worksheets" section) — populated by
    /// loadClassSessions, alongside the sheet title for each one (a
    /// session only stores sheet_id, not the sheet's own title, so this
    /// mirrors SessionsView's own "fetch separately, cross-reference by
    /// dictionary" convention rather than requiring a joined query).
    @Published var classSessions: [FieldworkSession] = []
    @Published var sheetTitlesBySheetId: [String: String] = [:]

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

    func deleteTask(_ task: FieldworkTask) async {
        await run {
            try await self.service.deleteTask(id: task.id)
            self.tasks.removeAll { $0.id == task.id }
        }
    }

    func loadClassEntries(classId: String) async {
        await run { self.classEntries = try await self.service.fetchClassEntries(classId: classId) }
    }

    /// Loads the sessions assigned to this class, plus the title of each
    /// one's worksheet. Sheet titles are fetched individually per unique
    /// sheet_id (a class typically has a small number of distinct
    /// worksheets assigned, so this stays cheap) rather than via a
    /// joined query, matching this file's existing style of separate
    /// fetches cross-referenced by dictionary (see SessionsView's own
    /// classroomStore/store split for the same pattern).
    func loadClassSessions(classId: String) async {
        await run {
            let sessions = try await self.sessionService.fetchSessions(classId: classId)
            self.classSessions = sessions

            let uniqueSheetIds = Set(sessions.map { $0.sheetId })
            var titles: [String: String] = [:]
            for sheetId in uniqueSheetIds {
                if let sheet = try? await self.worksheetService.fetchSheet(id: sheetId) {
                    titles[sheetId] = sheet.title
                }
            }
            self.sheetTitlesBySheetId = titles
        }
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
