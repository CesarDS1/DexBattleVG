//
//  PokeDexBattleApp.swift
//  PokeDexBattle
//
//  Created by Sergio Cesar Nieto Ramirez on 17/02/26.
//
//  Theme preference is persisted in UserDefaults via @AppStorage so the
//  user's choice survives app restarts. The raw Int maps to AppTheme:
//    0 = system (follows the device setting)
//    1 = light
//    2 = dark

import SwiftUI
import SwiftData

/// The three appearance choices available in the app.
enum AppTheme: Int, CaseIterable {
    case system = 0
    case light  = 1
    case dark   = 2

    /// Maps to the SwiftUI `ColorScheme` value, or `nil` for system-default.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// The SF Symbol name shown in the toolbar button.
    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    /// The localized label used in the menu and accessibility hint.
    var label: String {
        switch self {
        case .system: return String(localized: "theme.system", defaultValue: "System")
        case .light:  return String(localized: "theme.light",  defaultValue: "Light")
        case .dark:   return String(localized: "theme.dark",   defaultValue: "Dark")
        }
    }
}

// MARK: - Environment key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: Binding<AppTheme> = .constant(.system)
}

extension EnvironmentValues {
    /// The user-selected app theme, readable and settable by any view in the hierarchy.
    var appTheme: Binding<AppTheme> {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - App

@main
struct PokeDexBattleApp: App {

    /// Persisted theme preference (raw Int matching AppTheme).
    @AppStorage("appTheme") private var themeRaw: Int = AppTheme.system.rawValue

    private var theme: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: themeRaw) ?? .system },
            set: { themeRaw = $0.rawValue }
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appTheme, theme)
                // Apply the chosen color scheme at the root so the entire app respects it.
                .preferredColorScheme(theme.wrappedValue.colorScheme)
        }
        // Attach the shared SwiftData ModelContainer so the environment
        // is set up before any view appears. AppContainer.shared lives in
        // the Data layer; Presentation views never import SwiftData directly.
        .modelContainer(AppContainer.shared)
    }
}
