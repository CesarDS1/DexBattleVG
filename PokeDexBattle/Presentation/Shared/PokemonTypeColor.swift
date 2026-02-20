//
//  PokemonTypeColor.swift
//  PokeDexBattle — Presentation Layer
//
//  Shared utility: canonical SwiftUI color for each of the 18 Pokémon elemental types.
//  Extracted here to avoid duplication across PokemonDetailView, MovesView, FormsView,
//  and TypeMatchupView.
//

import SwiftUI

/// Returns the canonical display `Color` for a Pokémon elemental type name.
///
/// Covers all 18 Gen 9 types (Normal, Fire, Water, Electric, Grass, Ice, Fighting,
/// Poison, Ground, Flying, Psychic, Bug, Rock, Ghost, Dragon, Dark, Steel, Fairy).
/// Unknown type strings fall back to `.secondary`.
///
/// - Parameter type: Lowercase type name as returned by PokeAPI (e.g. `"fire"`, `"dragon"`).
/// - Returns: A `Color` suitable for use as a badge background or tint.
func pokemonTypeColor(_ type: String) -> Color {
    switch type {
    case "normal":   return .secondary
    case "fire":     return .orange
    case "water":    return .blue
    case "electric": return .yellow
    case "grass":    return .green
    case "ice":      return .cyan
    case "fighting": return .red
    case "poison":   return .purple
    case "ground":   return Color(red: 0.73, green: 0.57, blue: 0.30)  // distinct brown-tan
    case "flying":   return .teal
    case "psychic":  return .pink
    case "bug":      return .mint
    case "rock":     return .gray
    case "ghost":    return Color(red: 0.44, green: 0.34, blue: 0.65)  // distinct muted purple
    case "dragon":   return .indigo
    case "dark":     return Color(red: 0.35, green: 0.25, blue: 0.18)  // distinct dark brown
    case "steel":    return Color(red: 0.60, green: 0.62, blue: 0.68)  // distinct steel blue-gray
    case "fairy":    return Color(red: 0.93, green: 0.52, blue: 0.72)  // distinct fairy pink
    default:         return .secondary
    }
}
