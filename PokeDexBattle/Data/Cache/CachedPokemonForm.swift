//
//  CachedPokemonForm.swift
//  PokeDexBattle — Data Layer / Cache
//
//  SwiftData model for one alternate form / regional variant of a Pokémon species.
//

import SwiftData
import Foundation

/// Persistent cache entry for one alternate form of a Pokémon species.
@Model
final class CachedPokemonForm {
    /// PokeAPI Pokémon ID for this specific form — unique primary key.
    @Attribute(.unique) var id: Int
    /// Pokédex ID of the base species this form belongs to.
    var pokemonID: Int
    var name: String
    /// Absolute URL string for the form's sprite.
    var spriteURLString: String?
    /// `true` for the default/base form; `false` for alternate forms.
    var isDefault: Bool
    /// Elemental type names for this specific form.
    var types: [String]

    init(
        id: Int,
        pokemonID: Int,
        name: String,
        spriteURLString: String?,
        isDefault: Bool,
        types: [String]
    ) {
        self.id = id
        self.pokemonID = pokemonID
        self.name = name
        self.spriteURLString = spriteURLString
        self.isDefault = isDefault
        self.types = types
    }
}
