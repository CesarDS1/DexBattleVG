//
//  PokemonDetailView.swift
//  PokeDexBattle — Presentation Layer
//
//  Detail screen for a single Pokémon, organised into three tabs:
//   • About   — sprite, types, measurements, Pokédex entry, and navigation to Moves/Evolutions/Forms
//   • Stats   — base stat bars
//   • Matchup — defensive type-effectiveness chart (computed in-memory, no API call)
//
//  The pinned header also contains a cry button that streams the Pokémon's
//  .ogg audio from the PokeAPI cries CDN via CryPlayerService.
//

import SwiftUI

/// Full-detail screen for a single Pokémon.
///
/// Layout:
/// ```
/// ┌────────────────────────────────────────┐
/// │  artwork  •  name  •  #number  •  🔊   │  ← pinned header
/// │           [Type]  [Type]               │
/// ├────────────────────────────────────────┤
/// │  About  │  Stats  │  Matchup           │  ← TabView
/// └────────────────────────────────────────┘
/// ```
struct PokemonDetailView: View {

    @State private var viewModel: PokemonDetailViewModel
    /// Tracks the currently selected tab (0 = About, 1 = Stats, 2 = Matchup).
    @State private var selectedTab = 0
    /// Manages audio playback for the Pokémon cry; one instance per detail screen.
    @State private var cryPlayer = CryPlayerService()

    init(pokemon: Pokemon) {
        _viewModel = State(initialValue: PokemonDetailViewModel(pokemonID: pokemon.id))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let detail = viewModel.detail {
                detailContent(detail)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                ProgressView(String(localized: "Loading Pokémon…"))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onDisappear {
            cryPlayer.stop()
        }
    }

    // MARK: - Top-level layout

    /// Pinned identity header + tab switcher.
    ///
    /// The header (artwork, name, dex number, cry button, type badges) is always visible
    /// above the `TabView` so the Pokémon's identity stays on screen regardless of the active tab.
    private func detailContent(_ detail: PokemonDetail) -> some View {
        VStack(spacing: 0) {

            // ── Pinned header ───────────────────────────────────────────────
            VStack(spacing: 16) {
                headerSection(detail)
                typeSection(detail)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 12)
            .background(.background)

            Divider()

            // ── Tabbed content ──────────────────────────────────────────────
            TabView(selection: $selectedTab) {

                // Tab 1 — About
                ScrollView {
                    aboutTabContent(detail)
                        .padding()
                }
                .tag(0)
                .tabItem {
                    Label(String(localized: "About"), systemImage: "info.circle")
                }

                // Tab 2 — Stats
                ScrollView {
                    statsSection(detail)
                        .padding()
                }
                .tag(1)
                .tabItem {
                    Label(String(localized: "Stats"), systemImage: "chart.bar")
                }

                // Tab 3 — Matchup (pure in-memory computation, no async work)
                TypeMatchupView(
                    matchup: TypeChart.defensiveMatchup(for: detail.types)
                )
                .tag(2)
                .tabItem {
                    Label(String(localized: "Matchup"), systemImage: "shield")
                }
            }
        }
    }

    // MARK: - Tab content

    /// About tab body: height/weight card + description + navigation buttons to sub-screens.
    private func aboutTabContent(_ detail: PokemonDetail) -> some View {
        VStack(spacing: 24) {
            measurementsSection(detail)
            if !detail.description.isEmpty {
                descriptionSection(detail.description)
            }
            navigationButtons(detail)
        }
    }

    // MARK: - Pinned header sections

    private func headerSection(_ detail: PokemonDetail) -> some View {
        VStack(spacing: 8) {
            // Show high-res official artwork; fall back to the pixel sprite if unavailable
            AsyncImage(url: detail.officialArtworkURL ?? detail.spriteURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                case .failure:
                    // Artwork CDN failed — try the smaller sprite as a fallback
                    AsyncImage(url: detail.spriteURL) { image in
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                case .empty:
                    ProgressView()
                @unknown default:
                    ProgressView()
                }
            }
            .frame(width: 160, height: 160)

            // Cry button centred below the artwork
            if let cryURL = detail.cryURL {
                cryButton(url: cryURL)
            }

            // Name and Pokédex number — centred
            VStack(spacing: 4) {
                Text(detail.name.capitalized)
                    .font(.largeTitle.bold())
                Text("#\(String(format: "%03d", detail.id))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Animated cry button — icon and tint change based on playback state.
    private func cryButton(url: URL) -> some View {
        Button {
            cryPlayer.toggle(url: url)
        } label: {
            Group {
                switch cryPlayer.state {
                case .idle:
                    Image(systemName: "speaker.wave.2")
                case .loading:
                    ProgressView()
                        .controlSize(.small)
                case .playing:
                    Image(systemName: "speaker.wave.3.fill")
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers)
                case .error:
                    Image(systemName: "speaker.slash")
                }
            }
            .font(.title2)
            .frame(width: 44, height: 44)
        }
        .tint(cryPlayer.state == .error ? .red : .accentColor)
        .accessibilityLabel(cryButtonAccessibilityLabel)
        .animation(.easeInOut(duration: 0.2), value: cryPlayer.state)
    }

    /// Localized accessibility label for the cry button based on current playback state.
    private var cryButtonAccessibilityLabel: String {
        switch cryPlayer.state {
        case .idle:    return String(localized: "cry.play",    defaultValue: "Play cry")
        case .loading: return String(localized: "cry.loading", defaultValue: "Loading cry")
        case .playing: return String(localized: "cry.stop",    defaultValue: "Stop cry")
        case .error:   return String(localized: "cry.error",   defaultValue: "Cry unavailable")
        }
    }

    /// Type badge row — uses the shared `pokemonTypeColor` utility.
    private func typeSection(_ detail: PokemonDetail) -> some View {
        HStack(spacing: 8) {
            ForEach(detail.types, id: \.self) { type in
                Text(localizedTypeName(type))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(pokemonTypeColor(type), in: Capsule())
            }
        }
    }

    // MARK: - About tab sections

    private func measurementsSection(_ detail: PokemonDetail) -> some View {
        HStack(spacing: 0) {
            measurementCell(
                label: String(localized: "Height"),
                value: String(format: "%.1f m", Double(detail.height) / 10)
            )
            Divider().frame(height: 44)
            measurementCell(
                label: String(localized: "Weight"),
                value: String(format: "%.1f kg", Double(detail.weight) / 10)
            )
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func measurementCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Pokédex flavor-text description card displayed below the measurements row.
    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Pokédex Entry"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Group of navigation buttons linking to Moves, Evolutions, and Forms screens.
    private func navigationButtons(_ detail: PokemonDetail) -> some View {
        VStack(spacing: 12) {
            navButton(
                icon: "list.bullet.clipboard",
                label: String(localized: "Moves by Level"),
                color: .blue,
                destination: MovesView(pokemonID: detail.id, pokemonName: detail.name)
            )
            navButton(
                icon: "arrow.triangle.branch",
                label: String(localized: "Evolutions"),
                color: .green,
                destination: EvolutionsView(pokemonID: detail.id, pokemonName: detail.name)
            )
            navButton(
                icon: "square.stack.3d.up",
                label: String(localized: "Forms & Variants"),
                color: .purple,
                destination: FormsView(pokemonID: detail.id, pokemonName: detail.name)
            )
        }
    }

    /// Reusable tinted `NavigationLink` button with an icon and label.
    private func navButton<D: View>(icon: String, label: String, color: Color, destination: D) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Stats tab section

    private func statsSection(_ detail: PokemonDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Base Stats"))
                .font(.headline)

            ForEach(detail.stats, id: \.name) { stat in
                statRow(stat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(_ stat: PokemonDetail.Stat) -> some View {
        HStack(spacing: 12) {
            Text(statLabel(stat.name))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text("\(stat.value)")
                .font(.subheadline.bold())
                .frame(width: 36, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(statBarColor(stat.value))
                        .frame(width: geo.size.width * min(CGFloat(stat.value) / 255, 1))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Error state

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
            Button(String(localized: "Retry")) {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Helpers

    /// Maps the raw PokeAPI stat name to a localized short display label.
    private func statLabel(_ name: String) -> String {
        localizedStatName(name)
    }

    /// Returns a color for a stat bar based on the stat's base value.
    private func statBarColor(_ value: Int) -> Color {
        switch value {
        case 0..<50:   return .red
        case 50..<80:  return .orange
        case 80..<100: return .yellow
        default:       return .green
        }
    }
}
