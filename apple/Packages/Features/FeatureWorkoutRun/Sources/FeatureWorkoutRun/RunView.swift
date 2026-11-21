import SwiftUI
import Domain
import TimerEngine
import DesignSystem

/// Écran de séance (Figma : « Run — Compact (Intervals) » et « Run — Gym Mode »).
/// Polices : Manrope n'est pas encore embarquée, police système en attendant.
public struct RunView: View {
    let viewModel: RunViewModel
    let onClose: () -> Void

    public init(viewModel: RunViewModel, onClose: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        let gym = viewModel.displayMode == .gym
        ZStack {
            if gym {
                DS.Colors.gymBackground.ignoresSafeArea()
            } else {
                DS.Colors.backgroundGradient.ignoresSafeArea()
            }
            VStack(alignment: .leading, spacing: 0) {
                topBar(gym: gym)
                if gym { gymContent } else { compactContent }
                Spacer(minLength: 8)
                progressBar(gym: gym)
                controls(gym: gym)
            }
            .padding(.bottom, 12)
        }
        .task { @MainActor in
            // Rafraîchit l'affichage ~5 fois par seconde ; le temps réel vient des horodatages du moteur.
            while !Task.isCancelled {
                viewModel.refresh()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    // MARK: - Barre du haut

    private func topBar(gym: Bool) -> some View {
        HStack(spacing: 6) {
            Button(action: { viewModel.stop(); onClose() }) {
                Text("■  Stop")
                    .font(.system(size: gym ? 14 : 15, weight: .bold))
                    .foregroundStyle(gym ? Color.black : DS.Colors.accentError)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(gym ? Color.black.opacity(0.12) : DS.Colors.accentError.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: DS.Radius.chip))
            }
            Spacer()
            if gym {
                Text(viewModel.roundText)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(DS.Colors.gymBackground)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: DS.Radius.chip))
            } else {
                pill(viewModel.roundText)
                pill(viewModel.totalTimerText)
            }
            modePill(gym: gym)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold).monospacedDigit())
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
    }

    private func modePill(gym: Bool) -> some View {
        Button {
            viewModel.displayMode = gym ? .compact : .gym
        } label: {
            HStack(spacing: 4) {
                Text("compact").fontWeight(gym ? .semibold : .bold)
                    .foregroundStyle(gym ? Color.black.opacity(0.35) : DS.Colors.textPrimary)
                Text("|").foregroundStyle(gym ? Color.black.opacity(0.25) : DS.Colors.textFaint)
                Text("gym").fontWeight(gym ? .heavy : .regular)
                    .foregroundStyle(gym ? Color.black : DS.Colors.textTertiary)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(gym ? Color.black.opacity(0.12) : DS.Colors.glassSoft,
                        in: RoundedRectangle(cornerRadius: DS.Radius.chip))
        }
    }

    // MARK: - Mode compact

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.workout.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
                Text(viewModel.blockCounterText)
                    .font(.system(size: 11, weight: .bold)).tracking(2)
                    .foregroundStyle(DS.Colors.textSecondary)
                Text(viewModel.blockTitle)
                    .font(.system(size: 44, weight: .heavy)).tracking(-2)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .minimumScaleFactor(0.6).lineLimit(2)
                ForEach(viewModel.blockLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 28).padding(.top, 28)

            VStack(spacing: 4) {
                Text("BLOC")
                    .font(.system(size: 11, weight: .bold)).tracking(2)
                    .foregroundStyle(DS.Colors.textSecondary)
                ring
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.45), lineWidth: 12)
            if let progress = viewModel.blockProgress {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.Colors.accentGreen, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            // Règle critique n° 3 : même taille minutes / secondes, seule la graisse change.
            timerText(viewModel.mainTimerText, size: 36, minutesWeight: .bold, secondsWeight: .ultraLight)
        }
        .frame(width: 236, height: 236)
        .padding(12)
    }

    // MARK: - Mode gym

    private var gymContent: some View {
        VStack(spacing: 8) {
            Text(viewModel.totalTimerText)
                .font(.system(size: 32, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.black.opacity(0.35))
                .padding(.top, 40)
            Capsule().fill(Color.black.opacity(0.15)).frame(width: 48, height: 2)
            Text(viewModel.mainTimerText)
                .font(.system(size: 120, weight: .heavy).monospacedDigit())
                .tracking(-6)
                .foregroundStyle(Color.black)
                .minimumScaleFactor(0.5).lineLimit(1)
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.blockCounterText)
                    .font(.system(size: 13, weight: .bold)).tracking(2)
                    .foregroundStyle(Color.black.opacity(0.5))
                Text(viewModel.blockTitle)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Color.black)
                ForEach(viewModel.blockLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Progression et commandes

    @ViewBuilder
    private func progressBar(gym: Bool) -> some View {
        if let overall = viewModel.overallProgress {
            HStack(spacing: 12) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(gym ? Color.black.opacity(0.12) : Color.white.opacity(0.45))
                        Capsule()
                            .fill(gym ? Color.black : DS.Colors.accentGreen)
                            .frame(width: proxy.size.width * Double(overall.done) / Double(max(1, overall.total)))
                    }
                }
                .frame(height: 6)
                Text("\(overall.done) / \(overall.total)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(gym ? Color.black.opacity(0.45) : DS.Colors.textSecondary)
            }
            .padding(.horizontal, 24).padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func controls(gym: Bool) -> some View {
        let phase = viewModel.state.phase
        VStack(spacing: 12) {
            if phase == .idle {
                bigButton("▶  Démarrer", gym: gym) { viewModel.start() }
            } else if viewModel.isFinished {
                bigButton("Terminé", gym: gym) { onClose() }
            } else {
                HStack(spacing: 10) {
                    bigButton(viewModel.advanceLabel, gym: gym) { viewModel.advance() }
                    pauseButton(gym: gym)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func bigButton(_ title: String, gym: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: gym ? 16 : 20, weight: .bold))
                .foregroundStyle(gym ? DS.Colors.gymBackground : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: gym ? 52 : 80)
                .background(gym ? Color.black.opacity(0.88) : DS.Colors.accentGreen,
                            in: RoundedRectangle(cornerRadius: gym ? DS.Radius.small : DS.Radius.medium))
        }
    }

    private func pauseButton(gym: Bool) -> some View {
        Button { viewModel.togglePause() } label: {
            Text(viewModel.state.phase == .paused ? "▶" : "⏸")
                .font(.system(size: gym ? 22 : 18))
                .foregroundStyle(gym ? Color.black.opacity(0.4) : DS.Colors.textPrimary)
                .frame(width: gym ? 52 : 80, height: gym ? 52 : 80)
                .background(gym ? Color.black.opacity(0.1) : DS.Colors.glass,
                            in: RoundedRectangle(cornerRadius: gym ? DS.Radius.small : DS.Radius.medium))
        }
    }

    // MARK: - Texte du chrono

    private func timerText(_ text: String, size: CGFloat, minutesWeight: Font.Weight, secondsWeight: Font.Weight) -> some View {
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        let minutes = parts.first ?? "00"
        let seconds = parts.count > 1 ? parts[1] : "00"
        return HStack(spacing: 0) {
            Text(minutes + ":").font(.system(size: size, weight: minutesWeight).monospacedDigit())
            Text(seconds).font(.system(size: size, weight: secondsWeight).monospacedDigit())
        }
        .foregroundStyle(DS.Colors.textPrimary)
    }
}
