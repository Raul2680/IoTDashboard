import SwiftUI
import Combine

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case glow = "Glow"
    case premium = "Premium"
    case metal = "Metal"
    case ultra = "Ultra"
    
    var id: String { self.rawValue }
}

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "Sistema"
    case light = "Claro"
    case dark = "Escuro"
    case ocean = "Oceano"
    case forest = "Floresta"
    case sunset = "Pôr do Sol"
    case cyberpunk = "Cyberpunk"
    case slate = "Ardósia"
    case goldLines = "Premium Gold"
    case neonCity = "Neon City"
    
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .sunset: return .light
        default: return .dark
        }
    }
    
    var accentColor: Color {
        switch self {
        case .ocean: return Color(red: 0.0, green: 0.6, blue: 1.0)
        case .forest: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .sunset: return Color(red: 1.0, green: 0.4, blue: 0.3)
        case .cyberpunk: return Color(red: 0.8, green: 0.2, blue: 1.0)
        case .slate: return Color(red: 0.4, green: 0.5, blue: 0.6)
        case .goldLines: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .neonCity: return Color(red: 0.5, green: 0.3, blue: 1.0)
        default: return .blue
        }
    }
    
    var deepBaseColor: Color {
        switch self {
        case .goldLines, .dark: return Color(red: 0.05, green: 0.05, blue: 0.05)
        case .neonCity: return Color(red: 0.02, green: 0.02, blue: 0.1)
        case .ocean: return Color(red: 0.0, green: 0.05, blue: 0.15)
        case .forest: return Color(red: 0.02, green: 0.1, blue: 0.05)
        case .cyberpunk: return Color(red: 0.02, green: 0.0, blue: 0.05)
        case .slate: return Color(red: 0.12, green: 0.14, blue: 0.17)
        case .sunset: return Color(red: 1.0, green: 0.95, blue: 0.9)
        default: return Color(.systemGroupedBackground)
        }
    }

    // RESOLVE O ERRO: Adiciona a propriedade que a View procura
    var backgroundResource: String? {
        switch self {
        case .goldLines: return "gold_topography"
        case .neonCity: return "big_ben_neon"
        default: return nil
        }
    }
    
    // Alias para manter compatibilidade com códigos anteriores
    var backgroundImageName: String? {
        return self.backgroundResource
    }

    var patternIcons: [String] {
        switch self {
        case .ocean: return ["waveform.path", "drop.fill", "humidity.fill"]
        case .forest: return ["leaf.fill", "sprout.fill", "wind"]
        case .cyberpunk: return ["cpu.fill", "memorychip.fill", "network"]
        case .slate: return ["chart.xyaxis.line", "gauge.with.needle.fill", "tablecells.fill"]
        default: return ["bolt.fill", "wifi", "sensor.fill"]
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "desktopcomputer"
        case .light: return "sun.max.circle.fill"
        case .dark: return "moon.circle.fill"
        case .ocean: return "drop.circle.fill"
        case .forest: return "leaf.circle.fill"
        case .sunset: return "sun.haze.fill"
        case .cyberpunk: return "trident.fill"
        case .slate: return "gearshape.2.fill"
        case .goldLines: return "crown.fill"
        case .neonCity: return "building.2.crop.circle.fill"
        }
    }
}
