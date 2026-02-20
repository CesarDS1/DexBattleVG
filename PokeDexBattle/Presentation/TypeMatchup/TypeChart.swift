//
//  TypeChart.swift
//  PokeDexBattle — Presentation Layer
//
//  Pure Swift type-effectiveness engine. No SwiftUI, no networking, no domain imports.
//  Contains the full Gen 9 defensive type chart and the logic to compute combined
//  dual-type matchups for any Pokémon.
//

import Foundation

// MARK: - TypeMatchup

/// Defensive type matchup result, grouped by damage multiplier.
///
/// Produced by `TypeChart.defensiveMatchup(for:)` and consumed directly by `TypeMatchupView`.
/// The `normal` bucket (1× damage) is computed but intentionally hidden from the UI,
/// since neutral matchups carry no actionable information for the player.
struct TypeMatchup {
    /// Attacking types that deal **0×** damage — the Pokémon is completely immune.
    let immune: [String]
    /// Attacking types that deal **0.25×** damage (dual-type double resistance).
    let quarterResistant: [String]
    /// Attacking types that deal **0.5×** damage.
    let halfResistant: [String]
    /// Attacking types that deal **1×** damage (neutral — hidden in the UI).
    let normal: [String]
    /// Attacking types that deal **2×** damage.
    let doubleWeak: [String]
    /// Attacking types that deal **4×** damage (dual-type double weakness).
    let quadWeak: [String]
}

// MARK: - TypeChart

/// Gen 9 type effectiveness chart and matchup computation engine.
///
/// Implemented as a caseless `enum` to prevent instantiation — all members are static.
/// Only entries that deviate from 1× are stored in the chart dictionary; all omitted
/// attacker→defender pairs are implicitly 1.0× by convention.
enum TypeChart {

    // MARK: All 18 type names (lowercase, matching PokeAPI spelling)

    /// Complete ordered list of all Gen 9 type names.
    static let allTypes: [String] = [
        "normal", "fire", "water", "electric", "grass", "ice",
        "fighting", "poison", "ground", "flying", "psychic", "bug",
        "rock", "ghost", "dragon", "dark", "steel", "fairy"
    ]

    // MARK: Effectiveness table

    /// Full Gen 9 offensive type chart.
    ///
    /// Keyed as `chart[attackingType][defendingType] = multiplier`.
    /// Only non-1× values are stored. Lookups that miss any key return 1.0×
    /// via `effectiveness(attacker:defender:)`.
    ///
    /// Source: https://bulbapedia.bulbagarden.net/wiki/Type/Damage_dealt_to
    private static let chart: [String: [String: Double]] = [
        "normal": [
            "rock": 0.5, "ghost": 0.0, "steel": 0.5
        ],
        "fire": [
            "fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 2.0,
            "bug": 2.0, "rock": 0.5, "dragon": 0.5, "steel": 2.0
        ],
        "water": [
            "fire": 2.0, "water": 0.5, "grass": 0.5, "ground": 2.0,
            "rock": 2.0, "dragon": 0.5
        ],
        "electric": [
            "water": 2.0, "electric": 0.5, "grass": 0.5, "ground": 0.0,
            "flying": 2.0, "dragon": 0.5
        ],
        "grass": [
            "fire": 0.5, "water": 2.0, "grass": 0.5, "poison": 0.5,
            "ground": 2.0, "flying": 0.5, "bug": 0.5, "rock": 2.0,
            "dragon": 0.5, "steel": 0.5
        ],
        "ice": [
            "fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 0.5,
            "ground": 2.0, "flying": 2.0, "dragon": 2.0, "steel": 0.5
        ],
        "fighting": [
            "normal": 2.0, "ice": 2.0, "poison": 0.5, "flying": 0.5,
            "psychic": 0.5, "bug": 0.5, "rock": 2.0, "ghost": 0.0,
            "dark": 2.0, "steel": 2.0, "fairy": 0.5
        ],
        "poison": [
            "grass": 2.0, "poison": 0.5, "ground": 0.5, "rock": 0.5,
            "ghost": 0.5, "steel": 0.0, "fairy": 2.0
        ],
        "ground": [
            "fire": 2.0, "electric": 2.0, "grass": 0.5, "poison": 2.0,
            "flying": 0.0, "bug": 0.5, "rock": 2.0, "steel": 2.0
        ],
        "flying": [
            "electric": 0.5, "grass": 2.0, "fighting": 2.0, "bug": 2.0,
            "rock": 0.5, "steel": 0.5
        ],
        "psychic": [
            "fighting": 2.0, "poison": 2.0, "psychic": 0.5,
            "dark": 0.0, "steel": 0.5
        ],
        "bug": [
            "fire": 0.5, "grass": 2.0, "fighting": 0.5, "flying": 0.5,
            "psychic": 2.0, "ghost": 0.5, "dark": 2.0, "steel": 0.5,
            "fairy": 0.5
        ],
        "rock": [
            "fire": 2.0, "ice": 2.0, "fighting": 0.5, "ground": 0.5,
            "flying": 2.0, "bug": 2.0, "steel": 0.5
        ],
        "ghost": [
            "normal": 0.0, "psychic": 2.0, "ghost": 2.0, "dark": 0.5
        ],
        "dragon": [
            "dragon": 2.0, "steel": 0.5, "fairy": 0.0
        ],
        "dark": [
            "fighting": 0.5, "psychic": 2.0, "ghost": 2.0,
            "dark": 0.5, "fairy": 0.5
        ],
        "steel": [
            "fire": 0.5, "water": 0.5, "electric": 0.5, "ice": 2.0,
            "rock": 2.0, "steel": 0.5, "fairy": 2.0
        ],
        "fairy": [
            "fire": 0.5, "fighting": 2.0, "poison": 0.5,
            "dragon": 2.0, "dark": 2.0, "steel": 0.5
        ]
    ]

    // MARK: - Public API

    /// Returns the damage multiplier when an attack of `attacker` type hits a Pokémon of `defender` type.
    ///
    /// - Parameters:
    ///   - attacker: The attacking move's type name (e.g. `"fire"`).
    ///   - defender: The defending Pokémon's single type name (e.g. `"grass"`).
    /// - Returns: One of `0.0`, `0.5`, `1.0`, or `2.0`. Defaults to `1.0` for unknown pairs.
    static func effectiveness(attacker: String, defender: String) -> Double {
        chart[attacker]?[defender] ?? 1.0
    }

    /// Computes the full defensive type matchup for a Pokémon with the given types.
    ///
    /// For each of the 18 attacking types, multiplies effectiveness against each of the
    /// Pokémon's own types. Dual-type Pokémon receive the combined product
    /// (e.g. Fire/Flying vs. Rock → 2× × 2× = 4×).
    ///
    /// - Parameter pokemonTypes: The Pokémon's type list from `PokemonDetail.types`
    ///   (1–2 elements, lowercase PokeAPI names).
    /// - Returns: A `TypeMatchup` with attacking types bucketed by their combined multiplier.
    static func defensiveMatchup(for pokemonTypes: [String]) -> TypeMatchup {
        var immune:    [String] = []
        var quarterX:  [String] = []
        var halfX:     [String] = []
        var normalX:   [String] = []
        var doubleX:   [String] = []
        var quadX:     [String] = []

        for attacker in allTypes {
            // Multiply effectiveness across all of the Pokémon's types
            let multiplier = pokemonTypes.reduce(1.0) { product, defenderType in
                product * effectiveness(attacker: attacker, defender: defenderType)
            }

            // Exact floating-point comparison is safe here: the only possible products
            // of values in {0, 0.5, 1.0, 2.0} are {0, 0.25, 0.5, 1.0, 2.0, 4.0},
            // all of which are exactly representable as IEEE 754 doubles.
            switch multiplier {
            case 0.0:   immune.append(attacker)
            case 0.25:  quarterX.append(attacker)
            case 0.5:   halfX.append(attacker)
            case 2.0:   doubleX.append(attacker)
            case 4.0:   quadX.append(attacker)
            default:    normalX.append(attacker)   // 1.0×
            }
        }

        return TypeMatchup(
            immune: immune,
            quarterResistant: quarterX,
            halfResistant: halfX,
            normal: normalX,
            doubleWeak: doubleX,
            quadWeak: quadX
        )
    }
}
