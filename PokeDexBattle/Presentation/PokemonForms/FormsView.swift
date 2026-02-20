//
//  FormsView.swift
//  PokeDexBattle — Presentation Layer
//
//  Displays all alternate forms and regional variants of a Pokémon species
//  in a 2-column grid. Each card shows the sprite, display name, type badges,
//  and a "Default" label for the base form.
//

import SwiftUI

/// Shows all forms and regional variants of a Pokémon species in a 2-column card grid.
struct FormsView: View {
    @State private var viewModel: FormsViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(pokemonID: Int, pokemonName: String) {
        _viewModel = State(initialValue: FormsViewModel(pokemonID: pokemonID, pokemonName: pokemonName))
    }

    var body: some View {
        Group {
            if !viewModel.forms.isEmpty {
                formGrid
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                ProgressView(String(localized: "Loading forms…"))
            }
        }
        .navigationTitle(String(format: String(localized: "%@ Forms"), viewModel.pokemonName.capitalized))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: - Grid

    private var formGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.forms) { form in
                    formCard(form)
                }
            }
            .padding()
        }
    }

    /// Card displaying one form with its sprite, name, type badges, and a default label.
    /// Tapping navigates to the full detail screen for that form's Pokémon.
    private func formCard(_ form: PokemonForm) -> some View {
        let pokemon = Pokemon(
            id: form.id,
            name: form.name,
            spriteURL: form.spriteURL,
            types: form.types
        )
        return NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
            VStack(spacing: 8) {
                // Sprite
                AsyncImage(url: form.spriteURL) { image in
                    image.resizable().interpolation(.none).scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 90, height: 90)

                // Display name — strip the base species name prefix for cleaner labels
                Text(formDisplayName(form.name))
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Type badges
                HStack(spacing: 4) {
                    ForEach(form.types, id: \.self) { type in
                        Text(localizedTypeName(type))
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(pokemonTypeColor(type), in: Capsule())
                    }
                }

                // Default badge
                if form.isDefault {
                    Text(String(localized: "Default"))
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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

    // MARK: - Helpers

    /// Converts a variety name like "charizard-mega-x" to "Mega X",
    /// stripping the base species name prefix for a clean display label.
    private func formDisplayName(_ name: String) -> String {
        let parts = name.split(separator: "-").map(String.init)
        // Try to drop the first word if it matches the Pokémon's base name
        let baseName = viewModel.pokemonName.lowercased()
        let filtered = parts.first?.lowercased() == baseName ? Array(parts.dropFirst()) : parts
        guard !filtered.isEmpty else { return name.capitalized }
        return filtered.map { $0.capitalized }.joined(separator: " ")
    }

}
