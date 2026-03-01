//
//  TeamListView.swift
//  PokeDexBattle — Presentation Layer
//
//  Root screen for the Teams tab.
//  Displays the user's saved teams as card-style rows with a sprite strip.
//  A "+" toolbar button presents an inline alert to name a new team.
//

import SwiftUI

struct TeamListView: View {
    @State private var viewModel = TeamListViewModel()

    /// Controls the "New Team" name-entry alert.
    @State private var showingNewTeamAlert = false
    /// Text bound to the alert's TextField.
    @State private var newTeamName = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "tab.teams", defaultValue: "Teams"))
                .toolbar { toolbarContent }
                .alert(
                    String(localized: "team.new.alert.title", defaultValue: "New Team"),
                    isPresented: $showingNewTeamAlert
                ) {
                    newTeamAlert
                }
                .task { await viewModel.load() }
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.teams.isEmpty {
            loadingView
        } else if let error = viewModel.errorMessage, viewModel.teams.isEmpty {
            errorView(message: error)
        } else if viewModel.teams.isEmpty {
            emptyState
        } else {
            teamList
        }
    }

    // MARK: - Team list

    private var teamList: some View {
        List {
            ForEach(viewModel.teams) { team in
                NavigationLink(destination: TeamDetailView(team: team)) {
                    TeamRowView(team: team)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .padding(.vertical, 3)
                )
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                Task { await viewModel.deleteTeams(at: offsets) }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.load() }
    }

    // MARK: - Empty state

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

    // MARK: - Loading / error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text(String(localized: "team.loading", defaultValue: "Loading teams…"))
                .foregroundStyle(.secondary)
        }
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
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                newTeamName = ""
                showingNewTeamAlert = true
            } label: {
                Image(systemName: "plus")
                    .accessibilityLabel(
                        String(localized: "team.new.button", defaultValue: "Create team")
                    )
            }
        }
    }

    // MARK: - New team alert

    @ViewBuilder
    private var newTeamAlert: some View {
        TextField(
            String(localized: "team.new.placeholder", defaultValue: "Team name"),
            text: $newTeamName
        )
        Button(String(localized: "team.new.confirm", defaultValue: "Create")) {
            Task { await viewModel.createTeam(name: newTeamName) }
        }
        Button(String(localized: "Cancel"), role: .cancel) {
            newTeamName = ""
        }
    }
}

// MARK: - Team row

/// Card-style list row showing team name, member count, and a sprite strip.
private struct TeamRowView: View {
    let team: PokemonTeam

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(team.name)
                    .font(.headline)
                Spacer()
                Text("\(team.members.count) / 6")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            spriteStrip
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    /// Six sprite slots — filled with an AsyncImage, empty with a placeholder circle.
    private var spriteStrip: some View {
        HStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { slot in
                if let member = team.members.first(where: { $0.slot == slot }) {
                    AsyncImage(url: member.spriteURL) { image in
                        image.resizable().interpolation(.none).scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 48, height: 48)
                } else {
                    ZStack {
                        Circle()
                            .fill(.quaternary)
                            .frame(width: 48, height: 48)
                        Image(systemName: "plus")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

#Preview {
    TeamListView()
}
