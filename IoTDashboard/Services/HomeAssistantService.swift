import Foundation
import Combine

class HomeAssistantService: ObservableObject {
    @Published var config: HomeAssistantConfig?
    @Published var isConnected = false
    @Published var errorMessage: String?
    
    private let configKey = "homeAssistantConfig"
    
    init() {
        loadConfig()
    }
    
    // MARK: - Config Management
    func saveConfig(_ config: HomeAssistantConfig) {
        self.config = config
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
        
        if config.isEnabled {
            testConnection()
        }
    }
    
    func loadConfig() {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let decoded = try? JSONDecoder().decode(HomeAssistantConfig.self, from: data) else {
            return
        }
        self.config = decoded
        
        if decoded.isEnabled {
            testConnection()
        }
    }
    
    // MARK: - Connection Test
    func testConnection(completion: ((Bool, String?) -> Void)? = nil) {
        guard let config = config, config.isValid else {
            errorMessage = "Configuração inválida"
            isConnected = false
            completion?(false, "Configuração inválida")
            return
        }
        
        guard let url = URL(string: "\(config.serverURL)/api/") else {
            errorMessage = "URL inválido"
            isConnected = false
            completion?(false, "URL inválido")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isConnected = false
                    completion?(false, error.localizedDescription)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        self.isConnected = true
                        self.errorMessage = nil
                        completion?(true, nil)
                        print("✅ Home Assistant conectado!")
                    } else if httpResponse.statusCode == 401 {
                        self.errorMessage = "Token inválido"
                        self.isConnected = false
                        completion?(false, "Token inválido")
                    } else {
                        self.errorMessage = "Erro HTTP \(httpResponse.statusCode)"
                        self.isConnected = false
                        completion?(false, "HTTP \(httpResponse.statusCode)")
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch Devices
    func fetchDevices(completion: @escaping ([Device]) -> Void) {
        guard let config = config, config.isValid else {
            print("❌ Home Assistant não configurado")
            completion([])
            return
        }
        
        guard let url = URL(string: "\(config.serverURL)/api/states") else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Erro ao buscar dispositivos: \(error?.localizedDescription ?? "Unknown")")
                completion([])
                return
            }
            
            do {
                let entities = try JSONDecoder().decode([HomeAssistantEntity].self, from: data)
                let devices = self.convertToDevices(entities)
                
                DispatchQueue.main.async {
                    print("✅ \(devices.count) dispositivos encontrados no Home Assistant")
                    completion(devices)
                }
            } catch {
                print("❌ Erro ao parse JSON: \(error)")
                completion([])
            }
        }.resume()
    }
    
    // MARK: - Control Device
    func controlDevice(entityId: String, service: String, serviceData: [String: Any] = [:]) {
        guard let config = config, config.isValid else { return }
        
        // Extrai domain do entity_id (ex: light.sala -> light)
        let domain = String(entityId.split(separator: ".").first ?? "")
        
        guard let url = URL(string: "\(config.serverURL)/api/services/\(domain)/\(service)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["entity_id": entityId]
        body.merge(serviceData) { _, new in new }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Erro ao controlar dispositivo: \(error.localizedDescription)")
            } else {
                print("✅ Comando enviado: \(service) para \(entityId)")
            }
        }.resume()
    }
    
    // MARK: - Convert Home Assistant Entities to Devices
    private func convertToDevices(_ entities: [HomeAssistantEntity]) -> [Device] {
        var devices: [Device] = []
        
        for entity in entities {
            // Filtra apenas entidades de interesse (lights, switches, sensors)
            guard let domain = entity.entity_id.split(separator: ".").first else { continue }
            
            var deviceType: DeviceType
            var connectionProtocol: ConnectionProtocol = .http
            
            switch String(domain) {
            case "light":
                deviceType = .led
            case "switch":
                deviceType = .light
            case "sensor":
                // Apenas sensores de temperatura/humidade
                guard entity.attributes.unit_of_measurement == "°C" ||
                      entity.attributes.unit_of_measurement == "%" else { continue }
                deviceType = .sensor
            case "binary_sensor":
                // Sensor de gás, fumo, etc
                if entity.attributes.device_class == "gas" || entity.attributes.device_class == "smoke" {
                    deviceType = .gas
                } else {
                    continue
                }
            default:
                continue
            }
            
            let device = Device(
                id: entity.entity_id,
                name: entity.attributes.friendly_name ?? entity.entity_id,
                type: deviceType,
                ip: config?.serverURL ?? "",
                connectionProtocol: connectionProtocol,
                isOnline: entity.state != "unavailable",
                state: entity.state == "on",
                room: entity.attributes.area_id ?? "Sem Divisão"
            )

            
            devices.append(device)
        }
        
        return devices
    }
}
