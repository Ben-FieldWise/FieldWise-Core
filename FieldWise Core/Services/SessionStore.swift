//
//  SessionStore.swift
//  FieldWise Core
//
//  Observable view-model over SessionService for Phase 1C: teachers
//  publish sheets as sessions and review responses; students join a
//  session by code and fill in / submit their answers. Mirrors the
//  WorksheetStore pattern (run/errorText).
//

import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {

    private let service = SessionService()

    // Teacher side
    @Published var sessions: [FieldworkSession] = []
    @Published var responses: [StudentResponse] = []
    @Published var displayNamesByStudentId: [String: String] = [:]

    // Student side
    @Published var activeSession: FieldworkSession?
    @Published var mySheet: FieldworkSheet?
    @Published var mySections: [WorksheetSection] = []
    @Published var myQuestionsBySection: [String: [WorksheetQuestion]] = [:]
    @Published var myResponse: StudentResponse?
    @Published var answers: [String: SessionAnswerValue] = [:]

    /// Every response the student has ever started, across sessions —
    /// separate from `myResponse` (singular, the one currently being
    /// filled in) — powers the "My worksheets" completed-work list.
    @Published var myResponses: [StudentResponse] = []

    @Published var isLoading = false
    @Published var errorText: String?

    // MARK: - Teacher: publish / manage

    @discardableResult
    func publish(sheetId: String, teacherId: String, classId: String? = nil) async -> FieldworkSession? {
        var created: FieldworkSession?
        await run {
            let session = try await self.service.createSession(sheetId: sheetId, createdBy: teacherId, classId: classId)
            self.sessions.insert(session, at: 0)
            created = session
        }
        return created
    }

    func loadMySessions(teacherId: String) async {
        await run { self.sessions = try await self.service.fetchMySessions(createdBy: teacherId) }
    }

    func loadSessions(sheetId: String) async {
        await run { self.sessions = try await self.service.fetchSessions(sheetId: sheetId) }
    }

    func closeSession(_ session: FieldworkSession) async {
        await run {
            try await self.service.setSessionStatus(id: session.id, status: "closed")
            if let i = self.sessions.firstIndex(where: { $0.id == session.id }) {
                self.sessions[i].status = "closed"
            }
        }
    }

    func reopenSession(_ session: FieldworkSession) async {
        await run {
            try await self.service.setSessionStatus(id: session.id, status: "active")
            if let i = self.sessions.firstIndex(where: { $0.id == session.id }) {
                self.sessions[i].status = "active"
            }
        }
    }

    // MARK: - Teacher: review responses

    func loadResponses(sessionId: String) async {
        await run {
            self.responses = try await self.service.fetchResponses(sessionId: sessionId)
            let studentIds = Array(Set(self.responses.map { $0.studentId }))
            self.displayNamesByStudentId = try await self.service.fetchDisplayNames(for: studentIds)
        }
    }

    /// Loads every response the student has started, for the "My
    /// worksheets" list (separate from the single in-progress
    /// myResponse/answers state used while filling in a worksheet).
    func loadMyResponses() async {
        await run { self.myResponses = try await self.service.fetchMyResponses() }
    }

    func markReviewed(_ response: StudentResponse) async {
        await run {
            try await self.service.markReviewed(responseId: response.id)
            if let i = self.responses.firstIndex(where: { $0.id == response.id }) {
                self.responses[i].status = .reviewed
            }
        }
    }

    // MARK: - Student: join + fill in

    /// Joins a session by code, then loads the sheet's sections/questions
    /// and the student's (new or existing) response in full, so the
    /// fill-in view has everything it needs in one call.
    /// Loads full detail for a response the student already has — the
    /// "reopen a completed/in-progress worksheet from the list" path,
    /// as opposed to joinAndLoad's "enter a code for the first time"
    /// path. Populates the same fields WorksheetFillView reads, so it
    /// can be reused unmodified.
    func loadResponseDetail(response: StudentResponse, worksheetService: WorksheetService = WorksheetService()) async {
        await run {
            let session = try await self.service.fetchSession(id: response.sessionId)
            let sheet = try await worksheetService.fetchSheet(id: session.sheetId)
            let sections = try await worksheetService.fetchSections(sheetId: session.sheetId)
            var map: [String: [WorksheetQuestion]] = [:]
            for section in sections {
                map[section.id] = try await worksheetService.fetchQuestions(sectionId: section.id)
            }

            self.activeSession = session
            self.mySheet = sheet
            self.mySections = sections
            self.myQuestionsBySection = map
            self.myResponse = response
            self.answers = response.answers
        }
    }

    func joinAndLoad(code: String, worksheetService: WorksheetService = WorksheetService()) async {
        await run {
            let joined = try await self.service.joinSession(code: code)
            let sheet = try await worksheetService.fetchSheet(id: joined.sheetId)
            let sections = try await worksheetService.fetchSections(sheetId: joined.sheetId)
            var map: [String: [WorksheetQuestion]] = [:]
            for section in sections {
                map[section.id] = try await worksheetService.fetchQuestions(sectionId: section.id)
            }
            let response = try await self.service.fetchMyResponse(id: joined.responseId)

            self.activeSession = FieldworkSession(
                id: joined.sessionId, sheetId: joined.sheetId, createdBy: "",
                classId: nil, sessionCode: code, status: joined.sessionStatus,
                opensAt: nil, closesAt: nil, createdAt: nil, updatedAt: nil
            )
            self.mySheet = sheet
            self.mySections = sections
            self.myQuestionsBySection = map
            self.myResponse = response
            self.answers = response.answers
        }
    }

    /// All questions across every section, in order — convenient for the
    /// fill-in view and for required-question validation.
    var allMyQuestions: [WorksheetQuestion] {
        mySections.flatMap { myQuestionsBySection[$0.id] ?? [] }
    }

    var unansweredRequiredCount: Int {
        allMyQuestions.filter { question in
            guard question.required else { return false }
            return isEmpty(answers[question.id])
        }.count
    }

    func setAnswer(_ value: SessionAnswerValue?, for questionId: String) {
        if let value { answers[questionId] = value }
        else { answers.removeValue(forKey: questionId) }
    }

    func saveDraft() async {
        guard let response = myResponse else { return }
        await run {
            try await self.service.saveDraft(responseId: response.id, answers: self.answers)
        }
    }

    @discardableResult
    func submit() async -> Bool {
        guard let response = myResponse else { return false }
        guard unansweredRequiredCount == 0 else {
            errorText = "Please answer all required questions before submitting."
            return false
        }
        var success = false
        await run {
            try await self.service.submit(responseId: response.id, answers: self.answers)
            self.myResponse?.status = .submitted
            success = true
        }
        return success
    }

    // MARK: - Helpers

    private func isEmpty(_ value: SessionAnswerValue?) -> Bool {
        guard let value else { return true }
        switch value {
        case .string(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .stringArray(let a): return a.isEmpty
        case .table(let t): return t.isEmpty || t.allSatisfy { row in row.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        case .int: return false
        case .null: return true
        }
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        isLoading = true; errorText = nil
        defer { isLoading = false }
        do { try await work() }
        catch { errorText = error.localizedDescription }
    }
}
