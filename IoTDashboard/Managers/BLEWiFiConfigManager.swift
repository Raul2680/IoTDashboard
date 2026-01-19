import Foundation
import CoreBluetooth
import Combine

class BLEWiFiConfigManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var networks: [WiFiNetwork] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isScanning = false
    @Published var statusMessage = ""
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var scanChar: CBCharacteristic?
    private var configChar: CBCharacteristic?
    
    // UUIDs do ESP32
    private let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    private let scanUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    private let configUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a9")
    
    private var connectionTimer: Timer?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func connect(to device: Device) {
        print("🔵 [BLE] ========================================")
        print("🔵 [BLE] A INICIAR SCAN BLE")
        print("🔵 [BLE] Estado do Bluetooth: \(centralManager.state.rawValue)")
        print("🔵 [BLE] ========================================")
        
        statusMessage = "A procurar ESP32-Sensor..."
        connectionStatus = .connecting
        
        // ✅ Aumenta timeout para 30 segundos
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout()
        }
        
        // Para o scan anterior se existir
        centralManager.stopScan()
        
        // Aguarda 1 segundo e inicia novo scan
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            print("🔍 [BLE] A INICIAR SCAN AGORA...")
            self.centralManager.scanForPeripherals(
                withServices: nil,
                options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: false
                ]
            )
            print("✅ [BLE] Scan iniciado com sucesso")
        }
    }
    
    private func handleConnectionTimeout() {
        guard connectionStatus == .connecting else { return }
        
        print("❌❌❌ [BLE] TIMEOUT - ESP32-Sensor não encontrado em 30 segundos")
        print("❌ [BLE] Dispositivos encontrados durante o scan: \(peripheral == nil ? "NENHUM" : "Alguns, mas não o ESP32")")
        statusMessage = "❌ ESP32-Sensor não encontrado. Verifica se está ligado."
        connectionStatus = .disconnected
        centralManager.stopScan()
    }
    
    func configureWiFi(ssid: String, password: String) {
        guard let char = configChar, let data = "\(ssid):\(password)".data(using: .utf8) else {
            statusMessage = "❌ Erro ao preparar credenciais"
            return
        }
        print("📡 [BLE] A enviar: \(ssid):\(String(repeating: "*", count: password.count))")
        statusMessage = "⏳ A enviar credenciais..."
        peripheral?.writeValue(data, for: char, type: .withResponse)
    }
    
    // MARK: - Central Manager Delegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔵 [BLE] ========================================")
        print("🔵 [BLE] ESTADO DO BLUETOOTH MUDOU")
        print("🔵 [BLE] Estado: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            print("✅✅✅ [BLE] Bluetooth está LIGADO e PRONTO!")
            statusMessage = "Bluetooth pronto"
        case .poweredOff:
            print("❌❌❌ [BLE] Bluetooth está DESLIGADO!")
            statusMessage = "❌ Ativa o Bluetooth nas definições"
            connectionStatus = .disconnected
        case .unauthorized:
            print("❌❌❌ [BLE] SEM PERMISSÃO!")
            statusMessage = "❌ Sem permissão para Bluetooth"
            connectionStatus = .disconnected
        case .unsupported:
            print("❌❌❌ [BLE] Bluetooth NÃO SUPORTADO neste dispositivo")
            statusMessage = "❌ Bluetooth não suportado"
        case .resetting:
            print("⚠️ [BLE] Bluetooth a REINICIAR...")
            statusMessage = "Bluetooth a reiniciar..."
        case .unknown:
            print("⚠️ [BLE] Estado DESCONHECIDO")
            statusMessage = "Estado desconhecido..."
        @unknown default:
            print("⚠️ [BLE] Estado INESPERADO")
        }
        print("🔵 [BLE] ========================================")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "[Sem Nome]"
        let uuid = peripheral.identifier.uuidString
        
        // ✅ MOSTRA TODOS OS DISPOSITIVOS ENCONTRADOS
        print("📡 [BLE] Dispositivo: '\(name)' | UUID: \(uuid.prefix(8))... | RSSI: \(RSSI)dBm")
        
        // Mostra dados de advertising
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            print("   📦 Serviços: \(serviceUUIDs.map { $0.uuidString })")
        }
        
        // ✅ Verifica múltiplas condições
        let hasTargetService = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        let containsServiceUUID = hasTargetService?.contains(serviceUUID) == true
        let nameMatches = name.contains("ESP32") || name.contains("Sensor")
        
        print("   🔍 Contém serviceUUID? \(containsServiceUUID)")
        print("   🔍 Nome corresponde? \(nameMatches)")
        
        if containsServiceUUID || nameMatches {
            print("✅✅✅ [BLE] ESP32 IDENTIFICADO!")
            print("✅✅✅ [BLE] Nome: \(name)")
            print("✅✅✅ [BLE] A CONECTAR AGORA...")
            
            self.peripheral = peripheral
            centralManager.stopScan()
            connectionTimer?.invalidate()
            statusMessage = "ESP32 encontrado! A conectar..."
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅✅✅ [BLE] CONECTADO AO \(peripheral.name ?? "ESP32")!")
        print("✅ [BLE] A descobrir serviços...")
        connectionStatus = .connected
        statusMessage = "Conectado! A procurar serviços..."
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌❌❌ [BLE] FALHA AO CONECTAR!")
        print("❌ [BLE] Erro: \(error?.localizedDescription ?? "Desconhecido")")
        statusMessage = "❌ Falha ao conectar: \(error?.localizedDescription ?? "Erro desconhecido")"
        connectionStatus = .disconnected
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("⚠️ [BLE] DESCONECTADO do \(peripheral.name ?? "ESP32")")
        if let error = error {
            print("❌ [BLE] Erro: \(error.localizedDescription)")
            statusMessage = "❌ Desconectado: \(error.localizedDescription)"
        }
        connectionStatus = .disconnected
    }
    
    // MARK: - Peripheral Delegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ [BLE] Erro ao descobrir serviços: \(error)")
            statusMessage = "❌ Erro: \(error.localizedDescription)"
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            print("❌ [BLE] Nenhum serviço encontrado no ESP32")
            statusMessage = "❌ Serviço BLE não encontrado"
            return
        }
        
        print("✅ [BLE] \(services.count) serviço(s) encontrado(s):")
        for service in services {
            print("   📦 Serviço: \(service.uuid)")
            peripheral.discoverCharacteristics([scanUUID, configUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("❌ [BLE] Erro ao descobrir características: \(error)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("❌ [BLE] Nenhuma característica encontrada")
            return
        }
        
        print("✅ [BLE] \(characteristics.count) característica(s) encontrada(s):")
        
        for char in characteristics {
            print("   📝 \(char.uuid)")
            
            if char.uuid == scanUUID {
                scanChar = char
                print("✅✅✅ [BLE] Scan Characteristic ENCONTRADA!")
                scanWiFiNetworks()
            }
            
            if char.uuid == configUUID {
                configChar = char
                print("✅✅✅ [BLE] Config Characteristic ENCONTRADA!")
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ [BLE] Erro ao ler característica: \(error)")
            return
        }
        
        guard let data = characteristic.value, let message = String(data: data, encoding: .utf8) else {
            print("❌ [BLE] Dados inválidos recebidos")
            return
        }
        
        print("📩 [BLE] Recebido (\(data.count) bytes): \(message.prefix(200))")
        
        DispatchQueue.main.async {
            if characteristic.uuid == self.scanUUID {
                print("📡 [BLE] A processar lista de redes WiFi...")
                self.parseNetworks(message)
            } else if characteristic.uuid == self.configUUID {
                print("📩 [BLE] Resposta do ESP32: \(message)")
                switch message {
                case "OK":
                    self.statusMessage = "✅ Wi-Fi configurado! ESP32 vai reiniciar."
                case let msg where msg.contains("ERROR"):
                    self.statusMessage = "❌ \(msg)"
                default:
                    self.statusMessage = "ESP32: \(message)"
                }
            }
        }
    }
    
    func scanWiFiNetworks() {
        guard let char = scanChar else {
            print("❌ [BLE] Scan Characteristic não está disponível")
            statusMessage = "❌ Não foi possível iniciar scan"
            return
        }
        
        print("🔍 [BLE] A pedir scan de redes WiFi ao ESP32...")
        isScanning = true
        statusMessage = "A procurar redes WiFi..."
        peripheral?.readValue(for: char)
        
        // Timeout de 15 segundos para o scan
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isScanning == true {
                print("⚠️ [BLE] Timeout no scan de redes WiFi")
                self?.isScanning = false
                if self?.networks.isEmpty == true {
                    self?.statusMessage = "⚠️ Nenhuma rede encontrada"
                }
            }
        }
    }
    
    private func parseNetworks(_ string: String) {
        print("📡 [BLE] String recebida: \(string.prefix(300))...")
        
        let parts = string.split(separator: ";")
        print("📡 [BLE] \(parts.count) rede(s) no formato bruto")
        
        self.networks = parts.compactMap { net in
            let fields = net.split(separator: ":")
            guard fields.count == 3 else {
                print("⚠️ [BLE] Rede com formato inválido: \(net)")
                return nil
            }
            
            let ssid = String(fields[0])
            let rssi = Int(fields[1]) ?? -100
            let secure = fields[2] == "1"
            
            print("   ✅ \(ssid) | \(rssi)dBm | \(secure ? "🔒 Segura" : "🔓 Aberta")")
            return WiFiNetwork(ssid: ssid, rssi: rssi, secure: secure)
        }
        
        isScanning = false
        
        if networks.isEmpty {
            statusMessage = "⚠️ Nenhuma rede WiFi encontrada"
            print("❌ [BLE] Nenhuma rede válida após parsing")
        } else {
            statusMessage = "✅ \(networks.count) rede(s) encontrada(s)"
            print("✅✅✅ [BLE] TOTAL: \(networks.count) redes WiFi disponíveis")
        }
    }
    
    func disconnect() {
        print("🔌 [BLE] A desconectar...")
        connectionTimer?.invalidate()
        if let p = peripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        centralManager.stopScan()
        connectionStatus = .disconnected
        statusMessage = ""
    }
}
