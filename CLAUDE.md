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

- **Presentation** depends on Domain entities and the repository protocols only.
- **Data** implements the protocols and maps DTOs to Domain entities.
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
│   │   ├── Pokemon.swift              # Pokemon, PokemonDetail, PokemonMove, EvolutionStage, PokemonForm
│   │   └── PokemonTeam.swift          # PokemonTeam, TeamMember (team builder domain entities)
│   └── Repositories/
│       ├── PokemonRepository.swift    # Protocol — Pokédex data (list, detail, moves, evolutions, forms)
│       ├── FavoritesRepository.swift  # Protocol — fetchFavoriteIDs, isFavorite, addFavorite, removeFavorite
│       └── TeamRepository.swift       # Protocol — fetchAll, create, rename, delete, addMember, removeMember
│
├── Data/
│   ├── DTOs/
│   │   └── PokemonDTO.swift           # Decodable structs matching PokeAPI JSON
│   ├── Network/
│   │   ├── PokeAPIClient.swift        # URLSession wrapper with generic fetch<T>
│   │   └── NetworkLogger.swift        # Console logger (request / response / error)
│   ├── Cache/
│   │   ├── AppContainer.swift         # Singleton ModelContainer (SwiftData) — 8 models
│   │   ├── CachedPokemon.swift        # SwiftData model — list entry
│   │   ├── CachedPokemonDetail.swift  # SwiftData model — full detail (en + es descriptions, genderRate)
│   │   ├── CachedPokemonMove.swift    # SwiftData model — level-up move (en + es effects)
│   │   ├── CachedEvolutionNode.swift  # SwiftData model — flattened evolution tree node
│   │   ├── CachedPokemonForm.swift    # SwiftData model — alternate form/variant
│   │   ├── CachedFavoritePokemon.swift # SwiftData model — favorited Pokémon ID + timestamp
│   │   ├── CachedTeam.swift           # SwiftData model — team (name, members relationship)
│   │   └── CachedTeamMember.swift     # SwiftData model — team member snapshot (pokemonID, name, sprite, types)
│   └── Repositories/
│       ├── PokemonRepositoryImpl.swift  # Cache-first; maps DTOs → Domain entities
│       ├── FavoritesRepositoryImpl.swift # SwiftData CRUD for favorites; per-operation ModelContext
│       └── TeamRepositoryImpl.swift     # SwiftData CRUD for teams; per-operation ModelContext
│
├── Presentation/
│   ├── PokemonList/
│   │   ├── PokemonListViewModel.swift  # Pokédex list + search + type filter + favorites filter
│   │   ├── PokemonListView.swift
│   │   └── PokemonRowView.swift        # Shows heart.fill badge when isFavorite = true
│   ├── PokemonDetail/
│   │   ├── PokemonDetailViewModel.swift # Fetches detail + isFavorite concurrently (async let)
│   │   └── PokemonDetailView.swift      # Segmented tabs, animated stat bars, gender bar, heart toolbar
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
│   ├── TeamBuilder/
│   │   ├── TeamListViewModel.swift     # Loads all teams; create/delete team actions
│   │   ├── TeamListView.swift          # Team list with new-team alert and empty state
│   │   ├── TeamDetailViewModel.swift   # Members grid; rename/delete member actions
│   │   ├── TeamDetailView.swift        # Sprite strip header + member grid + inline rename
│   │   ├── SelectTeamSheet.swift       # Sheet: choose an existing team or create new
│   │   ├── AddToTeamViewModel.swift    # Handles add-to-team logic; enforces 6-member cap
│   │   └── AddToTeamView.swift         # UI for the add-to-team flow with feedback toast
│   └── Shared/
│       └── LocalizationHelper.swift   # localizedTypeName / localizedStatName / localizedDamageClass / localizedGenerationLabel
│
├── Localizable.xcstrings              # Single string catalog (en + es) — Xcode 15+ format
├── ContentView.swift                  # Entry point — TabView with Pokédex + Teams tabs
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
| `async let` for concurrent detail + isFavorite fetch | `PokemonDetailViewModel.load()` uses `async let` to fetch `PokemonDetail` and `isFavorite` in parallel, avoiding two sequential round-trips |
| `nonisolated init` on Data layer classes | Prevents Swift 6 actor-isolation warnings when Data layer objects are created as default parameter values |
| SwiftData cache (8 model types) | Cache-first pattern for Pokédex data (5 models). Two additional models for Team Builder (CachedTeam, CachedTeamMember). One model for Favorites (CachedFavoritePokemon). Pull-to-refresh clears only the 5 Pokédex models |
| Favorites survive `clearAllCache()` | `CachedFavoritePokemon` is not included in `clearAllCache()`; favorites are user data, independent of the API cache |
| `@Attribute(.unique)` on `CachedFavoritePokemon.pokemonID` | SwiftData treats duplicate inserts as UPSERTs, making `addFavorite` idempotent |
| `genderRate` sentinel `-2` | Legacy `CachedPokemonDetail` rows written before the gender feature lack `genderRate`. Default value `-2` triggers a cache miss and forces a network re-fetch |
| Official artwork URL | Built statically: `https://raw.githubusercontent.com/PokeAPI/sprites/master/.../official-artwork/{id}.png` — no extra API call needed |
| `.task` inside NavigationStack (not on it) | `.task` on a `NavigationStack` fires only once (the stack never disappears during push/pop). Placing `.task` on the inner `VStack`/content ensures it re-fires on every pop-back, keeping `loadFavorites()` and other state in sync |
| `Canvas` for gender ratio bar | `Canvas { ctx, size in }` receives its correct size immediately — no zero-width flash on first layout pass that would occur with `GeometryReader` inside a `ScrollView` |
| `UIColor { traits in }` for adaptive colors | Evaluated at render time (not init time), so dark-mode and high-contrast environment changes are picked up live. Used for `genderPink` in the detail screen |
| `@ScaledMetric` for artwork size | Scales the official artwork proportionally with the user's Dynamic Type preference |
| `@Environment(\.accessibilityReduceMotion)` | Stat-bar spring animation is skipped when "Reduce Motion" is enabled in Accessibility settings |
| `Picker(.segmented)` for detail tabs | HIG recommends a segmented control (not an embedded `TabView`) for secondary content switching within a detail screen |
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

**Favorites / Team Builder strings** — all keys prefixed `fav.*` and `team.*` in `Localizable.xcstrings`.

### Adding a new language
1. Add the language in Xcode → Project → Info → Localizations.
2. Add translations to `Localizable.xcstrings`.
3. Extend the `switch` statements in `LocalizationHelper.swift`.
4. Add the new language code to the `supported` array in `PokemonRepositoryImpl.apiLanguageCode`.
5. Add new cache columns (e.g. `descriptionTextDe`) in `CachedPokemonDetail` and `CachedPokemonMove` following the same `en`/`es` pattern.

---

## SwiftData cache

### Models

| Model | Key fields | Unique constraint | Cleared by pull-to-refresh |
|---|---|---|---|
| `CachedPokemon` | `id`, `name`, `spriteURLString`, `types` | `id` | ✅ |
| `CachedPokemonDetail` | `id`, `name`, `height`, `weight`, `types`, `statsJSON`, `spriteURLString`, `officialArtworkURLString`, `descriptionText` (en), `descriptionTextEs`, `genderRate` | `id` | ✅ |
| `CachedPokemonMove` | `id`, `pokemonID`, `name`, `levelLearnedAt`, `power`, `accuracy`, `pp`, `damageClass`, `type`, `shortEffect` (en), `shortEffectEs` | `id` | ✅ |
| `CachedEvolutionNode` | `ownerPokemonID`, `nodeID`, `name`, `spriteURLString`, `trigger`, `parentID` | — (composite) | ✅ |
| `CachedPokemonForm` | `id`, `pokemonID`, `name`, `spriteURLString`, `isDefault`, `types` | — | ✅ |
| `CachedFavoritePokemon` | `pokemonID`, `addedAt` | `pokemonID` (`@Attribute(.unique)`) | ❌ user data |
| `CachedTeam` | `id`, `name`, `createdAt`, `@Relationship(deleteRule: .cascade) members` | — | ❌ user data |
| `CachedTeamMember` | `id`, `teamID`, `pokemonID`, `pokemonName`, `spriteURLString`, `types`, `addedAt` | — | ❌ user data |

### Cache-first pattern (Pokédex methods)
```
1. Create ModelContext → fetch SwiftData rows
2. If rows found → map to Domain entities → return immediately
3. Network fetch → map DTOs → Domain entities
4. Create new ModelContext → insert rows → save
5. Return domain entities
```

`clearAllCache()` deletes only the 5 Pokédex model types; called by `PokemonListViewModel.refreshAll()` on pull-to-refresh. Favorites and Team Builder data are **never** cleared.

### genderRate sentinel
`CachedPokemonDetail.genderRate` defaults to `-2`. A value of `-2` signals a legacy cache row (written before the gender feature was added). The repository skips the cache read when it sees `-2` and re-fetches from the network, which writes the real value.

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
1. Add any new domain entity fields to `Domain/Entities/Pokemon.swift` (or create a new entity file).
2. Add new DTO fields to `Data/DTOs/PokemonDTO.swift` if a new API field is needed.
3. Add a new method to the appropriate repository protocol and implement it in the `Impl` class.
4. Create `Presentation/YourFeature/YourViewModel.swift` — `@MainActor @Observable final class`.
5. Create `Presentation/YourFeature/YourView.swift` — `@State private var viewModel = YourViewModel()`.

### ViewModel conventions
- All ViewModels are `@MainActor @Observable final class`.
- Exposed state uses `private(set)` — the View can read but never write directly.
- User actions are `async func` methods (e.g. `load()`, `retry()`), called from the View via `Task { }`.
- Guard against duplicate calls with `guard !isLoading` or similar at the top of every load method.
- Use `async let` to fetch independent data sources concurrently within a single `load()` call.

### View conventions
- Views never call the repository directly — always through the ViewModel.
- Use `@State private var viewModel = ViewModel()` (not `@StateObject`).
- **Always** place `.task { await viewModel.load() }` on the content **inside** the `NavigationStack`, never on the `NavigationStack` itself. The `NavigationStack` never disappears during push/pop, so `.task` on it fires only once. On inner content it re-fires on every pop-back.
- Break complex `body` into `private var` computed properties or `private func` returning `some View`.
- Use `@ViewBuilder` when a helper may return different view types (e.g. conditional guard + two branches).
- Prefer `Canvas { ctx, size in }` over `GeometryReader` for proportional drawing inside `ScrollView` — avoids zero-width flash on first layout pass.

### Favorites conventions
- `FavoritesRepository` is the only path to read/write `CachedFavoritePokemon`.
- `PokemonListViewModel` always calls `loadFavorites()` inside `loadAll()` (before the hasLoaded guard) so the list stays in sync on every pop-back from a detail screen.
- `PokemonDetailViewModel` uses `async let` to fetch `isFavorite` concurrently with `fetchPokemonDetail`.
- `toggleFavorite()` in detail uses an optimistic update: flip `isFavorite` immediately, then persist asynchronously.

### Team Builder conventions
- Teams are persisted in `CachedTeam` / `CachedTeamMember` via `TeamRepository`.
- Members store a snapshot of the Pokémon (name, spriteURL, types) so the team tab works offline.
- Maximum 6 members per team — enforced in `AddToTeamViewModel` with user feedback.
- `CachedTeam` uses `deleteRule: .cascade` on the members relationship; deleting a team removes all its members automatically.

### Localization conventions
- All hardcoded UI strings: `String(localized: "key", defaultValue: "English fallback")`.
- PokeAPI identifier strings (types, stats, etc.): call the appropriate `localized*` function from `LocalizationHelper.swift`.
- PokeAPI text content: cache both `en` and `es` raw strings in SwiftData; call `localizedText(en:es:)` at read time.
- New `evo.*` trigger strings: add to `Localizable.xcstrings` and use `String(localized: "evo.key", defaultValue: "...")` in `triggerDescription(_:)`.
- Favorites keys: prefix `fav.*`. Team Builder keys: prefix `team.*`.
