import Foundation
import Testing
import Domain
import TestSupport
@testable import FeaturePhotoImport

@MainActor @Suite struct PhotoImportViewModelTests {
    private let workout = Workout(name: "Fran", format: .forTime, steps: [Step(type: .reps, movement: "Thrusters", value: 21)])

    @Test func startsIdle() {
        let model = PhotoImportViewModel(service: FakeWorkoutImportService(result: .success(workout)))
        #expect(model.status == .idle)
    }

    @Test func successMovesToReview() async {
        let model = PhotoImportViewModel(service: FakeWorkoutImportService(result: .success(workout)))
        await model.importPhoto(data: Data([1]))
        #expect(model.status == .review(workout))
    }

    @Test func validationErrorShowsItsMessage() async {
        let service = FakeWorkoutImportService(result: .failure(.validation("Photo illisible")))
        let model = PhotoImportViewModel(service: service)
        await model.importPhoto(data: Data([1]))
        #expect(model.status == .failed("Photo illisible"))
    }

    @Test func offlineGivesAFriendlyMessage() async {
        let model = PhotoImportViewModel(service: FakeWorkoutImportService(result: .failure(.offline)))
        await model.importPhoto(data: Data([1]))
        guard case .failed(let message) = model.status else {
            Issue.record("statut inattendu")
            return
        }
        #expect(message.contains("connexion"))
    }

    @Test func resetGoesBackToIdle() async {
        let model = PhotoImportViewModel(service: FakeWorkoutImportService(result: .success(workout)))
        await model.importPhoto(data: Data([1]))
        model.reset()
        #expect(model.status == .idle)
    }

    @Test func stepDetailIsReadable() {
        let step = Step(type: .reps, movement: "Thrusters", value: 21, weight: 43)
        #expect(PhotoImportView.detail(of: step) == "21 reps · 43 kg")
    }
}
