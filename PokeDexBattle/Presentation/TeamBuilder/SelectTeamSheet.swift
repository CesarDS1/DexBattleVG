//
//  SelectTeamSheet.swift
//  PokeDexBattle — Presentation Layer
//
//  Sheet presented from PokemonDetailView.
//  Shows all existing teams and lets the user add the current Pokémon to
//  any team that isn't full and doesn't already contain it.
//

import SwiftUI

// MARK: - ViewModel

@MainActor @Observable
private final class SelectTeamViewModel {
    private(set) var teams: [PokemonTeam] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var addedToTeamID: UUID? = nil

    private let pokemon: Pokemon
    private let repository: TeamRepository

    init(pokemon: Pokemon,
         repository: TeamRepository = TeamRepositoryImpl()) {
        self.pokemon = pokemon
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            teams = try await repository.fetchAllTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addToTeam(_ team: PokemonTeam) async {
        let member = TeamMember(
            id: UUID(),
            pokemonID: pokemon.id,
            name: pokemon.name,
            spriteURL: pokemon.spriteURL,
            types: pokemon.types,
            slot: 0
        )
        do {
            try await repository.addMember(member, toTeamID: team.id)
            addedToTeamID = team.id
            teams = try await repository.fetchAllTeams()   // refresh counts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTeamAndAdd(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let newTeam = try await repository.createTeam(name: trimmed)
            await addToTeam(newTeam)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

struct SelectTeamSheet: View {
    let pokemon: Pokemon

    @State private var viewModel: SelectTeamViewModel
    @State private var showingNewTeamAlert = false
    @State private var newTeamName = ""
    @Environment(\.dismiss) private var dismiss

    init(pokemon: Pokemon) {
        self.pokemon = pokemon
        _viewModel = State(initialValue: SelectTeamViewModel(pokemon: pokemon))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(
                    String(localized: "team.select.title",
                           defaultValue: "Add to Team")
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            newTeamName = ""
                            showingNewTeamAlert = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(
                            String(localized: "team.new.button", defaultValue: "Create team")
                        )
                    }
                }
                .alert(
                    String(localized: "team.new.alert.title", defaultValue: "New Team"),
                    isPresented: $showingNewTeamAlert
                ) {
                    TextField(
                        String(localized: "team.new.placeholder", defaultValue: "Team name"),
                        text: $newTeamName
                    )
                    Button(String(localized: "team.new.confirm", defaultValue: "Create")) {
                        Task { await viewModel.createTeamAndAdd(name: newTeamName) }
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await viewModel.load() }
        .onChange(of: viewModel.addedToTeamID) { _, id in
            if id != nil { dismiss() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.teams.isEmpty {
            emptyState
        } else {
            teamList
        }
    }

    private var teamList: some View {
        List(viewModel.teams) { team in
            teamRow(team)
        }
        .listStyle(.plain)
    }

    private func teamRow(_ team: PokemonTeam) -> some View {
        let alreadyAdded = team.contains(pokemonID: pokemon.id)
        let isFull = team.isFull

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.headline)
                Text("\(team.members.count) / 6")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if alreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel(
                        String(localized: "team.picker.already.added",
                               defaultValue: "Already on team")
                    )
            } else {
                Button {
                    Task { await viewModel.addToTeam(team) }
                } label: {
                    Text(String(localized: "team.select.add", defaultValue: "Add"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            isFull ? Color.secondary : Color.accentColor,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(isFull)
                .accessibilityLabel(
                    isFull
                    ? String(localized: "team.error.full",
                             defaultValue: "This team already has 6 Pokémon.")
                    : String(localized: "team.select.add.label",
                             defaultValue: "Add \(pokemon.name.capitalized) to \(team.name)")
                )
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "team.list.empty.title", defaultValue: "No Teams Yet"),
                systemImage: "person.3"
            )
        } description: {
            Text(String(localized: "team.list.empty.subtitle",
                        defaultValue: "Create your first team of up to 6 Pokémon."))
        } actions: {
            Button(String(localized: "team.new.cta", defaultValue: "Create Team")) {
                newTeamName = ""
                showingNewTeamAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    SelectTeamSheet(
        pokemon: Pokemon(
            id: 25,
            name: "pikachu",
            spriteURL: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png"),
            types: ["electric"]
        )
    )
}
