import SwiftUI
import Combine

// MARK: - THEME MANAGER
class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") var currentTheme: AppTheme = .slate {
        didSet {
            objectWillChange.send()
        }
    }
    
    var colorScheme: ColorScheme? { currentTheme.colorScheme }
    var accentColor: Color { currentTheme.accentColor }
    
    func getColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .blue
        }
    }
}

// MARK: - ENUMS DE ESTILO
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "Sistema", light = "Claro", dark = "Escuro", ocean = "Oceano", forest = "Floresta", cyberpunk = "Cyberpunk", slate = "Ardósia"
    
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        self == .light ? .light : .dark
    }
    
    // ✅ ACENTO CYBERPUNK: Rosa Neon Elétrico (Puxado para o Magenta 80s)
    var accentColor: Color {
        switch self {
        case .cyberpunk: return Color(red: 1.0, green: 0.0, blue: 0.55)
        case .ocean: return Color(red: 0.15, green: 0.85, blue: 0.82)
        case .forest: return Color(red: 0.34, green: 0.85, blue: 0.56)
        case .slate: return Color(red: 0.44, green: 0.54, blue: 0.65)
        default: return .blue
        }
    }
    
    // ✅ BASE CYBERPUNK: Preto Profundo com Matiz Violeta (OLED Optimized)
    var deepBaseColor: Color {
        switch self {
        case .cyberpunk:
            return Color(red: 0.02, green: 0.0, blue: 0.05)
        case .ocean:
            return Color(red: 0.02, green: 0.08, blue: 0.16)
        case .forest:
            return Color(red: 0.04, green: 0.08, blue: 0.06)
        case .slate:
            return Color(red: 0.12, green: 0.14, blue: 0.17)
        case .light:
            return Color(UIColor.systemGroupedBackground)
        default:
            return Color(red: 0.05, green: 0.05, blue: 0.05)
        }
    }

    // Compatibilidade com as tuas Views
    var backgroundResource: String? { nil }
    var backgroundImageName: String? { self.backgroundResource }

    // ✅ ÍCONES DE PADRÃO: Hardware e Código
    var patternIcons: [String] {
        switch self {
        case .cyberpunk: return ["cpu.fill", "memorychip.fill", "terminal.fill", "antenna.radiowaves.left.and.right"]
        case .ocean: return ["drop.fill", "waveform.path", "humidity.fill", "bubbles.and.sparkles.fill"]
        case .forest: return ["leaf.fill", "sprout.fill", "wind", "cloud.sun.fill"]
        case .slate: return ["chart.xyaxis.line", "gauge.with.needle.fill", "tablecells.fill", "square.stack.3d.up.fill"]
        default: return ["bolt.fill", "wifi", "sensor.fill", "house.fill"]
        }
    }
    
    var icon: String {
        switch self {
        case .cyberpunk: return "trident.fill"
        case .ocean: return "drop.circle.fill"
        case .forest: return "leaf.circle.fill"
        case .slate: return "gearshape.2.fill"
        default: return "moon.circle.fill"
        }
    }
}
