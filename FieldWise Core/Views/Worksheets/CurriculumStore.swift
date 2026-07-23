//
//  CurriculumStore.swift
//  FieldWise Core
//
//  Observable view-model over CurriculumService for Phase 1E: browsing
//  curriculum points to attach to a sheet, and managing the links for
//  whichever sheet is currently open. Mirrors the WorksheetStore pattern
//  (run/errorText).
//

import Foundation
import Combine

@MainActor
final class CurriculumStore: ObservableObject {

    private let service = CurriculumService()

    /// All points for the level band currently being browsed, grouped by
    /// sub-strand name for section headers in the picker (e.g. "Water in
    /// the world"). Populated by loadPoints(levelBand:).
    @Published var points: [CurriculumPoint] = []

    /// Links already on the sheet currently being edited, keyed by
    /// curriculum_point_id for O(1) "is this one already linked?" checks
    /// in the picker's row rendering.
    @Published var linkedPointIds: Set<String> = []
    @Published var links: [SheetCurriculumLink] = []

    @Published var isLoading = false
    @Published var errorText: String?

    // MARK: - Browsing reference data

    func loadPoints(levelBand: String) async {
        await run {
            self.points = try await self.service.fetchPoints(levelBand: levelBand)
        }
    }

    /// Points grouped by sub-strand name, in sort_order within each group,
    /// for section-headed display in the picker.
    var pointsBySubstrand: [(substrandName: String, points: [CurriculumPoint])] {
        var order: [String] = []
        var groups: [String: [CurriculumPoint]] = [:]

        for point in points {
            let name = point.substrand?.name ?? "Other"
            if groups[name] == nil { order.append(name) }
            groups[name, default: []].append(point)
        }

        return order.map { ($0, groups[$0] ?? []) }
    }

    // MARK: - Managing a sheet's links

    func loadLinks(sheetId: String) async {
        await run {
            let fetched = try await self.service.fetchLinks(sheetId: sheetId)
            self.links = fetched
            self.linkedPointIds = Set(fetched.map { $0.curriculumPointId })
        }
    }

    func toggleLink(sheetId: String, point: CurriculumPoint, teacherId: String) async {
        if linkedPointIds.contains(point.id) {
            await unlink(sheetId: sheetId, pointId: point.id)
        } else {
            await link(sheetId: sheetId, point: point, teacherId: teacherId)
        }
    }

    private func link(sheetId: String, point: CurriculumPoint, teacherId: String) async {
        // Optimistic UI: flip the toggle immediately, roll back on failure,
        // matching the responsiveness teachers expect from a tap target
        // in a scrolling list of ~54 rows.
        linkedPointIds.insert(point.id)
        await run {
            do {
                let created = try await self.service.linkPoint(
                    sheetId: sheetId, curriculumPointId: point.id, createdBy: teacherId)
                var withPoint = created
                withPoint.curriculumPoint = point
                self.links.append(withPoint)
            } catch {
                self.linkedPointIds.remove(point.id)
                throw error
            }
        }
    }

    private func unlink(sheetId: String, pointId: String) async {
        let previousLinks = links
        linkedPointIds.remove(pointId)
        links.removeAll { $0.curriculumPointId == pointId }
        await run {
            do {
                try await self.service.unlinkPoint(sheetId: sheetId, curriculumPointId: pointId)
            } catch {
                self.linkedPointIds.insert(pointId)
                self.links = previousLinks
                throw error
            }
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
