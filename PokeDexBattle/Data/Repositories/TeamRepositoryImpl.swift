//
//  TeamRepositoryImpl.swift
//  PokeDexBattle — Data Layer
//
//  Concrete implementation of `TeamRepository` backed by SwiftData.
//  All reads and writes go directly to the local store — there is no
//  network source for team data.
//
//  Follows the same ModelContext-per-operation pattern used throughout
//  `PokemonRepositoryImpl`: each method creates its own context to stay
//  thread-safe across Swift concurrency task boundaries.
//

import Foundation
import SwiftData

/// Concrete `TeamRepository` that persists team data in SwiftData.
final class TeamRepositoryImpl: TeamRepository {

    nonisolated init() {}

    // MARK: - TeamRepository

    /// Returns all saved teams sorted by creation date (oldest first),
    /// each with their members sorted by slot.
    func fetchAllTeams() async throws -> [PokemonTeam] {
        let ctx = ModelContext(AppContainer.shared)

        let teamDescriptor = FetchDescriptor<CachedTeam>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let cachedTeams = try ctx.fetch(teamDescriptor)

        return cachedTeams.map { cached in
            // Extract to a plain local variable — #Predicate cannot capture
            // a property of another SwiftData @Model object directly.
            let cid = cached.id
            let memberDescriptor = FetchDescriptor<CachedTeamMember>(
                predicate: #Predicate { $0.teamID == cid },
                sortBy: [SortDescriptor(\.slot)]
            )
            let cachedMembers = (try? ctx.fetch(memberDescriptor)) ?? []
            return domainTeam(from: cached, members: cachedMembers)
        }
    }

    /// Creates a new empty team with the given name.
    func createTeam(name: String) async throws -> PokemonTeam {
        let newID = UUID()
        let now = Date.now
        let ctx = ModelContext(AppContainer.shared)
        ctx.insert(CachedTeam(id: newID, name: name, createdAt: now))
        try ctx.save()
        return PokemonTeam(id: newID, name: name, members: [], createdAt: now)
    }

    /// Renames an existing team. Throws `TeamError.teamNotFound` if the team is missing.
    func renameTeam(id: UUID, newName: String) async throws {
        let ctx = ModelContext(AppContainer.shared)
        let descriptor = FetchDescriptor<CachedTeam>(
            predicate: #Predicate { $0.id == id }
        )
        guard let team = try ctx.fetch(descriptor).first else {
            throw TeamError.teamNotFound
        }
        team.name = newName
        try ctx.save()
    }

    /// Deletes a team and all of its member records.
    func deleteTeam(id: UUID) async throws {
        let ctx = ModelContext(AppContainer.shared)

        // Delete team record
        let teamDescriptor = FetchDescriptor<CachedTeam>(
            predicate: #Predicate { $0.id == id }
        )
        if let team = try ctx.fetch(teamDescriptor).first {
            ctx.delete(team)
        }

        // Delete all member records (manual cascade — no @Relationship used)
        let memberDescriptor = FetchDescriptor<CachedTeamMember>(
            predicate: #Predicate { $0.teamID == id }
        )
        let members = try ctx.fetch(memberDescriptor)
        for member in members { ctx.delete(member) }

        try ctx.save()
    }

    /// Adds a Pokémon to the specified team.
    /// - Throws: `TeamError.teamFull` or `TeamError.duplicate` when applicable.
    func addMember(_ member: TeamMember, toTeamID teamID: UUID) async throws {
        let ctx = ModelContext(AppContainer.shared)

        // Validate team exists
        let teamDescriptor = FetchDescriptor<CachedTeam>(
            predicate: #Predicate { $0.id == teamID }
        )
        guard try ctx.fetch(teamDescriptor).first != nil else {
            throw TeamError.teamNotFound
        }

        // Fetch current members to validate count and duplicates
        let memberDescriptor = FetchDescriptor<CachedTeamMember>(
            predicate: #Predicate { $0.teamID == teamID }
        )
        let existing = try ctx.fetch(memberDescriptor)

        guard existing.count < 6 else { throw TeamError.teamFull }
        guard !existing.contains(where: { $0.pokemonID == member.pokemonID }) else {
            throw TeamError.duplicate
        }

        let slot = existing.count           // next available slot
        let cached = CachedTeamMember(
            id: UUID(),
            teamID: teamID,
            pokemonID: member.pokemonID,
            name: member.name,
            spriteURLString: member.spriteURL?.absoluteString,
            types: member.types,
            slot: slot
        )
        ctx.insert(cached)
        try ctx.save()
    }

    /// Removes the member at `slot` from the team and reorders remaining members.
    func removeMember(slot: Int, fromTeamID teamID: UUID) async throws {
        let ctx = ModelContext(AppContainer.shared)

        let descriptor = FetchDescriptor<CachedTeamMember>(
            predicate: #Predicate { $0.teamID == teamID },
            sortBy: [SortDescriptor(\.slot)]
        )
        var members = try ctx.fetch(descriptor)

        guard let index = members.firstIndex(where: { $0.slot == slot }) else { return }
        ctx.delete(members[index])
        members.remove(at: index)

        // Reindex remaining members so slots stay contiguous
        for (newSlot, remaining) in members.enumerated() {
            remaining.slot = newSlot
        }
        try ctx.save()
    }

    // MARK: - Mapping helpers

    private func domainTeam(from cached: CachedTeam,
                            members: [CachedTeamMember]) -> PokemonTeam {
        PokemonTeam(
            id: cached.id,
            name: cached.name,
            members: members.map { domainMember(from: $0) },
            createdAt: cached.createdAt
        )
    }

    private func domainMember(from cached: CachedTeamMember) -> TeamMember {
        TeamMember(
            id: cached.id,
            pokemonID: cached.pokemonID,
            name: cached.name,
            spriteURL: cached.spriteURLString.flatMap(URL.init),
            types: cached.types,
            slot: cached.slot
        )
    }
}
