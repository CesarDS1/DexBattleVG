//
//  MovesView.swift
//  PokeDexBattle — Presentation Layer
//

import SwiftUI

struct MovesView: View {
    @State private var viewModel: MovesViewModel

    init(pokemonID: Int, pokemonName: String) {
        _viewModel = State(initialValue: MovesViewModel(pokemonID: pokemonID, pokemonName: pokemonName))
    }

    var body: some View {
        Group {
            if !viewModel.groupedMoves.isEmpty {
                movesList
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                ProgressView(String(localized: "Loading moves…"))
            }
        }
        .navigationTitle(String(format: String(localized: "%@ Moves"), viewModel.pokemonName.capitalized))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Grouped list

    private var movesList: some View {
        List {
            ForEach(viewModel.groupedMoves, id: \.level) { group in
                Section {
                    ForEach(group.moves) { move in
                        MoveRowView(move: move)
                    }
                } header: {
                    levelHeader(group.level)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func levelHeader(_ level: Int) -> some View {
        HStack {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.yellow)
            Text(level == 0 ? String(localized: "Level 1") : String(format: String(localized: "Level %lld"), level))
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
            Button(String(localized: "Retry")) {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - MoveRowView

struct MoveRowView: View {
    let move: PokemonMove

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name + type badge
            HStack {
                Text(move.name.replacingOccurrences(of: "-", with: " ").capitalized)
                    .font(.headline)
                Spacer()
                typeBadge(move.type)
                classBadge(move.damageClass)
            }

            // Stats row
            HStack(spacing: 16) {
                statChip(label: String(localized: "PP"), value: "\(move.pp)")
                statChip(label: String(localized: "Power"), value: move.power.map(String.init) ?? "—")
                statChip(label: String(localized: "Acc."), value: move.accuracy.map { "\($0)%" } ?? "—")
            }

            // Short effect description
            Text(move.shortEffect)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func typeBadge(_ type: String) -> some View {
        Text(localizedTypeName(type))
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(pokemonTypeColor(type), in: Capsule())
    }

    private func classBadge(_ damageClass: String) -> some View {
        let icon: String
        switch damageClass {
        case "physical": icon = "⚔️"
        case "special":  icon = "✨"
        default:         icon = "🛡"
        }
        return Text("\(icon) \(localizedDamageClass(damageClass))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func statChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 44)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

}
