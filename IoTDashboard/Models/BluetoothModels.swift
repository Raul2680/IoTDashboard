import Foundation
import CoreBluetooth

// MARK: - Estados de Ligação
enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
}

// MARK: - Modelo de Dispositivo Bluetooth
struct DiscoveredDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
}

// MARK: - Modelo de Rede Wi-Fi
struct WiFiNetwork: Identifiable, Codable {
    let ssid: String
    let rssi: Int
    let secure: Bool
    var id: String { ssid }
}
