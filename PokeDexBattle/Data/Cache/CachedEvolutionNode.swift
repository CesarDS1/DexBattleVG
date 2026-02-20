//
//  CachedEvolutionNode.swift
//  PokeDexBattle — Data Layer / Cache
//
//  SwiftData model for one node in an evolution chain.
//
//  Because `@Model` classes cannot be self-referencing (recursive), the
//  `EvolutionStage` tree is flattened into rows. Each row carries:
//    - `ownerPokemonID` — the Pokédex ID that was originally queried
//    - `nodeID`         — the Pokédex ID of this particular stage
//    - `parentID`       — the nodeID of the parent stage (nil = root / base form)
//
//  On read, the rows are reconstructed into the recursive `EvolutionStage` tree
//  by `PokemonRepositoryImpl.buildEvolutionTree(from:rootParentID:ownerID:)`.
//

import SwiftData
import Foundation

/// Flattened persistent row representing one stage in an evolution chain.
@Model
final class CachedEvolutionNode {
    /// Pokédex ID of the Pokémon whose chain this node belongs to.
    var ownerPokemonID: Int
    /// Pokédex ID of this evolution stage (e.g. 5 for Charmeleon).
    var nodeID: Int
    var name: String
    /// Absolute URL string for the stage's sprite.
    var spriteURLString: String?
    /// Human-readable evolution trigger (e.g. "Level 36", "Use Fire Stone").
    var trigger: String
    /// `nodeID` of the parent stage; `nil` for the root / base form.
    var parentID: Int?

    init(
        ownerPokemonID: Int,
        nodeID: Int,
        name: String,
        spriteURLString: String?,
        trigger: String,
        parentID: Int?
    ) {
        self.ownerPokemonID = ownerPokemonID
        self.nodeID = nodeID
        self.name = name
        self.spriteURLString = spriteURLString
        self.trigger = trigger
        self.parentID = parentID
    }
}
