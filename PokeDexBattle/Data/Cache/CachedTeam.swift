//
//  CachedTeam.swift
//  PokeDexBattle — Data Layer / Cache
//
//  SwiftData model for a user-created Pokémon team.
//  Mirrors the `PokemonTeam` domain entity — no domain types are imported here.
//

import SwiftData
import Foundation

/// Persistent record for a single user-created team.
/// Members are stored separately in `CachedTeamMember` with a plain UUID foreign key.
@Model
final class CachedTeam {
    /// Stable UUID — unique primary key and foreign key used by `CachedTeamMember`.
    @Attribute(.unique) var id: UUID
    /// User-defined display name.
    var name: String
    /// Creation timestamp used for default sort order.
    var createdAt: Date

    init(id: UUID, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
