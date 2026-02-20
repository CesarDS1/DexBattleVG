//
//  CachedPokemon.swift
//  PokeDexBattle — Data Layer / Cache
//
//  SwiftData model for a lightweight list-screen Pokémon entry.
//  Mirrors the `Pokemon` domain entity — no domain types are imported here.
//

import SwiftData
import Foundation

/// Persistent cache entry for a single lightweight Pokémon (list-screen data only).
@Model
final class CachedPokemon {
    /// National Pokédex ID — unique primary key.
    @Attribute(.unique) var id: Int
    var name: String
    /// Absolute URL string for the official sprite, or nil if unavailable.
    var spriteURLString: String?
    /// Elemental type names (e.g. `["fire", "flying"]`).
    var types: [String]

    init(id: Int, name: String, spriteURLString: String?, types: [String]) {
        self.id = id
        self.name = name
        self.spriteURLString = spriteURLString
        self.types = types
    }
}
