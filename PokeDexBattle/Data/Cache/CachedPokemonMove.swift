//
//  CachedPokemonMove.swift
//  PokeDexBattle — Data Layer / Cache
//
//  SwiftData model for a single level-up move belonging to a Pokémon.
//

import SwiftData
import Foundation

/// Persistent cache entry for one level-up move of a Pokémon.
@Model
final class CachedPokemonMove {
    /// PokeAPI move ID — unique primary key across all moves.
    @Attribute(.unique) var id: Int
    /// The Pokédex ID of the Pokémon this move belongs to.
    var pokemonID: Int
    var name: String
    var levelLearnedAt: Int
    var power: Int?
    var accuracy: Int?
    var pp: Int?
    var damageClass: String
    var type: String
    /// Move short-effect description in English.
    var shortEffect: String
    /// Move short-effect description in Spanish; empty string when unavailable.
    var shortEffectEs: String

    init(
        id: Int,
        pokemonID: Int,
        name: String,
        levelLearnedAt: Int,
        power: Int?,
        accuracy: Int?,
        pp: Int?,
        damageClass: String,
        type: String,
        shortEffect: String,
        shortEffectEs: String
    ) {
        self.id = id
        self.pokemonID = pokemonID
        self.name = name
        self.levelLearnedAt = levelLearnedAt
        self.power = power
        self.accuracy = accuracy
        self.pp = pp
        self.damageClass = damageClass
        self.type = type
        self.shortEffect = shortEffect
        self.shortEffectEs = shortEffectEs
    }
}
