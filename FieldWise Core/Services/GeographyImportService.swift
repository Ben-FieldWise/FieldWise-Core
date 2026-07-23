//
//  GeographyImportService.swift
//  FieldWise Core
//
//  Converts a decoded .fieldwise.json (from Geography's format_version 2
//  export) into a real Core worksheet: a FieldworkSheet, one section for
//  the narrative inquiry stages, one section per site, and questions
//  seeded with the originally recorded answers.
//
//  Built entirely on top of WorksheetService's existing createSheet/
//  addSection/addQuestion -- the same orchestration pattern
//  WorksheetService.duplicateSheet already uses -- rather than raw
//  inserts, so this always goes through the same validated write path as
//  manual authoring in the builder.
//
//  Design decisions (confirmed with the person before building):
//    - Recorded answers ARE carried over as options.seedValue on each
//      question, not discarded. The importer produces a worksheet that
//      already contains the teacher's own recorded data, not a blank
//      template.
//    - A field only gets a seedValue if it actually has recorded content;
//      unanswered fields import as ordinary blank questions.
//    - Photos are never seeded (no image data in the JSON) -- a
//      photo_upload question is still added so the slot exists, with a
//      note in its prompt that the original photo needs re-uploading.
//

import Foundation

enum GeographyImportError: LocalizedError {
    case unsupportedFormatVersion(found: Int, supported: Int)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion(let found, let supported):
            return "This file uses format version \(found), but this version of Core only supports version \(supported). Re-export from a matching version of FieldWise Geography."
        case .decodingFailed(let underlying):
            return "Couldn't read this file as a FieldWise investigation export: \(underlying.localizedDescription)"
        }
    }
}

enum GeographyImportService {

    /// The format_version this importer understands. Matches
    /// InvestigationDataExporter.currentFormatVersion in Geography at the
    /// time this was written -- see GeographyImportError.unsupportedFormatVersion
    /// for what happens if a future export bumps this.
    static let supportedFormatVersion = 2

    // MARK: - Decoding

    static func decode(_ data: Data) throws -> InvestigationImport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let imported = try decoder.decode(InvestigationImport.self, from: data)
            guard imported.formatVersion == supportedFormatVersion else {
                throw GeographyImportError.unsupportedFormatVersion(
                    found: imported.formatVersion, supported: supportedFormatVersion)
            }
            return imported
        } catch let error as GeographyImportError {
            throw error
        } catch {
            throw GeographyImportError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Import (creates the real worksheet)

    /// Creates a new FieldworkSheet (plus sections/questions) from a
    /// decoded investigation export, owned by `createdBy`. Returns the
    /// created sheet once every section/question has been written.
    ///
    /// @MainActor because WorksheetService's initializer is main-actor
    /// isolated (it touches SupabaseManager.shared, itself main-actor
    /// bound) -- constructing one via a default parameter value from a
    /// nonisolated static function triggers a real Swift concurrency
    /// warning ("call to main actor-isolated initializer in a synchronous
    /// nonisolated context"). This matches how WorksheetStore and the
    /// other UI-adjacent stores in this app are already @MainActor, and
    /// every real caller of this function is already on the main actor
    /// (SwiftUI Task { } blocks), so this doesn't change actual behavior
    /// — it just makes the isolation the compiler already expects explicit.
    @discardableResult
    @MainActor
    static func importInvestigation(
        _ imported: InvestigationImport,
        createdBy: String,
        service: WorksheetService? = nil
    ) async throws -> FieldworkSheet {
        let service = service ?? WorksheetService()

        let sheet = try await service.createSheet(
            createdBy: createdBy,
            title: imported.title,
            description: "Imported from a FieldWise Geography investigation (\(imported.templateId)).",
            subjectArea: "Geography",
            yearLevel: nil
        )

        var sectionOrder = 0

        // Inquiry section: one long_answer question per non-empty narrative stage.
        let inquiryQuestions = buildInquiryQuestions(for: imported)
        if !inquiryQuestions.isEmpty {
            let section = try await service.addSection(
                sheetId: sheet.id, title: "Inquiry", instructions: nil, order: sectionOrder)
            sectionOrder += 1
            try await addQuestions(inquiryQuestions, to: section, service: service)
        }

        // One section per site.
        for site in imported.sites {
            let section = try await service.addSection(
                sheetId: sheet.id, title: site.name, instructions: nil, order: sectionOrder)
            sectionOrder += 1
            let siteQuestions = buildSiteQuestions(for: site)
            try await addQuestions(siteQuestions, to: section, service: service)
        }

        return sheet
    }

    // MARK: - Question building (pure, testable — no network calls)

    private struct PlannedQuestion {
        var type: WorksheetQuestionType
        var prompt: String
        var options: WorksheetQuestionOptions
    }

    private static func buildInquiryQuestions(for imported: InvestigationImport) -> [PlannedQuestion] {
        var questions: [PlannedQuestion] = []

        func addStage(_ label: String, _ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            questions.append(PlannedQuestion(
                type: .longAnswer, prompt: label,
                options: WorksheetQuestionOptions(seedValue: .string(trimmed))
            ))
        }

        addStage("Ask", imported.question)
        addStage("Predict", imported.prediction)
        addStage("Explain", imported.explanation)
        addStage("Evaluate", imported.evaluation)
        addStage("Conclude", imported.conclusion)
        if let country = imported.countryReflection {
            addStage("Connection to Country", country)
        }

        return questions
    }

    private static func buildSiteQuestions(for site: ImportedSite) -> [PlannedQuestion] {
        var questions: [PlannedQuestion] = []

        // GPS, if the site was ever located.
        if let lat = site.latitude, let lon = site.longitude {
            let coordText = String(format: "%.5f, %.5f", lat, lon)
            questions.append(PlannedQuestion(
                type: .gpsPoint, prompt: "Site location",
                options: WorksheetQuestionOptions(seedValue: .string(coordText))
            ))
        }

        // One question per recorded field, typed and seeded by kind.
        for record in site.fields {
            if let question = plannedQuestion(for: record) {
                questions.append(question)
            }
        }

        // Free-text observation notes.
        let notes = site.observationNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            questions.append(PlannedQuestion(
                type: .longAnswer, prompt: "Observation notes",
                options: WorksheetQuestionOptions(seedValue: .string(notes))
            ))
        }

        // Photo slot, unseeded — the original image bytes aren't in the
        // JSON (only filenames), so this just reserves the question and
        // tells the next student what was originally captured here.
        if !site.photoFilenames.isEmpty {
            let count = site.photoFilenames.count
            let noun = count == 1 ? "photo" : "photos"
            questions.append(PlannedQuestion(
                type: .photoUpload,
                prompt: "Site photo (\(count) original \(noun) not carried over — please add a current photo)",
                options: WorksheetQuestionOptions()
            ))
        }

        return questions
    }

    /// Maps one recorded field to a typed, seeded question. Returns nil
    /// only if the field's kind is unrecognised (defensive — every kind
    /// Geography currently defines is handled below).
    private static func plannedQuestion(for record: ImportedFieldRecord) -> PlannedQuestion? {
        let value = record.value

        switch record.kind {
        case "text", "note":
            let trimmed = value.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return PlannedQuestion(
                type: .longAnswer,
                prompt: promptWithGuidance(record),
                options: WorksheetQuestionOptions(
                    seedValue: trimmed.isEmpty ? nil : .string(trimmed))
            )

        case "number":
            guard let number = value.number else {
                return PlannedQuestion(type: .shortAnswer, prompt: promptWithGuidance(record), options: .init())
            }
            let unitSuffix = record.unit.map { " \($0)" } ?? ""
            return PlannedQuestion(
                type: .shortAnswer,
                prompt: promptWithGuidance(record),
                options: WorksheetQuestionOptions(seedValue: .string("\(formatted(number))\(unitSuffix)"))
            )

        case "rating":
            return PlannedQuestion(
                type: .ratingScale,
                prompt: promptWithGuidance(record),
                options: WorksheetQuestionOptions(
                    min: 1, max: 5,
                    seedValue: value.rating > 0 ? .int(value.rating) : nil)
            )

        case "choice":
            let trimmed = value.choice.trimmingCharacters(in: .whitespacesAndNewlines)
            return PlannedQuestion(
                type: .multipleChoice,
                prompt: promptWithGuidance(record),
                options: WorksheetQuestionOptions(
                    choices: record.options,
                    seedValue: trimmed.isEmpty ? nil : .string(trimmed))
            )

        case "checklist":
            return PlannedQuestion(
                type: .checkbox,
                prompt: promptWithGuidance(record),
                options: WorksheetQuestionOptions(
                    choices: record.options,
                    seedValue: value.checklist.isEmpty ? nil : .stringArray(value.checklist))
            )

        default:
            // Unknown kind (e.g. a future Geography field type this
            // version of Core doesn't know about yet). Import it as a
            // plain short answer with the recorded text, rather than
            // silently dropping the field entirely.
            let trimmed = value.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return PlannedQuestion(
                type: .shortAnswer,
                prompt: promptWithGuidance(record),
                options: WorksheetQuestionOptions(seedValue: trimmed.isEmpty ? nil : .string(trimmed))
            )
        }
    }

    /// Appends the field's guidance text to its prompt in parentheses,
    /// matching how the field's `guidance` was shown as a hint in
    /// Geography's own site-entry form.
    private static func promptWithGuidance(_ record: ImportedFieldRecord) -> String {
        guard let guidance = record.guidance, !guidance.isEmpty else { return record.label }
        return "\(record.label) (\(guidance))"
    }

    private static func formatted(_ number: Double) -> String {
        if number == number.rounded() {
            return String(format: "%.0f", number)
        }
        return String(number)
    }

    // MARK: - Write helper

    @MainActor
    private static func addQuestions(
        _ questions: [PlannedQuestion], to section: WorksheetSection, service: WorksheetService
    ) async throws {
        for (index, question) in questions.enumerated() {
            _ = try await service.addQuestion(
                sectionId: section.id, type: question.type, prompt: question.prompt,
                options: question.options, required: false, requiredTool: nil, order: index
            )
        }
    }
}
