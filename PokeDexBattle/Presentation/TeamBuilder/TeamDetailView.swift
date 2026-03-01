//
//  TeamDetailView.swift
//  PokeDexBattle — Presentation Layer
//
//  Shows a single team's six-slot grid (2 columns × 3 rows) plus
//  rename / delete actions. Each slot shows official artwork when filled
//  or a placeholder circle when empty.
//

import SwiftUI

struct TeamDetailView: View {
    /// Receives the initial team snapshot from the list; ViewModel reloads from store.
    let team: PokemonTeam

    @State private var viewModel: TeamDetailViewModel
    @Environment(\.dismiss) private var dismiss

    // Alert states
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var showingDeleteConfirm = false
    @State private var slotPendingRemoval: Int? = nil

    // Sheet for adding members (Fase 6)
    @State private var showingAddSheet = false

    init(team: PokemonTeam) {
        self.team = team
        _viewModel = State(initialValue: TeamDetailViewModel(team: team))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                memberGrid
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if !viewModel.team.members.isEmpty {
                    memberCountBadge
                }
            }
        }
        .navigationTitle(viewModel.team.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // Rename alert
        .alert(
            String(localized: "team.rename.alert.title", defaultValue: "Rename Team"),
            isPresented: $showingRenameAlert
        ) {
            renameAlert
        }
        // Delete confirmation
        .confirmationDialog(
            String(localized: "team.delete.confirm.title",
                   defaultValue: "Delete \"\(viewModel.team.name)\"?"),
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            deleteDialog
        }
        // Remove-member confirmation
        .confirmationDialog(
            String(localized: "team.remove.confirm.title",
                   defaultValue: "Remove Pokémon?"),
            isPresented: Binding(
                get: { slotPendingRemoval != nil },
                set: { if !$0 { slotPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            removeMemberDialog
        }
        // Add-to-team sheet — reload via onDismiss (reliable, no race condition)
        .sheet(isPresented: $showingAddSheet, onDismiss: {
            Task { await viewModel.reload() }
        }) {
            AddToTeamView(
                teamID: viewModel.team.id,
                currentMemberIDs: Set(viewModel.team.members.map(\.pokemonID))
            )
        }
        .task { await viewModel.reload() }
    }

    // MARK: - Member grid (2 columns × 3 rows)

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var memberGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<6, id: \.self) { slot in
                if let member = viewModel.team.members.first(where: { $0.slot == slot }) {
                    filledSlot(member: member, slot: slot)
                } else {
                    emptySlot(slot: slot)
                }
            }
        }
    }

    private func filledSlot(member: TeamMember, slot: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                AsyncImage(url: member.spriteURL) { image in
                    image.resizable().interpolation(.none).scaledToFit()
                } placeholder: {
                    ProgressView().frame(width: 80, height: 80)
                }
                .frame(width: 80, height: 80)

                Text(member.name.capitalized)
                    .font(.caption.bold())
                    .lineLimit(1)

                if let type = member.types.first {
                    Text(localizedTypeName(type))
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(pokemonTypeColor(type), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))

            // Remove button
            Button {
                slotPendingRemoval = slot
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .background(Circle().fill(.background))
            }
            .offset(x: 6, y: -6)
            .accessibilityLabel(
                String(localized: "team.slot.remove",
                       defaultValue: "Remove \(member.name.capitalized) from team")
            )
        }
    }

    private func emptySlot(slot: Int) -> some View {
        Button {
            showingAddSheet = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(.quaternary))

                Text(String(localized: "team.slot.empty", defaultValue: "Empty"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(localized: "team.slot.add", defaultValue: "Add Pokémon to slot \(slot + 1)")
        )
    }

    private var memberCountBadge: some View {
        Text("\(viewModel.team.members.count) / 6 Pokémon")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    renameText = viewModel.team.name
                    showingRenameAlert = true
                } label: {
                    Label(String(localized: "team.rename", defaultValue: "Rename"),
                          systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label(String(localized: "team.delete", defaultValue: "Delete Team"),
                          systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }

        if !viewModel.team.isFull {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel(
                            String(localized: "team.add.button",
                                   defaultValue: "Add Pokémon to team")
                        )
                }
            }
        }
    }

    // MARK: - Dialogs

    @ViewBuilder
    private var renameAlert: some View {
        TextField(
            String(localized: "team.new.placeholder", defaultValue: "Team name"),
            text: $renameText
        )
        Button(String(localized: "team.rename.confirm", defaultValue: "Rename")) {
            Task { await viewModel.renameTeam(newName: renameText) }
        }
        Button(String(localized: "Cancel"), role: .cancel) {}
    }

    @ViewBuilder
    private var deleteDialog: some View {
        Button(
            String(localized: "team.delete.confirm", defaultValue: "Delete Team"),
            role: .destructive
        ) {
            Task {
                await viewModel.deleteTeam()
                dismiss()
            }
        }
        Button(String(localized: "Cancel"), role: .cancel) {}
    }

    @ViewBuilder
    private var removeMemberDialog: some View {
        if let slot = slotPendingRemoval,
           let member = viewModel.team.members.first(where: { $0.slot == slot }) {
            Button(
                String(localized: "team.remove.confirm",
                       defaultValue: "Remove \(member.name.capitalized)"),
                role: .destructive
            ) {
                Task {
                    await viewModel.removeMember(slot: slot)
                    slotPendingRemoval = nil
                }
            }
        }
        Button(String(localized: "Cancel"), role: .cancel) {
            slotPendingRemoval = nil
        }
    }
}

#Preview {
    NavigationStack {
        TeamDetailView(
            team: PokemonTeam(
                id: UUID(),
                name: "Dream Team",
                members: [],
                createdAt: .now
            )
        )
    }
}
