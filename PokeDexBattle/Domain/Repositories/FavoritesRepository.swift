//
//  FavoritesRepository.swift
//  PokeDexBattle — Domain Layer
//
//  Defines the contract for persisting and querying the user's favourite Pokémon.
//  The Presentation layer depends only on this protocol; the concrete SwiftData
//  implementation lives in `FavoritesRepositoryImpl` in the Data layer.
//

import Foundation

/// Read/write interface for the user's favourite Pokémon set.
///
/// All methods are `async` to allow the concrete implementation to
/// perform any I/O (SwiftData, network, etc.) without blocking the caller.
protocol FavoritesRepository {
    /// Returns the set of National Pokédex IDs currently marked as favourites.
    func fetchFavoriteIDs() async -> Set<Int>

    /// Returns `true` if the given Pokémon is currently a favourite.
    func isFavorite(pokemonID: Int) async -> Bool

    /// Adds the given Pokémon to favourites. No-ops if already present.
    func addFavorite(pokemonID: Int) async

    /// Removes the given Pokémon from favourites. No-ops if not present.
    func removeFavorite(pokemonID: Int) async
}
