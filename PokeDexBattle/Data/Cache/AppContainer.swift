//
//  AppContainer.swift
//  PokeDexBattle — Data Layer / Cache
//
//  Singleton `ModelContainer` shared across the entire app.
//  Lives in the Data layer so that Presentation and Domain layers
//  never need to import SwiftData directly.
//
//  Usage:
//    - App entry point:  `.modelContainer(AppContainer.shared)`
//    - Repository reads: `ModelContext(AppContainer.shared)`
//

import SwiftData

/// Namespace that vends the shared `ModelContainer` for all SwiftData cache models.
enum AppContainer {
    /// The single `ModelContainer` for the app.
    /// Initialised lazily on first access; force-unwrapped because a schema
    /// error is a developer mistake, not a runtime condition.
    static let shared: ModelContainer = {
        let schema = Schema([
            CachedPokemon.self,
            CachedPokemonDetail.self,
            CachedPokemonMove.self,
            CachedEvolutionNode.self,
            CachedPokemonForm.self,
            CachedTeam.self,
            CachedTeamMember.self,
            CachedFavoritePokemon.self,
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("SwiftData ModelContainer init failed: \(error)")
        }
    }()
}
