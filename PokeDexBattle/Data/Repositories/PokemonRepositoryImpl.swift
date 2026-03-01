//
//  PokemonRepositoryImpl.swift
//  PokeDexBattle — Data Layer
//
//  Concrete implementation of `PokemonRepository`.
//  Responsibilities:
//    1. Call `PokeAPIClient` to fetch raw DTOs.
//    2. Map each DTO to a clean Domain entity (no DTO type ever leaks into the Domain).
//    3. Apply any business rules (deduplication, sorting, filtering by learn method).
//    4. Cache results in SwiftData and serve from cache on subsequent launches.
//
//  `PokemonRepositoryImpl` is the only place in the app that knows about both
//  the Data layer (DTOs / client / cache) and the Domain layer (entities / protocol).
//

import Foundation
import SwiftData

/// Concrete `PokemonRepository` backed by `PokeAPIClient` with SwiftData caching.
/// Instantiated with dependency injection so tests can provide a stub client.
final class PokemonRepositoryImpl: PokemonRepository {
    /// The underlying HTTP client used for all network calls.
    private let apiClient: PokeAPIClient

    /// Creates a repository with an optional custom API client.
    /// - Parameter apiClient: Defaults to a standard `PokeAPIClient()`.
    nonisolated init(apiClient: PokeAPIClient = PokeAPIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - PokemonRepository

    /// Fetches all Pokémon in the National Pokédex, serving from cache when available.
    ///
    /// Cache-first strategy:
    /// 1. Query SwiftData for any `CachedPokemon` rows — return immediately if found.
    /// 2. On cache miss: fetch from network, write to SwiftData, then return.
    ///
    /// - Returns: All Pokémon sorted by National Pokédex number, each with `types` populated.
    /// - Throws: `URLError` or `DecodingError` on network or parsing failure.
    func fetchAllPokemon() async throws -> [Pokemon] {
        // 1. Try cache
        let readCtx = ModelContext(AppContainer.shared)
        let descriptor = FetchDescriptor<CachedPokemon>(
            sortBy: [SortDescriptor(\.id)]
        )
        if let cached = try? readCtx.fetch(descriptor), !cached.isEmpty {
            return cached.map {
                Pokemon(
                    id: $0.id,
                    name: $0.name,
                    spriteURL: $0.spriteURLString.flatMap(URL.init),
                    types: $0.types
                )
            }
        }

        // 2. Network fetch
        let pokemon = try await fetchAllPokemonFromNetwork()

        // 3. Write to cache (new context for thread safety)
        let writeCtx = ModelContext(AppContainer.shared)
        for p in pokemon {
            writeCtx.insert(CachedPokemon(
                id: p.id,
                name: p.name,
                spriteURLString: p.spriteURL?.absoluteString,
                types: p.types
            ))
        }
        try? writeCtx.save()

        return pokemon
    }

    /// Fetches full detail for a single Pokémon, serving from cache when available.
    ///
    /// Height and weight are passed through as-is (decimetres / hectograms);
    /// conversion to metres / kilograms is the Presentation layer's responsibility.
    /// - Parameter id: The National Pokédex number.
    /// - Returns: A fully populated `PokemonDetail`.
    /// - Throws: `URLError` or `DecodingError` on failure.
    func fetchPokemonDetail(id: Int) async throws -> PokemonDetail {
        // 1. Try cache
        let readCtx = ModelContext(AppContainer.shared)
        var descriptor = FetchDescriptor<CachedPokemonDetail>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        // Skip cache if genderRate == -2: that row was written before this field was added.
        // SwiftData's @Attribute(.unique) + insert acts as REPLACE, so the re-fetch below
        // will overwrite the stale row and the next launch will be served from cache.
        if let cached = try? readCtx.fetch(descriptor).first, cached.genderRate != -2 {
            let stats = cached.decodedStats.map {
                PokemonDetail.Stat(name: $0.name, value: $0.value)
            }
            return PokemonDetail(
                id: cached.id,
                name: cached.name,
                height: cached.height,
                weight: cached.weight,
                types: cached.types,
                stats: stats,
                spriteURL: cached.spriteURLString.flatMap(URL.init),
                officialArtworkURL: cached.officialArtworkURLString.flatMap(URL.init)
                    ?? Self.officialArtworkURL(for: cached.id),
                description: Self.localizedText(
                    en: cached.descriptionText,
                    es: cached.descriptionTextEs
                ),
                cryURL: cached.cryURLString.flatMap(URL.init)
                    ?? Self.cryURL(for: cached.name),
                genderRate: cached.genderRate
            )
        }

        // 2. Network fetch — detail first, then species using the species ID from the detail
        // response. This handles alternate forms (Mega, Alolan, Gigantamax, etc.) whose own
        // ID differs from their base species ID (e.g. Mega Charizard X id=10034, species id=6).
        // Fetching /pokemon-species/10034 would return 404; we must use dto.species.id (=6).
        let dto = try await apiClient.fetchPokemonDetail(id: id)
        let species = try await apiClient.fetchSpecies(id: dto.species.id)

        // Extract both English and Spanish flavor-text entries from the species response.
        // We cache both so switching the device language never shows a stale translation.
        let descriptionEn = Self.cleanFlavorText(
            species.flavorTextEntries.first(where: { $0.language.name == "en" })?.flavorText ?? ""
        )
        let descriptionEs = Self.cleanFlavorText(
            species.flavorTextEntries.first(where: { $0.language.name == "es" })?.flavorText ?? ""
        )

        let cryURL = Self.cryURL(for: dto.name)
        let detail = PokemonDetail(
            id: dto.id,
            name: dto.name,
            height: dto.height,
            weight: dto.weight,
            types: dto.types.map(\.type.name),
            stats: dto.stats.map { .init(name: $0.stat.name, value: $0.baseStat) },
            spriteURL: dto.sprites.frontDefault.flatMap(URL.init),
            officialArtworkURL: Self.officialArtworkURL(for: dto.id),
            description: Self.localizedText(en: descriptionEn, es: descriptionEs),
            cryURL: cryURL,
            genderRate: species.genderRate
        )

        // 3. Write to cache — store both language strings.
        // @Attribute(.unique) on `id` means SwiftData REPLACES any existing row with the same id,
        // so this insert also serves as an upsert for stale rows (genderRate == -2).
        let writeCtx = ModelContext(AppContainer.shared)
        let shims = detail.stats.map {
            CachedPokemonDetail.StatShim(name: $0.name, value: $0.value)
        }
        writeCtx.insert(CachedPokemonDetail(
            id: detail.id,
            name: detail.name,
            height: detail.height,
            weight: detail.weight,
            types: detail.types,
            stats: shims,
            spriteURLString: detail.spriteURL?.absoluteString,
            officialArtworkURLString: detail.officialArtworkURL?.absoluteString,
            descriptionText: descriptionEn,
            descriptionTextEs: descriptionEs,
            cryURLString: cryURL?.absoluteString,
            genderRate: detail.genderRate
        ))
        try? writeCtx.save()

        return detail
    }

    /// Fetches all moves a Pokémon learns by levelling up, serving from cache when available.
    ///
    /// On a cache miss the full concurrent-fetch pipeline runs (see original documentation).
    /// - Parameter pokemonID: The National Pokédex number.
    /// - Returns: Level-up moves sorted by level, then name.
    /// - Throws: `URLError` or `DecodingError` if any request fails.
    func fetchMoves(for pokemonID: Int) async throws -> [PokemonMove] {
        // 1. Try cache
        let readCtx = ModelContext(AppContainer.shared)
        let descriptor = FetchDescriptor<CachedPokemonMove>(
            predicate: #Predicate { $0.pokemonID == pokemonID },
            sortBy: [
                SortDescriptor(\.levelLearnedAt),
                SortDescriptor(\.name)
            ]
        )
        if let cached = try? readCtx.fetch(descriptor), !cached.isEmpty {
            return cached.map {
                PokemonMove(
                    id: $0.id,
                    name: $0.name,
                    levelLearnedAt: $0.levelLearnedAt,
                    power: $0.power,
                    accuracy: $0.accuracy,
                    pp: $0.pp ?? 0,
                    damageClass: $0.damageClass,
                    type: $0.type,
                    shortEffect: Self.localizedText(en: $0.shortEffect, es: $0.shortEffectEs)
                )
            }
        }

        // 2. Network fetch — returns (move, rawEffects) pairs so we can cache both languages
        let pairs = try await fetchMovesFromNetwork(for: pokemonID)

        // 3. Write to cache — store both en/es strings so locale-switching never needs a re-download
        let writeCtx = ModelContext(AppContainer.shared)
        for (m, effects) in pairs {
            writeCtx.insert(CachedPokemonMove(
                id: m.id,
                pokemonID: pokemonID,
                name: m.name,
                levelLearnedAt: m.levelLearnedAt,
                power: m.power,
                accuracy: m.accuracy,
                pp: m.pp,
                damageClass: m.damageClass,
                type: m.type,
                shortEffect: effects.en,
                shortEffectEs: effects.es
            ))
        }
        try? writeCtx.save()

        return pairs.map(\.0)
    }

    /// Fetches the evolution chain for a Pokémon, serving from cache when available.
    ///
    /// Cache uses a flattened table (`CachedEvolutionNode`); on read the tree is
    /// reconstructed recursively via `buildEvolutionTree(from:rootParentID:ownerID:)`.
    func fetchEvolutionChain(for pokemonID: Int) async throws -> EvolutionStage {
        // 1. Try cache
        let readCtx = ModelContext(AppContainer.shared)
        let descriptor = FetchDescriptor<CachedEvolutionNode>(
            predicate: #Predicate { $0.ownerPokemonID == pokemonID }
        )
        if let cached = try? readCtx.fetch(descriptor), !cached.isEmpty {
            return buildEvolutionTree(from: cached, parentID: nil, ownerID: pokemonID)
        }

        // 2. Network fetch
        let root = try await fetchEvolutionChainFromNetwork(for: pokemonID)

        // 3. Flatten the tree and write to cache
        let writeCtx = ModelContext(AppContainer.shared)
        flattenAndInsert(stage: root, parentID: nil, ownerID: pokemonID, into: writeCtx)
        try? writeCtx.save()

        return root
    }

    /// Fetches alternate forms for a Pokémon species, serving from cache when available.
    ///
    /// The form whose `id` matches `pokemonID` is always excluded — that is the Pokémon
    /// the user is already viewing on the detail screen, so showing it again would be a duplicate.
    func fetchForms(for pokemonID: Int) async throws -> [PokemonForm] {
        // 1. Try cache
        let readCtx = ModelContext(AppContainer.shared)
        let descriptor = FetchDescriptor<CachedPokemonForm>(
            predicate: #Predicate { $0.pokemonID == pokemonID }
        )
        if let cached = try? readCtx.fetch(descriptor), !cached.isEmpty {
            return cached
                .map {
                    PokemonForm(
                        id: $0.id,
                        name: $0.name,
                        spriteURL: $0.spriteURLString.flatMap(URL.init),
                        isDefault: $0.isDefault,
                        types: $0.types
                    )
                }
                // Exclude the currently-viewed Pokémon — it is always a duplicate
                .filter { $0.id != pokemonID }
                .sorted {
                    if $0.isDefault != $1.isDefault { return $0.isDefault }
                    return $0.name < $1.name
                }
        }

        // 2. Network fetch
        let forms = try await fetchFormsFromNetwork(for: pokemonID)

        // 3. Write to cache
        let writeCtx = ModelContext(AppContainer.shared)
        for f in forms {
            writeCtx.insert(CachedPokemonForm(
                id: f.id,
                pokemonID: pokemonID,
                name: f.name,
                spriteURLString: f.spriteURL?.absoluteString,
                isDefault: f.isDefault,
                types: f.types
            ))
        }
        try? writeCtx.save()

        return forms
    }

    /// Deletes all cached data so the next fetch goes to the network.
    func clearAllCache() async {
        let ctx = ModelContext(AppContainer.shared)
        try? ctx.delete(model: CachedPokemon.self)
        try? ctx.delete(model: CachedPokemonDetail.self)
        try? ctx.delete(model: CachedPokemonMove.self)
        try? ctx.delete(model: CachedEvolutionNode.self)
        try? ctx.delete(model: CachedPokemonForm.self)
        try? ctx.save()
    }

    // MARK: - URL helpers

    /// Builds the high-resolution official artwork URL for a given Pokédex ID.
    /// Hosted on the PokeAPI GitHub sprites CDN — no authentication required.
    /// Returns `nil` only if the URL string is malformed (should never happen).
    private static func officialArtworkURL(for id: Int) -> URL? {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(id).png")
    }

    /// Builds the MP3 cry URL for a Pokémon from the Pokémon Showdown audio CDN.
    ///
    /// Pokémon Showdown hosts iOS-compatible MP3 cries keyed by the lowercase hyphenated
    /// Pokémon name (the same name the PokeAPI returns, e.g. "bulbasaur", "mr-mime").
    /// AVFoundation supports MP3 natively; the PokeAPI OGG Vorbis files are not playable
    /// on iOS (error -12864 / kAudioFileUnsupportedFileTypeError).
    private static func cryURL(for name: String) -> URL? {
        URL(string: "https://play.pokemonshowdown.com/audio/cries/\(name).mp3")
    }

    /// Removes `\n`, `\r`, and form-feed (`\f`) control characters from a raw PokeAPI
    /// string, collapsing any resulting runs of whitespace into single spaces.
    private static func cleanFlavorText(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\n",       with: " ")
            .replacingOccurrences(of: "\r",       with: " ")
            .replacingOccurrences(of: "\u{000C}", with: " ")   // form-feed (\f)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The PokeAPI language code that matches the current device language.
    /// PokeAPI supports: "en", "es", "de", "fr", "it", "ja", "ko", "zh-Hans", "zh-Hant".
    /// Falls back to "en" for any unsupported language.
    private static var apiLanguageCode: String {
        let supported = ["en", "es", "de", "fr", "it", "ja", "ko"]
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return supported.contains(lang) ? lang : "en"
    }

    /// Returns the string for the device language when available, falling back to English.
    /// Used for any multi-language PokeAPI array (flavor text, move effects, etc.).
    private static func localizedText(en: String, es: String) -> String {
        let lang = apiLanguageCode
        if lang == "es" && !es.isEmpty { return es }
        return en
    }

    // MARK: - Private network helpers

    /// Carries both the English and Spanish short-effect strings for a move
    /// through the network fetch → cache write pipeline without polluting the domain entity.
    private struct MoveEffects {
        let en: String
        let es: String
    }

    /// Pure network implementation of `fetchAllPokemon` (no cache interaction).
    ///
    /// Steps:
    /// 1. Probe the list endpoint with `limit=1` to discover the total count.
    /// 2. Fetch all entries (`limit=count`) to obtain every name + numeric ID.
    /// 3. Concurrently fetch `/pokemon/{id}` for every entry using `withThrowingTaskGroup`.
    /// 4. Return results sorted by Pokédex ID ascending.
    private func fetchAllPokemonFromNetwork() async throws -> [Pokemon] {
        let listDTO = try await apiClient.fetchAllPokemon()

        let pokemon: [Pokemon] = try await withThrowingTaskGroup(of: Pokemon.self) { group in
            for entry in listDTO.results {
                let id = entry.extractedID
                // Skip IDs above 1025 — those are alternate forms/variants, not base species
                guard id <= 1025 else { continue }
                group.addTask {
                    let detail = try await self.apiClient.fetchPokemonDetail(id: id)
                    return Pokemon(
                        id: detail.id,
                        name: detail.name,
                        spriteURL: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(detail.id).png"),
                        types: detail.types.map(\.type.name)
                    )
                }
            }
            var results: [Pokemon] = []
            for try await p in group { results.append(p) }
            return results
        }

        // Task group output order is non-deterministic — restore Pokédex order
        return pokemon.sorted { $0.id < $1.id }
    }

    /// Pure network implementation of `fetchMoves(for:)`.
    ///
    /// Returns `(PokemonMove, MoveEffects)` pairs so the caller can cache raw en/es strings
    /// while exposing only the locale-correct `shortEffect` in the domain entity.
    private func fetchMovesFromNetwork(for pokemonID: Int) async throws -> [(PokemonMove, MoveEffects)] {
        let detailDTO = try await apiClient.fetchPokemonDetail(id: pokemonID)

        // Collect unique level-up moves, keeping the highest level seen across versions
        var levelUpMoves: [Int: (name: String, level: Int)] = [:]
        for slot in detailDTO.moves {
            let moveID = slot.move.id
            for versionDetail in slot.versionGroupDetails where versionDetail.moveLearnMethod.name == "level-up" {
                let existing = levelUpMoves[moveID]
                if existing == nil || versionDetail.levelLearnedAt > existing!.level {
                    levelUpMoves[moveID] = (slot.move.name, versionDetail.levelLearnedAt)
                }
            }
        }

        // Fetch all move details concurrently — extract both en and es effect text
        let pairs: [(PokemonMove, MoveEffects)] = try await withThrowingTaskGroup(
            of: (PokemonMove, MoveEffects).self
        ) { group in
            for (moveID, info) in levelUpMoves {
                group.addTask {
                    let dto = try await self.apiClient.fetchMoveDetail(id: moveID)
                    // effect_entries only has en and fr — use it for the English short effect.
                    let effectEn = dto.effectEntries
                        .first(where: { $0.language.name == "en" })?
                        .shortEffect ?? ""
                    // flavor_text_entries has full language coverage including Spanish.
                    // Use the last (most recent game version) entry per language.
                    let flavorEs = dto.flavorTextEntries
                        .last(where: { $0.language.name == "es" })?
                        .flavorText ?? ""
                    let flavorEn = dto.flavorTextEntries
                        .last(where: { $0.language.name == "en" })?
                        .flavorText ?? ""
                    // Spanish: prefer flavor text in es; fallback to flavor text in en; then effect in en.
                    let effectEs = !flavorEs.isEmpty ? flavorEs
                                 : !flavorEn.isEmpty ? flavorEn
                                 : effectEn
                    // English: prefer the short effect (more technical); fallback to flavor text.
                    let finalEn = !effectEn.isEmpty ? effectEn
                                : !flavorEn.isEmpty ? flavorEn
                                : ""
                    let effects = MoveEffects(en: finalEn, es: effectEs)
                    let move = PokemonMove(
                        id: dto.id,
                        name: info.name,
                        levelLearnedAt: info.level,
                        power: dto.power,
                        accuracy: dto.accuracy,
                        pp: dto.pp,
                        damageClass: dto.damageClass.name,
                        type: dto.type.name,
                        shortEffect: Self.localizedText(en: effectEn, es: effectEs)
                    )
                    return (move, effects)
                }
            }
            var results: [(PokemonMove, MoveEffects)] = []
            for try await pair in group { results.append(pair) }
            return results
        }

        return pairs.sorted {
            let (a, _) = $0
            let (b, _) = $1
            return a.levelLearnedAt == b.levelLearnedAt
                ? a.name < b.name
                : a.levelLearnedAt < b.levelLearnedAt
        }
    }

    /// Pure network implementation of `fetchEvolutionChain(for:)`.
    ///
    /// Fetches the evolution chain for a Pokémon and maps it to a recursive `EvolutionStage` tree.
    private func fetchEvolutionChainFromNetwork(for pokemonID: Int) async throws -> EvolutionStage {
        // Fetch the pokemon detail first to resolve the correct species ID.
        // Alternate forms (Mega, Alolan, etc.) share their base species — using the form's
        // own pokemonID against /pokemon-species/ would return 404.
        let pokemonDetail = try await apiClient.fetchPokemonDetail(id: pokemonID)
        let species  = try await apiClient.fetchSpecies(id: pokemonDetail.species.id)
        let chainDTO = try await apiClient.fetchEvolutionChain(id: species.evolutionChain.id)

        // Pre-fetch all species IDs concurrently so we have sprites for every stage
        func collectNames(_ link: EvolutionChainDTO.ChainLinkDTO) -> [String] {
            var names = [link.species.name]
            for child in link.evolvesTo { names += collectNames(child) }
            return names
        }
        let allNames = collectNames(chainDTO.chain)

        let idMap: [String: Int] = try await withThrowingTaskGroup(of: (String, Int).self) { group in
            for name in allNames {
                group.addTask {
                    let detail = try await self.apiClient.fetchPokemonDetail(id: 0, name: name)
                    return (name, detail.id)
                }
            }
            var map: [String: Int] = [:]
            for try await pair in group { map[pair.0] = pair.1 }
            return map
        }

        // Recursively build the domain tree
        func buildStage(_ link: EvolutionChainDTO.ChainLinkDTO) -> EvolutionStage {
            let id = idMap[link.species.name] ?? 0
            let spriteURL = URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")
            let trigger = link.evolutionDetails.first.map(triggerDescription) ?? "Base form"
            return EvolutionStage(
                id: id,
                name: link.species.name,
                spriteURL: spriteURL,
                trigger: trigger,
                evolvesTo: link.evolvesTo.map(buildStage)
            )
        }
        return buildStage(chainDTO.chain)
    }

    /// Pure network implementation of `fetchForms(for:)`.
    private func fetchFormsFromNetwork(for pokemonID: Int) async throws -> [PokemonForm] {
        // Fetch the pokemon detail first to get the correct species ID.
        // Alternate forms (Mega, Alolan, etc.) have their own pokemon ID but share the
        // base species ID (e.g. Mega Charizard X: pokemonID=10034, speciesID=6).
        // /pokemon-species/10034 returns 404 — we must use the species ID from the detail.
        let pokemonDetail = try await apiClient.fetchPokemonDetail(id: pokemonID)
        let species = try await apiClient.fetchSpecies(id: pokemonDetail.species.id)

        let forms: [PokemonForm] = try await withThrowingTaskGroup(of: PokemonForm.self) { group in
            for variety in species.varieties {
                let varietyID = variety.pokemon.id
                let isDefault = variety.isDefault
                group.addTask {
                    let detail = try await self.apiClient.fetchPokemonDetail(id: varietyID)
                    return PokemonForm(
                        id: detail.id,
                        name: variety.pokemon.name,
                        spriteURL: detail.sprites.frontDefault.flatMap(URL.init),
                        isDefault: isDefault,
                        types: detail.types.map(\.type.name)
                    )
                }
            }
            var results: [PokemonForm] = []
            for try await form in group { results.append(form) }
            return results
        }

        // Exclude the currently-viewed Pokémon — it is always a duplicate on the forms screen.
        // Default form first, then alphabetical.
        return forms
            .filter { $0.id != pokemonID }
            .sorted {
                if $0.isDefault != $1.isDefault { return $0.isDefault }
                return $0.name < $1.name
            }
    }

    // MARK: - Evolution cache helpers

    /// Recursively flattens an `EvolutionStage` tree into `CachedEvolutionNode` rows
    /// and inserts them into the provided `ModelContext`.
    private func flattenAndInsert(
        stage: EvolutionStage,
        parentID: Int?,
        ownerID: Int,
        into ctx: ModelContext
    ) {
        ctx.insert(CachedEvolutionNode(
            ownerPokemonID: ownerID,
            nodeID: stage.id,
            name: stage.name,
            spriteURLString: stage.spriteURL?.absoluteString,
            trigger: stage.trigger,
            parentID: parentID
        ))
        for child in stage.evolvesTo {
            flattenAndInsert(stage: child, parentID: stage.id, ownerID: ownerID, into: ctx)
        }
    }

    /// Reconstructs an `EvolutionStage` tree from a flat array of `CachedEvolutionNode` rows.
    /// - Parameters:
    ///   - nodes: All rows for the given `ownerID`.
    ///   - parentID: The `nodeID` of the parent stage (`nil` for the root).
    ///   - ownerID: The Pokémon whose chain is being reconstructed (used for logging only).
    private func buildEvolutionTree(
        from nodes: [CachedEvolutionNode],
        parentID: Int?,
        ownerID: Int
    ) -> EvolutionStage {
        // Find the node whose parentID matches — there should be exactly one root (parentID == nil)
        guard let node = nodes.first(where: { $0.parentID == parentID }) else {
            // Fallback: return a minimal placeholder (should never happen with valid cache data)
            return EvolutionStage(id: 0, name: "Unknown", spriteURL: nil, trigger: "Base form", evolvesTo: [])
        }
        // Recursively build each child stage that points to this node as its parent
        let evolvesTo: [EvolutionStage] = nodes
            .filter { $0.parentID == node.nodeID }
            .map { child in buildEvolutionTree(from: nodes, parentID: child.nodeID, ownerID: ownerID) }

        return EvolutionStage(
            id: node.nodeID,
            name: node.name,
            spriteURL: node.spriteURLString.flatMap(URL.init),
            trigger: node.trigger,
            evolvesTo: evolvesTo
        )
    }

    // MARK: - Private helpers

    /// Converts a raw `EvolutionDetailDTO` into a localized human-readable trigger string.
    private func triggerDescription(_ detail: EvolutionChainDTO.EvolutionDetailDTO) -> String {
        switch detail.trigger.name {
        case "level-up":
            var parts: [String] = []
            if let lvl = detail.minLevel {
                parts.append(String(format: String(localized: "evo.level %lld", defaultValue: "Level %lld"), lvl))
            }
            if let happiness = detail.minHappiness {
                parts.append(String(format: String(localized: "evo.happiness %lld", defaultValue: "Happiness ≥ %lld"), happiness))
            }
            if let time = detail.timeOfDay, !time.isEmpty {
                parts.append(localizedTimeOfDay(time))
            }
            return parts.isEmpty
                ? String(localized: "evo.level-up", defaultValue: "Level up")
                : parts.joined(separator: ", ")
        case "use-item":
            if let item = detail.item {
                let itemName = item.name.replacingOccurrences(of: "-", with: " ").capitalized
                return String(format: String(localized: "evo.use-item %@", defaultValue: "Use %@"), itemName)
            }
            return String(localized: "evo.use-item-generic", defaultValue: "Use item")
        case "trade":
            if let held = detail.heldItem {
                let itemName = held.name.replacingOccurrences(of: "-", with: " ").capitalized
                return String(format: String(localized: "evo.trade-holding %@", defaultValue: "Trade holding %@"), itemName)
            }
            return String(localized: "evo.trade", defaultValue: "Trade")
        default:
            return detail.trigger.name.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    /// Maps a PokeAPI time-of-day string to a localized display label.
    private func localizedTimeOfDay(_ raw: String) -> String {
        switch raw.lowercased() {
        case "day":   return String(localized: "evo.time.day",   defaultValue: "Day")
        case "night": return String(localized: "evo.time.night", defaultValue: "Night")
        default:      return raw.capitalized
        }
    }
}
