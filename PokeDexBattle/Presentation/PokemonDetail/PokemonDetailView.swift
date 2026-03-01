//
//  PokemonDetailView.swift
//  PokeDexBattle — Presentation Layer
//
//  Detail screen for a single Pokémon, organised into three sections:
//   • About   — sprite, types, measurements, gender, Pokédex entry, navigation buttons
//   • Stats   — animated base stat bars (spring animation, reduce-motion aware)
//   • Matchup — defensive type-effectiveness chart (computed in-memory, no API call)
//
//  The pinned header integrates with iOS 26 Liquid Glass via .regularMaterial.
//  A segmented Picker replaces the embedded TabView (HIG-recommended for detail screens).
//

import SwiftUI

/// Full-detail screen for a single Pokémon.
///
/// Layout:
/// ```
/// ┌────────────────────────────────────────┐
/// │  artwork  •  name  •  #number  •  🔊   │  ← pinned header (.regularMaterial)
/// │           [Type]  [Type]               │
/// ├────────────────────────────────────────┤
/// │    About    │    Stats    │   Matchup  │  ← segmented Picker
/// ├────────────────────────────────────────┤
/// │           (scrollable content)         │
/// └────────────────────────────────────────┘
/// ```
struct PokemonDetailView: View {

    @State private var viewModel: PokemonDetailViewModel
    /// Tracks the currently selected tab (0 = About, 1 = Stats, 2 = Matchup).
    @State private var selectedTab = 0
    /// Drives the fill animation for stat bars. Set to `true` on first Stats tab visit.
    @State private var statBarsAnimated = false
    /// Manages audio playback for the Pokémon cry; one instance per detail screen.
    @State private var cryPlayer = CryPlayerService()
    /// Drives the "Add to Team" sheet.
    @State private var showingSelectTeam = false
    /// Retained so the sheet can construct a TeamMember snapshot.
    private let pokemon: Pokemon

    /// Scales the official artwork proportionally with the user's Dynamic Type size.
    @ScaledMetric(relativeTo: .largeTitle) private var artworkSize: CGFloat = 160
    /// Respects the "Reduce Motion" accessibility preference for stat bar animation.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(pokemon: Pokemon) {
        self.pokemon = pokemon
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                favoriteButton
            }
        }
        .task {
            await viewModel.load()
        }
        .onDisappear {
            cryPlayer.stop()
        }
        .sheet(isPresented: $showingSelectTeam) {
            SelectTeamSheet(pokemon: pokemon)
        }
    }

    // MARK: - Top-level layout

    /// Pinned identity header + segmented tab picker + scrollable tab content.
    private func detailContent(_ detail: PokemonDetail) -> some View {
        VStack(spacing: 0) {

            // ── Pinned header ───────────────────────────────────────────────
            // .regularMaterial integrates with iOS 26 Liquid Glass navigation chrome
            // and provides depth separation from the scrollable content below.
            VStack(spacing: 16) {
                headerSection(detail)
                typeSection(detail)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 12)
            .background(.regularMaterial)

            Divider()

            // ── Segmented Picker ────────────────────────────────────────────
            // HIG recommends a segmented control (not an embedded TabView tab bar)
            // for secondary content switching within a detail screen.
            Picker("", selection: $selectedTab) {
                Text(String(localized: "About")).tag(0)
                Text(String(localized: "Stats")).tag(1)
                Text(String(localized: "Matchup")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.background)

            Divider()

            // ── Scrollable tab content ──────────────────────────────────────
            ScrollView {
                switch selectedTab {
                case 1:
                    statsSection(detail)
                        .padding()
                case 2:
                    TypeMatchupView(matchup: TypeChart.defensiveMatchup(for: detail.types))
                        .padding()
                default:
                    aboutTabContent(detail)
                        .padding()
                }
            }
        }
    }

    // MARK: - Tab content

    /// About tab body: measurements + gender + Pokédex entry + navigation buttons.
    private func aboutTabContent(_ detail: PokemonDetail) -> some View {
        VStack(spacing: 24) {
            measurementsSection(detail)
            genderSection(detail)
            if !detail.description.isEmpty {
                descriptionSection(detail.description)
            }
            navigationButtons(detail)
        }
    }

    // MARK: - Pinned header sections

    private func headerSection(_ detail: PokemonDetail) -> some View {
        VStack(spacing: 8) {
            // Pre-resolve the best available URL before AsyncImage.
            // This avoids the nested-AsyncImage anti-pattern where a CDN failure
            // triggers a second network request inside the .failure branch.
            let imageURL = detail.officialArtworkURL ?? detail.spriteURL

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                case .failure:
                    // Static placeholder — no second network request on failure.
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                @unknown default:
                    ProgressView()
                }
            }
            .frame(width: artworkSize, height: artworkSize)

            // Cry button centred below the artwork
            if let cryURL = detail.cryURL {
                cryButton(url: cryURL)
            }

            // Name and Pokédex number — centred.
            // Locale en_US avoids locale-sensitive capitalisation bugs (e.g. Turkish i → İ).
            VStack(spacing: 4) {
                Text(detail.name.capitalized(with: Locale(identifier: "en_US")))
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

    /// A single measurement cell. `.accessibilityElement(children: .combine)` makes
    /// VoiceOver read value + label as one unit (e.g. "1.5 m Height").
    private func measurementCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Pokédex flavor-text description card.
    /// `.textSelection(.enabled)` lets users long-press to copy the entry.
    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Pokédex Entry"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Group of navigation buttons linking to Moves, Evolutions, Forms, and Team Builder.
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
            addToTeamButton
        }
    }

    /// Tinted button that presents the SelectTeamSheet.
    /// `.colorScheme(.dark)` forces the render context so white text stays
    /// legible on teal in all contrast modes.
    private var addToTeamButton: some View {
        Button {
            showingSelectTeam = true
        } label: {
            HStack {
                Image(systemName: "person.badge.plus")
                Text(String(localized: "team.detail.addButton",
                            defaultValue: "Add to Team"))
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .colorScheme(.dark)
        }
        // No explicit accessibilityLabel — VoiceOver already reads the visible Text.
        .accessibilityHint(
            String(localized: "team.detail.addButton.hint",
                   defaultValue: "Opens a sheet to choose which team to add this Pokémon to")
        )
    }

    /// Toolbar heart button that toggles this Pokémon's favorite state.
    /// Uses `.symbolEffect(.bounce)` to provide tactile feedback on toggle.
    private var favoriteButton: some View {
        Button {
            Task { await viewModel.toggleFavorite() }
        } label: {
            Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(viewModel.isFavorite ? .red : .primary)
                .symbolEffect(.bounce, value: viewModel.isFavorite)
                .accessibilityLabel(
                    viewModel.isFavorite
                        ? String(localized: "fav.remove", defaultValue: "Unfavorite")
                        : String(localized: "fav.add",    defaultValue: "Favorite")
                )
        }
    }

    /// Reusable tinted `NavigationLink` button with a leading icon, label, and trailing chevron.
    /// `.colorScheme(.dark)` ensures `.foregroundStyle(.white)` stays legible on any
    /// coloured background, including in high-contrast mode.
    private func navButton<D: View>(icon: String, label: String, color: Color, destination: D) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .colorScheme(.dark)
        }
    }

    // MARK: - Gender section

    /// Adaptive pink that renders correctly in light, dark, and high-contrast environments.
    /// Defined as a computed property so `UIColor`'s trait-collection callback is evaluated
    /// at render time (not at init time), picking up live trait changes.
    private var genderPink: Color {
        Color(UIColor { traits in
            switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
            case (_, .high):
                // Deeper saturation for high contrast — ensures WCAG AA on .quaternary bg
                return UIColor(red: 0.80, green: 0.20, blue: 0.50, alpha: 1)
            case (.dark, _):
                // Lighter/more luminous in dark mode to maintain legibility
                return UIColor(red: 0.95, green: 0.50, blue: 0.72, alpha: 1)
            default:
                return UIColor(red: 0.88, green: 0.35, blue: 0.60, alpha: 1)
            }
        })
    }

    /// Card showing the male/female ratio as a split colour bar, or a "Genderless" label.
    /// Omitted entirely for invalid/sentinel `genderRate` values to prevent corrupt layout.
    @ViewBuilder
    private func genderSection(_ detail: PokemonDetail) -> some View {
        // Guard against the -2 legacy cache sentinel and any other unexpected values.
        if detail.genderRate >= -1 && detail.genderRate <= 8 {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "gender.label", defaultValue: "Gender"))
                    .font(.headline)

                if detail.genderRate == -1 {
                    // Genderless Pokémon (e.g. Magnemite, Staryu, Metagross)
                    HStack(spacing: 6) {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(.secondary)
                        Text(String(localized: "gender.genderless", defaultValue: "Genderless"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    let femaleRatio = Double(detail.genderRate) / 8.0
                    let maleRatio   = 1.0 - femaleRatio

                    // Canvas-based bar: no GeometryReader, no zero-width flash on first layout.
                    // The Canvas receives its correct size immediately and draws both segments
                    // in a single pass; Capsule clip rounds the ends.
                    Canvas { ctx, size in
                        let maleWidth = size.width * maleRatio
                        if maleWidth > 0 {
                            ctx.fill(
                                Path(CGRect(x: 0, y: 0,
                                            width: maleWidth, height: size.height)),
                                with: .color(.blue)
                            )
                        }
                        if femaleRatio > 0 {
                            ctx.fill(
                                Path(CGRect(x: maleWidth, y: 0,
                                            width: size.width * femaleRatio, height: size.height)),
                                with: .color(genderPink)
                            )
                        }
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())

                    // Percentage labels below the bar
                    HStack {
                        Text("♂ \(genderPercentageLabel(maleRatio))")
                            .foregroundStyle(.blue)
                        Spacer()
                        Text("♀ \(genderPercentageLabel(femaleRatio))")
                            .foregroundStyle(genderPink)
                    }
                    .font(.subheadline.monospacedDigit())
                }
            }
            // The entire card is a single VoiceOver element with a synthesised label.
            // This groups the title, bar, and percentage labels into one announcement.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(genderAccessibilityLabel(for: detail.genderRate))
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Builds the VoiceOver label for the gender card.
    private func genderAccessibilityLabel(for genderRate: Int) -> String {
        if genderRate == -1 {
            return String(localized: "gender.a11y.genderless",
                          defaultValue: "Gender: Genderless")
        }
        guard genderRate >= 0, genderRate <= 8 else { return "" }
        let femaleRatio = Double(genderRate) / 8.0
        let maleRatio   = 1.0 - femaleRatio
        return String(
            format: String(localized: "gender.a11y.format",
                           defaultValue: "Gender: %@ male, %@ female"),
            genderPercentageLabel(maleRatio),
            genderPercentageLabel(femaleRatio)
        )
    }

    /// Formats a gender ratio (0.0–1.0) as a clean percentage string.
    /// Shows whole numbers without trailing ".0" (e.g. "50%" not "50.0%").
    private func genderPercentageLabel(_ ratio: Double) -> String {
        let percent = ratio * 100
        if percent.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(percent))%"
        }
        return String(format: "%.1f%%", percent)
    }

    // MARK: - Stats tab section

    /// Stat bars animate from zero on the first visit to the Stats tab.
    /// Subsequent visits (within the same detail screen lifetime) show bars at full width.
    /// The animation is skipped when "Reduce Motion" is enabled.
    private func statsSection(_ detail: PokemonDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Base Stats"))
                .font(.headline)

            ForEach(detail.stats, id: \.name) { stat in
                statRow(stat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !statBarsAnimated else { return }
            withAnimation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.6, dampingFraction: 0.8).delay(0.1)
            ) {
                statBarsAnimated = true
            }
        }
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

            // GeometryReader reads the bar's available width after layout.
            // Starting at zero width aligns intentionally with the spring animation:
            // the bar grows from 0 → correct value, creating a smooth fill effect.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(statBarColor(stat.value))
                        .frame(width: statBarsAnimated
                               ? geo.size.width * min(CGFloat(stat.value) / 255, 1)
                               : 0)
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

    /// Returns a colour for a stat bar based on the stat's base value.
    /// Thresholds align with competitive Pokémon stat tiers (poor → average → good → great → exceptional).
    private func statBarColor(_ value: Int) -> Color {
        switch value {
        case 0..<50:    return .red
        case 50..<80:   return .orange
        case 80..<110:  return .yellow
        case 110..<150: return .green
        default:        return .teal    // Exceptional — e.g. Blissey HP 255, Shuckle Def/SpDef 230
        }
    }
}
