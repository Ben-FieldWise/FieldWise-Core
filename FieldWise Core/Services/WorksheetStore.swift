//
//  WorksheetStore.swift
//  FieldWise Core
//
//  Observable view-model over WorksheetService for the worksheet builder:
//  a teacher's sheets, and the sections/questions of whichever sheet is
//  currently open. Mirrors the ClassroomStore pattern (run/errorText).
//

import Foundation
import Combine

@MainActor
final class WorksheetStore: ObservableObject {

    private let service = WorksheetService()

    @Published var sheets: [FieldworkSheet] = []
    @Published var sections: [WorksheetSection] = []
    @Published var questionsBySection: [String: [WorksheetQuestion]] = [:]
    @Published var isLoading = false
    @Published var errorText: String?

    // MARK: - Sheets

    func loadMySheets(teacherId: String) async {
        await run { self.sheets = try await self.service.fetchMySheets(createdBy: teacherId) }
    }

    @discardableResult
    func createSheet(teacherId: String, title: String, description: String?,
                      subjectArea: String?, yearLevel: String?) async -> FieldworkSheet? {
        var created: FieldworkSheet?
        await run {
            let sheet = try await self.service.createSheet(
                createdBy: teacherId, title: title, description: description,
                subjectArea: subjectArea, yearLevel: yearLevel)
            self.sheets.insert(sheet, at: 0)
            created = sheet
        }
        return created
    }

    func renameSheet(_ sheet: FieldworkSheet, title: String, description: String?) async {
        await run {
            try await self.service.renameSheet(id: sheet.id, title: title, description: description)
            if let i = self.sheets.firstIndex(where: { $0.id == sheet.id }) {
                self.sheets[i].title = title
                self.sheets[i].description = description
            }
        }
    }

    func setStatus(_ sheet: FieldworkSheet, status: String) async {
        await run {
            try await self.service.setSheetStatus(id: sheet.id, status: status)
            if let i = self.sheets.firstIndex(where: { $0.id == sheet.id }) {
                self.sheets[i].status = status
            }
        }
    }

    func deleteSheet(_ sheet: FieldworkSheet) async {
        await run {
            try await self.service.deleteSheet(id: sheet.id)
            self.sheets.removeAll { $0.id == sheet.id }
        }
    }

    // MARK: - Sheet detail (sections + questions)

    func loadDetail(sheetId: String) async {
        print("loadDetail called for sheetId: \(sheetId)")
        await run {
            self.sections = try await self.service.fetchSections(sheetId: sheetId)
            print("fetched \(self.sections.count) sections")
            var map: [String: [WorksheetQuestion]] = [:]
            for section in self.sections {
                map[section.id] = try await self.service.fetchQuestions(sectionId: section.id)
            }
            self.questionsBySection = map
        }
    }

    @discardableResult
    func addSection(sheetId: String, title: String, instructions: String?) async -> WorksheetSection? {
        var created: WorksheetSection?
        await run {
            let section = try await self.service.addSection(
                sheetId: sheetId, title: title, instructions: instructions,
                order: self.sections.count)
            self.sections.append(section)
            self.questionsBySection[section.id] = []
            created = section
        }
        return created
    }

    func deleteSection(_ section: WorksheetSection) async {
        await run {
            try await self.service.deleteSection(id: section.id)
            self.sections.removeAll { $0.id == section.id }
            self.questionsBySection.removeValue(forKey: section.id)
        }
    }

    @discardableResult
    func addQuestion(sectionId: String, type: WorksheetQuestionType, prompt: String,
                      options: WorksheetQuestionOptions, required: Bool,
                      requiredTool: String?) async -> WorksheetQuestion? {
        var created: WorksheetQuestion?
        await run {
            let order = self.questionsBySection[sectionId]?.count ?? 0
            let question = try await self.service.addQuestion(
                sectionId: sectionId, type: type, prompt: prompt, options: options,
                required: required, requiredTool: requiredTool, order: order)
            self.questionsBySection[sectionId, default: []].append(question)
            created = question
        }
        return created
    }

    func deleteQuestion(_ question: WorksheetQuestion) async {
        await run {
            try await self.service.deleteQuestion(id: question.id)
            self.questionsBySection[question.sectionId]?.removeAll { $0.id == question.id }
        }
    }

    // MARK: - Helpers

    private func run(_ work: @escaping () async throws -> Void) async {
        isLoading = true; errorText = nil
        defer { isLoading = false }
        do { try await work() }
        catch { errorText = error.localizedDescription }
    }
}
