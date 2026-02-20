//
//  LocalizationHelper.swift
//  PokeDexBattle — Presentation Layer / Shared
//
//  Maps raw PokeAPI English identifiers (type names, stat names, damage classes,
//  evolution triggers, generation labels) to localized display strings.
//
//  All keys are intentionally NOT in Localizable.xcstrings so that adding a new
//  language only requires extending the switch statements below — not hunting
//  through every view file.
//

import Foundation

// MARK: - Pokémon types

/// Returns the localized display name for a PokeAPI type identifier (e.g. "fire" → "Fuego").
func localizedTypeName(_ apiName: String) -> String {
    switch apiName.lowercased() {
    case "normal":   return String(localized: "type.normal",   defaultValue: "Normal")
    case "fire":     return String(localized: "type.fire",     defaultValue: "Fire")
    case "water":    return String(localized: "type.water",    defaultValue: "Water")
    case "electric": return String(localized: "type.electric", defaultValue: "Electric")
    case "grass":    return String(localized: "type.grass",    defaultValue: "Grass")
    case "ice":      return String(localized: "type.ice",      defaultValue: "Ice")
    case "fighting": return String(localized: "type.fighting", defaultValue: "Fighting")
    case "poison":   return String(localized: "type.poison",   defaultValue: "Poison")
    case "ground":   return String(localized: "type.ground",   defaultValue: "Ground")
    case "flying":   return String(localized: "type.flying",   defaultValue: "Flying")
    case "psychic":  return String(localized: "type.psychic",  defaultValue: "Psychic")
    case "bug":      return String(localized: "type.bug",      defaultValue: "Bug")
    case "rock":     return String(localized: "type.rock",     defaultValue: "Rock")
    case "ghost":    return String(localized: "type.ghost",    defaultValue: "Ghost")
    case "dragon":   return String(localized: "type.dragon",   defaultValue: "Dragon")
    case "dark":     return String(localized: "type.dark",     defaultValue: "Dark")
    case "steel":    return String(localized: "type.steel",    defaultValue: "Steel")
    case "fairy":    return String(localized: "type.fairy",    defaultValue: "Fairy")
    case "stellar":  return String(localized: "type.stellar",  defaultValue: "Stellar")
    default:         return apiName.capitalized
    }
}

// MARK: - Base stats

/// Returns the localized abbreviation for a PokeAPI stat name (e.g. "special-attack" → "Atq. Esp.").
func localizedStatName(_ apiName: String) -> String {
    switch apiName.lowercased() {
    case "hp":              return String(localized: "HP")
    case "attack":          return String(localized: "Atk")
    case "defense":         return String(localized: "Def")
    case "special-attack":  return String(localized: "Sp. Atk")
    case "special-defense": return String(localized: "Sp. Def")
    case "speed":           return String(localized: "Speed")
    default:                return apiName.capitalized
    }
}

// MARK: - Damage classes

/// Returns the localized name for a PokeAPI damage class (e.g. "physical" → "Físico").
func localizedDamageClass(_ apiName: String) -> String {
    switch apiName.lowercased() {
    case "physical": return String(localized: "damage.physical", defaultValue: "Physical")
    case "special":  return String(localized: "damage.special",  defaultValue: "Special")
    case "status":   return String(localized: "damage.status",   defaultValue: "Status")
    default:         return apiName.capitalized
    }
}

// MARK: - Generation / region labels

/// Returns the localized region label for a generation number (e.g. 1 → "Kanto I").
func localizedGenerationLabel(_ gen: Int) -> String {
    switch gen {
    case 1:  return String(localized: "gen.1",  defaultValue: "Kanto I")
    case 2:  return String(localized: "gen.2",  defaultValue: "Johto II")
    case 3:  return String(localized: "gen.3",  defaultValue: "Hoenn III")
    case 4:  return String(localized: "gen.4",  defaultValue: "Sinnoh IV")
    case 5:  return String(localized: "gen.5",  defaultValue: "Unova V")
    case 6:  return String(localized: "gen.6",  defaultValue: "Kalos VI")
    case 7:  return String(localized: "gen.7",  defaultValue: "Alola VII")
    case 8:  return String(localized: "gen.8",  defaultValue: "Galar VIII")
    default: return String(localized: "gen.9",  defaultValue: "Paldea IX")
    }
}
