//
//  EvolutionsViewModel.swift
//  PokeDexBattle — Presentation Layer
//

import Foundation
import Observation

/// ViewModel for `EvolutionsView`.
/// Fetches the recursive evolution chain for a Pokémon and exposes
/// the root `EvolutionStage` node to the View.
@MainActor
@Observable
final class EvolutionsViewModel {
    /// Root of the evolution tree. `nil` until `load()` succeeds.
    private(set) var chain: EvolutionStage?
    /// `true` while the network requests are in flight.
    private(set) var isLoading = false
    /// Non-nil when the most recent load attempt failed. Cleared on `retry()`.
    private(set) var errorMessage: String?

    /// Pokémon name used to build the navigation title.
    let pokemonName: String
    private let pokemonID: Int
    private let repository: PokemonRepository

    /// Creates the ViewModel for a specific Pokémon's evolution screen.
    /// - Parameters:
    ///   - pokemonID: The National Pokédex number of any Pokémon in the chain.
    ///   - pokemonName: Lowercase name used for the navigation title.
    ///   - repository: Defaults to the live `PokemonRepositoryImpl`.
    init(pokemonID: Int, pokemonName: String, repository: PokemonRepository = PokemonRepositoryImpl()) {
        self.pokemonID   = pokemonID
        self.pokemonName = pokemonName
        self.repository  = repository
    }

    // MARK: - Intent

    /// Fetches the evolution chain from the repository. No-ops if already loaded or loading.
    func load() async {
        guard chain == nil, !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            chain = try await repository.fetchEvolutionChain(for: pokemonID)
        } catch {
            errorMessage = "Failed to load evolutions: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Resets state and re-triggers `load()`.
    func retry() async {
        chain = nil
        errorMessage = nil
        await load()
    }
}
