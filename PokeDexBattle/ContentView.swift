//
//  ContentView.swift
//  PokeDexBattle
//
//  Created by Sergio Cesar Nieto Ramirez on 17/02/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab(String(localized: "tab.pokedex", defaultValue: "Pokédex"),
                systemImage: "list.star") {
                PokemonListView()
            }
            Tab(String(localized: "tab.teams", defaultValue: "Teams"),
                systemImage: "person.3") {
                TeamListView()
            }
        }
    }
}

#Preview {
    ContentView()
}
