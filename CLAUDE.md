# CLAUDE.md — PokeDexBattle

This file tells Claude Code everything it needs to know to work on this project autonomously.

---

## Project overview

**PokeDexBattle** is a native iOS app built with SwiftUI and Swift 6.
It displays the full National Pokédex by consuming the public **PokeAPI v2** (`https://pokeapi.co/api/v2`).
The app is fully **localized in English and Spanish** — both the app UI strings and PokeAPI content (descriptions, move effects, evolution triggers) adapt to the device language automatically.

---

## Architecture

The project follows **Clean Architecture** with **MVVM** in the Presentation layer.
Dependency flow is strictly one-directional:

```
Presentation  →  Domain  ←  Data
```

- **Presentation** depends on Domain entities and the `PokemonRepository` protocol only.
- **Data** implements the protocol and maps DTOs to Domain entities.
- **Domain** has zero external dependencies — no framework imports except `Foundation`.

### Layer locations

| Layer        | Path                                           |
|--------------|------------------------------------------------|
| Domain       | `PokeDexBattle/Domain/`                        |
| Data         | `PokeDexBattle/Data/`                          |
| Presentation | `PokeDexBattle/Presentation/`                  |

---

## Folder structure

```
PokeDexBattle/
├── Domain/
│   ├── Entities/
│   │   └── Pokemon.swift              # Pokemon, PokemonDetail, PokemonMove, EvolutionStage, PokemonForm
│   └── Repositories/
│       └── PokemonRepository.swift    # Protocol — the only API the Presentation layer sees
│
├── Data/
│   ├── DTOs/
│   │   └── PokemonDTO.swift           # Decodable structs matching PokeAPI JSON
│   ├── Network/
│   │   ├── PokeAPIClient.swift        # URLSession wrapper with generic fetch<T>
│   │   └── NetworkLogger.swift        # Console logger (request / response / error)
│   ├── Cache/
│   │   ├── AppContainer.swift         # Singleton ModelContainer (SwiftData)
│   │   ├── CachedPokemon.swift        # SwiftData model — list entry
│   │   ├── CachedPokemonDetail.swift  # SwiftData model — full detail (en + es descriptions)
│   │   ├── CachedPokemonMove.swift    # SwiftData model — level-up move (en + es effects)
│   │   ├── CachedEvolutionNode.swift  # SwiftData model — flattened evolution tree node
│   │   └── CachedPokemonForm.swift    # SwiftData model — alternate form/variant
│   └── Repositories/
│       └── PokemonRepositoryImpl.swift  # Cache-first; maps DTOs → Domain entities
│
├── Presentation/
│   ├── PokemonList/
│   │   ├── PokemonListViewModel.swift
│   │   ├── PokemonListView.swift
│   │   └── PokemonRowView.swift
│   ├── PokemonDetail/
│   │   ├── PokemonDetailViewModel.swift
│   │   └── PokemonDetailView.swift
│   ├── PokemonMoves/
│   │   ├── MovesViewModel.swift
│   │   └── MovesView.swift
│   ├── PokemonEvolutions/
│   │   ├── EvolutionsViewModel.swift
│   │   └── EvolutionsView.swift
│   ├── PokemonForms/
│   │   ├── FormsViewModel.swift
│   │   └── FormsView.swift
│   ├── TypeMatchup/
│   │   ├── TypeChart.swift
│   │   └── TypeMatchupView.swift
│   └── Shared/
│       └── LocalizationHelper.swift   # localizedTypeName / localizedStatName / localizedDamageClass / localizedGenerationLabel
│
├── Localizable.xcstrings              # Single string catalog (en + es) — Xcode 15+ format
├── ContentView.swift                  # Entry point — renders PokemonListView
└── PokeDexBattleApp.swift             # @main app struct — attaches ModelContainer
```

---

## Key technical decisions

| Decision | Rationale |
|---|---|
| `@Observable` instead of `ObservableObject` | iOS 26 target; `@Observable` (Swift Observation framework) avoids the `Combine` import requirement |
| `@State` for `@Observable` class ViewModels | `@StateObject` is for `ObservableObject`; `@State` is correct for `@Observable` classes |
| Single `fetchAllPokemon()` call | Fetches count first, then all 1 025 base-species Pokémon (IDs 1–1025) concurrently — avoids pagination complexity and enables instant in-memory search |
| `withThrowingTaskGroup` for moves | Each Pokémon can have 30–80 level-up moves; concurrent fetching reduces latency from O(n) sequential to ~O(1) parallel |
| `nonisolated init` on Data layer classes | Prevents Swift 6 actor-isolation warnings when Data layer objects are created as default parameter values |
| SwiftData cache (5 model types) | Cache-first pattern: all 5 repository methods read SwiftData first, fall back to network on miss, write back on fetch. Pull-to-refresh calls `clearAllCache()` |
| Official artwork URL | Built statically: `https://raw.githubusercontent.com/PokeAPI/sprites/master/.../official-artwork/{id}.png` — no extra API call needed |
| Localization — UI strings | `Localizable.xcstrings` (Xcode 15+ catalog) with `en` + `es` entries; `LocalizationHelper.swift` maps PokeAPI identifiers (type names, stat names, damage classes, generation labels) to localized strings |
| Localization — PokeAPI content | `PokemonRepositoryImpl` fetches `en` and `es` entries from PokeAPI multi-language arrays (flavor text, move effects). Both are cached in SwiftData (`descriptionText`/`descriptionTextEs`, `shortEffect`/`shortEffectEs`). At read time, `apiLanguageCode` picks the right string based on `Locale.current`, falling back to English |
| Evolution trigger localization | `triggerDescription(_:)` in `PokemonRepositoryImpl` produces localized strings via `String(localized:)` keys (`evo.*`) defined in `Localizable.xcstrings` |

---

## Localization

### Supported languages
| Language | App UI | PokeAPI content |
|---|---|---|
| English (`en`) | ✅ | ✅ |
| Spanish (`es`) | ✅ | ✅ |

### How it works

**UI strings** — use `String(localized: "key")` everywhere. All keys live in `Localizable.xcstrings`.

**PokeAPI identifiers** (type names, stat names, damage classes, generation labels) — mapped in `Presentation/Shared/LocalizationHelper.swift`:
- `localizedTypeName(_:)` — 19 Pokémon types
- `localizedStatName(_:)` — HP, Atk, Def, Sp. Atk, Sp. Def, Speed
- `localizedDamageClass(_:)` — physical, special, status
- `localizedGenerationLabel(_:)` — Gen I–IX with region names

**PokeAPI text content** (descriptions, move effects) — fetched from `flavor_text_entries[]` / `effect_entries[]`, both `en` and `es` entries cached. `localizedText(en:es:)` in the repository picks the correct one at read time via `apiLanguageCode`.

**Evolution trigger strings** — constructed in `triggerDescription(_:)` using `String(localized:)` keys prefixed with `evo.*` in `Localizable.xcstrings`.

### Adding a new language
1. Add the language in Xcode → Project → Info → Localizations.
2. Add translations to `Localizable.xcstrings`.
3. Extend the `switch` statements in `LocalizationHelper.swift`.
4. Add the new language code to the `supported` array in `PokemonRepositoryImpl.apiLanguageCode`.
5. Add new cache columns (e.g. `descriptionTextDe`) in `CachedPokemonDetail` and `CachedPokemonMove` following the same `en`/`es` pattern.

---

## SwiftData cache

### Models

| Model | Key fields | Unique constraint |
|---|---|---|
| `CachedPokemon` | `id`, `name`, `spriteURLString`, `types` | `id` |
| `CachedPokemonDetail` | `id`, `name`, `height`, `weight`, `types`, `statsJSON`, `spriteURLString`, `officialArtworkURLString`, `descriptionText` (en), `descriptionTextEs` | `id` |
| `CachedPokemonMove` | `id`, `pokemonID`, `name`, `levelLearnedAt`, `power`, `accuracy`, `pp`, `damageClass`, `type`, `shortEffect` (en), `shortEffectEs` | `id` |
| `CachedEvolutionNode` | `ownerPokemonID`, `nodeID`, `name`, `spriteURLString`, `trigger`, `parentID` | — (composite) |
| `CachedPokemonForm` | `id`, `pokemonID`, `name`, `spriteURLString`, `isDefault`, `types` | — |

### Cache-first pattern (all 5 methods)
```
1. Create ModelContext → fetch SwiftData rows
2. If rows found → map to Domain entities → return immediately
3. Network fetch → map DTOs → Domain entities
4. Create new ModelContext → insert rows → save
5. Return domain entities
```

`clearAllCache()` deletes all 5 model types; called by `PokemonListViewModel.refreshAll()` on pull-to-refresh.

---

## Build & run

### Requirements
- Xcode 26.0.1 or later
- iOS 26.0 Simulator or device
- Swift 5.9+ (Swift 6 language mode not enabled — uses concurrency warnings, not errors)

### Build from command line
```bash
xcodebuild \
  -project PokeDexBattle.xcodeproj \
  -scheme PokeDexBattle \
  -destination 'platform=iOS Simulator,arch=arm64,id=D731B82A-BE5B-45DA-9FEA-7B432E7B30AC' \
  build
```

> **Note:** The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ auto-sync).
> New Swift files placed anywhere inside `PokeDexBattle/` are automatically included in the build target — no need to manually add them to `project.pbxproj`.

---

## Network logging

Every HTTP request is printed to the console automatically via `NetworkLogger`.
To see output when running from the command line:

```bash
xcrun simctl launch --console-pty <SIMULATOR_ID> com.cesar.personal.PokeDexBattle
```

Example output:
```
┌─────────────────────────────────────────────
│ 📤 REQUEST  [18:42:01.123]
│ URL: https://pokeapi.co/api/v2/pokemon?limit=1&offset=0
└─────────────────────────────────────────────

┌─────────────────────────────────────────────
│ 📥 RESPONSE ✅ [18:42:01.487]
│ URL: https://pokeapi.co/api/v2/pokemon?limit=1&offset=0
│ Status: 200  |  Size: 1.3 KB  |  Duration: 364 ms
└─────────────────────────────────────────────
```

---

## Common patterns

### Adding a new screen
1. Add any new domain entity fields to `Domain/Entities/Pokemon.swift`.
2. Add new DTO fields to `Data/DTOs/PokemonDTO.swift` if a new API field is needed.
3. Add a new method to `PokemonRepository` protocol and implement it in `PokemonRepositoryImpl`.
4. Create `Presentation/YourFeature/YourViewModel.swift` — `@MainActor @Observable final class`.
5. Create `Presentation/YourFeature/YourView.swift` — `@State private var viewModel = YourViewModel()`.

### ViewModel conventions
- All ViewModels are `@MainActor @Observable final class`.
- Exposed state uses `private(set)` — the View can read but never write directly.
- User actions are `async func` methods (e.g. `load()`, `retry()`), called from the View via `Task { }`.
- Guard against duplicate calls with `guard !isLoading` or similar at the top of every load method.

### View conventions
- Views never call the repository directly — always through the ViewModel.
- Use `@State private var viewModel = ViewModel()` (not `@StateObject`).
- Trigger loading with `.task { await viewModel.load() }`.
- Break complex `body` into `private var` computed properties or `private func` returning `some View`.

### Localization conventions
- All hardcoded UI strings: `String(localized: "key", defaultValue: "English fallback")`.
- PokeAPI identifier strings (types, stats, etc.): call the appropriate `localized*` function from `LocalizationHelper.swift`.
- PokeAPI text content: cache both `en` and `es` raw strings in SwiftData; call `localizedText(en:es:)` at read time.
- New `evo.*` trigger strings: add to `Localizable.xcstrings` and use `String(localized: "evo.key", defaultValue: "...")` in `triggerDescription(_:)`.
