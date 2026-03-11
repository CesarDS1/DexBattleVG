//
//  PokemonListView.swift
//  PokeDexBattle — Presentation Layer
//
//  The root screen of the app: a searchable, type-filterable Pokédex list.
//  All business logic lives in `PokemonListViewModel`; this file contains
//  only layout and navigation declarations.
//

import SwiftUI

/// Root view that displays the full National Pokédex with live search and type filtering.
struct PokemonListView: View {
    @State private var viewModel = PokemonListViewModel()
    @Environment(\.appTheme) private var appTheme
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.hasLoaded && !viewModel.availableTypes.isEmpty {
                    typeFilterBar
                    Divider()
                }
                content
            }
            .navigationTitle(String(localized: "Pokédex"))
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String(localized: "Search Pokémon")
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    favoritesFilterButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    themeMenuButton
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    aboutButton
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            // IMPORTANT: .task must be inside the NavigationStack (on the VStack), NOT on
            // the NavigationStack itself. The NavigationStack never disappears during push/pop,
            // so a .task on it would only fire once at app launch and never again on pop-back.
            // On the VStack, it fires every time the list becomes the top of the stack again,
            // letting loadAll() → loadFavorites() pick up changes made in the detail screen.
            .task {
                await viewModel.loadAll()
            }
        }
    }

    // MARK: - About button

    private var aboutButton: some View {
        Button {
            showingAbout = true
        } label: {
            Image(systemName: "info.circle")
                .accessibilityLabel(String(localized: "about.title", defaultValue: "About"))
        }
    }

    // MARK: - Favorites filter button

    /// Toolbar button that toggles the "show favorites only" filter.
    /// Filled red heart when active; outline heart when inactive.
    private var favoritesFilterButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleFavoritesFilter()
            }
        } label: {
            Image(systemName: viewModel.showFavoritesOnly ? "heart.fill" : "heart")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(viewModel.showFavoritesOnly ? .red : .primary)
                .accessibilityLabel(
                    viewModel.showFavoritesOnly
                        ? String(localized: "fav.filter.off", defaultValue: "Show all Pokémon")
                        : String(localized: "fav.filter.on",  defaultValue: "Show favorites only")
                )
        }
    }

    // MARK: - Theme menu

    /// Toolbar button that opens a menu to switch between System / Light / Dark.
    private var themeMenuButton: some View {
        Menu {
            ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                Button {
                    appTheme.wrappedValue = theme
                } label: {
                    Label(theme.label, systemImage: theme.iconName)
                }
            }
        } label: {
            Image(systemName: appTheme.wrappedValue.iconName)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(String(localized: "theme.button", defaultValue: "Appearance"))
        }
    }

    // MARK: - Type filter bar

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableTypes, id: \.self) { type in
                    typeChip(type)
                }
                if viewModel.isFiltering {
                    Button {
                        viewModel.clearTypeFilters()
                    } label: {
                        Text(String(localized: "Clear"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.quaternary, in: Capsule())
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isFiltering)
        }
    }

    private func typeChip(_ type: String) -> some View {
        let isSelected = viewModel.selectedTypes.contains(type)
        let color = pokemonTypeColor(type)
        return Button {
            viewModel.toggleType(type)
        } label: {
            Text(localizedTypeName(type))
                .font(.subheadline.bold())
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? AnyShapeStyle(color)
                        : AnyShapeStyle(color.opacity(0.12)),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(color, lineWidth: isSelected ? 0 : 1.5)
                )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(message: error)
        } else if viewModel.showFavoritesOnly && viewModel.favoriteIDs.isEmpty {
            favoritesEmptyState
        } else {
            pokemonList
        }
    }

    /// Shown when the favorites filter is active but no Pokémon have been favorited yet.
    private var favoritesEmptyState: some View {
        ContentUnavailableView(
            String(localized: "fav.empty.title", defaultValue: "No Favorites Yet"),
            systemImage: "heart",
            description: Text(
                String(localized: "fav.empty.subtitle",
                       defaultValue: "Swipe left on any Pokémon to add it to your favorites.")
            )
        )
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(String(localized: "Loading all Pokémon…"))
                .foregroundStyle(.secondary)
        }
    }

    private var pokemonList: some View {
        List {
            ForEach(viewModel.groupedByGeneration) { group in
                Section {
                    if !viewModel.collapsedGenerations.contains(group.id) {
                        ForEach(group.pokemon) { pokemon in
                            NavigationLink(destination: PokemonDetailView(pokemon: pokemon)) {
                                PokemonRowView(
                                    pokemon: pokemon,
                                    isFavorite: viewModel.isFavorite(pokemon.id)
                                )
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                let alreadyFav = viewModel.isFavorite(pokemon.id)
                                Button {
                                    Task { await viewModel.toggleFavorite(pokemonID: pokemon.id) }
                                } label: {
                                    Label(
                                        alreadyFav
                                            ? String(localized: "fav.remove", defaultValue: "Unfavorite")
                                            : String(localized: "fav.add",    defaultValue: "Favorite"),
                                        systemImage: alreadyFav ? "heart.slash.fill" : "heart.fill"
                                    )
                                }
                                .tint(alreadyFav ? .gray : .red)
                            }
                        }
                    }
                } header: {
                    generationHeader(group)
                }
            }

            if viewModel.isSearchingOrFiltering && viewModel.groupedByGeneration.isEmpty {
                Text(String(localized: "No Pokémon match your filters."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshAll()
        }
    }

    private func generationHeader(_ group: PokemonListViewModel.GenerationGroup) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleGeneration(group.id)
            }
        } label: {
            HStack(spacing: 8) {
                Text(group.label)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(group.pokemon.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .rotationEffect(
                        viewModel.collapsedGenerations.contains(group.id)
                            ? .degrees(-90) : .degrees(0)
                    )
                    .animation(
                        .easeInOut(duration: 0.2),
                        value: viewModel.collapsedGenerations.contains(group.id)
                    )
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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
}

#Preview {
    PokemonListView()
}
