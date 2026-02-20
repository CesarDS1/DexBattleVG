//
//  FormsViewModel.swift
//  PokeDexBattle — Presentation Layer
//

import Foundation
import Observation

/// ViewModel for `FormsView`.
/// Fetches all alternate forms and regional variants for a Pokémon species.
@MainActor
@Observable
final class FormsViewModel {
    /// All forms fetched from the repository. Default form appears first.
    private(set) var forms: [PokemonForm] = []
    /// `true` while the network requests are in flight.
    private(set) var isLoading = false
    /// Non-nil when the most recent load attempt failed. Cleared on `retry()`.
    private(set) var errorMessage: String?

    /// Pokémon name used to build the navigation title.
    let pokemonName: String
    private let pokemonID: Int
    private let repository: PokemonRepository

    /// Creates the ViewModel for a specific Pokémon's forms screen.
    /// - Parameters:
    ///   - pokemonID: The National Pokédex number of the base Pokémon.
    ///   - pokemonName: Lowercase name used for the navigation title.
    ///   - repository: Defaults to the live `PokemonRepositoryImpl`.
    init(pokemonID: Int, pokemonName: String, repository: PokemonRepository = PokemonRepositoryImpl()) {
        self.pokemonID   = pokemonID
        self.pokemonName = pokemonName
        self.repository  = repository
    }

    // MARK: - Intent

    /// Fetches all forms from the repository. No-ops if already loaded or loading.
    func load() async {
        guard forms.isEmpty, !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            forms = try await repository.fetchForms(for: pokemonID)
        } catch {
            errorMessage = "Failed to load forms: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Resets state and re-triggers `load()`.
    func retry() async {
        forms = []
        errorMessage = nil
        await load()
    }
}
