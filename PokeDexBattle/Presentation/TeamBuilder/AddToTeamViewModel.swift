//
//  AddToTeamViewModel.swift
//  PokeDexBattle — Presentation Layer
//
//  Manages the Pokémon picker sheet.
//  Loads all Pokémon (reusing the existing repository) and exposes
//  search + type-filter state identical to PokemonListViewModel.
//  On selection it calls TeamRepository.addMember to persist the choice.
//

import Foundation

@MainActor @Observable
final class AddToTeamViewModel {

    // MARK: - State

    private(set) var allPokemon: [Pokemon] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchQuery: String = ""
    private(set) var selectedTypes: Set<String> = []
    private(set) var availableTypes: [String] = []

    /// Pokémon IDs successfully added during the current sheet session.
    /// Lets the picker show checkmarks immediately after adding, without
    /// needing to re-fetch the full team from SwiftData.
    private(set) var addedInSession: Set<Int> = []

    // MARK: - Private

    private let teamID: UUID
    private let currentMemberIDs: Set<Int>
    private let pokemonRepository: PokemonRepository
    private let teamRepository: TeamRepository

    // MARK: - Init

    nonisolated init(
        teamID: UUID,
        currentMemberIDs: Set<Int> = [],
        pokemonRepository: PokemonRepository = PokemonRepositoryImpl(),
        teamRepository: TeamRepository = TeamRepositoryImpl()
    ) {
        self.teamID = teamID
        self.currentMemberIDs = currentMemberIDs
        self.pokemonRepository = pokemonRepository
        self.teamRepository = teamRepository
    }

    // MARK: - Computed

    /// Pokémon filtered by search text and selected types.
    var filteredPokemon: [Pokemon] {
        var result = allPokemon

        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery) ||
                String(format: "%03d", $0.id).contains(searchQuery)
            }
        }

        if !selectedTypes.isEmpty {
            result = result.filter { !Set($0.types).isDisjoint(with: selectedTypes) }
        }

        return result
    }

    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isFiltering: Bool { !selectedTypes.isEmpty }

    var isSearchingOrFiltering: Bool { isSearching || isFiltering }

    /// Returns true if the given Pokémon is already on the team —
    /// either it was a member when the picker opened, or it was
    /// added during the current session.
    func isAlreadyOnTeam(pokemonID: Int) -> Bool {
        currentMemberIDs.contains(pokemonID) || addedInSession.contains(pokemonID)
    }

    // MARK: - Intent

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            allPokemon = try await pokemonRepository.fetchAllPokemon()
            let allTypes = allPokemon.flatMap(\.types)
            availableTypes = Array(Set(allTypes)).sorted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleType(_ type: String) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    func clearTypeFilters() {
        selectedTypes.removeAll()
    }

    /// Adds the selected Pokémon to the team.
    /// On success the button changes to a checkmark immediately (via `addedInSession`).
    /// The actual SwiftData write happens here — no separate "Save" step is needed.
    func addPokemon(_ pokemon: Pokemon) async {
        // Clear any previous error so the user sees fresh feedback.
        errorMessage = nil
        let member = TeamMember(
            id: UUID(),
            pokemonID: pokemon.id,
            name: pokemon.name,
            spriteURL: pokemon.spriteURL,
            types: pokemon.types,
            slot: 0   // TeamRepositoryImpl assigns the real slot based on count
        )
        do {
            try await teamRepository.addMember(member, toTeamID: teamID)
            // Mark as added so the row shows a checkmark without re-fetching.
            addedInSession.insert(pokemon.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns true if the team is full based on the initial member count
    /// plus the Pokémon added during this session.
    var isTeamFull: Bool {
        (currentMemberIDs.count + addedInSession.count) >= 6
    }

    func clearError() {
        errorMessage = nil
    }

    func retry() async {
        allPokemon = []
        await load()
    }
}
