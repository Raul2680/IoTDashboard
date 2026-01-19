import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "Sistema"
    case light = "Claro"
    case dark = "Escuro"
    case ocean = "Oceano"
    case forest = "Floresta"
    
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        default: return .dark
        }
    }
    
    var accentColor: Color {
        switch self {
        case .ocean: return Color(red: 0.0, green: 0.6, blue: 1.0)
        case .forest: return Color(red: 0.2, green: 0.8, blue: 0.4)
        default: return .blue
        }
    }
    
    var deepBaseColor: Color {
        switch self {
        case .ocean: return Color(red: 0.0, green: 0.05, blue: 0.15)
        case .forest: return Color(red: 0.02, green: 0.1, blue: 0.05)
        case .dark: return Color(red: 0.05, green: 0.05, blue: 0.05)
        default: return Color(.systemGroupedBackground)
        }
    }

    var patternIcons: [String] {
        switch self {
        case .ocean: return ["drop.fill", "bolt.fill", "waveform.path", "bubbles.and.sparkles.fill"]
        case .forest: return ["leaf.fill", "bolt.fill", "sensor.fill", "tree.fill"]
        default: return ["cpu", "wifi", "bolt.fill", "sensor.fill"]
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .ocean: return "drop.fill"
        case .forest: return "leaf.fill"
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") var currentTheme: AppTheme = .system {
        didSet {
            objectWillChange.send()
        }
    }
    
    var colorScheme: ColorScheme? { currentTheme.colorScheme }
    var accentColor: Color { currentTheme.accentColor }
}
