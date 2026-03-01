//
//  PokemonDetailViewModel.swift
//  PokeDexBattle — Presentation Layer
//
//  Drives the individual Pokémon detail screen.
//  Fetches a single `PokemonDetail` on demand and exposes the result,
//  loading state, error, and favorites state to the View.
//

import Foundation
import Observation

/// ViewModel for `PokemonDetailView`.
///
/// Responsibilities:
/// - Fetch `PokemonDetail` exactly once via `load()`, guarding against duplicate calls.
/// - Expose `detail`, `isLoading`, and `errorMessage` for the View to render.
/// - Provide `isFavorite` state and a `toggleFavorite()` action backed by `FavoritesRepository`.
/// - Provide a `retry()` method that resets state and re-fetches.
///
/// Marked `@MainActor` to ensure all published-property mutations are on the main thread.
@MainActor
@Observable
final class PokemonDetailViewModel {
    /// The loaded Pokémon detail. `nil` until `load()` completes successfully.
    private(set) var detail: PokemonDetail?

    /// `true` while the network request is in flight.
    private(set) var isLoading = false

    /// Non-nil when the most recent `load()` attempt failed. Cleared on `retry()`.
    private(set) var errorMessage: String?

    /// Whether this Pokémon is in the user's favorites list.
    private(set) var isFavorite = false

    /// The National Pokédex number for the Pokémon to fetch.
    private let pokemonID: Int
    private let repository: PokemonRepository
    private let favoritesRepository: FavoritesRepository

    /// Creates the ViewModel for a specific Pokémon.
    /// - Parameters:
    ///   - pokemonID: The National Pokédex number.
    ///   - repository: Defaults to the live `PokemonRepositoryImpl`.
    ///   - favoritesRepository: Defaults to the live `FavoritesRepositoryImpl`.
    init(
        pokemonID: Int,
        repository: PokemonRepository = PokemonRepositoryImpl(),
        favoritesRepository: FavoritesRepository = FavoritesRepositoryImpl()
    ) {
        self.pokemonID = pokemonID
        self.repository = repository
        self.favoritesRepository = favoritesRepository
    }

    // MARK: - Intent

    /// Fetches `PokemonDetail` and the current favorites state concurrently.
    /// No-ops if detail is already loaded or a request is in flight.
    func load() async {
        guard detail == nil, !isLoading else { return }

        isLoading = true
        errorMessage = nil

        // Fetch detail and favorites state concurrently for faster first paint.
        async let fetchedDetail = repository.fetchPokemonDetail(id: pokemonID)
        async let fetchedIsFav  = favoritesRepository.isFavorite(pokemonID: pokemonID)

        do {
            detail    = try await fetchedDetail
            isFavorite = await fetchedIsFav
        } catch {
            errorMessage = "Failed to load details: \(error.localizedDescription)"
            // Still update isFavorite even if detail fetch failed.
            isFavorite = await fetchedIsFav
        }

        isLoading = false
    }

    /// Toggles the favorite state for this Pokémon and persists the change.
    func toggleFavorite() async {
        let newValue = !isFavorite
        // Optimistic update — UI responds instantly.
        isFavorite = newValue

        if newValue {
            await favoritesRepository.addFavorite(pokemonID: pokemonID)
        } else {
            await favoritesRepository.removeFavorite(pokemonID: pokemonID)
        }
    }

    /// Clears the current detail and re-triggers `load()`.
    /// Called when the user taps "Retry" after a failed load.
    func retry() async {
        detail = nil
        await load()
    }
}
