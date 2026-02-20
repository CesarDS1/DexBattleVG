//
//  EvolutionsView.swift
//  PokeDexBattle — Presentation Layer
//
//  Displays the full evolution chain as a vertical flow of stages.
//  Branching chains (e.g. Eevee) are rendered as a column of parallel branches.
//

import SwiftUI

/// Shows the evolution chain for a Pokémon, rendered top-to-bottom.
/// Each stage displays the sprite, name, Pokédex number, and the trigger
/// condition required to reach it (e.g. "Level 16", "Use Fire Stone").
struct EvolutionsView: View {
    @State private var viewModel: EvolutionsViewModel

    init(pokemonID: Int, pokemonName: String) {
        _viewModel = State(initialValue: EvolutionsViewModel(pokemonID: pokemonID, pokemonName: pokemonName))
    }

    var body: some View {
        Group {
            if let chain = viewModel.chain {
                chainContent(chain)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                ProgressView(String(localized: "Loading evolutions…"))
            }
        }
        .navigationTitle(String(format: String(localized: "%@ Evolutions"), viewModel.pokemonName.capitalized))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: - Chain renderer

    /// Wraps the recursive stage tree in a scrollable container.
    private func chainContent(_ root: EvolutionStage) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                stageView(root, isRoot: true)
            }
            .padding(.vertical)
        }
    }

    /// Renders a single evolution stage and recursively renders its children.
    /// When a stage has multiple children (branching), they appear in a vertical stack
    /// of parallel branches, each preceded by an arrow and trigger label.
    /// AnyView is intentional here to break the recursive opaque-return-type cycle.
    private func stageView(_ stage: EvolutionStage, isRoot: Bool) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                // The stage card itself
                stageCard(stage, showTrigger: !isRoot)

                // Render children
                if !stage.evolvesTo.isEmpty {
                    if stage.evolvesTo.count == 1 {
                        // Linear chain — single arrow then next stage
                        arrowRow(label: stage.evolvesTo[0].trigger)
                        stageView(stage.evolvesTo[0], isRoot: false)
                    } else {
                        // Branching chain — each branch on its own row
                        VStack(spacing: 8) {
                            ForEach(stage.evolvesTo) { branch in
                                VStack(spacing: 0) {
                                    arrowRow(label: branch.trigger)
                                    stageView(branch, isRoot: false)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
        )
    }

    /// Card showing the sprite, name, and Pokédex number for one evolution stage.
    /// Tapping navigates to the full detail screen for that stage's Pokémon.
    private func stageCard(_ stage: EvolutionStage, showTrigger: Bool) -> some View {
        let pokemon = Pokemon(
            id: stage.id,
            name: stage.name,
            spriteURL: stage.spriteURL,
            types: []   // types not needed to open the detail screen; detail fetches its own data
        )
        return NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
            HStack(spacing: 16) {
                AsyncImage(url: stage.spriteURL) { image in
                    image.resizable().interpolation(.none).scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.name.replacingOccurrences(of: "-", with: " ").capitalized)
                        .font(.headline)
                    Text("#\(String(format: "%03d", stage.id))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    /// A downward arrow row with the trigger condition label beneath it.
    private func arrowRow(label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.down")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
            Button(String(localized: "Retry")) { Task { await viewModel.retry() } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
