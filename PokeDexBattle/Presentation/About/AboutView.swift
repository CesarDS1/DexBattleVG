//
//  AboutView.swift
//  PokeDexBattle — Presentation Layer
//
//  A sheet that shows the app version, data source credits, and a disclaimer
//  clarifying that all Pokémon assets belong to their respective owners and
//  are used here for non-commercial purposes only.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            List {
                appSection
                dataSourcesSection
                disclaimerSection
            }
            .navigationTitle(String(localized: "about.title", defaultValue: "About"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - App info

    private var appSection: some View {
        Section(String(localized: "about.section.app", defaultValue: "App")) {
            HStack {
                Text(String(localized: "about.version", defaultValue: "Version"))
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(String(localized: "about.build", defaultValue: "Build"))
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Data sources

    private var dataSourcesSection: some View {
        Section(String(localized: "about.section.data", defaultValue: "Data Sources")) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PokéAPI")
                    .font(.subheadline.bold())
                Text(String(localized: "about.pokeapi.description",
                            defaultValue: "Pokémon data is provided by PokéAPI (pokeapi.co), a free and open Pokémon RESTful API."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        Section(String(localized: "about.section.disclaimer", defaultValue: "Disclaimer")) {
            Text(String(localized: "about.disclaimer.text",
                        defaultValue: "Pokémon and all related names, characters, and images are trademarks of Nintendo, Game Freak, and Creatures Inc. This app is not affiliated with, endorsed by, or associated with Nintendo, Game Freak, or The Pokémon Company in any way. All Pokémon assets are used solely for non-commercial, personal purposes."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }
}

#Preview {
    AboutView()
}
