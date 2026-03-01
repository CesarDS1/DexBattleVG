//
//  FavoritesRepositoryImpl.swift
//  PokeDexBattle — Data Layer
//
//  Concrete `FavoritesRepository` backed by a SwiftData table (`CachedFavoritePokemon`).
//  Each method creates its own `ModelContext` — the same per-operation pattern used by
//  `PokemonRepositoryImpl` — to keep contexts short-lived and thread-safe.
//
//  Favourites are intentionally decoupled from the Pokédex cache:
//  calling `clearAllCache()` (pull-to-refresh) never removes the user's favourites.
//

import Foundation
import SwiftData

/// SwiftData-backed implementation of `FavoritesRepository`.
final class FavoritesRepositoryImpl: FavoritesRepository {

    nonisolated init() {}

    // MARK: - FavoritesRepository

    /// Fetches all favourited Pokédex IDs in a single SwiftData query.
    func fetchFavoriteIDs() async -> Set<Int> {
        let ctx = ModelContext(AppContainer.shared)
        let descriptor = FetchDescriptor<CachedFavoritePokemon>()
        let rows = (try? ctx.fetch(descriptor)) ?? []
        return Set(rows.map(\.pokemonID))
    }

    /// Returns `true` if the given ID is in the favourites table.
    func isFavorite(pokemonID: Int) async -> Bool {
        let ctx = ModelContext(AppContainer.shared)
        var descriptor = FetchDescriptor<CachedFavoritePokemon>(
            predicate: #Predicate { $0.pokemonID == pokemonID }
        )
        descriptor.fetchLimit = 1
        return (try? ctx.fetch(descriptor).first) != nil
    }

    /// Inserts a new `CachedFavoritePokemon` row.
    /// `@Attribute(.unique)` on `pokemonID` means SwiftData silently replaces
    /// any existing row with the same ID, so this is safe to call even if already present.
    func addFavorite(pokemonID: Int) async {
        let ctx = ModelContext(AppContainer.shared)
        ctx.insert(CachedFavoritePokemon(pokemonID: pokemonID))
        try? ctx.save()
    }

    /// Deletes the matching row if it exists; silently succeeds if not found.
    func removeFavorite(pokemonID: Int) async {
        let ctx = ModelContext(AppContainer.shared)
        var descriptor = FetchDescriptor<CachedFavoritePokemon>(
            predicate: #Predicate { $0.pokemonID == pokemonID }
        )
        descriptor.fetchLimit = 1
        guard let row = try? ctx.fetch(descriptor).first else { return }
        ctx.delete(row)
        try? ctx.save()
    }
}
