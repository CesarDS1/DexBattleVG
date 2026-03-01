//
//  Pokemon.swift
//  PokeDexBattle — Domain Layer
//
//  Pure Swift value types that represent the core business entities.
//  This file has zero framework imports — it must never depend on
//  UIKit, SwiftUI, Foundation networking, or any Data-layer type.
//

import Foundation

/// Lightweight representation of a single Pokémon as returned by the list endpoint.
/// Used to populate the Pokédex list and pass context to the detail screen.
struct Pokemon: Identifiable, Equatable {
    /// Unique National Pokédex number (extracted from the PokeAPI URL).
    let id: Int
    /// Lowercase name as returned by the API (e.g. "bulbasaur").
    let name: String
    /// Remote URL for the front-facing sprite image; may be nil for edge-case entries.
    let spriteURL: URL?
    /// Ordered list of elemental type names (e.g. `["grass", "poison"]`).
    /// Fetched alongside the bulk load so type-based filtering is available on the list screen.
    let types: [String]
}

/// Full detail for a single Pokémon, fetched from the `/pokemon/{id}` endpoint.
/// Displayed on the detail screen together with type badges, measurements, and stats.
struct PokemonDetail: Identifiable, Equatable {
    /// National Pokédex number.
    let id: Int
    /// Lowercase name as returned by the API.
    let name: String
    /// Height in decimetres as provided by the API (divide by 10 for metres).
    let height: Int
    /// Weight in hectograms as provided by the API (divide by 10 for kilograms).
    let weight: Int
    /// Ordered list of type names (e.g. ["grass", "poison"]).
    let types: [String]
    /// Base stat values used to render the stat bar chart.
    let stats: [Stat]
    /// Remote URL for the front-facing pixel sprite (96×96). Used as a fast placeholder.
    let spriteURL: URL?
    /// Remote URL for the high-resolution official artwork (475×475+). Used on the detail screen.
    /// Built from `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{id}.png`
    let officialArtworkURL: URL?
    /// Pokédex flavor-text description for this Pokémon (first available English entry).
    /// Control characters (`\n`, `\f`) have been normalised to single spaces.
    let description: String
    /// URL for the Pokémon's latest cry audio (.ogg).
    /// Built from `https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/{id}.ogg`
    let cryURL: URL?
    /// Gender ratio from the species endpoint.
    /// `-1` = genderless (e.g. Magnemite, Staryu).
    /// `0`–`8` = eighths female: `0` → 0% ♀ / 100% ♂, `4` → 50/50, `8` → 100% ♀.
    /// `-2` = sentinel value for legacy cache rows that predate this field (should never reach the UI).
    let genderRate: Int

    /// A single base stat (e.g. HP = 45, Attack = 49).
    struct Stat: Equatable {
        /// API name of the stat (e.g. "hp", "special-attack").
        let name: String
        /// Numeric base value (0–255).
        let value: Int
    }
}

/// A single move that a Pokémon can learn by levelling up.
/// Fetched concurrently from `/move/{id}` and enriched with the level
/// at which the Pokémon first learns it.
struct PokemonMove: Identifiable, Equatable {
    /// Unique move ID from the API.
    let id: Int
    /// Hyphenated lowercase move name (e.g. "vine-whip").
    let name: String
    /// The level at which this Pokémon learns the move (0 means level 1).
    let levelLearnedAt: Int
    /// Base power of the move; `nil` for status moves that deal no direct damage.
    let power: Int?
    /// Accuracy percentage (0–100); `nil` for moves that never miss (e.g. Swift).
    let accuracy: Int?
    /// Maximum number of times the move can be used before a PP restore.
    let pp: Int
    /// Category of the move: `"physical"`, `"special"`, or `"status"`.
    let damageClass: String
    /// Elemental type name (e.g. "grass", "fire").
    let type: String
    /// Short English description of the move's effect from the API.
    let shortEffect: String
}

// MARK: - Evolutions

/// One node in an evolution chain, representing a single stage Pokémon.
/// Chains can branch (e.g. Eevee's eight evolutions), so each stage stores
/// an array of `evolvesTo` children rather than a single next pointer.
struct EvolutionStage: Identifiable, Equatable {
    /// The Pokémon's National Pokédex ID, used to load its sprite.
    let id: Int
    /// Lowercase hyphenated species name (e.g. "ivysaur").
    let name: String
    /// Sprite URL built from the Pokédex ID.
    let spriteURL: URL?
    /// Human-readable trigger description (e.g. "Level 16", "Use Thunder Stone", "Trade").
    let trigger: String
    /// Next evolution stages reachable from this node. Empty for final-stage Pokémon.
    let evolvesTo: [EvolutionStage]
}

// MARK: - Forms

/// An alternate form or regional variant of a base Pokémon species.
/// Fetched from the `/pokemon/{id}` endpoint for each variety listed
/// on the species resource. The base (default) form is excluded.
struct PokemonForm: Identifiable, Equatable {
    /// The form Pokémon's unique ID (may differ from the base species ID for alternates).
    let id: Int
    /// Display name derived from the variety name (e.g. "Charizard Mega X").
    let name: String
    /// Sprite URL for the form's front-facing sprite.
    let spriteURL: URL?
    /// Whether this is the default (base) form of the species.
    let isDefault: Bool
    /// Types of this specific form (may differ from the base; e.g. Alolan forms).
    let types: [String]
}
