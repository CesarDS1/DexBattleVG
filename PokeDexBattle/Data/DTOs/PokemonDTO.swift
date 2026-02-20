//
//  PokemonDTO.swift
//  PokeDexBattle — Data Layer
//
//  Data Transfer Objects (DTOs) that mirror the exact JSON structure returned
//  by the PokeAPI v2 endpoints. They are `Decodable` only — they are never
//  created manually and never cross the boundary into the Domain or Presentation layers.
//  `PokemonRepositoryImpl` maps every DTO to a clean Domain entity before returning it.
//

import Foundation

// MARK: - List

/// Top-level response from `GET /pokemon?limit=N&offset=0`.
/// Contains the total count used to dynamically size the follow-up all-Pokémon request.
struct PokemonListResponseDTO: Decodable {
    /// Total number of Pokémon in the National Pokédex (e.g. 1350).
    let count: Int
    /// URL for the next page, or `nil` when all results have been fetched.
    let next: String?
    /// Abbreviated entries — only name and resource URL are returned by this endpoint.
    let results: [PokemonEntryDTO]
}

/// Abbreviated Pokémon entry returned inside the list response.
struct PokemonEntryDTO: Decodable {
    /// Lowercase hyphenated name (e.g. "bulbasaur").
    let name: String
    /// Full resource URL (e.g. "https://pokeapi.co/api/v2/pokemon/1/").
    let url: String

    /// Extracts the numeric ID from the tail of the resource URL.
    /// The URL always ends with `/{id}/` so we split on "/" and parse the last segment.
    var extractedID: Int {
        let parts = url.split(separator: "/")
        return Int(parts.last ?? "0") ?? 0
    }
}

// MARK: - Detail

/// Full response from `GET /pokemon/{id}`.
/// Contains physical attributes, types, sprites, base stats, and the full move list.
struct PokemonDetailDTO: Decodable {
    /// National Pokédex number.
    let id: Int
    /// Lowercase hyphenated name.
    let name: String
    /// Height in decimetres.
    let height: Int
    /// Weight in hectograms.
    let weight: Int
    /// Type slot entries (a Pokémon has 1 or 2 types).
    let types: [TypeSlotDTO]
    /// Sprite URLs container.
    let sprites: SpritesDTO
    /// Base stat entries (HP, Attack, Defense, Sp. Atk, Sp. Def, Speed).
    let stats: [StatSlotDTO]
    /// All moves this Pokémon can learn, across every game version and learn method.
    let moves: [MoveSlotDTO]
    /// Reference to the species resource — use this to get the correct species ID
    /// for alternate forms (Mega, Alolan, Gigantamax, etc.) whose own ID differs
    /// from their base species ID (e.g. Mega Charizard X has id=10034 but species id=6).
    let species: NamedResourceDTO

    // MARK: Move slots

    /// Wrapper that pairs a move reference with its version-specific learn details.
    struct MoveSlotDTO: Decodable {
        /// Reference to the move resource (name + URL).
        let move: MoveRefDTO
        /// Per-version details (level learned, learn method).
        let versionGroupDetails: [VersionGroupDetailDTO]
        enum CodingKeys: String, CodingKey {
            case move
            case versionGroupDetails = "version_group_details"
        }
    }

    /// Minimal move reference embedded in each move slot.
    struct MoveRefDTO: Decodable {
        /// Lowercase hyphenated move name (e.g. "vine-whip").
        let name: String
        /// Full resource URL used to extract the move ID.
        let url: String

        /// Numeric move ID extracted from the resource URL.
        var id: Int {
            let parts = url.split(separator: "/")
            return Int(parts.last ?? "0") ?? 0
        }
    }

    /// Per-version-group learn details for a single move.
    struct VersionGroupDetailDTO: Decodable {
        /// Level at which the move is learned (0 = learned at level 1 via machine or egg in some versions).
        let levelLearnedAt: Int
        /// The method by which the move is learned (e.g. "level-up", "machine", "egg").
        let moveLearnMethod: LearnMethodDTO
        enum CodingKeys: String, CodingKey {
            case levelLearnedAt  = "level_learned_at"
            case moveLearnMethod = "move_learn_method"
        }
    }

    /// Learn method descriptor (only the `name` field is needed).
    struct LearnMethodDTO: Decodable {
        /// e.g. "level-up", "machine", "egg", "tutor".
        let name: String
    }

    // MARK: Types

    /// Wraps the type info with its slot number (1 = primary, 2 = secondary).
    struct TypeSlotDTO: Decodable {
        /// The actual type information.
        let type: TypeInfoDTO
    }

    /// Elemental type descriptor.
    struct TypeInfoDTO: Decodable {
        /// Lowercase type name (e.g. "grass", "poison").
        let name: String
    }

    // MARK: Sprites

    /// Container for sprite image URLs.
    struct SpritesDTO: Decodable {
        /// URL string for the default front-facing sprite; may be `nil` for some entries.
        let frontDefault: String?
        enum CodingKeys: String, CodingKey {
            case frontDefault = "front_default"
        }
    }

    // MARK: Stats

    /// Pairs a stat descriptor with its base value.
    struct StatSlotDTO: Decodable {
        /// Numeric base stat value (e.g. 45 for Bulbasaur's HP).
        let baseStat: Int
        /// Stat identifier containing its API name.
        let stat: StatInfoDTO
        enum CodingKeys: String, CodingKey {
            case baseStat = "base_stat"
            case stat
        }
    }

    /// Stat name descriptor.
    struct StatInfoDTO: Decodable {
        /// API stat name (e.g. "hp", "attack", "special-defense").
        let name: String
    }
}

// MARK: - Move Detail

/// Full response from `GET /move/{id}`.
/// Contains power, accuracy, PP, damage class, type, and effect descriptions.
struct MoveDetailDTO: Decodable {
    /// Unique move ID.
    let id: Int
    /// Lowercase hyphenated move name (e.g. "vine-whip").
    let name: String
    /// Base power; `nil` for status moves.
    let power: Int?
    /// Accuracy percentage; `nil` for moves that always hit (e.g. Swift).
    let accuracy: Int?
    /// Maximum PP (Power Points) before a restore is needed.
    let pp: Int
    /// Damage class: "physical", "special", or "status".
    let damageClass: DamageClassDTO
    /// Elemental type of the move.
    let type: TypeInfoDTO
    /// Localised effect descriptions (one per language — only en and fr have entries).
    let effectEntries: [EffectEntryDTO]
    /// Per-version, per-language flavor text descriptions (en, es, fr, de, it, etc.).
    /// Used to provide Spanish move descriptions since `effect_entries` only has en/fr.
    let flavorTextEntries: [MoveFlavorTextEntryDTO]

    enum CodingKeys: String, CodingKey {
        case id, name, power, accuracy, pp, type
        case damageClass      = "damage_class"
        case effectEntries    = "effect_entries"
        case flavorTextEntries = "flavor_text_entries"
    }

    /// Damage category descriptor.
    struct DamageClassDTO: Decodable {
        /// "physical", "special", or "status".
        let name: String
    }

    /// Elemental type descriptor (reused inside move detail).
    struct TypeInfoDTO: Decodable {
        /// Lowercase type name (e.g. "grass").
        let name: String
    }

    /// One localised effect entry.
    struct EffectEntryDTO: Decodable {
        /// Brief English description of the move's effect.
        let shortEffect: String
        /// Language this entry is written in.
        let language: LanguageDTO
        enum CodingKeys: String, CodingKey {
            case shortEffect = "short_effect"
            case language
        }
    }

    /// Language descriptor.
    struct LanguageDTO: Decodable {
        /// ISO 639-1 language code (e.g. "en", "fr").
        let name: String
    }

    /// One flavor-text entry for a specific game version and language.
    /// The `flavor_text_entries` array has broader language coverage than `effect_entries`
    /// (includes es, de, it, ko, etc.) — used as the localized description source.
    struct MoveFlavorTextEntryDTO: Decodable {
        /// The raw flavor text for this move in the given language and version.
        let flavorText: String
        /// Language this entry is written in.
        let language: LanguageDTO
        enum CodingKeys: String, CodingKey {
            case flavorText = "flavor_text"
            case language
        }
    }
}

// MARK: - Species

/// Response from `GET /pokemon-species/{id}`.
/// Used to resolve the evolution chain URL, list alternate varieties (forms),
/// and retrieve the Pokédex flavor-text description.
struct PokemonSpeciesDTO: Decodable {
    /// Reference to the evolution chain resource for this species.
    let evolutionChain: EvolutionChainRefDTO
    /// All forms/varieties of this species (default + alternates).
    let varieties: [VarietyDTO]
    /// Localised Pokédex flavor-text entries (one per game version per language).
    let flavorTextEntries: [FlavorTextEntryDTO]

    enum CodingKeys: String, CodingKey {
        case evolutionChain    = "evolution_chain"
        case varieties
        case flavorTextEntries = "flavor_text_entries"
    }

    /// One flavor-text entry for a specific game version and language.
    struct FlavorTextEntryDTO: Decodable {
        /// The raw Pokédex description string (may contain `\n` and `\f` control characters).
        let flavorText: String
        /// Language this entry is written in.
        let language: LanguageRefDTO
        enum CodingKeys: String, CodingKey {
            case flavorText = "flavor_text"
            case language
        }
    }

    /// Minimal language reference — only the name is needed.
    struct LanguageRefDTO: Decodable {
        /// ISO 639-1 language code (e.g. "en", "es", "fr").
        let name: String
    }

    /// Wrapper holding the URL for the evolution chain resource.
    struct EvolutionChainRefDTO: Decodable {
        /// Full resource URL, e.g. "https://pokeapi.co/api/v2/evolution-chain/1/".
        let url: String

        /// Numeric chain ID extracted from the resource URL.
        var id: Int {
            let parts = url.split(separator: "/")
            return Int(parts.last ?? "0") ?? 0
        }
    }

    /// One variety entry — links a species to one of its Pokémon forms.
    struct VarietyDTO: Decodable {
        /// `true` for the standard form; `false` for Mega, Alolan, Gigantamax, etc.
        let isDefault: Bool
        /// Reference to the `/pokemon/{id}` resource for this variety.
        let pokemon: NamedResourceDTO
        enum CodingKeys: String, CodingKey {
            case isDefault = "is_default"
            case pokemon
        }
    }
}

// MARK: - Evolution Chain

/// Response from `GET /evolution-chain/{id}`.
/// The chain is a recursive tree; `chain` is always the base (unevolved) stage.
struct EvolutionChainDTO: Decodable {
    /// The root node of the evolution tree.
    let chain: ChainLinkDTO

    /// A single node in the evolution tree.
    struct ChainLinkDTO: Decodable {
        /// Species reference for this stage (name + URL).
        let species: NamedResourceDTO
        /// Conditions under which this Pokémon evolves into the next stage(s).
        /// Empty for the root (base) form.
        let evolutionDetails: [EvolutionDetailDTO]
        /// All direct evolutions from this stage (may be 0, 1, or many).
        let evolvesTo: [ChainLinkDTO]

        enum CodingKeys: String, CodingKey {
            case species
            case evolutionDetails = "evolution_details"
            case evolvesTo        = "evolves_to"
        }
    }

    /// Conditions that trigger an evolution. Only the fields used by the app are decoded.
    struct EvolutionDetailDTO: Decodable {
        /// Trigger type: "level-up", "use-item", "trade", "shed", etc.
        let trigger: NamedResourceDTO
        /// Minimum level required (level-up trigger); `nil` when not applicable.
        let minLevel: Int?
        /// Item used to trigger the evolution (use-item trigger); `nil` otherwise.
        let item: NamedResourceDTO?
        /// Minimum happiness required (level-up with friendship); `nil` otherwise.
        let minHappiness: Int?
        /// Time of day constraint ("day", "night", or ""); `nil` otherwise.
        let timeOfDay: String?
        /// Held item required during trade; `nil` otherwise.
        let heldItem: NamedResourceDTO?

        enum CodingKeys: String, CodingKey {
            case trigger
            case minLevel      = "min_level"
            case item
            case minHappiness  = "min_happiness"
            case timeOfDay     = "time_of_day"
            case heldItem      = "held_item"
        }
    }
}

// MARK: - Shared

/// A generic named API resource reference (name + URL), used across many endpoints.
struct NamedResourceDTO: Decodable {
    /// Lowercase hyphenated resource name.
    let name: String
    /// Full resource URL.
    let url: String

    /// Numeric ID extracted from the resource URL tail segment.
    var id: Int {
        let parts = url.split(separator: "/")
        return Int(parts.last ?? "0") ?? 0
    }
}
