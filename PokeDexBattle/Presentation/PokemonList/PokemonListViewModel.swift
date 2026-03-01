//
//  PokemonListViewModel.swift
//  PokeDexBattle — Presentation Layer
//
//  Drives the Pokédex list screen. Owns all state for loading, searching,
//  type-filtering, and error handling. The View is kept declarative and
//  stateless — every decision lives here.
//

import Foundation
import Observation

/// ViewModel for `PokemonListView`.
///
/// Responsibilities:
/// - Load the complete National Pokédex once via `loadAll()`.
/// - Expose `filteredPokemon` that combines the live `searchQuery` with any active `selectedTypes`.
/// - Derive `availableTypes` from the loaded data for the filter chip bar.
/// - Surface `isLoading`, `hasLoaded`, and `errorMessage` so the View can render
///   the correct state without any business logic of its own.
///
/// Marked `@MainActor` so all property mutations happen on the main thread,
/// satisfying SwiftUI's requirement for UI updates.
@MainActor
@Observable
final class PokemonListViewModel {

    // MARK: - State

    /// Full list of all Pokémon fetched from the API, in Pokédex order.
    private(set) var pokemon: [Pokemon] = []

    /// `true` while a network request is in flight.
    private(set) var isLoading = false

    /// Flipped to `true` after the first `loadAll()` completes (success or error).
    /// Used by the View to distinguish "not yet loaded" from "loaded but empty".
    private(set) var hasLoaded = false

    /// Non-nil when the most recent load attempt failed. Cleared on retry.
    private(set) var errorMessage: String?

    /// The text typed into the search bar. Setting this re-evaluates `filteredPokemon` instantly.
    var searchQuery: String = ""

    /// The set of type names the user has selected to filter by.
    /// Empty means no type filter is active (all types shown).
    private(set) var selectedTypes: Set<String> = []

    /// All unique type names found in the loaded Pokémon list, sorted alphabetically.
    /// Used to populate the type filter chip bar. Built once when `loadAll()` completes.
    private(set) var availableTypes: [String] = []

    /// Set of generation numbers the user has manually collapsed.
    /// Empty by default — all sections start expanded.
    private(set) var collapsedGenerations: Set<Int> = []

    // MARK: - Computed

    /// Returns `pokemon` filtered by `showFavoritesOnly`, `searchQuery`, and/or `selectedTypes`.
    ///
    /// - Favourites filter: applied first when `showFavoritesOnly` is `true`.
    /// - Name filter: case- and diacritic-insensitive substring match.
    /// - Type filter: a Pokémon passes if it has **at least one** of the selected types (union).
    var filteredPokemon: [Pokemon] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        var result = pokemon
        if showFavoritesOnly {
            result = result.filter { favoriteIDs.contains($0.id) }
        }
        if !trimmed.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
        if !selectedTypes.isEmpty {
            result = result.filter { !Set($0.types).isDisjoint(with: selectedTypes) }
        }
        return result
    }

    /// `true` when the user has typed a non-whitespace search query.
    var isSearching: Bool { !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty }

    /// `true` when at least one type filter chip is selected.
    var isFiltering: Bool { !selectedTypes.isEmpty }

    /// `true` when any filter (search, type, or favourites-only) is active.
    /// Used to decide whether to show the "no results" empty-state message inside the list.
    var isSearchingOrFiltering: Bool { isSearching || isFiltering || showFavoritesOnly }

    // MARK: - Generation grouping

    /// Represents one generation section: its numeric key, display label, and filtered Pokémon.
    struct GenerationGroup: Identifiable {
        let id: Int          // generation number (1–9, or 10 for "Other")
        let label: String    // e.g. "Kanto I"
        let pokemon: [Pokemon]
    }

    /// `filteredPokemon` partitioned into generation groups, sorted ascending.
    /// Groups that contain zero Pokémon after filtering are omitted entirely.
    var groupedByGeneration: [GenerationGroup] {
        var dict: [Int: [Pokemon]] = [:]
        for p in filteredPokemon {
            let g = Self.generation(for: p.id)
            dict[g, default: []].append(p)
        }
        return dict.keys.sorted().compactMap { gen in
            guard let list = dict[gen], !list.isEmpty else { return nil }
            return GenerationGroup(id: gen, label: Self.generationLabel(gen), pokemon: list)
        }
    }

    // MARK: - Generation helpers

    /// Returns the generation number (1–9) for a given National Pokédex ID.
    /// IDs 1–1025 cover all nine generations. Entries above 1025 are filtered
    /// out at the repository level so this function never receives them.
    static func generation(for id: Int) -> Int {
        switch id {
        case 1...151:    return 1
        case 152...251:  return 2
        case 252...386:  return 3
        case 387...493:  return 4
        case 494...649:  return 5
        case 650...721:  return 6
        case 722...809:  return 7
        case 810...905:  return 8
        default:         return 9   // 906–1025  (Paldea)
        }
    }

    /// Human-readable section label combining region name and Roman numeral (localized).
    static func generationLabel(_ gen: Int) -> String {
        localizedGenerationLabel(gen)
    }

    // MARK: - Favourites state

    /// IDs of all Pokémon currently marked as favourites. Refreshed on every list appearance.
    private(set) var favoriteIDs: Set<Int> = []

    /// When `true` the list shows only Pokémon whose IDs are in `favoriteIDs`.
    private(set) var showFavoritesOnly = false

    /// Returns `true` if the given Pokédex ID is currently marked as a favourite.
    func isFavorite(_ id: Int) -> Bool { favoriteIDs.contains(id) }

    // MARK: - Dependencies

    private let repository: PokemonRepository
    private let favoritesRepository: FavoritesRepository

    /// Creates the ViewModel with optional repository overrides (useful for previews/tests).
    init(
        repository: PokemonRepository = PokemonRepositoryImpl(),
        favoritesRepository: FavoritesRepository = FavoritesRepositoryImpl()
    ) {
        self.repository          = repository
        self.favoritesRepository = favoritesRepository
    }

    // MARK: - Intent

    /// Fetches all Pokémon from the repository (including their types).
    /// Always refreshes favourites (fast SwiftData read) to stay in sync with detail screen.
    /// Guards the expensive Pokémon fetch against duplicate calls.
    func loadAll() async {
        // Favourites refresh is cheap — always run it so the list stays in sync
        // after the user returns from a detail screen where they may have toggled a favourite.
        await loadFavorites()

        guard !isLoading, !hasLoaded else { return }

        isLoading = true
        errorMessage = nil

        do {
            pokemon = try await repository.fetchAllPokemon()
            availableTypes = Array(Set(pokemon.flatMap(\.types))).sorted()
        } catch {
            errorMessage = "Failed to load Pokémon: \(error.localizedDescription)"
        }

        isLoading = false
        hasLoaded = true
    }

    /// Refreshes the in-memory `favoriteIDs` from SwiftData.
    /// Called automatically by `loadAll()` and by `toggleFavorite(pokemonID:)`.
    func loadFavorites() async {
        favoriteIDs = await favoritesRepository.fetchFavoriteIDs()
    }

    /// Adds or removes the Pokémon from favourites, updating `favoriteIDs` immediately
    /// for instant UI feedback without requiring a full list reload.
    func toggleFavorite(pokemonID: Int) async {
        if favoriteIDs.contains(pokemonID) {
            await favoritesRepository.removeFavorite(pokemonID: pokemonID)
            favoriteIDs.remove(pokemonID)
        } else {
            await favoritesRepository.addFavorite(pokemonID: pokemonID)
            favoriteIDs.insert(pokemonID)
        }
    }

    /// Toggles the "show favourites only" filter on/off.
    func toggleFavoritesFilter() {
        showFavoritesOnly.toggle()
    }

    /// Resets state and re-triggers `loadAll()`.
    /// Called when the user taps "Retry" after a failed load.
    func retry() async {
        hasLoaded = false
        errorMessage = nil
        selectedTypes = []
        availableTypes = []
        await loadAll()
    }

    /// Clears the local SwiftData Pokédex cache and re-fetches everything from the network.
    /// Called when the user pulls to refresh on the Pokédex list.
    ///
    /// Note: Favourites are **not** cleared — they are user data independent of the API cache.
    func refreshAll() async {
        await repository.clearAllCache()
        hasLoaded = false
        errorMessage = nil
        pokemon = []
        selectedTypes = []
        availableTypes = []
        collapsedGenerations = []
        showFavoritesOnly = false
        await loadAll()
    }

    /// Toggles the given type in `selectedTypes`.
    /// Tapping an already-selected chip deselects it; tapping an unselected chip adds it.
    /// - Parameter type: Lowercase PokeAPI type name (e.g. `"fire"`).
    func toggleType(_ type: String) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    /// Clears all active type filters.
    func clearTypeFilters() {
        selectedTypes = []
    }

    /// Toggles the collapsed/expanded state of a generation section.
    /// - Parameter gen: The generation number to toggle (1–9, or 10 for "Other").
    func toggleGeneration(_ gen: Int) {
        if collapsedGenerations.contains(gen) {
            collapsedGenerations.remove(gen)
        } else {
            collapsedGenerations.insert(gen)
        }
    }
}
