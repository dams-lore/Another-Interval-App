import Foundation
import Testing
import Domain
import Backend
import TestSupport
@testable import DataLayer

@Suite struct DataLayerTests {
    @Test func moduleNameIsStable() {
        #expect(DataLayer.moduleName == "DataLayer")
    }
}

@Suite struct WorkoutImportMapperTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func map(_ dto: WorkoutImportDTO) throws -> Workout {
        try WorkoutImportMapper.workout(from: dto, defaultName: "WOD 21/11/2026", now: now)
    }

    @Test func mapsAForTimeWorkout() throws {
        let dto = WorkoutImportDTO(name: "Fran", format: "for_time", steps: [
            .init(type: "reps", movement: "Thrusters", value: 21, weight: 43),
        ])
        let workout = try map(dto)
        #expect(workout.name == "Fran")
        #expect(workout.format == .forTime)
        #expect(workout.source == .photoImport)
        #expect(workout.steps.first?.weight == 43)
    }

    @Test func mapsAmrapCapTime() throws {
        let dto = WorkoutImportDTO(name: "Cindy", format: "amrap", capTime: 1200, steps: [
            .init(type: "reps", movement: "Pull-ups", value: 5),
        ])
        #expect(try map(dto).capTime == 1200)
    }

    @Test func convertsMinutesToSecondsForTimedSteps() throws {
        let dto = WorkoutImportDTO(name: "Tabata", format: "intervals", rounds: 8, steps: [
            .init(type: "time", movement: "Work", value: 2, unit: "min"),
            .init(type: "time", movement: "Rest", value: 30, unit: "s"),
        ])
        let workout = try map(dto)
        #expect(workout.steps[0].value == 120)
        #expect(workout.steps[0].unit == "s")
        #expect(workout.steps[1].value == 30)
        #expect(workout.rounds == 8)
    }

    @Test func missingNameFallsBackToTheDefault() throws {
        let dto = WorkoutImportDTO(name: "  ", format: "for_time", steps: [.init(type: "reps", movement: "Squats", value: 10)])
        #expect(try map(dto).name == "WOD 21/11/2026")
    }

    @Test func unknownFormatIsRejected() {
        let dto = WorkoutImportDTO(name: "X", format: "chipper", steps: [])
        #expect(throws: DomainError.self) { try map(dto) }
    }

    @Test func unknownStepTypeIsRejected() {
        let dto = WorkoutImportDTO(name: "X", format: "for_time", steps: [.init(type: "yoga", movement: "Pose", value: 1)])
        #expect(throws: DomainError.self) { try map(dto) }
    }

    @Test func nonPositiveCapAndRoundsAreDropped() throws {
        let dto = WorkoutImportDTO(name: "X", format: "for_time", capTime: 0, rounds: 0, steps: [.init(type: "reps", movement: "Squats", value: 10)])
        let workout = try map(dto)
        #expect(workout.capTime == nil)
        #expect(workout.rounds == nil)
    }
}

@Suite struct ImportErrorMappingTests {
    @Test func missingKeyGivesAHelpfulMessage() {
        let error = PhotoWorkoutImportService.domainError(for: .missingAPIKey)
        #expect(error == .validation("Clé API manquante : voir le fichier Secrets.xcconfig."))
    }

    @Test func unauthorizedMentionsTheKey() {
        let error = PhotoWorkoutImportService.domainError(for: .http(status: 401, message: "invalid x-api-key"))
        #expect(error == .validation("Clé API refusée (invalid x-api-key)."))
    }

    @Test func dateIsFormattedInFrench() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)   // 14/11/2023 (UTC)
        #expect(PhotoWorkoutImportService.dateString(date).count == 10)
    }

    @Test func serviceFailsWithoutAKeyBeforeAnyNetworkCall() async {
        let service = PhotoWorkoutImportService(client: AnthropicImportClient(apiKey: ""), clock: TestClock())
        await #expect(throws: DomainError.self) {
            _ = try await service.importWorkout(imageData: Data([1]), mimeType: "image/jpeg")
        }
    }
}
