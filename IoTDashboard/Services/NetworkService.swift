import Foundation
import Network

class NetworkService {
    static let shared = NetworkService()
    private var browser: NWBrowser?
    private var foundDevices: [Device] = []
    
    private let queue = DispatchQueue(label: "com.iot.network.bonjour")
    
    // --- CONFIGURAÇÃO MANUAL ---
    // Confirma se este IP é EXATAMENTE o que vês no log antigo.
    private let knownBulbIp = "192.168.0.220"
    private let knownBulbId = "bf947f8ad3c2f5aeafl17r"

    func scanForDevices(completion: @escaping ([Device]) -> Void) {
        foundDevices.removeAll()
        browser?.cancel()
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // Procura serviços HTTP (_http._tcp)
        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: parameters)
        self.browser = browser
        
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            
            for result in results {
                if case .service(let name, let type, let domain, _) = result.endpoint {
                    self.resolveService(name: name, type: type, domain: domain) { device in
                        if let device = device {
                            DispatchQueue.main.async {
                                // Adiciona se ainda não existir (compara pelo ID)
                                if !self.foundDevices.contains(where: { $0.id == device.id }) {
                                    self.foundDevices.append(device)
                                    completion(self.foundDevices)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        browser.start(queue: queue)
        print("🔍 Scan iniciado... À procura de \(knownBulbIp) ou 'Bedroom'...")
    }
    
    private func resolveService(name: String, type: String, domain: String, completion: @escaping (Device?) -> Void) {
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, _) = innerEndpoint {
                    
                    // 1. Limpeza agressiva do IP
                    var ip = "\(host)"
                    // Remove interface (ex: %en0)
                    ip = ip.components(separatedBy: "%").first ?? ip
                    // Remove prefixo IPv6 mapped (ex: ::ffff:192.168.0.220)
                    ip = ip.replacingOccurrences(of: "::ffff:", with: "")
                    
                    // 2. Normalização do nome para comparação
                    let cleanName = name.lowercased()
                    let isLed = cleanName.contains("led") || cleanName.contains("light")

                    let newDevice = Device(
                        id: ip, // Usamos o IP como ID único agora
                        name: name,
                        type: isLed ? .led : .sensor,
                        ip: ip,
                        connectionProtocol: isLed ? .udp : .http,
                        isOnline: true,
                        state: false,
                        temperature: 0.0,
                        humidity: 0.0,
                        gasLevel: 0,
                        lastUpdate: Date(),
                        ledState: nil
                    )

                    completion(newDevice)
                    connection.cancel()
                }
            case .failed(_):
                connection.cancel()
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
}
