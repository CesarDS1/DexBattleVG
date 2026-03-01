//
//  TeamRepository.swift
//  PokeDexBattle — Domain Layer
//
//  Defines the contract for all team CRUD operations.
//  Intentionally separate from `PokemonRepository`:
//   - PokemonRepository is read-only and wraps a remote API.
//   - TeamRepository is read-write and wraps a local user data store.
//  The Presentation layer depends on this protocol only — never on the
//  concrete `TeamRepositoryImpl` in the Data layer.
//

import Foundation

/// Async repository contract for team management operations.
///
/// Conforming types live in the Data layer and handle SwiftData persistence.
/// All methods are `async throws` for consistency, even though current
/// implementations are local-only (no network calls involved).
protocol TeamRepository {
    /// Returns all saved teams sorted by creation date (oldest first).
    func fetchAllTeams() async throws -> [PokemonTeam]

    /// Creates a new empty team with the given name and returns it.
    /// - Parameter name: The user-defined display name for the team.
    func createTeam(name: String) async throws -> PokemonTeam

    /// Renames an existing team.
    /// - Parameters:
    ///   - id: The UUID of the team to rename.
    ///   - newName: The replacement display name.
    func renameTeam(id: UUID, newName: String) async throws

    /// Permanently deletes a team and all of its members.
    /// - Parameter id: The UUID of the team to delete.
    func deleteTeam(id: UUID) async throws

    /// Adds a Pokémon to a team.
    /// - Parameters:
    ///   - member: The `TeamMember` snapshot to insert.
    ///   - teamID: The UUID of the target team.
    /// - Throws: `TeamError.teamFull` if the team already has six members.
    ///           `TeamError.duplicate` if the Pokémon is already on the team.
    func addMember(_ member: TeamMember, toTeamID teamID: UUID) async throws

    /// Removes a member from a team by its slot index.
    /// - Parameters:
    ///   - slot: The zero-based slot index of the member to remove.
    ///   - teamID: The UUID of the team.
    func removeMember(slot: Int, fromTeamID teamID: UUID) async throws
}

// MARK: - Domain errors

/// Errors specific to the Team Builder domain.
enum TeamError: LocalizedError {
    /// Attempted to add a seventh Pokémon to an already full team.
    case teamFull
    /// The Pokémon is already a member of this team.
    case duplicate
    /// The referenced team does not exist in the store.
    case teamNotFound

    var errorDescription: String? {
        switch self {
        case .teamFull:
            return String(localized: "team.error.full",
                          defaultValue: "This team already has 6 Pokémon.")
        case .duplicate:
            return String(localized: "team.error.duplicate",
                          defaultValue: "This Pokémon is already on the team.")
        case .teamNotFound:
            return String(localized: "team.error.notFound",
                          defaultValue: "Team not found.")
        }
    }
}
