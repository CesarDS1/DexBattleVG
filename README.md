# PokeDexBattle

A native iOS Pokédex app built with **SwiftUI** and **Swift**, consuming the public [PokeAPI v2](https://pokeapi.co/).
Fully localized in **English and Spanish** — UI strings, Pokédex descriptions, move effects, and evolution triggers all adapt to the device language automatically.

---

## Features

- **Full Pokédex** — loads all 1 025 base-species Pokémon (IDs 1–1025) concurrently in a single fetch session
- **Live search** — instantly filters the entire list by name as you type
- **Type filter** — filter the list by one or more elemental types simultaneously
- **Generation groups** — list is sectioned by generation (I–IX) with collapsible headers
- **Pull-to-refresh** — clears the SwiftData cache and re-fetches everything from the network
- **Detail screen** — high-resolution official artwork (475×475+), type badges, Pokédex entry description, colour-coded base stat bars, and a defensive type-matchup chart
- **Moves by level** — full list of level-up moves with power, accuracy, PP, damage class, type badge, and a localized short effect description
- **Evolutions** — full evolution chain rendered as a branching tree; tap any stage to navigate directly to that Pokémon's detail screen
- **Forms & Variants** — alternate forms and regional variants (Mega, Alolan, Gigantamax, etc.); tap any form to navigate to its detail screen
- **Type matchup chart** — defensive effectiveness (weak / resistant / immune) computed in-memory from a built-in type chart, no API call needed
- **SwiftData cache** — cache-first strategy across all 5 data types; subsequent launches are instant
- **Localization** — English and Spanish throughout: UI strings via `Localizable.xcstrings`, PokeAPI text (descriptions, move effects) cached per language and served by device locale, evolution trigger strings via `String(localized:)`
- **Network logging** — every HTTP request and response is printed to the Xcode console with timestamp, status code, payload size, and duration

---

## Screenshots

| Pokédex List | Detail — About | Moves by Level | Evolutions |
|---|---|---|---|
| Searchable, filterable list grouped by generation | Artwork, types, Pokédex entry, stat bars, matchup | Level-up moves with localized effect descriptions | Branching evolution chain, tap to navigate |

---

## Architecture

The app follows **Clean Architecture** with **MVVM** in the Presentation layer.

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                     │
│  PokemonListView / ViewModel                        │
│  PokemonDetailView / ViewModel                      │
│  MovesView / MovesViewModel                         │
│  EvolutionsView / EvolutionsViewModel               │
│  FormsView / FormsViewModel                         │
│  TypeMatchupView / TypeChart                        │
│  Shared / LocalizationHelper                        │
└──────────────────────┬──────────────────────────────┘
                       │ depends on
┌──────────────────────▼──────────────────────────────┐
│                      Domain                         │
│  Pokemon, PokemonDetail, PokemonMove,               │
│  EvolutionStage, PokemonForm  (value types)         │
│  PokemonRepository  (protocol)                      │
└──────────────────────▲──────────────────────────────┘
                       │ implements
┌──────────────────────┴──────────────────────────────┐
│                       Data                          │
│  PokemonRepositoryImpl  (cache-first)               │
│  PokeAPIClient  (URLSession)                        │
│  NetworkLogger                                      │
│  PokemonDTO / MoveDetailDTO / PokemonSpeciesDTO /   │
│  EvolutionChainDTO                                  │
│  CachedPokemon / CachedPokemonDetail /              │
│  CachedPokemonMove / CachedEvolutionNode /          │
│  CachedPokemonForm  (SwiftData models)              │
│  AppContainer  (singleton ModelContainer)           │
└─────────────────────────────────────────────────────┘
```

**Dependency rule:** arrows point inward only. The Domain layer has no external dependencies.

---

## Tech stack

| Technology | Usage |
|---|---|
| SwiftUI | All UI — declarative, no UIKit |
| Swift Concurrency (`async/await`, `withThrowingTaskGroup`) | All network calls; parallel fetching of moves, evolution stages, and forms |
| `@Observable` (Swift Observation) | ViewModels — replaces `ObservableObject`/`@Published` |
| SwiftData | On-device cache — 5 model types, cache-first pattern |
| URLSession | HTTP client |
| PokeAPI v2 | Data source (`https://pokeapi.co/api/v2`) |
| `Localizable.xcstrings` | Modern Xcode 15+ string catalog with `en` + `es` translations |

---

## Requirements

- **Xcode** 26.0.1 or later
- **iOS** 26.0+ (Simulator or device)
- **Swift** 5.9+
- Internet connection on first launch (subsequent launches served from SwiftData cache)

---

## Getting started

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd PokeDexBattle
   ```

2. Open the project in Xcode:
   ```bash
   open PokeDexBattle.xcodeproj
   ```

3. Select an iOS 26 Simulator and press **⌘R** to run.

### Build from Terminal

```bash
xcodebuild \
  -project PokeDexBattle.xcodeproj \
  -scheme PokeDexBattle \
  -destination 'platform=iOS Simulator,arch=arm64,id=D731B82A-BE5B-45DA-9FEA-7B432E7B30AC' \
  build
```

---

## Project structure

```
PokeDexBattle/
├── Domain/
│   ├── Entities/
│   │   └── Pokemon.swift              # Pokemon, PokemonDetail, PokemonMove,
│   │                                  # EvolutionStage, PokemonForm
│   └── Repositories/
│       └── PokemonRepository.swift    # Protocol — the only API Presentation sees
│
├── Data/
│   ├── DTOs/
│   │   └── PokemonDTO.swift           # Decodable structs matching PokeAPI JSON
│   ├── Network/
│   │   ├── PokeAPIClient.swift        # URLSession wrapper (generic fetch<T>)
│   │   └── NetworkLogger.swift        # Console request / response logger
│   ├── Cache/
│   │   ├── AppContainer.swift         # Singleton ModelContainer
│   │   ├── CachedPokemon.swift        # SwiftData — list entry
│   │   ├── CachedPokemonDetail.swift  # SwiftData — full detail (en + es descriptions)
│   │   ├── CachedPokemonMove.swift    # SwiftData — level-up move (en + es effects)
│   │   ├── CachedEvolutionNode.swift  # SwiftData — flattened evolution tree node
│   │   └── CachedPokemonForm.swift    # SwiftData — alternate form / variant
│   └── Repositories/
│       └── PokemonRepositoryImpl.swift  # Cache-first; maps DTOs → Domain entities
│
├── Presentation/
│   ├── PokemonList/                   # Pokédex list, search, type filter, gen groups
│   ├── PokemonDetail/                 # Artwork, types, description, stats, matchup tabs
│   ├── PokemonMoves/                  # Level-up moves with localized effect descriptions
│   ├── PokemonEvolutions/             # Branching evolution chain; tap to navigate
│   ├── PokemonForms/                  # Alternate forms / regional variants; tap to navigate
│   ├── TypeMatchup/                   # Defensive type effectiveness chart
│   └── Shared/
│       └── LocalizationHelper.swift   # localizedTypeName / localizedStatName /
│                                      # localizedDamageClass / localizedGenerationLabel
│
├── Localizable.xcstrings              # String catalog — en + es (Xcode 15+ format)
├── ContentView.swift                  # Entry point → PokemonListView
└── PokeDexBattleApp.swift             # @main — attaches ModelContainer
```

---

## API endpoints used

| Endpoint | Purpose |
|---|---|
| `GET /pokemon?limit=1` | Read total Pokémon count |
| `GET /pokemon?limit={count}&offset=0` | Fetch all Pokémon names + IDs |
| `GET /pokemon/{id}` | Fetch detail (types, stats, sprites, move list) |
| `GET /pokemon-species/{id}` | Fetch flavor-text description (en + es) and variety list |
| `GET /move/{id}` | Fetch move detail (power, accuracy, PP, effect in en + es) |
| `GET /evolution-chain/{id}` | Fetch full evolution chain tree |

Sprites and official artwork are loaded from the GitHub-hosted CDN:
- Sprite: `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/{id}.png`
- Artwork: `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{id}.png`

---

## Localization

The app is fully localized in **English** and **Spanish**.

| Content | Strategy |
|---|---|
| UI strings | `Localizable.xcstrings` — `String(localized: "key")` everywhere |
| Type names, stat names, damage classes, generation labels | `LocalizationHelper.swift` — switch-based mapping from PokeAPI English identifiers to `String(localized:)` keys |
| Pokédex descriptions | Fetched in both `en` and `es` from `/pokemon-species/{id}`, cached separately in SwiftData, served by `Locale.current` at read time |
| Move effect descriptions | Fetched in both `en` and `es` from `/move/{id}`, cached separately in SwiftData, served by `Locale.current` at read time |
| Evolution trigger strings | Constructed in-app via `String(localized: "evo.*")` keys in `Localizable.xcstrings` |

### Adding a new language

1. Add the language in Xcode → Project → Info → Localizations.
2. Add translations to `Localizable.xcstrings`.
3. Extend the `switch` statements in `LocalizationHelper.swift`.
4. Add the new language code to the `supported` array in `PokemonRepositoryImpl.apiLanguageCode`.
5. Add new cache columns (e.g. `descriptionTextDe`) in `CachedPokemonDetail` and `CachedPokemonMove`.

---

## SwiftData cache

Five `@Model` types are registered in a single `ModelContainer` (via `AppContainer.shared`):

| Model | Cached data |
|---|---|
| `CachedPokemon` | ID, name, sprite URL, types |
| `CachedPokemonDetail` | Full detail + English and Spanish Pokédex description |
| `CachedPokemonMove` | Move stats + English and Spanish short-effect description |
| `CachedEvolutionNode` | Flattened evolution tree node (reconstructed into a tree at read time) |
| `CachedPokemonForm` | Alternate form metadata |

All 5 caches are wiped by pull-to-refresh (`PokemonListViewModel.refreshAll()`), triggering a full re-fetch from the network.

---

## Contributing

1. Follow the existing Clean Architecture layering — no shortcuts across layers.
2. New screens follow the `ViewModel + View` pattern in their own folder under `Presentation/`.
3. Domain entities must stay free of framework imports (Foundation only).
4. All user-visible strings must use `String(localized:)` and have entries in `Localizable.xcstrings` for both `en` and `es`.
5. Any new PokeAPI text content (multi-language arrays) must cache both `en` and `es` raw strings in SwiftData and use `localizedText(en:es:)` at read time.
6. Run a clean build before submitting: `xcodebuild clean build`.

---

## License

This project is for educational purposes. Pokémon and all related names are trademarks of Nintendo / Game Freak.
Pokémon data is provided by [PokéAPI](https://pokeapi.co/) under the [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) licence.
