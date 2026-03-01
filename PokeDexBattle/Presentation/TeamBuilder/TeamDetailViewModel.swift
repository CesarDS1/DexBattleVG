//
//  TeamDetailViewModel.swift
//  PokeDexBattle — Presentation Layer
//
//  Manages the state of a single team detail screen:
//  member list, remove/rename operations, and the rename alert.
//

import Foundation

@MainActor @Observable
final class TeamDetailViewModel {

    // MARK: - State

    private(set) var team: PokemonTeam
    private(set) var errorMessage: String?
    private(set) var isDeleting = false

    // MARK: - Private

    private let repository: TeamRepository

    // MARK: - Init

    init(team: PokemonTeam,
         repository: TeamRepository = TeamRepositoryImpl()) {
        self.team = team
        self.repository = repository
    }

    // MARK: - Intent

    /// Reloads team data from the store to reflect any external changes.
    func reload() async {
        do {
            let all = try await repository.fetchAllTeams()
            if let updated = all.first(where: { $0.id == team.id }) {
                team = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes the member at the given slot and reloads.
    func removeMember(slot: Int) async {
        do {
            try await repository.removeMember(slot: slot, fromTeamID: team.id)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Renames the team and reloads.
    func renameTeam(newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await repository.renameTeam(id: team.id, newName: trimmed)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes the entire team. Callers should dismiss the view on success.
    func deleteTeam() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await repository.deleteTeam(id: team.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
