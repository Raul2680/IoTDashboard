import Foundation

enum DeviceType: String, Codable, CaseIterable, Identifiable {
    case light = "Luz"
    case sensor = "Sensor"
    case led = "LED"
    case gas = "Gás"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .led: return "💡 LED RGB"
        case .sensor: return "🌡️ Sensor DHT"
        case .gas: return "💨 Sensor de Gás"
        case .light: return "🔆 Luz Inteligente"
        }
    }
}

enum ConnectionProtocol: String, Codable {
    case udp
    case http
}

struct Device: Identifiable, Codable, Hashable {
    // Mantemos todos os campos originais
    var id: String
    var name: String
    var type: DeviceType
    var ip: String
    var connectionProtocol: ConnectionProtocol
    var isOnline: Bool = false
    var state: Bool = false
    var room: String? = nil

    var temperature: Double?
    var humidity: Double?
    var gasLevel: Int?
    var lastUpdate: Date?
    var ledState: LedState?
    var sensorData: SensorData?
    var gasData: GasData?
}

// ✅ O SEGREDO: Colocar o init aqui preserva o inicializador automático da struct
extension Device {
    init(name: String, ip: String, type: DeviceType? = nil, connectionProtocol: ConnectionProtocol? = nil, isOnline: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.ip = ip
        self.isOnline = isOnline
        self.state = false
        self.room = nil
        
        // Lógica de Identificação Automática (O que resolve o "ESP32 Auto")
        if let explicitType = type {
            self.type = explicitType
        } else {
            let lowerName = name.lowercased()
            if lowerName.contains("gas") {
                self.type = .gas
            } else if lowerName.contains("led") {
                self.type = .led
            } else if lowerName.contains("sensor") || lowerName.contains("dht") {
                self.type = .sensor
            } else {
                self.type = .light
            }
        }
        
        // Protocolo Padrão baseado no tipo
        if let proto = connectionProtocol {
            self.connectionProtocol = proto
        } else {
            self.connectionProtocol = (self.type == .led) ? .udp : .http
        }
    }
}

struct LedState: Codable, Hashable {
    var isOn: Bool
    var r: Int
    var g: Int
    var b: Int
    var brightness: Int
}
