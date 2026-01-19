import Foundation
import Network

class UDPService {
    private var connection: NWConnection?
    private let deviceIP: String
    private let port: UInt16 = 4210  // Porta UDP do ESP32
    
    init(ip: String) {
        self.deviceIP = ip
        setupConnection()
    }
    
    private func setupConnection() {
        let host = NWEndpoint.Host(deviceIP)
        let port = NWEndpoint.Port(rawValue: self.port)!
        
        connection = NWConnection(host: host, port: port, using: .udp)
        connection?.start(queue: .global())
    }
    
    func sendCommand(_ command: String) {
        let data = command.data(using: .utf8)
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("❌ UDP Erro ao enviar \(command): \(error)")
            } else {
                print("✅ UDP Enviado: \(command)")
            }
        })
    }
    
    func sendColor(r: Int, g: Int, b: Int, brightness: Int) {
        let command = "COLOR:\(r),\(g),\(b),\(brightness)"
        sendCommand(command)
    }
    
    func stop() {
        connection?.cancel()
        connection = nil
    }
}
