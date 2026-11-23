import SwiftUI
import PhotosUI
import Domain
import DesignSystem

/// Import d'une séance par photo (Figma : « Import 1/2/3 » — version fonctionnelle simple, finition design ensuite).
public struct PhotoImportView: View {
    let viewModel: PhotoImportViewModel
    let onStart: (Workout) -> Void
    let onSave: ((Workout) -> Void)?
    let onClose: () -> Void

    @State private var pickerItem: PhotosPickerItem?

    public init(
        viewModel: PhotoImportViewModel,
        onStart: @escaping (Workout) -> Void,
        onSave: ((Workout) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onStart = onStart
        self.onSave = onSave
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            DS.Colors.backgroundGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button("Fermer", action: onClose)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                }
                content
                Spacer()
            }
            .padding(20)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle:
            VStack(alignment: .leading, spacing: 16) {
                Text("Importer une séance")
                    .font(.system(size: 32, weight: .heavy)).foregroundStyle(DS.Colors.textPrimary)
                Text("Choisis la photo d'un tableau ou d'une feuille de séance : l'IA la transforme en séance prête à lancer.")
                    .font(.system(size: 15)).foregroundStyle(DS.Colors.textSecondary)
                picker(title: "Choisir une photo")
            }
        case .analysing:
            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text("Lecture en cours")
                    .font(.system(size: 28, weight: .heavy)).foregroundStyle(DS.Colors.textPrimary)
                Text("L'IA reconstruit ta séance…")
                    .font(.system(size: 15)).foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity).padding(.top, 60)
        case .review(let workout):
            review(workout)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 16) {
                Text("Import impossible")
                    .font(.system(size: 28, weight: .heavy)).foregroundStyle(DS.Colors.textPrimary)
                Text(message)
                    .font(.system(size: 15)).foregroundStyle(DS.Colors.accentError)
                picker(title: "Essayer avec une autre photo")
            }
        }
    }

    private func picker(title: String) -> some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Text(title)
                .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(DS.Colors.accentGreen, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        }
    }

    private func review(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(workout.name)
                .font(.system(size: 32, weight: .heavy)).foregroundStyle(DS.Colors.textPrimary)
            HStack(spacing: 8) {
                chip(workout.format.rawValue.uppercased())
                if let cap = workout.capTime { chip("cap \(Int(cap / 60)) min") }
                if let rounds = workout.rounds { chip("\(rounds) rounds") }
            }
            Text("BLOCS DÉTECTÉS")
                .font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(DS.Colors.textSecondary)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(workout.steps) { step in
                        HStack {
                            Text(step.movement).font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text(Self.detail(of: step)).font(.system(size: 14)).foregroundStyle(DS.Colors.textSecondary)
                        }
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(14)
                        .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: DS.Radius.badge))
                    }
                }
            }
            Button { onStart(workout) } label: {
                Text("Lancer la séance")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(DS.Colors.accentGreen, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
            }
            if let onSave {
                Button { onSave(workout) } label: {
                    Text("Enregistrer sans lancer")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(DS.Colors.textPrimary)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                }
            }
            Button("Recommencer", action: { pickerItem = nil; viewModel.reset() })
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold)).foregroundStyle(DS.Colors.textSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(DS.Colors.glass, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
    }

    static func detail(of step: Step) -> String {
        var parts = ["\(Int(step.value)) \(step.unit ?? (step.type == .reps ? "reps" : ""))"]
        if let weight = step.weight { parts.append("\(Int(weight)) kg") }
        return parts.joined(separator: " · ").trimmingCharacters(in: .whitespaces)
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.fail("Impossible de lire cette photo.")
            return
        }
        await viewModel.importPhoto(data: ImageEncoding.jpegData(from: data))
    }
}
