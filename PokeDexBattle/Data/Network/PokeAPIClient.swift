//
//  PokeAPIClient.swift
//  PokeDexBattle — Data Layer
//
//  Low-level HTTP client that wraps `URLSession` and decodes JSON responses
//  into DTO types. This class knows nothing about domain entities or UI —
//  it only fetches raw data and deserialises it.
//
//  All public methods are `async throws` and delegate to a single private
//  generic `fetch<T>` method that handles logging, timing, and error propagation.
//

import Foundation

/// Stateless HTTP client for the PokeAPI v2 (`https://pokeapi.co/api/v2`).
/// Inject a custom `URLSession` (e.g. with a `URLProtocol` stub) for unit testing.
final class PokeAPIClient {
    private let baseURL = "https://pokeapi.co/api/v2"
    /// The underlying `URLSession` used for all network requests.
    private let session: URLSession

    /// Creates a new client.
    /// - Parameter session: The URLSession to use. Defaults to `.shared`.
    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Fetches every Pokémon in the National Pokédex in two network calls:
    /// 1. A lightweight call with `limit=1` to read the total `count` from the API.
    /// 2. A second call with `limit=count` to retrieve all entries at once.
    ///
    /// This avoids hard-coding the total count and adapts automatically when
    /// new Pokémon are added to the API.
    /// - Returns: A `PokemonListResponseDTO` whose `results` array contains all entries.
    /// - Throws: `URLError` or `DecodingError` on failure.
    func fetchAllPokemon() async throws -> PokemonListResponseDTO {
        let countDTO: PokemonListResponseDTO = try await fetch(
            url: try makeURL(path: "/pokemon", queryItems: [.init(name: "limit", value: "1")])
        )
        let url = try makeURL(path: "/pokemon", queryItems: [
            .init(name: "limit",  value: "\(countDTO.count)"),
            .init(name: "offset", value: "0")
        ])
        return try await fetch(url: url)
    }

    /// Fetches full detail for a single Pokémon from `/pokemon/{id}` or `/pokemon/{name}`.
    /// When `name` is provided it takes precedence over `id` (used for evolution chain resolution).
    /// - Parameters:
    ///   - id: The National Pokédex number. Ignored when `name` is non-empty.
    ///   - name: Lowercase hyphenated species name (e.g. "ivysaur"). Defaults to `""`.
    /// - Returns: A fully populated `PokemonDetailDTO`.
    /// - Throws: `URLError` or `DecodingError` on failure.
    func fetchPokemonDetail(id: Int, name: String = "") async throws -> PokemonDetailDTO {
        let slug = name.isEmpty ? "\(id)" : name
        let url  = try makeURL(path: "/pokemon/\(slug)")
        return try await fetch(url: url)
    }

    /// Fetches detailed information for a single move from `/move/{id}`.
    /// Called concurrently for all level-up moves by `PokemonRepositoryImpl.fetchMoves`.
    /// - Parameter id: The move's unique ID from the API.
    /// - Returns: A fully populated `MoveDetailDTO`.
    /// - Throws: `URLError` or `DecodingError` on failure.
    func fetchMoveDetail(id: Int) async throws -> MoveDetailDTO {
        let url = try makeURL(path: "/move/\(id)")
        return try await fetch(url: url)
    }

    /// Fetches species information for a Pokémon from `/pokemon-species/{id}`.
    /// Contains the evolution chain URL and the list of alternate varieties (forms).
    /// - Parameter id: The National Pokédex number.
    /// - Returns: A `PokemonSpeciesDTO` with chain reference and varieties.
    /// - Throws: `URLError` or `DecodingError` on failure.
    func fetchSpecies(id: Int) async throws -> PokemonSpeciesDTO {
        let url = try makeURL(path: "/pokemon-species/\(id)")
        return try await fetch(url: url)
    }

    /// Fetches the full evolution chain from `/evolution-chain/{id}`.
    /// - Parameter id: The chain ID (extracted from the species response URL).
    /// - Returns: A recursive `EvolutionChainDTO` rooted at the base form.
    /// - Throws: `URLError` or `DecodingError` on failure.
    func fetchEvolutionChain(id: Int) async throws -> EvolutionChainDTO {
        let url = try makeURL(path: "/evolution-chain/\(id)")
        return try await fetch(url: url)
    }

    // MARK: - Private helpers

    /// Builds a `URL` by appending `path` to `baseURL` and optionally attaching query items.
    /// - Parameters:
    ///   - path: The API path segment (e.g. "/pokemon/1").
    ///   - queryItems: Optional query parameters (e.g. limit, offset).
    /// - Returns: A fully formed `URL`.
    /// - Throws: `URLError(.badURL)` if URL construction fails.
    private func makeURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents(string: baseURL + path)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return url
    }

    /// Generic HTTP GET that logs the request, awaits the response, logs the result,
    /// validates the status code, and decodes the JSON body into `T`.
    ///
    /// - Parameter url: The fully constructed URL to fetch.
    /// - Returns: An instance of `T` decoded from the response body.
    /// - Throws:
    ///   - `URLError` if the session throws (no connectivity, timeout, etc.)
    ///   - `URLError(.badServerResponse)` for non-2xx HTTP status codes.
    ///   - `DecodingError` if JSON decoding fails.
    private func fetch<T: Decodable>(url: URL) async throws -> T {
        NetworkLogger.logRequest(url)
        let start = Date()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            NetworkLogger.logError(url, error: error, duration: Date().timeIntervalSince(start))
            throw error
        }

        let duration   = Date().timeIntervalSince(start)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        NetworkLogger.logResponse(url, statusCode: statusCode, byteCount: data.count, duration: duration)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
