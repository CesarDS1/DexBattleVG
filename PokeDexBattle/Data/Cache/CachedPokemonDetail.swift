//
//  CachedPokemonDetail.swift
//  PokeDexBattle — Data Layer / Cache
//
//  SwiftData model for full Pokémon detail data.
//  Stats are JSON-encoded because SwiftData cannot natively store
//  plain Swift structs in a column.
//

import SwiftData
import Foundation

/// Persistent cache entry for full Pokémon detail (detail screen data).
@Model
final class CachedPokemonDetail {
    /// National Pokédex ID — unique primary key.
    @Attribute(.unique) var id: Int
    var name: String
    /// Height in decimetres (conversion to metres is the Presentation layer's job).
    var height: Int
    /// Weight in hectograms (conversion to kilograms is the Presentation layer's job).
    var weight: Int
    /// Elemental type names.
    var types: [String]
    /// JSON-encoded array of `StatShim` values (SwiftData can't store plain structs).
    var statsJSON: Data
    /// Absolute URL string for the front-default pixel sprite (96×96).
    var spriteURLString: String?
    /// Absolute URL string for the high-resolution official artwork (475×475+).
    var officialArtworkURLString: String?
    /// Pokédex flavor-text description in English (control characters already normalised to spaces).
    var descriptionText: String
    /// Pokédex flavor-text description in Spanish; empty string when no Spanish entry exists.
    var descriptionTextEs: String
    /// Absolute URL string for the Pokémon's latest cry audio (.ogg).
    var cryURLString: String?
    /// Gender ratio from the species endpoint.
    /// `-1` = genderless; `0`–`8` = eighths female.
    /// Default `-2` is a sentinel for rows cached before this field was added —
    /// the repository treats `-2` as a cache miss and re-fetches from the network.
    var genderRate: Int = -2

    // MARK: - Codable shim for [Stat]

    /// Mirrors `PokemonDetail.Stat` — used only for JSON encoding/decoding within this cache model.
    struct StatShim: Codable {
        var name: String
        var value: Int
    }

    init(
        id: Int,
        name: String,
        height: Int,
        weight: Int,
        types: [String],
        stats: [StatShim],
        spriteURLString: String?,
        officialArtworkURLString: String?,
        descriptionText: String,
        descriptionTextEs: String,
        cryURLString: String?,
        genderRate: Int
    ) {
        self.id = id
        self.name = name
        self.height = height
        self.weight = weight
        self.types = types
        self.statsJSON = (try? JSONEncoder().encode(stats)) ?? Data()
        self.spriteURLString = spriteURLString
        self.officialArtworkURLString = officialArtworkURLString
        self.descriptionText = descriptionText
        self.descriptionTextEs = descriptionTextEs
        self.cryURLString = cryURLString
        self.genderRate = genderRate
    }

    /// Decodes the JSON-stored stats back into `StatShim` values.
    var decodedStats: [StatShim] {
        (try? JSONDecoder().decode([StatShim].self, from: statsJSON)) ?? []
    }
}
