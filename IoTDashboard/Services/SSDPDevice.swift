import Foundation
import Network
import Combine

// Modelo simples para o dispositivo encontrado
struct SSDPDevice: Identifiable, Hashable {
    let id = UUID()
    var location: String
    var server: String
    var st: String
    var ip: String
    
    func hash(into hasher: inout Hasher) { hasher.combine(location) }
    static func == (lhs: SSDPDevice, rhs: SSDPDevice) -> Bool { return lhs.location == rhs.location }
}

class SSDPService: ObservableObject {
    @Published var foundDevices: [SSDPDevice] = []
    
    private var connection: NWConnection?
    private let multicastGroup = NWEndpoint.Host("239.255.255.250")
    private let port = NWEndpoint.Port(integerLiteral: 1900)
    private let queue = DispatchQueue(label: "com.iot.ssdp")
    
    private let message = """
    M-SEARCH * HTTP/1.1\r
    HOST: 239.255.255.250:1900\r
    MAN: "ssdp:discover"\r
    MX: 2\r
    ST: ssdp:all\r
    \r
    """
    
    func startDiscovery() {
        print("📡 A iniciar descoberta SSDP (Modo Compatibilidade)...")
        
        // 1. Criar parâmetros UDP padrão (sem restrições de interface)
        let parameters = NWParameters.udp
        
        // Permite reutilizar a porta 1900 (crucial para SSDP)
        parameters.allowLocalEndpointReuse = true
        
        // Tenta usar IPv4 (dispositivos IoT antigos preferem isto)
        if let ipProtocol = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipProtocol.version = .v4
        }
        
        // ⚠️ REMOVIDO: requiredInterfaceType e prohibitedInterfaceTypes
        // A causa do erro 50 era tentar forçar o iOS a ignorar interfaces.
        // Agora deixamos o sistema escolher a melhor rota (que será o Wi-Fi se disponível).
        
        // 2. Criar a conexão
        self.connection = NWConnection(host: multicastGroup, port: port, using: parameters)
        
        // 3. Listener de estado
        self.connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ Socket SSDP Aberto! A enviar M-SEARCH...")
                self?.sendSearchPacket()
                self?.receiveResponse()
            case .failed(let error):
                print("❌ Falha SSDP: \(error.localizedDescription)")
                self?.restartDiscovery()
            case .waiting(let error):
                print("⏳ A aguardar rede (Erro: \(error.localizedDescription))...")
                // Se continuar a dar erro 50 aqui, é garantidamente problema de Entitlement (ver abaixo)
            case .cancelled:
                print("🛑 SSDP Cancelado.")
            default:
                break
            }
        }
        
        self.connection?.start(queue: queue)
    }
    
    private func restartDiscovery() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.connection?.state != .ready {
                self.stopDiscovery()
                self.startDiscovery()
            }
        }
    }
    
    func stopDiscovery() {
        connection?.cancel()
        connection = nil
    }
    
    private func sendSearchPacket() {
        guard let data = message.data(using: .utf8) else { return }
        
        // Envia várias vezes
        for i in 0..<3 {
            queue.asyncAfter(deadline: .now() + Double(i) * 1.0) {
                self.connection?.send(content: data, completion: .contentProcessed({ error in
                    if let error = error {
                        print("❌ Erro envio: \(error)")
                    } else {
                        print("📤 M-SEARCH enviado (\(i+1))")
                    }
                }))
            }
        }
    }
    
    private func receiveResponse() {
        connection?.receiveMessage { [weak self] (content, context, isComplete, error) in
            if let data = content, let responseString = String(data: data, encoding: .utf8) {
                self?.parseResponse(responseString)
            }
            if error == nil {
                self?.receiveResponse()
            }
        }
    }
    
    private func parseResponse(_ response: String) {
        let lines = response.components(separatedBy: "\r\n")
        var headers: [String: String] = [:]
        
        for line in lines {
            if let range = line.range(of: ": ") {
                let key = String(line[..<range.lowerBound]).uppercased()
                let value = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        
        if let location = headers["LOCATION"] {
            let ip = extractIP(from: location)
            // Tenta obter o nome mais amigável possível
            let server = headers["FRIENDLYNAME"] ?? headers["SERVER"] ?? headers["ST"] ?? "Smart Device"
            
            if !ip.isEmpty && ip != "0.0.0.0" {
                let newDevice = SSDPDevice(
                    location: location,
                    server: server,
                    st: headers["ST"] ?? "Unknown",
                    ip: ip
                )
                
                DispatchQueue.main.async {
                    if !self.foundDevices.contains(where: { $0.location == newDevice.location }) {
                        print("💡 SSDP Encontrado: \(ip) (\(server))")
                        self.foundDevices.append(newDevice)
                    }
                }
            }
        }
    }
    
    private func extractIP(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            // Fallback para IPs crus
            if let range = urlString.range(of: "//"), let portRange = urlString.range(of: ":", options: .backwards) {
                let start = range.upperBound
                let end = portRange.lowerBound
                if start < end { return String(urlString[start..<end]) }
            }
            return ""
        }
        return host
    }
}
