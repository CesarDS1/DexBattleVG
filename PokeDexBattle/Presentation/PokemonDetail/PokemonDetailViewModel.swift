//
//  PokemonDetailViewModel.swift
//  PokeDexBattle — Presentation Layer
//
//  Drives the individual Pokémon detail screen.
//  Fetches a single `PokemonDetail` on demand and exposes the result,
//  loading state, and any error to the View.
//

import Foundation
import Observation

/// ViewModel for `PokemonDetailView`.
///
/// Responsibilities:
/// - Fetch `PokemonDetail` exactly once via `load()`, guarding against duplicate calls.
/// - Expose `detail`, `isLoading`, and `errorMessage` for the View to render.
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

    /// The National Pokédex number for the Pokémon to fetch.
    private let pokemonID: Int
    private let repository: PokemonRepository

    /// Creates the ViewModel for a specific Pokémon.
    /// - Parameters:
    ///   - pokemonID: The National Pokédex number.
    ///   - repository: Defaults to the live `PokemonRepositoryImpl`.
    init(pokemonID: Int, repository: PokemonRepository = PokemonRepositoryImpl()) {
        self.pokemonID = pokemonID
        self.repository = repository
    }

    // MARK: - Intent

    /// Fetches `PokemonDetail` from the repository.
    /// No-ops if detail is already loaded or a request is in flight.
    func load() async {
        guard detail == nil, !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            detail = try await repository.fetchPokemonDetail(id: pokemonID)
        } catch {
            errorMessage = "Failed to load details: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Clears the current detail and re-triggers `load()`.
    /// Called when the user taps "Retry" after a failed load.
    func retry() async {
        detail = nil
        await load()
    }
}
