//
//  ClassroomModels.swift
//  FieldWise Core
//
//  Codable models for the Firebase-backed teacher/student classroom
//  system: who someone is (UserProfile), what class they're in
//  (SchoolClass), what they've been asked to do (FieldworkTask), and
//  what they've actually recorded (FieldworkEntry).
//
//  These mirror the Firestore collections directly — see
//  FirestoreService.swift for the collection names and security rules,
//  and FIRESTORE_RULES.md for the deployable rules text. Field names
//  here are deliberately kept identical to their Firestore document
//  field names so Codable's default key mapping just works without a
//  CodingKeys table to keep in sync by hand.
//

import Foundation

// MARK: - Role

/// Fixed Year 7–12 range, stored as SchoolClass.yearLevel (plain string,
/// e.g. "Year 10") so the DB column stays simple text — the fixed set of
/// options lives here in one place and is reused by the class-creation
/// picker, the student join form's picker, and anywhere a year level is
/// displayed, so all three always offer/expect exactly the same values.
enum YearLevel: String, CaseIterable, Identifiable {
    case year7 = "Year 7"
    case year8 = "Year 8"
    case year9 = "Year 9"
    case year10 = "Year 10"
    case year11 = "Year 11"
    case year12 = "Year 12"

    var id: String { rawValue }
}

enum UserRole: String, Codable {
    case teacher
    case student
}

// MARK: - UserProfile  (collection: "users", document id = Firebase Auth uid)

/// One person — teacher or student. The document ID in Firestore is
/// always the Firebase Auth `uid`, so it's deliberately not stored as a
/// field inside the document itself (it'd just be a second source of
/// truth for the same value). `FirestoreService` attaches the id when
/// decoding, via `UserProfile.with(id:)`.
struct UserProfile: Codable, Identifiable, Equatable {
    var id: String = ""
    var role: UserRole
    var schoolId: String
    var displayName: String
    var classId: String?
    var createdAt: Date?

    // Exclude `id` — it's the Firestore document ID, not a stored field.
    // It's attached after decode via .with(id:).
    enum CodingKeys: String, CodingKey {
        case role, schoolId, displayName, classId, createdAt
    }

    func with(id: String) -> UserProfile {
        var copy = self
        copy.id = id
        return copy
    }

    static func newTeacher(displayName: String, schoolId: String) -> UserProfile {
        UserProfile(role: .teacher, schoolId: schoolId, displayName: displayName, classId: nil, createdAt: Date())
    }

    static func newStudent(displayName: String, schoolId: String, classId: String) -> UserProfile {
        UserProfile(role: .student, schoolId: schoolId, displayName: displayName, classId: classId, createdAt: Date())
    }
}

// MARK: - SchoolClass  (collection: "classes", document id = auto)

struct SchoolClass: Codable, Identifiable, Equatable {
    var id: String = ""
    var teacherId: String
    var schoolId: String
    var name: String
    var classCode: String
    var yearLevel: String?
    var active: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case teacherId, schoolId, name, classCode, yearLevel, active, createdAt
    }

    func with(id: String) -> SchoolClass {
        var copy = self
        copy.id = id
        return copy
    }

    static func new(teacherId: String, schoolId: String, name: String, classCode: String, yearLevel: String?) -> SchoolClass {
        SchoolClass(teacherId: teacherId, schoolId: schoolId, name: name, classCode: classCode, yearLevel: yearLevel, active: true, createdAt: Date())
    }
}

// MARK: - FieldworkTask  (collection: "fieldworkTasks", document id = auto)

struct FieldworkTask: Codable, Identifiable, Equatable {
    var id: String = ""
    var classId: String
    var title: String
    var instructions: String
    var bookletId: String?          // if set, this task IS a structured booklet
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case classId, title, instructions, bookletId, createdAt
    }

    var isBooklet: Bool { bookletId != nil }

    func with(id: String) -> FieldworkTask {
        var copy = self
        copy.id = id
        return copy
    }

    static func new(classId: String, title: String, instructions: String) -> FieldworkTask {
        FieldworkTask(classId: classId, title: title, instructions: instructions, bookletId: nil, createdAt: Date())
    }
}

// MARK: - FieldworkEntry  (collection: "fieldworkEntries", document id = client-generated UUID)

enum FieldworkEntryStatus: String, Codable {
    case draft
    case submitted
}

struct FieldworkEntryGPS: Codable, Equatable {
    var lat: Double
    var lng: Double
}

struct FieldworkEntryWeather: Codable, Equatable {
    var temp: Double
    var condition: String
}

struct FieldworkEntrySoilColour: Codable, Equatable {
    var hue: String
    var value: String
    var chroma: String
    var hex: String
}

struct FieldworkEntry: Codable, Identifiable, Equatable {
    var id: String = ""
    var taskId: String
    var classId: String
    var studentUid: String
    var studentDisplayName: String
    var status: FieldworkEntryStatus
    var gps: FieldworkEntryGPS?
    var notes: String
    var soilColour: FieldworkEntrySoilColour?
    var weather: FieldworkEntryWeather?
    var photoStoragePaths: [String]
    var clientCreatedAt: Date?
    var serverCreatedAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case taskId, classId, studentUid, studentDisplayName, status
        case gps, notes, soilColour, weather, photoStoragePaths
        case clientCreatedAt, serverCreatedAt, updatedAt
    }

    func with(id: String) -> FieldworkEntry {
        var copy = self
        copy.id = id
        return copy
    }

    /// A fresh draft entry, given a brand-new client-generated id so it
    /// can be created and edited entirely offline before ever reaching
    /// Firestore.
    static func newDraft(taskId: String, classId: String, studentUid: String, studentDisplayName: String) -> FieldworkEntry {
        let now = Date()
        return FieldworkEntry(
            id: UUID().uuidString,
            taskId: taskId,
            classId: classId,
            studentUid: studentUid,
            studentDisplayName: studentDisplayName,
            status: .draft,
            gps: nil,
            notes: "",
            soilColour: nil,
            weather: nil,
            photoStoragePaths: [],
            clientCreatedAt: now,
            serverCreatedAt: nil,
            updatedAt: now
        )
    }
}
