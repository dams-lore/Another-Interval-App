import Foundation
import Testing
import Domain
import TestSupport
@testable import FeatureWorkoutRun

@MainActor @Suite struct EveryXViewModelTests {
    private func workout() -> Workout {
        Workout(
            name: "DARK ZONE", format: .emom,
            steps: [
                Step(type: .reps, movement: "Row", value: 20, unit: "cal"),
                Step(type: .reps, movement: "Burpees Over Row", value: 15),
                Step(type: .reps, movement: "Row", value: 20, unit: "cal"),
                Step(type: .reps, movement: "Burpees Over Row", value: 15),
            ],
            rounds: 3, intervalSeconds: 300
        )
    }

    private func makeModel(_ clock: TestClock, _ guidance: RecordingGuidanceOutput? = nil) -> EveryXViewModel {
        let model = EveryXViewModel(workout: workout(), clock: clock, guidance: guidance)
        model.countdown = 0
        return model
    }

    /// Fait avancer le temps puis valide une étape.
    private func tap(_ model: EveryXViewModel, _ clock: TestClock, after seconds: TimeInterval) {
        clock.advance(by: seconds)
        model.refresh()
        model.tap()
    }

    @Test func recapDescribesTheSession() {
        let model = makeModel(TestClock())
        #expect(model.setCount == 3)
        #expect(model.interval == 300)
        #expect(model.totalDuration == 900)
        #expect(model.stepLines.first == "20 cal Row")
        #expect(model.explanationText.contains("5:00"))
        #expect(model.explanationText.contains("15:00"))
    }

    @Test func valuesCanBeEditedBeforeStart() {
        let model = makeModel(TestClock())
        model.adjustStep(at: 0, by: -5)           // 20 -> 15 calories
        model.adjustSets(by: 2)                   // 3 -> 5 sets
        model.adjustInterval(by: 60)              // 5:00 -> 6:00
        #expect(model.stepLines[0] == "15 cal Row")
        #expect(model.setCount == 5)
        #expect(model.interval == 360)
        #expect(model.totalDuration == 1800)
    }

    @Test func editedValuesAreClamped() {
        let model = makeModel(TestClock())
        model.adjustStep(at: 1, by: -100)
        model.adjustSets(by: -100)
        model.adjustInterval(by: -10_000)
        model.adjustStep(at: 99, by: 1)           // étape inexistante : ignorée
        #expect(model.steps[1].value == 1)
        #expect(model.setCount == 1)
        #expect(model.interval == 60)
    }

    @Test func valuesCannotBeEditedOnceStarted() {
        let model = makeModel(TestClock())
        model.start()
        model.adjustStep(at: 0, by: 5)
        model.adjustSets(by: 1)
        #expect(model.steps[0].value == 20)
        #expect(model.setCount == 3)
    }

    @Test func notesAreNotInTheStepTitles() {
        var workout = self.workout()
        workout.steps[0].notes = "H/F : 20/16"
        let model = EveryXViewModel(workout: workout, clock: TestClock())
        #expect(model.stepLines[0] == "20 cal Row")
        #expect(model.stepNote(at: 0) == "H/F : 20/16")
        #expect(model.stepNote(at: 1) == nil)
    }

    @Test func startShowsTheFirstSet() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        clock.advance(by: 47)
        model.refresh()
        #expect(model.setNumber == 1)
        #expect(model.stepNumber == 1)
        #expect(model.windowRemainingText == "4:13")
        #expect(model.setElapsedText == "0:47")
        #expect(model.currentStepTitle == "20 cal Row")
        #expect(model.doneButtonTitle == "Row fini")
    }

    @Test func tapsRecordSplitsAndReachRest() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        tap(model, clock, after: 53)    // row 0:53
        #expect(model.stepNumber == 2)
        #expect(model.doneButtonTitle == "Burpees fini")
        tap(model, clock, after: 40)    // burpees 0:40
        tap(model, clock, after: 60)    // row 1:00
        #expect(model.doneButtonTitle == "Fin du set")   // dernière étape
        #expect(model.isResting == false)
        tap(model, clock, after: 42)    // burpees 0:42 : set fini à 3:15
        #expect(model.isResting)
        #expect(model.completionTimeText == "3:15")
        #expect(model.windowRemainingText == "1:45")
        #expect(model.nextStepTitle == "20 cal Row")
        #expect(model.segmentStates == [true, true, true, true])
    }

    @Test func nextSetStartsAutomaticallyAndKeepsTheResult() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        for seconds in [53.0, 40, 60, 42] { tap(model, clock, after: seconds) }   // set fini à 195 s
        clock.advance(by: 106)   // 301 s
        model.refresh()
        #expect(model.setNumber == 2)
        #expect(model.isResting == false)
        #expect(model.stepNumber == 1)
        let first = model.results.first
        #expect(first?.completionTime == 195)
        #expect(first?.splits.map(\.duration) == [53, 40, 60, 42])
        #expect(first?.rest == 105)
    }

    @Test func unfinishedSetIsMarkedAndNextSetStarts() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        tap(model, clock, after: 60)    // une seule étape validée
        clock.advance(by: 241)          // 301 s : le set 2 part
        model.refresh()
        #expect(model.setNumber == 2)
        #expect(model.results.first?.isCompleted == false)
        #expect(model.badges == [.notFinished, .current, .todo])
    }

    @Test func undoSetCompletionReopensTheLastStep() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        for seconds in [50.0, 40, 60, 40] { tap(model, clock, after: seconds) }
        #expect(model.isResting)
        model.undoSetCompletion()
        #expect(model.isResting == false)
        #expect(model.stepNumber == 4)
        clock.advance(by: 10)
        model.refresh()
        model.tap()
        #expect(model.isResting)
        #expect(model.completionTimeText == "3:20")   // 50+40+60+40+10 = 200 s
    }

    @Test func tapsAreIgnoredDuringRestAndBeforeStart() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.tap()
        #expect(model.results.isEmpty)
        model.start()
        for seconds in [10.0, 10, 10, 10] { tap(model, clock, after: seconds) }
        let before = model.results.count
        model.tap()
        model.tap()
        #expect(model.results.count == before)
        #expect(model.isResting)
    }

    @Test func sessionFinishesWithASummary() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        // set 1 : 195 s, set 2 : 190 s (démarre à 300 s), set 3 non fini
        for seconds in [53.0, 40, 60, 42] { tap(model, clock, after: seconds) }
        clock.advance(by: 105)   // 300 s
        model.refresh()
        for seconds in [50.0, 40, 60, 40] { tap(model, clock, after: seconds) }
        clock.advance(by: 700)   // fin des 900 s
        model.refresh()
        #expect(model.isFinished)
        let summary = model.summary
        #expect(summary.results.count == 3)
        #expect(summary.completedCount == 2)
        #expect(summary.bestTime == 190)
        #expect(summary.worstTime == 195)
        #expect(summary.spread == 5)
        #expect(model.badges == [.done, .done, .notFinished])
        #expect(model.shareText.contains("2/3 sets"))
        #expect(model.shareText.contains("Set 3 : non fini"))
    }

    @Test func stopFinishesAndKeepsWhatWasDone() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        tap(model, clock, after: 30)
        model.stop()
        #expect(model.isFinished)
        #expect(model.summary.results.count == 1)
        #expect(model.summary.results.first?.splits.count == 1)
    }

    @Test func playsStepAndSetSignals() {
        let clock = TestClock()
        let guidance = RecordingGuidanceOutput()
        let model = makeModel(clock, guidance)
        model.start()
        for seconds in [10.0, 10, 10, 10] { tap(model, clock, after: seconds) }
        let cues = guidance.cues
        #expect(cues.filter { $0 == .stepDone }.count == 3)
        #expect(cues.filter { $0 == .setDone }.count == 1)
    }

    @Test func finishedSessionIsReportedOnceWithItsSetResults() {
        let clock = TestClock()
        let reported = ReportCollector()
        let model = EveryXViewModel(workout: workout(), clock: clock, onFinished: { reported.items.append($0) })
        model.countdown = 0
        model.start()
        for seconds in [53.0, 40, 60, 42] { tap(model, clock, after: seconds) }
        clock.advance(by: 1_000)
        model.refresh()
        model.refresh()
        #expect(reported.items.count == 1)
        #expect(reported.items.first?.setResults.count == 3)
        #expect(reported.items.first?.completedSets == 1)
        #expect(reported.items.first?.workout.name == "DARK ZONE")
    }

    @Test func aSessionWithoutAnyTapIsNotRecorded() {
        let clock = TestClock()
        let reported = ReportCollector()
        let model = EveryXViewModel(workout: workout(), clock: clock, onFinished: { reported.items.append($0) })
        model.countdown = 0
        model.start()
        clock.advance(by: 20)
        model.stop()
        #expect(reported.items.isEmpty)
    }

    @Test func shareTextMatchesTheSharedFormatter() {
        let clock = TestClock()
        let model = makeModel(clock)
        model.start()
        tap(model, clock, after: 30)
        model.stop()
        #expect(model.shareText == ResultText.share(workout: model.workout, summary: model.summary))
    }
}

/// Reçoit les séances terminées pendant les tests.
@MainActor final class ReportCollector {
    var items: [SessionRecord] = []
}
