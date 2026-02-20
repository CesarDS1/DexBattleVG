//
//  TypeMatchupView.swift
//  PokeDexBattle — Presentation Layer
//
//  Displays the defensive type effectiveness chart for a Pokémon.
//  Receives a pre-computed `TypeMatchup` — performs no I/O and requires no ViewModel.
//

import SwiftUI

/// Tab 3 of `PokemonDetailView` — shows which attacking types deal bonus, reduced,
/// or zero damage against this Pokémon based on its elemental type(s).
///
/// The matchup is computed synchronously by `TypeChart.defensiveMatchup(for:)` and
/// passed in as a value; no network call or `async` work is performed here.
struct TypeMatchupView: View {

    /// Pre-computed matchup buckets — produced by `TypeChart.defensiveMatchup(for:)`.
    let matchup: TypeMatchup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── Weaknesses ────────────────────────────────────────────────

                if !matchup.quadWeak.isEmpty {
                    matchupSection(
                        title: String(localized: "Weak"),
                        multiplierLabel: "4×",
                        types: matchup.quadWeak,
                        headerColor: .red
                    )
                }

                if !matchup.doubleWeak.isEmpty {
                    matchupSection(
                        title: String(localized: "Weak"),
                        multiplierLabel: "2×",
                        types: matchup.doubleWeak,
                        headerColor: .orange
                    )
                }

                // ── Resistances ───────────────────────────────────────────────

                if !matchup.halfResistant.isEmpty {
                    matchupSection(
                        title: String(localized: "Resistant"),
                        multiplierLabel: "½×",
                        types: matchup.halfResistant,
                        headerColor: .green
                    )
                }

                if !matchup.quarterResistant.isEmpty {
                    matchupSection(
                        title: String(localized: "Resistant"),
                        multiplierLabel: "¼×",
                        types: matchup.quarterResistant,
                        headerColor: .mint
                    )
                }

                // ── Immunities ────────────────────────────────────────────────

                if !matchup.immune.isEmpty {
                    matchupSection(
                        title: String(localized: "Immune"),
                        multiplierLabel: "0×",
                        types: matchup.immune,
                        headerColor: .secondary
                    )
                }

                // Normal (1×) types are intentionally omitted — neutral matchups
                // carry no strategic information worth displaying.

                // Edge case: a Pokémon with no notable matchups (very rare)
                if matchup.quadWeak.isEmpty &&
                   matchup.doubleWeak.isEmpty &&
                   matchup.halfResistant.isEmpty &&
                   matchup.quarterResistant.isEmpty &&
                   matchup.immune.isEmpty {
                    Text(String(localized: "No notable type matchups."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }

    // MARK: - Subviews

    /// A labelled section showing a group of attacking types that share the same multiplier.
    ///
    /// - Parameters:
    ///   - title: Section title (e.g. "Weak", "Resistant").
    ///   - multiplierLabel: Human-readable multiplier (e.g. "2×", "½×").
    ///   - types: Attacking type names to display as badges.
    ///   - headerColor: Color applied to the section header text.
    private func matchupSection(
        title: String,
        multiplierLabel: String,
        types: [String],
        headerColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            // Section header: "Weak  2×"
            HStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(multiplierLabel)
                    .font(.headline.bold())
            }
            .foregroundStyle(headerColor)

            // Adaptive grid — badges wrap naturally to fit available width
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(types, id: \.self) { type in
                    typeBadge(type, multiplier: multiplierLabel)
                }
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }

    /// A single type badge capsule showing the type name and its effectiveness multiplier.
    ///
    /// Uses the shared `pokemonTypeColor` utility for the background tint.
    ///
    /// - Parameters:
    ///   - type: Lowercase PokeAPI type name (e.g. `"fire"`).
    ///   - multiplier: Multiplier label rendered inside the badge (e.g. `"2×"`).
    private func typeBadge(_ type: String, multiplier: String) -> some View {
        HStack(spacing: 4) {
            Text(localizedTypeName(type))
                .font(.subheadline.bold())
            Text(multiplier)
                .font(.caption.bold())
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(pokemonTypeColor(type), in: Capsule())
    }
}
