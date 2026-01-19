import Foundation
import SwiftUI
import Combine

class DeviceViewModel: ObservableObject {
    @Published var devices: [Device] = []
    private var pollingTimer: Timer?
    private var currentUserId: String?
    
    // ✅ NOVO: Referência ao Home Assistant Service
    weak var homeAssistantService: HomeAssistantService?
    
    init() {}
    
    func setUser(userId: String) {
        self.currentUserId = userId
        loadDevices()
        startPolling()
    }
    
    func clearUserDevices() {
        devices.removeAll()
        currentUserId = nil
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshAllDevices()
        }
    }
    
    func refreshAllDevices() {
        for index in devices.indices {
            let device = devices[index]
            
            // ✅ NOVO: Detecta se é dispositivo Home Assistant
            if device.id.hasPrefix("HA_") {
                refreshHomeAssistantDevice(at: index)
            } else {
                fetchDeviceData(at: index)
            }
        }
    }
    
    // ✅ NOVO: Refresh para dispositivos Home Assistant
    private func refreshHomeAssistantDevice(at index: Int) {
        guard let haService = homeAssistantService,
              let config = haService.config,
              config.isEnabled else {
            print("⚠️ Home Assistant não configurado")
            return
        }
        
        let device = devices[index]
        let entityId = device.id.replacingOccurrences(of: "HA_", with: "")
        
        guard let url = URL(string: "\(config.serverURL)/api/states/\(entityId)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                print("❌ Erro ao atualizar \(device.name): \(error?.localizedDescription ?? "Unknown")")
                DispatchQueue.main.async {
                    self?.devices[index].isOnline = false
                }
                return
            }
            
            do {
                let entity = try JSONDecoder().decode(HomeAssistantEntity.self, from: data)
                
                DispatchQueue.main.async {
                    self.devices[index].isOnline = entity.state != "unavailable"
                    self.devices[index].state = entity.state == "on"
                    self.devices[index].lastUpdate = Date()
                    
                    // ✅ Atualiza dados específicos por tipo
                    switch self.devices[index].type {
                    case .sensor:
                        if let temp = entity.attributes.temperature,
                           let hum = entity.attributes.humidity {
                            self.devices[index].sensorData = SensorData(
                                temperature: temp,
                                humidity: hum,
                                timestamp: Int(Date().timeIntervalSince1970)
                            )
                            self.devices[index].temperature = temp
                            self.devices[index].humidity = hum
                        }
                        
                    case .led:
                        if let brightness = entity.attributes.brightness,
                           let rgb = entity.attributes.rgb_color, rgb.count == 3 {
                            self.devices[index].ledState = LedState(
                                isOn: entity.state == "on",
                                r: rgb[0],
                                g: rgb[1],
                                b: rgb[2],
                                brightness: Int((Double(brightness) / 255.0) * 100)
                            )
                        }
                        
                    case .gas:
                        // Sensor binário de gás
                        self.devices[index].gasData = GasData(
                            mq2: entity.state == "on" ? 1000 : 0,
                            mq7: 0,
                            status: entity.state == "on" ? 2 : 0,
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                        
                    default:
                        break
                    }
                    
                    self.saveDevices()
                }
            } catch {
                print("❌ Erro ao parse entity \(entityId): \(error)")
            }
        }.resume()
    }
    
    // Mantém o fetchDeviceData original para dispositivos ESP32 locais
    func fetchDeviceData(at index: Int) {
        let device = devices[index]
        
        if device.connectionProtocol == .http {
            guard let url = URL(string: "http://\(device.ip)/status") else {
                print("❌ URL inválido para \(device.ip)")
                return
            }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Erro ao conectar a \(device.ip): \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.devices[index].isOnline = false
                    }
                    return
                }
                
                guard let data = data else {
                    print("❌ Sem dados de \(device.ip)")
                    DispatchQueue.main.async {
                        self.devices[index].isOnline = false
                    }
                    return
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ JSON inválido de \(device.ip)")
                    DispatchQueue.main.async {
                        self.devices[index].isOnline = false
                    }
                    return
                }
                
                print("✅ JSON recebido de \(device.ip): \(json)")
                
                DispatchQueue.main.async {
                    self.devices[index].isOnline = true
                    self.devices[index].lastUpdate = Date()
                    
                    // LED RGB
                    if let power = json["power"] as? Int,
                       let red = json["red"] as? Int,
                       let green = json["green"] as? Int,
                       let blue = json["blue"] as? Int,
                       let brightness = json["brightness"] as? Int {
                        
                        self.devices[index].ledState = LedState(
                            isOn: power == 1,
                            r: red,
                            g: green,
                            b: blue,
                            brightness: brightness
                        )
                        self.devices[index].state = (power == 1)
                    }
                    
                    // SENSOR
                    if let temp = json["temperature"] as? Double,
                       let hum = json["humidity"] as? Double {
                        
                        self.devices[index].sensorData = SensorData(
                            temperature: temp,
                            humidity: hum,
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                        self.devices[index].temperature = temp
                        self.devices[index].humidity = hum
                    }
                    
                    // GAS
                    if let gasValue = json["gas"] as? Int {
                        self.devices[index].gasData = GasData(
                            mq2: gasValue,
                            mq7: json["mq7"] as? Int ?? 0,
                            status: gasValue > 500 ? 2 : 0,
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                        self.devices[index].gasLevel = gasValue
                    }
                    
                    self.saveDevices()
                }
            }.resume()
        }
    }
    
    func controlLEDviaUDP(device: Device, power: Bool? = nil, r: Int? = nil, g: Int? = nil, b: Int? = nil, brightness: Int? = nil) {
        // ✅ Se for dispositivo HA, usa API do HA
        if device.id.hasPrefix("HA_") {
            controlHomeAssistantDevice(device: device, power: power, r: r, g: g, b: b, brightness: brightness)
            return
        }
        
        // Controlo UDP normal para ESP32
        let udpService = UDPService(ip: device.ip)
        
        if let power = power {
            let command = power ? "ON" : "OFF"
            udpService.sendCommand(command)
            print("✅ UDP: Power \(command) → \(device.ip)")
            
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index].state = power
                devices[index].ledState?.isOn = power
                saveDevices()
            }
        }
        
        if let r = r, let g = g, let b = b, let brightness = brightness {
            udpService.sendColor(r: r, g: g, b: b, brightness: brightness)
            print("✅ UDP: COLOR R:\(r) G:\(g) B:\(b) Brilho:\(brightness) → \(device.ip)")
            
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index].ledState = LedState(
                    isOn: power ?? false,
                    r: r,
                    g: g,
                    b: b,
                    brightness: brightness
                )
                saveDevices()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            udpService.stop()
        }
    }
    
    // ✅ NOVO: Controlar dispositivos Home Assistant
    private func controlHomeAssistantDevice(device: Device, power: Bool? = nil, r: Int? = nil, g: Int? = nil, b: Int? = nil, brightness: Int? = nil) {
        guard let haService = homeAssistantService,
              let config = haService.config else {
            print("❌ Home Assistant não configurado")
            return
        }
        
        let entityId = device.id.replacingOccurrences(of: "HA_", with: "")
        let domain = String(entityId.split(separator: ".").first ?? "")
        
        // Power ON/OFF
        if let power = power {
            let service = power ? "turn_on" : "turn_off"
            haService.controlDevice(entityId: entityId, service: service)
        }
        
        // Cor RGB (apenas para lights)
        if device.type == .led, let r = r, let g = g, let b = b, let brightness = brightness {
            let serviceData: [String: Any] = [
                "rgb_color": [r, g, b],
                "brightness": Int((Double(brightness) / 100.0) * 255)
            ]
            haService.controlDevice(entityId: entityId, service: "turn_on", serviceData: serviceData)
        }
    }
    
    // ✅ Sincronizar com Home Assistant
    func syncHomeAssistantDevices(haService: HomeAssistantService) {
        haService.fetchDevices { haDevices in
            // Remove dispositivos HA antigos
            self.devices.removeAll { $0.id.hasPrefix("HA_") }
            
            // Adiciona novos com prefixo
            let updatedDevices = haDevices.map { device -> Device in
                var d = device
                d.id = "HA_" + d.id
                return d
            }
            
            self.devices.append(contentsOf: updatedDevices)
            self.saveDevices()
            
            print("✅ \(haDevices.count) dispositivos sincronizados do Home Assistant")
        }
    }
    
    func removeDevice(_ device: Device) {
        devices.removeAll { $0.id == device.id }
        saveDevices()
    }
    
    func saveDevices() {
        guard let userId = currentUserId else {
            print("⚠️ Nenhum utilizador logado - dispositivos não guardados")
            return
        }
        
        if let encoded = try? JSONEncoder().encode(devices) {
            let key = "devices_\(userId)"
            UserDefaults.standard.set(encoded, forKey: key)
            print("✅ Dispositivos guardados para utilizador: \(userId)")
        }
    }
    
    private func loadDevices() {
        guard let userId = currentUserId else {
            print("⚠️ Nenhum utilizador logado - sem dispositivos para carregar")
            devices = []
            return
        }
        
        let key = "devices_\(userId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Device].self, from: data) else {
            print("ℹ️ Nenhum dispositivo guardado para \(userId)")
            devices = []
            return
        }
        
        devices = decoded
        print("✅ \(decoded.count) dispositivos carregados para \(userId)")
    }
}
