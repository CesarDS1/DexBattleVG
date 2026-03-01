//
//  PokemonTeam.swift
//  PokeDexBattle — Domain Layer
//
//  Pure Swift value types for the Team Builder feature.
//  This file has zero framework imports beyond Foundation —
//  it must never depend on SwiftUI, SwiftData, or any Data-layer type.
//

import Foundation

/// A snapshot of a single Pokémon slot inside a team.
///
/// Stores only the display data needed to render a team card and the type-matchup
/// coverage panel. It is a snapshot taken at add-time, so team data remains intact
/// even when the Pokédex cache is cleared by a pull-to-refresh.
struct TeamMember: Identifiable, Equatable, Hashable {
    /// Stable UUID assigned when the member is first persisted.
    /// Allows the same Pokémon to appear on different teams without ID collisions.
    let id: UUID
    /// National Pokédex number of the Pokémon.
    let pokemonID: Int
    /// Lowercase hyphenated name as returned by PokeAPI (e.g. "bulbasaur").
    let name: String
    /// Remote URL for the front-facing sprite. Used in team list rows and slot cells.
    let spriteURL: URL?
    /// Ordered list of elemental type names (e.g. ["grass", "poison"]).
    /// Used for the team type-coverage panel.
    let types: [String]
    /// Zero-based position in the team (0–5). Defines display order in the grid.
    let slot: Int
}

/// A user-created team containing up to six Pokémon.
///
/// Teams are persisted in SwiftData via `CachedTeam` / `CachedTeamMember` and
/// are independent of the Pokédex cache — `clearAllCache()` never removes teams.
struct PokemonTeam: Identifiable, Equatable {
    /// Stable UUID used as the primary key in SwiftData and for navigation.
    let id: UUID
    /// User-defined display name for this team.
    let name: String
    /// Team members ordered by `slot`. Contains at most 6 entries.
    let members: [TeamMember]
    /// The date this team was created, used for default sort order.
    let createdAt: Date

    /// Returns `true` when the team already has six members and cannot accept more.
    var isFull: Bool { members.count >= 6 }

    /// Returns the next available slot index, or `nil` when the team is full.
    var nextAvailableSlot: Int? {
        isFull ? nil : members.count
    }

    /// Returns `true` when `pokemonID` is already a member of this team.
    func contains(pokemonID: Int) -> Bool {
        members.contains(where: { $0.pokemonID == pokemonID })
    }
}
