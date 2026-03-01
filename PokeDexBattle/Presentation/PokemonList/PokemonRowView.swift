//
//  PokemonRowView.swift
//  PokeDexBattle — Presentation Layer
//
//  A single row cell used inside the Pokédex list.
//  Displays the sprite, name, Pokédex number, and elemental type badges.
//

import SwiftUI

/// A list row displaying a Pokémon's sprite, name, Pokédex number, and type badges.
///
/// Sprite images are loaded lazily via `AsyncImage` from the GitHub-hosted
/// PokeAPI sprites CDN. A `ProgressView` placeholder is shown while the image loads.
/// Type badges use the shared `pokemonTypeColor` utility for consistent colouring.
struct PokemonRowView: View {
    /// The lightweight Pokémon to display. Passed in from `PokemonListView`.
    let pokemon: Pokemon
    /// Whether this Pokémon is in the user's favorites. Drives the trailing heart icon.
    var isFavorite: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Sprite — 64×64 pt, pixel-art interpolation disabled for crispness
            AsyncImage(url: pokemon.spriteURL) { image in
                image
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                // Name — capitalised for display (API returns lowercase)
                Text(pokemon.name.capitalized)
                    .font(.headline)

                // Zero-padded Pokédex number (e.g. "#001")
                Text("#\(String(format: "%03d", pokemon.id))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Elemental type badges — localized type names
                HStack(spacing: 6) {
                    ForEach(pokemon.types, id: \.self) { type in
                        Text(localizedTypeName(type))
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(pokemonTypeColor(type), in: Capsule())
                    }
                }
            }

            Spacer()

            // Heart icon — only shown when the Pokémon is a favorite.
            // `.transition` + `.animation` produce a scale-and-opacity pop-in/pop-out.
            if isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(
                        String(localized: "fav.row.a11y", defaultValue: "Favorite")
                    )
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isFavorite)
    }
}
