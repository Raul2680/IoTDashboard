import Foundation
import SwiftUI
import CoreLocation

// MARK: - Tipos de Gatilhos (Atualizado para coincidir com a UI)
enum AutomationTriggerType: String, Codable, CaseIterable {
    case time = "Horário"
    case temperature = "Temperatura"
    case humidity = "Humidade"
    case gas = "Gás" // ✅ Alterado de gasDetected para gas
    case location = "Localização"
    case deviceState = "Estado do Dispositivo"
    case sunset = "Pôr do Sol"
    case sunrise = "Nascer do Sol"
}

// MARK: - Tipos de Ações (Atualizado para coincidir com a UI)
enum AutomationActionType: String, Codable, CaseIterable {
    case turnOn = "Ligar"
    case turnOff = "Desligar"
    case setRGB = "Cor LED" // ✅ Alterado de setColor para setRGB
    case setBrightness = "Ajustar Brilho"
    case notify = "Notificar"
    case sendEmail = "Enviar Email"
}

// MARK: - Condições de Comparação
enum ComparisonOperator: String, Codable, CaseIterable {
    case greaterThan = ">"
    case lessThan = "<"
    case equals = "="
    case notEquals = "≠"
}

// MARK: - Estrutura de Ação
struct AutomationAction: Identifiable, Codable {
    var id: String = UUID().uuidString
    var type: AutomationActionType
    var targetDeviceId: String?
    var value: String?
}

// MARK: - Estrutura de Localização
struct AutomationLocation: Codable {
    var latitude: Double
    var longitude: Double
    var radius: Double
    var name: String
    
    func distance(from location: CLLocation) -> Double {
        let center = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: center)
    }
    
    func contains(_ location: CLLocation) -> Bool {
        return distance(from: location) <= radius
    }
}

// MARK: - Histórico de Execução
struct AutomationExecution: Identifiable, Codable {
    var id: String = UUID().uuidString
    var automationId: String
    var timestamp: Date
    var success: Bool
    var message: String?
}

// MARK: - Modelo Principal de Automação
struct Automation: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var isEnabled: Bool = true
    var icon: String = "bolt.fill"
    var color: String = "blue"
    
    // GATILHO
    var triggerType: AutomationTriggerType
    var triggerTime: Date?
    var triggerDays: [Int]?
    
    var triggerDeviceId: String?
    var comparisonOperator: ComparisonOperator?
    var triggerValue: Double?
    
    var triggerLocation: AutomationLocation?
    var locationTriggerType: LocationTriggerType?
    
    // AÇÕES
    var actions: [AutomationAction] = []
    
    // EXECUÇÃO
    var lastTriggered: Date?
    var executionCount: Int = 0
    
    // MARK: - Helpers Visuais
    var uiColor: Color {
        switch color {
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
    
    var conditionsDescription: String {
        switch triggerType {
        case .time:
            let time = triggerTime?.formatted(date: .omitted, time: .shortened) ?? "?"
            if let days = triggerDays, !days.isEmpty {
                let dayNames = days.map { dayName($0) }.joined(separator: ", ")
                return "\(time) (\(dayNames))"
            }
            return time
            
        case .temperature:
            let op = comparisonOperator?.rawValue ?? ">"
            let val = triggerValue ?? 0
            return "Temperatura \(op) \(String(format: "%.1f", val))°C"
            
        case .humidity:
            let op = comparisonOperator?.rawValue ?? "<"
            let val = triggerValue ?? 0
            return "Humidade \(op) \(String(format: "%.0f", val))%"
            
        case .gas: // ✅ Atualizado
            return "Deteção de Gás"
            
        case .location:
            if let loc = triggerLocation {
                let type = locationTriggerType == .enter ? "Chegar a" : "Sair de"
                return "\(type) \(loc.name)"
            }
            return "Localização"
            
        case .sunset:
            return "Ao pôr do sol"
            
        case .sunrise:
            return "Ao nascer do sol"
            
        case .deviceState:
            return "Estado do dispositivo"
        }
    }
    
    var actionsDescription: String {
        if actions.isEmpty { return "Sem ações" }
        return actions.map { $0.type.rawValue }.joined(separator: ", ")
    }
    
    private func dayName(_ day: Int) -> String {
        let names = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
        return names[safe: day] ?? "?"
    }
}

enum LocationTriggerType: String, Codable, CaseIterable {
    case enter = "Entrar"
    case exit = "Sair"
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
