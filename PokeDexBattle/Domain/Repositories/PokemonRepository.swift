//
//  PokemonRepository.swift
//  PokeDexBattle — Domain Layer
//
//  Defines the contract between the Presentation and Data layers.
//  The Presentation layer depends only on this protocol — it never
//  imports or references `PokemonRepositoryImpl` or any Data type directly.
//  This inversion of control enables easy unit testing via mock implementations.
//

/// Async repository contract for all Pokémon data operations.
/// Conforming types (e.g. `PokemonRepositoryImpl`) live in the Data layer
/// and handle network fetching, DTO mapping, and caching.
protocol PokemonRepository {
    /// Fetches the complete National Pokédex in a single network operation.
    /// Returns every Pokémon entry (currently 1 350+) sorted by Pokédex number.
    /// - Throws: A `URLError` or decoding error if the request fails.
    func fetchAllPokemon() async throws -> [Pokemon]

    /// Fetches full details for a single Pokémon by its National Pokédex ID.
    /// - Parameter id: The National Pokédex number (1-based).
    /// - Throws: A `URLError` or decoding error if the request fails.
    func fetchPokemonDetail(id: Int) async throws -> PokemonDetail

    /// Fetches all moves a Pokémon can learn by levelling up, sorted by level then name.
    /// Move details are retrieved concurrently for performance.
    /// - Parameter pokemonID: The National Pokédex number of the Pokémon.
    /// - Throws: A `URLError` or decoding error if any request fails.
    func fetchMoves(for pokemonID: Int) async throws -> [PokemonMove]

    /// Fetches the full evolution chain for a Pokémon species and returns it as a
    /// recursive `EvolutionStage` tree rooted at the base form.
    /// Requires two sequential API calls: species (to get the chain URL) → chain.
    /// - Parameter pokemonID: The National Pokédex number of any Pokémon in the chain.
    /// - Throws: A `URLError` or decoding error if any request fails.
    func fetchEvolutionChain(for pokemonID: Int) async throws -> EvolutionStage

    /// Fetches all alternate forms and regional variants for a Pokémon species.
    /// The default form is included so the caller can display it alongside alternates.
    /// Each form requires its own `/pokemon/{id}` call (fetched concurrently).
    /// - Parameter pokemonID: The National Pokédex number of the base Pokémon.
    /// - Throws: A `URLError` or decoding error if any request fails.
    func fetchForms(for pokemonID: Int) async throws -> [PokemonForm]

    /// Deletes all locally cached data so the next fetch goes to the network.
    /// Called when the user pulls to refresh the Pokédex list.
    /// A default no-op implementation is provided for previews and mock repositories.
    func clearAllCache() async
}

extension PokemonRepository {
    /// Default no-op so existing conformances (mocks, previews) don't need to implement this.
    func clearAllCache() async { }
}
