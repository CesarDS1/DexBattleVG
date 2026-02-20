//
//  MovesViewModel.swift
//  PokeDexBattle — Presentation Layer
//
//  Drives the moves-by-level screen for a single Pokémon.
//  Fetches all level-up moves, then groups them by `levelLearnedAt`
//  so the View can render one `List` section per level.
//

import Foundation
import Observation

/// ViewModel for `MovesView`.
///
/// Responsibilities:
/// - Fetch all level-up moves for a specific Pokémon via `load()`.
/// - Group the sorted flat list into `[(level: Int, moves: [PokemonMove])]`,
///   preserving the ascending-level order coming from the repository.
/// - Expose `groupedMoves`, `isLoading`, and `errorMessage` to the View.
/// - Provide `retry()` for error recovery.
///
/// Marked `@MainActor` to ensure all state mutations happen on the main thread.
@MainActor
@Observable
final class MovesViewModel {
    /// Moves grouped by the level at which they are learned, in ascending level order.
    /// Each tuple's `moves` array is sorted alphabetically by name.
    private(set) var groupedMoves: [(level: Int, moves: [PokemonMove])] = []

    /// `true` while the network requests are in flight.
    private(set) var isLoading = false

    /// Non-nil when the most recent `load()` attempt failed. Cleared on `retry()`.
    private(set) var errorMessage: String?

    /// Pokémon name used to build the navigation title (e.g. "Bulbasaur Moves").
    let pokemonName: String

    private let pokemonID: Int
    private let repository: PokemonRepository

    /// Creates the ViewModel for a specific Pokémon's moves screen.
    /// - Parameters:
    ///   - pokemonID: The National Pokédex number.
    ///   - pokemonName: Lowercase name used for the screen title.
    ///   - repository: Defaults to the live `PokemonRepositoryImpl`.
    init(pokemonID: Int, pokemonName: String, repository: PokemonRepository = PokemonRepositoryImpl()) {
        self.pokemonID    = pokemonID
        self.pokemonName  = pokemonName
        self.repository   = repository
    }

    // MARK: - Intent

    /// Fetches and groups level-up moves for the Pokémon.
    /// No-ops if moves are already loaded or a request is in flight.
    func load() async {
        guard !isLoading, groupedMoves.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let moves = try await repository.fetchMoves(for: pokemonID)

            // Group moves by level while preserving the sort order from the repository.
            // We track insertion order separately because dictionary ordering is not guaranteed.
            var seen: [Int: [PokemonMove]] = [:]
            var order: [Int] = []
            for move in moves {
                if seen[move.levelLearnedAt] == nil {
                    order.append(move.levelLearnedAt)
                }
                seen[move.levelLearnedAt, default: []].append(move)
            }
            groupedMoves = order.map { level in
                (level: level, moves: seen[level] ?? [])
            }
        } catch {
            errorMessage = "Failed to load moves: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Clears loaded moves and re-triggers `load()`.
    /// Called when the user taps "Retry" after a failed load.
    func retry() async {
        groupedMoves = []
        errorMessage = nil
        await load()
    }
}
