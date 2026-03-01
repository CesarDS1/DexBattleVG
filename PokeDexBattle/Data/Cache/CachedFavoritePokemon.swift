//
//  CachedFavoritePokemon.swift
//  PokeDexBattle — Data Layer / Cache
//
//  SwiftData model that records which Pokémon the user has marked as a favourite.
//  Only the National Pokédex ID and the timestamp are stored; all display data
//  (name, sprite, types) is already present in `CachedPokemon` and is never duplicated.
//

import SwiftData
import Foundation

/// Persistent record of a single Pokémon marked as a favourite.
///
/// The table acts as a lightweight join set: `pokemonID` is the foreign key that
/// links back to `CachedPokemon.id`. No cascade relationship is used — the two
/// models are intentionally decoupled so favourites survive a full Pokédex cache clear.
@Model
final class CachedFavoritePokemon {
    /// National Pokédex number — unique primary key.
    @Attribute(.unique) var pokemonID: Int
    /// When the user added this Pokémon to their favourites.
    var addedAt: Date

    init(pokemonID: Int, addedAt: Date = .now) {
        self.pokemonID = pokemonID
        self.addedAt   = addedAt
    }
}
