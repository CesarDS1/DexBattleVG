//
//  TeamListViewModel.swift
//  PokeDexBattle — Presentation Layer
//
//  Manages the list of user-created teams: loading, creating, and deleting.
//  Follows the same @MainActor @Observable pattern used throughout the app.
//

import Foundation

@MainActor @Observable
final class TeamListViewModel {

    // MARK: - State (read-only to Views)

    private(set) var teams: [PokemonTeam] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // MARK: - Private

    private let repository: TeamRepository
    private var hasLoaded = false

    // MARK: - Init

    nonisolated init(repository: TeamRepository = TeamRepositoryImpl()) {
        self.repository = repository
    }

    // MARK: - Intent

    /// Loads all teams from the store. Guards against duplicate in-flight calls.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            teams = try await repository.fetchAllTeams()
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Creates a new empty team with `name` and reloads the list.
    func createTeam(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await repository.createTeam(name: trimmed)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes teams at the given offsets in the current `teams` array.
    func deleteTeams(at offsets: IndexSet) async {
        for index in offsets {
            let team = teams[index]
            do {
                try await repository.deleteTeam(id: team.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        await load()
    }

    func retry() async {
        hasLoaded = false
        await load()
    }
}
