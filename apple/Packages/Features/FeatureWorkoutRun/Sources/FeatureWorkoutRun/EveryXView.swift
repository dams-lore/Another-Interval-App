import SwiftUI
import Domain
import DesignSystem

/// Parcours « Every X × N » : récap avant départ → set en cours / repos → récap de fin.
/// Référence : docs/design/every-x-run.md (maquettes dans docs/design/reference/every-x/).
public struct EveryXView: View {
    let model: EveryXViewModel
    let onClose: () -> Void

    public init(model: EveryXViewModel, onClose: @escaping () -> Void = {}) {
        self.model = model
        self.onClose = onClose
    }

    public var body: some View {
        Group {
            if !model.hasStarted {
                EveryXSetupView(model: model, onClose: onClose)
            } else if model.isFinished {
                EveryXSummaryView(workout: model.workout, summary: model.summary, shareText: model.shareText, onClose: onClose)
            } else {
                EveryXRunView(model: model, onClose: onClose)
            }
        }
        .task { @MainActor in
            // Rafraîchit ~5 fois par seconde ; le temps réel vient des horodatages du moteur.
            while !Task.isCancelled {
                model.refresh()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }
}

// MARK: - 1. Récap avant départ

struct EveryXSetupView: View {
    let model: EveryXViewModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            DS.Colors.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button("Fermer", action: onClose)
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                        Spacer()
                    }
                    Text(model.workout.name)
                        .font(.system(size: 34, weight: .heavy)).tracking(-1)
                        .foregroundStyle(DS.Colors.textPrimary)

                    card {
                        Text("MODIFIABLE AVANT LE DÉPART")
                            .font(.system(size: 12, weight: .bold)).tracking(2)
                            .foregroundStyle(DS.Colors.textSecondary)
                        adjustRow("Intervalle", value: RunFormat.short(model.interval),
                                  minus: { model.adjustInterval(by: -30) }, plus: { model.adjustInterval(by: 30) })
                        adjustRow("Sets", value: "\(model.setCount)",
                                  minus: { model.adjustSets(by: -1) }, plus: { model.adjustSets(by: 1) })
                    }

                    card {
                        Text("DANS CHAQUE SET")
                            .font(.system(size: 12, weight: .bold)).tracking(2)
                            .foregroundStyle(DS.Colors.textSecondary)
                        ForEach(Array(model.stepLines.enumerated()), id: \.offset) { index, line in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 15, weight: .bold)).foregroundStyle(DS.Colors.textSecondary)
                                    .frame(width: 18, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line)
                                        .font(.system(size: 20, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                                        .lineLimit(2).minimumScaleFactor(0.7)
                                    if let note = model.stepNote(at: index) {
                                        Text(note).font(.system(size: 13)).foregroundStyle(DS.Colors.textSecondary)
                                    }
                                }
                                Spacer(minLength: 4)
                                roundButton("−") { model.adjustStep(at: index, by: -1) }
                                roundButton("+") { model.adjustStep(at: index, by: 1) }
                            }
                        }
                        Text(model.explanationText)
                            .font(.system(size: 14)).foregroundStyle(DS.Colors.textSecondary)
                    }

                    card {
                        HStack {
                            Text("Départ dans")
                                .font(.system(size: 20, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1).fixedSize()
                            Spacer(minLength: 12)
                            HStack(spacing: 4) {
                                ForEach([5.0, 10.0], id: \.self) { seconds in
                                    Button { model.countdown = seconds } label: {
                                        Text("\(Int(seconds)) s")
                                            .font(.system(size: 18, weight: .bold)).lineLimit(1).fixedSize()
                                            .foregroundStyle(model.countdown == seconds ? Color.white : DS.Colors.textSecondary)
                                            .padding(.horizontal, 18).padding(.vertical, 10)
                                            .background(model.countdown == seconds ? DS.Colors.textPrimary : Color.clear,
                                                        in: RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                            }
                            .padding(4)
                            .background(Color.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
                        }
                        Text("Un tap à la fin de chaque étape : tu obtiens un temps par étape. Touche n'importe où sur l'écran.")
                            .font(.system(size: 14)).foregroundStyle(DS.Colors.textSecondary)
                    }

                    Button { model.start() } label: {
                        Text("Démarrer")
                            .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 64)
                            .background(DS.Colors.accentGreen, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                    }
                }
                .padding(20)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(DS.Colors.glassBorder, lineWidth: 1))
    }

    private func adjustRow(_ title: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 20, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
            Spacer()
            roundButton("−", action: minus)
            Text(value)
                .font(.system(size: 22, weight: .heavy).monospacedDigit()).foregroundStyle(DS.Colors.textPrimary)
                .frame(minWidth: 60)
            roundButton("+", action: plus)
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 22, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.5), in: Circle())
        }
    }
}

// MARK: - 2 & 3. Set en cours et repos

struct EveryXRunView: View {
    let model: EveryXViewModel
    let onClose: () -> Void

    var body: some View {
        let resting = model.isResting
        let ink = resting ? DS.Colors.gymBackground : Color.black
        ZStack {
            (resting ? DS.Colors.restBackground : DS.Colors.gymBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar(resting: resting, ink: ink)
                Spacer()
                if model.isCountdown {
                    countdownContent(ink: ink)
                } else if resting {
                    restContent(ink: ink)
                } else {
                    workContent(ink: ink)
                }
                Spacer()
                badgeRow(resting: resting)
                bottomButtons(resting: resting)
            }
            .padding(.bottom, 12)
        }
        // Taper n'importe où sur l'écran valide l'étape (les boutons gardent la priorité).
        .contentShape(Rectangle())
        .onTapGesture { model.tap() }
        .keepScreenAwake()
    }

    private func topBar(resting: Bool, ink: Color) -> some View {
        HStack {
            pill("Stop", ink: ink, resting: resting) { model.stop(); onClose() }
            Spacer()
            Text(model.totalElapsedText)
                .font(.system(size: 22, weight: .heavy).monospacedDigit())
                .foregroundStyle(ink)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(pillBackground(resting: resting), in: Capsule())
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func pill(_ title: String, ink: Color, resting: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .heavy)).foregroundStyle(ink)
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(pillBackground(resting: resting), in: Capsule())
        }
    }

    private func pillBackground(resting: Bool) -> Color {
        resting ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
    }

    private func countdownContent(ink: Color) -> some View {
        VStack(spacing: 8) {
            Text("DÉPART DANS")
                .font(.system(size: 18, weight: .heavy)).tracking(3).foregroundStyle(ink.opacity(0.6))
            Text(model.countdownText)
                .font(.system(size: 160, weight: .heavy).monospacedDigit()).foregroundStyle(ink)
        }
    }

    private func workContent(ink: Color) -> some View {
        VStack(spacing: 10) {
            Text("SET \(model.setNumber) / \(model.setCount) · ÉTAPE \(model.stepNumber) / \(max(1, model.steps.count))")
                .font(.system(size: 20, weight: .heavy)).tracking(2).foregroundStyle(ink.opacity(0.55))
            Text(model.currentStepTitle)
                .font(.system(size: 38, weight: .heavy)).foregroundStyle(ink)
                .multilineTextAlignment(.center).minimumScaleFactor(0.6)
            bigTimer(model.windowRemainingText, ink: ink)
            Text("Set en cours \(model.setElapsedText)")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(ink.opacity(0.55))
            segments(ink: ink)
        }
        .padding(.horizontal, 20)
    }

    private func restContent(ink: Color) -> some View {
        VStack(spacing: 10) {
            Text("SET \(model.setNumber) / \(model.setCount) TENU")
                .font(.system(size: 20, weight: .heavy)).tracking(2).foregroundStyle(Color.white.opacity(0.55))
            Text("Repos")
                .font(.system(size: 38, weight: .heavy)).foregroundStyle(ink)
            bigTimer(model.windowRemainingText, ink: ink)
            Text(restCaption)
                .font(.system(size: 22, weight: .bold)).foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
            segments(ink: ink)
        }
        .padding(.horizontal, 20)
    }

    private var restCaption: String {
        var text = "Set en \(model.completionTimeText)"
        if let next = model.nextStepTitle { text += " · prochain : \(next)" }
        return text
    }

    private func bigTimer(_ text: String, ink: Color) -> some View {
        Text(text)
            .font(.system(size: 150, weight: .heavy).monospacedDigit()).tracking(-6)
            .foregroundStyle(ink).minimumScaleFactor(0.5).lineLimit(1)
    }

    private func segments(ink: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(model.segmentStates.enumerated()), id: \.offset) { _, done in
                Capsule().fill(done ? ink : ink.opacity(0.25)).frame(height: 10)
            }
        }
        .padding(.horizontal, 40).padding(.top, 6)
    }

    private func badgeRow(resting: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(model.badges.enumerated()), id: \.offset) { index, badge in
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(badgeInk(badge, resting: resting))
                    .frame(maxWidth: .infinity).frame(height: 38)
                    .background(badgeBackground(badge, resting: resting), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 10)
    }

    private func badgeBackground(_ badge: SetBadge, resting: Bool) -> Color {
        switch (badge, resting) {
        case (.current, false): Color.black
        case (.current, true), (.done, true): DS.Colors.gymBackground
        case (.done, false): Color.black.opacity(0.55)
        case (.notFinished, _): DS.Colors.accentError.opacity(0.6)
        case (.todo, false): Color.black.opacity(0.12)
        case (.todo, true): Color.white.opacity(0.12)
        }
    }

    private func badgeInk(_ badge: SetBadge, resting: Bool) -> Color {
        switch (badge, resting) {
        case (.current, false): DS.Colors.gymBackground
        case (.current, true), (.done, true): Color.black
        case (.done, false): DS.Colors.gymBackground
        case (.notFinished, _): Color.white
        case (.todo, false): Color.black.opacity(0.4)
        case (.todo, true): Color.white.opacity(0.4)
        }
    }

    private func bottomButtons(resting: Bool) -> some View {
        HStack(spacing: 12) {
            if model.isCountdown {
                EmptyView()
            } else if resting {
                bigButton("Annuler, set pas fini", resting: true) { model.undoSetCompletion() }
            } else {
                bigButton(model.doneButtonTitle, resting: false) { model.tap() }
            }
            Button { model.togglePause() } label: {
                Text(model.isPaused ? "Reprendre" : "Pause")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(resting ? DS.Colors.gymBackground : Color.black.opacity(0.7))
                    .frame(width: 110, height: 72)
                    .background(resting ? Color.white.opacity(0.12) : Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .padding(.horizontal, 16)
    }

    private func bigButton(_ title: String, resting: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(resting ? Color.white : DS.Colors.gymBackground)
                .frame(maxWidth: .infinity).frame(height: 72)
                .background(resting ? Color.white.opacity(0.12) : Color.black, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

// MARK: - 4. Récap de fin

/// Récap de fin d'une séance Every X (pendant la séance et depuis l'historique).
public struct EveryXSummaryView: View {
    let workout: Workout
    let summary: EveryXSummary
    let shareText: String
    let onClose: () -> Void

    public init(workout: Workout, summary: EveryXSummary, shareText: String, onClose: @escaping () -> Void) {
        self.workout = workout
        self.summary = summary
        self.shareText = shareText
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            DS.Colors.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(workout.name.uppercased()) TERMINÉE")
                        .font(.system(size: 15, weight: .bold)).tracking(2).foregroundStyle(DS.Colors.accentPurple)
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        Text("\(summary.completedCount)/\(summary.totalSets)")
                            .font(.system(size: 84, weight: .heavy)).tracking(-3).foregroundStyle(DS.Colors.textPrimary)
                        Text(averageCaption(summary))
                            .font(.system(size: 18, weight: .medium)).foregroundStyle(DS.Colors.textSecondary)
                    }
                    HStack(spacing: 10) {
                        statCard(summary.bestTime, "Meilleur set")
                        statCard(summary.worstTime, "Pire set")
                        statCard(summary.spread, "Écart")
                    }
                    setBySet(summary)
                    HStack(spacing: 12) {
                        ShareLink(item: shareText) {
                            actionLabel("Copier le résultat")
                        }
                        Button(action: onClose) { actionLabel("Terminer") }
                    }
                }
                .padding(20)
            }
        }
    }

    private func averageCaption(_ summary: EveryXSummary) -> String {
        guard let average = summary.averageTime else { return "sets finis" }
        return "sets finis, moyenne \(RunFormat.short(average))"
    }

    private func statCard(_ value: TimeInterval?, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.map { RunFormat.short($0) } ?? "—")
                .font(.system(size: 30, weight: .heavy).monospacedDigit()).foregroundStyle(DS.Colors.textPrimary)
            Text(title).font(.system(size: 15)).foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: 18))
    }

    private var movementNames: [String] {
        var seen: [String] = []
        for step in workout.steps where !seen.contains(step.movement) { seen.append(step.movement) }
        return seen
    }

    private func color(for movement: String) -> Color {
        let index = movementNames.firstIndex(of: movement) ?? 0
        return DS.Colors.stepPalette[index % DS.Colors.stepPalette.count]
    }

    private func setBySet(_ summary: EveryXSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SET PAR SET")
                .font(.system(size: 14, weight: .bold)).tracking(2).foregroundStyle(DS.Colors.textSecondary)
            HStack(spacing: 14) {
                ForEach(movementNames, id: \.self) { name in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(color(for: name)).frame(width: 16, height: 16)
                        Text(name).font(.system(size: 14)).foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(DS.Colors.restBar).frame(width: 16, height: 16)
                    Text("Repos").font(.system(size: 14)).foregroundStyle(DS.Colors.textSecondary)
                }
            }
            ForEach(summary.results) { result in
                row(for: result)
            }
        }
        .padding(18)
        .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(DS.Colors.glassBorder, lineWidth: 1))
    }

    private func row(for result: SetResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Set \(result.setIndex + 1)")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                .frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                bar(for: result)
                Text(headline(for: result))
                    .font(.system(size: 15)).foregroundStyle(DS.Colors.textSecondary)
                if !result.splits.isEmpty {
                    Text(result.splits.map { "\($0.movement.lowercased()) \(RunFormat.short($0.duration))" }.joined(separator: " · "))
                        .font(.system(size: 15)).foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }

    private func headline(for result: SetResult) -> String {
        guard let time = result.completionTime, let rest = result.rest else { return "non fini" }
        return "\(RunFormat.short(time)) · repos \(RunFormat.short(rest))"
    }

    private func bar(for result: SetResult) -> some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(Array(result.splits.enumerated()), id: \.offset) { _, split in
                    Rectangle().fill(color(for: split.movement))
                        .frame(width: proxy.size.width * min(1, split.duration / max(1, result.interval)))
                }
                if result.splits.isEmpty, let time = result.completionTime {
                    Rectangle().fill(DS.Colors.stepPalette[0])
                        .frame(width: proxy.size.width * min(1, time / max(1, result.interval)))
                }
                Rectangle().fill(DS.Colors.restBar)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(height: 22)
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary)
            .frame(maxWidth: .infinity).frame(height: 60)
            .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: 24))
    }
}
