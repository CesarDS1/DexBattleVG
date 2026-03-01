//
//  AddToTeamView.swift
//  PokeDexBattle — Presentation Layer
//
//  Sheet that lets the user pick Pokémon to add to a team.
//  Reuses PokemonRowView and the same search+type-filter UX from PokemonListView.
//
//  Design principles (fixes from Fase 6):
//  • The sheet NEVER auto-closes after an add — the user taps "Done" when finished.
//  • Each row shows a checkmark immediately after adding (via addedInSession).
//  • Errors from addPokemon are shown as an alert, not silently swallowed.
//  • The parent reloads via .sheet(onDismiss:), so no callback closure is needed.
//

import SwiftUI

struct AddToTeamView: View {
    let teamID: UUID

    @State private var viewModel: AddToTeamViewModel
    @State private var showingAddError = false
    @Environment(\.dismiss) private var dismiss

    init(teamID: UUID, currentMemberIDs: Set<Int> = []) {
        self.teamID = teamID
        _viewModel = State(
            initialValue: AddToTeamViewModel(
                teamID: teamID,
                currentMemberIDs: currentMemberIDs
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Team-full banner
                if viewModel.isTeamFull {
                    teamFullBanner
                }
                if !viewModel.allPokemon.isEmpty {
                    typeFilterBar
                    Divider()
                }
                content
            }
            .navigationTitle(
                String(localized: "team.add.picker.title", defaultValue: "Add Pokémon")
            )
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String(localized: "Search Pokémon")
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "team.picker.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            // Error alert for failed adds (team full, duplicate, etc.)
            .alert(
                String(localized: "team.picker.error.title", defaultValue: "Can't Add Pokémon"),
                isPresented: $showingAddError,
                presenting: viewModel.errorMessage
            ) { _ in
                Button(String(localized: "OK")) { viewModel.clearError() }
            } message: { message in
                Text(message)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await viewModel.load() }
        .onChange(of: viewModel.errorMessage) { _, msg in
            showingAddError = msg != nil
        }
    }

    // MARK: - Team full banner

    private var teamFullBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(String(localized: "team.picker.full.banner",
                        defaultValue: "Team is full! Tap Done to finish."))
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.green.opacity(0.12))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.allPokemon.isEmpty {
            loadingView
        } else if viewModel.allPokemon.isEmpty, let error = viewModel.errorMessage {
            errorView(message: error)
        } else {
            pokemonList
        }
    }

    // MARK: - Pokémon list

    private var pokemonList: some View {
        List {
            ForEach(viewModel.filteredPokemon) { pokemon in
                pickerRow(pokemon: pokemon)
                    .listRowSeparator(.hidden)
            }

            if viewModel.isSearchingOrFiltering && viewModel.filteredPokemon.isEmpty {
                Text(String(localized: "No Pokémon match your filters."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    private func pickerRow(pokemon: Pokemon) -> some View {
        let alreadyAdded = viewModel.isAlreadyOnTeam(pokemonID: pokemon.id)
        let teamFull = viewModel.isTeamFull && !alreadyAdded

        return HStack {
            PokemonRowView(pokemon: pokemon)
            Spacer()
            if alreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(
                        String(localized: "team.picker.already.added",
                               defaultValue: "Already on team")
                    )
            } else {
                Button {
                    Task { await viewModel.addPokemon(pokemon) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(teamFull ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(teamFull)
                .accessibilityLabel(
                    teamFull
                    ? String(localized: "team.error.full",
                             defaultValue: "This team already has 6 Pokémon.")
                    : String(localized: "team.picker.add.label",
                             defaultValue: "Add \(pokemon.name.capitalized) to team")
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: alreadyAdded)
    }

    // MARK: - Type filter bar (mirrors PokemonListView)

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
                .overlay(Capsule().strokeBorder(color, lineWidth: isSelected ? 0 : 1.5))
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Loading / error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text(String(localized: "Loading all Pokémon…"))
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message).multilineTextAlignment(.center)
            Button(String(localized: "Retry")) {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    AddToTeamView(teamID: UUID())
}
