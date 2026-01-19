import Foundation

enum DeviceType: String, Codable {
    case light = "Luz"
    case sensor = "Sensor"
    case led = "LED"
    case gas = "Gás"
}

enum ConnectionProtocol: String, Codable {
    case udp
    case http
}

struct Device: Identifiable, Codable, Hashable  {
    var id: String
    var name: String
    var type: DeviceType
    var ip: String
    var connectionProtocol: ConnectionProtocol
    var isOnline: Bool = false
    var state: Bool = false
    var room: String? = nil  

    
    // Dados de Sensores
    var temperature: Double?
    var humidity: Double?
    var gasLevel: Int?
    var lastUpdate: Date?
    var ledState: LedState?
    var sensorData: SensorData?
    var gasData: GasData?
}

struct LedState: Codable, Hashable  {
    var isOn: Bool
    var r: Int      // Red (0-255)
    var g: Int      // Green (0-255)
    var b: Int      // Blue (0-255)
    var brightness: Int  // 0-100
}
