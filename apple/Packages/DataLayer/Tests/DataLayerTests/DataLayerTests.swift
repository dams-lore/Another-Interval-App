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

    @Test func mapsAnEveryFiveMinutesWorkout() throws {
        let dto = WorkoutImportDTO(name: "EMF RX", format: "emom", rounds: 6, intervalSeconds: 300, steps: [
            .init(type: "reps", movement: "Row", value: 20, unit: "cal"),
            .init(type: "reps", movement: "Burpees Over Row", value: 15),
        ])
        let workout = try map(dto)
        #expect(workout.format == .emom)
        #expect(workout.rounds == 6)
        #expect(workout.intervalSeconds == 300)
        #expect(workout.steps.count == 2)
    }

    @Test func untimedIntervalsAreValid() throws {
        let dto = WorkoutImportDTO(name: "Chipper", format: "intervals", rounds: 5, steps: [
            .init(type: "distance", movement: "Run", value: 400, unit: "m"),
            .init(type: "reps", movement: "Burpees", value: 15),
        ])
        try map(dto).validate()
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

@Suite struct FileRepositoryTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AnotherIntervalTests-\(UUID().uuidString)")
    }

    private func workout(_ name: String, updated: TimeInterval = 0) -> Workout {
        Workout(
            name: name, format: .forTime, steps: [Step(type: .reps, movement: "Squats", value: 10)],
            createdAt: Date(timeIntervalSince1970: updated), updatedAt: Date(timeIntervalSince1970: updated)
        )
    }

    @Test func savedWorkoutsSurviveARestart() async throws {
        let directory = makeDirectory()
        let first = FileWorkoutRepository(directory: directory)
        try await first.save(workout("Fran"))
        let second = FileWorkoutRepository(directory: directory)   // « redémarrage » : nouvelle instance
        let loaded = try await second.all()
        #expect(loaded.map(\.name) == ["Fran"])
    }

    @Test func savingTwiceUpdatesInsteadOfDuplicating() async throws {
        let repository = FileWorkoutRepository(directory: makeDirectory())
        var item = workout("Fran")
        try await repository.save(item)
        item.name = "Fran (RX)"
        try await repository.save(item)
        let loaded = try await repository.all()
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "Fran (RX)")
    }

    @Test func mostRecentWorkoutComesFirst() async throws {
        let repository = FileWorkoutRepository(directory: makeDirectory())
        try await repository.save(workout("Ancienne", updated: 100))
        try await repository.save(workout("Récente", updated: 200))
        #expect(try await repository.all().map(\.name) == ["Récente", "Ancienne"])
    }

    @Test func deletedWorkoutsDisappearFromTheList() async throws {
        let repository = FileWorkoutRepository(directory: makeDirectory())
        let item = workout("Fran")
        try await repository.save(item)
        try await repository.delete(id: item.id)
        #expect(try await repository.all().isEmpty)
    }

    @Test func sessionsAreStoredNewestFirst() async throws {
        let directory = makeDirectory()
        let repository = FileSessionRepository(directory: directory)
        let base = workout("DARK ZONE")
        try await repository.save(SessionRecord(workout: base, startedAt: Date(timeIntervalSince1970: 100), duration: 60))
        try await repository.save(SessionRecord(workout: base, startedAt: Date(timeIntervalSince1970: 200), duration: 90))
        let loaded = try await FileSessionRepository(directory: directory).all()
        #expect(loaded.map(\.duration) == [90, 60])
    }

    @Test func sessionResultsKeepTheirDetails() async throws {
        let repository = FileSessionRepository(directory: makeDirectory())
        let split = StepSplit(stepIndex: 0, movement: "Row", duration: 53)
        let result = SetResult(setIndex: 0, splits: [split], completionTime: 195, interval: 300)
        try await repository.save(SessionRecord(workout: workout("DARK ZONE"), startedAt: Date(timeIntervalSince1970: 1), duration: 300, setResults: [result]))
        let loaded = try await repository.all()
        #expect(loaded.first?.setResults == [result])
    }

    @Test func aCorruptFileIsSetAsideAndTheListStartsEmpty() async throws {
        let directory = makeDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("workouts.json")
        try Data("pas du json".utf8).write(to: file)
        let repository = FileWorkoutRepository(directory: directory)
        #expect(try await repository.all().isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.appendingPathExtension("corrupt").path))
        try await repository.save(workout("Nouvelle"))       // on peut ré-écrire sans perdre l'ancien fichier
        #expect(try await repository.all().count == 1)
    }

    @Test func deleteSessionRemovesIt() async throws {
        let repository = FileSessionRepository(directory: makeDirectory())
        let record = SessionRecord(workout: workout("A"), startedAt: Date(), duration: 10)
        try await repository.save(record)
        try await repository.delete(id: record.id)
        #expect(try await repository.all().isEmpty)
    }
}
