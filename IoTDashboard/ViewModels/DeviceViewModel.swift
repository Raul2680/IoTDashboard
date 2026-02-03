import Foundation
import SwiftUI
import Combine

class DeviceViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var selectedDeviceForOverlay: Device? = nil
    @Published var showQuickControl: Bool = false
    private var pollingTimer: Timer?
    private var currentUserId: String?
    
    // ✅ NOVO: Referência ao Home Assistant Service
    weak var homeAssistantService: HomeAssistantService?
    
    // ✅ NOVO: Referência ao Automation ViewModel para processar regras
    weak var automationViewModel: AutomationViewModel?
    
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
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
    func updateDeviceDetails(device: Device, newName: String, newRoom: String) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].name = newName
            devices[index].room = newRoom
            saveDevices() // Guarda as alterações no UserDefaults
            print("✅ Dispositivo atualizado: \(newName) em \(newRoom)")
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
                            
                            // ✅ AVISA AS AUTOMAÇÕES (Home Assistant)
                            self.automationViewModel?.checkSensorAutomations(for: self.devices[index])
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
                        self.devices[index].gasData = GasData(
                            mq2: entity.state == "on" ? 1000 : 0,
                            mq7: 0,
                            status: entity.state == "on" ? 2 : 0,
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                        // ✅ AVISA AS AUTOMAÇÕES (Gás HA)
                        self.automationViewModel?.checkSensorAutomations(for: self.devices[index])
                        
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
    
    func toggleDevice(_ device: Device) {
        // 1. Encontrar o índice para atualizar a UI localmente
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        let newState = !device.state
        
        // ✅ MODO SIMULAÇÃO (Para os testes na Escola)
        // Se o IP for o de loopback, apenas mudamos o estado visual
        if device.ip == "127.0.0.1" {
            devices[index].state = newState
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            saveDevices()
            return // Não tenta fazer chamadas de rede reais
        }
        
        // ✅ DISPOSITIVOS REAIS
        if device.type == .led || device.type == .light {
            // Se o protocolo for UDP, usamos a tua função específica
            if device.connectionProtocol == .udp {
                controlLEDviaUDP(device: device, power: newState)
                // Atualizamos o estado local após enviar o comando
                devices[index].state = newState
            } else {
                // Se for luz via HTTP (ex: Shelly ou Tasmota)
                toggleHTTPDevice(device: device, state: newState, index: index)
            }
        } else {
            // Outros tipos de dispositivos (Sensores/Gás costumam ser apenas leitura,
            // mas aqui permitimos o toggle se necessário)
            devices[index].state = newState
        }
        
        saveDevices()
    }

    // Função auxiliar para dispositivos HTTP (evita crashar a UI)
    private func toggleHTTPDevice(device: Device, state: Bool, index: Int) {
        let path = state ? "on" : "off"
        guard let url = URL(string: "http://\(device.ip)/\(path)") else { return }
        
        URLSession.shared.dataTask(with: url) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    self.devices[index].state = state
                    self.saveDevices()
                }
            }
        }.resume()
    }
    
    func fetchDeviceData(at index: Int) {
        guard devices.indices.contains(index) else { return }
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
                        if self.devices.indices.contains(index) {
                            self.devices[index].isOnline = false
                        }
                    }
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    DispatchQueue.main.async {
                        if self.devices.indices.contains(index) {
                            self.devices[index].isOnline = false
                        }
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    guard self.devices.indices.contains(index) else { return }
                    
                    self.devices[index].isOnline = true
                    self.devices[index].lastUpdate = Date()
                    
                    // --- ATUALIZAÇÃO DO LED ---
                    if let power = json["power"] as? Int {
                        let isOn = (power == 1)
                        self.devices[index].state = isOn
                        
                        let red = json["red"] as? Int ?? json["r"] as? Int ?? 255
                        let green = json["green"] as? Int ?? json["g"] as? Int ?? 255
                        let blue = json["blue"] as? Int ?? json["b"] as? Int ?? 255
                        let brightness = json["brightness"] as? Int ?? json["bri"] as? Int ?? 100
                        
                        self.devices[index].ledState = LedState(
                            isOn: isOn,
                            r: red,
                            g: green,
                            b: blue,
                            brightness: brightness
                        )
                    }
                    
                    // --- ATUALIZAÇÃO DO SENSOR DHT ---
                    if let temp = json["temperature"] as? Double ?? json["temp"] as? Double {
                        let hum = json["humidity"] as? Double ?? json["hum"] as? Double ?? 0.0
                        
                        self.devices[index].sensorData = SensorData(
                            temperature: temp,
                            humidity: hum,
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                        self.devices[index].temperature = temp
                        self.devices[index].humidity = hum
                        
                        // ✅ CRUCIAL: AVISA AS AUTOMAÇÕES (ESP32)
                        self.automationViewModel?.checkSensorAutomations(for: self.devices[index])
                    }
                    
                    // --- ATUALIZAÇÃO DO SENSOR DE GÁS ---
                    if let gasValue = json["gas"] as? Int ?? json["mq2"] as? Int {
                        self.devices[index].gasData = GasData(
                            mq2: gasValue,
                            mq7: json["mq7"] as? Int ?? 0,
                            status: gasValue > 500 ? 2 : 0,
                            timestamp: Int(Date().timeIntervalSince1970)
                        )
                        self.devices[index].gasLevel = gasValue
                        
                        // ✅ AVISA AS AUTOMAÇÕES (Gás ESP32)
                        self.automationViewModel?.checkSensorAutomations(for: self.devices[index])
                    }
                    
                    self.saveDevices()
                }
            }.resume()
        }
    }
    
    func controlLEDviaUDP(device: Device, power: Bool? = nil, r: Int? = nil, g: Int? = nil, b: Int? = nil, brightness: Int? = nil) {
        if device.id.hasPrefix("HA_") {
            controlHomeAssistantDevice(device: device, power: power, r: r, g: g, b: b, brightness: brightness)
            return
        }
        
        let udpService = UDPService(ip: device.ip)
        
        if let power = power {
            let command = power ? "ON" : "OFF"
            udpService.sendCommand(command)
            
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index].state = power
                devices[index].ledState?.isOn = power
                saveDevices()
            }
        }
        
        if let r = r, let g = g, let b = b, let brightness = brightness {
            udpService.sendColor(r: r, g: g, b: b, brightness: brightness)
            
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index].ledState = LedState(
                    isOn: power ?? devices[index].state,
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
    
    private func controlHomeAssistantDevice(device: Device, power: Bool? = nil, r: Int? = nil, g: Int? = nil, b: Int? = nil, brightness: Int? = nil) {
        guard let haService = homeAssistantService, let config = haService.config else { return }
        
        let entityId = device.id.replacingOccurrences(of: "HA_", with: "")
        
        if let power = power {
            let service = power ? "turn_on" : "turn_off"
            haService.controlDevice(entityId: entityId, service: service)
        }
        
        if device.type == .led, let r = r, let g = g, let b = b, let brightness = brightness {
            let serviceData: [String: Any] = [
                "rgb_color": [r, g, b],
                "brightness": Int((Double(brightness) / 100.0) * 255)
            ]
            haService.controlDevice(entityId: entityId, service: "turn_on", serviceData: serviceData)
        }
    }
    
    func syncHomeAssistantDevices(haService: HomeAssistantService) {
        haService.fetchDevices { haDevices in
            self.devices.removeAll { $0.id.hasPrefix("HA_") }
            let updatedDevices = haDevices.map { device -> Device in
                var d = device
                d.id = "HA_" + d.id
                return d
            }
            self.devices.append(contentsOf: updatedDevices)
            self.saveDevices()
        }
    }
    
    func removeDevice(_ device: Device) {
        devices.removeAll { $0.id == device.id }
        saveDevices()
    }
    
    func saveDevices() {
        guard let userId = currentUserId else { return }
        if let encoded = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encoded, forKey: "devices_\(userId)")
        }
    }
    
    private func loadDevices() {
        guard let userId = currentUserId else { return }
        let key = "devices_\(userId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Device].self, from: data) {
            devices = decoded
        }
    }
}
