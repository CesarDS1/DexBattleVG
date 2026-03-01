//
//  CachedTeamMember.swift
//  PokeDexBattle — Data Layer / Cache
//
//  SwiftData model for a single slot in a user-created team.
//  Stores a snapshot of display data taken at add-time so team entries
//  remain intact even when the Pokédex cache is cleared by pull-to-refresh.
//
//  Relationship to `CachedTeam` is expressed via a plain UUID foreign key
//  (not a SwiftData @Relationship) to match the flat pattern used by all
//  existing cache models and avoid cross-context cascading complications.
//

import SwiftData
import Foundation

/// Persistent record for a single Pokémon slot inside a team.
@Model
final class CachedTeamMember {
    /// Own stable UUID — unique primary key.
    /// Distinct from `pokemonID` so the same Pokémon can appear on multiple teams.
    @Attribute(.unique) var id: UUID
    /// UUID of the owning `CachedTeam`. Plain foreign key — no SwiftData relationship.
    var teamID: UUID
    /// National Pokédex number of the Pokémon.
    var pokemonID: Int
    /// Lowercase hyphenated name (e.g. "bulbasaur").
    var name: String
    /// Absolute URL string for the front-facing sprite, or nil if unavailable.
    var spriteURLString: String?
    /// Elemental type names (e.g. ["grass", "poison"]).
    var types: [String]
    /// Zero-based position in the team (0–5).
    var slot: Int

    init(
        id: UUID,
        teamID: UUID,
        pokemonID: Int,
        name: String,
        spriteURLString: String?,
        types: [String],
        slot: Int
    ) {
        self.id = id
        self.teamID = teamID
        self.pokemonID = pokemonID
        self.name = name
        self.spriteURLString = spriteURLString
        self.types = types
        self.slot = slot
    }
}
