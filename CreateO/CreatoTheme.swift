import SwiftUI

enum CreatoTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .system: return "Matches the device setting"
        case .light: return "Clean and bright workspace"
        case .dark: return "Low-glare editing experience"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon.stars"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var accentColor: Color { .accentColor }

    static func from(_ rawValue: String) -> CreatoTheme {
        CreatoTheme(rawValue: rawValue) ?? .system
    }
}
