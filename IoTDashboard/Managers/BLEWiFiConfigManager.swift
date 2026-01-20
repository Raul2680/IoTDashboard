import Foundation
import CoreBluetooth
import Combine

class BLEWiFiConfigManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var networks: [WiFiNetwork] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isScanning = false
    @Published var statusMessage = ""
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var scanChar: CBCharacteristic?
    private var configChar: CBCharacteristic?
    
    // UUIDs (Devem coincidir exatamente com o código do ESP32)
    private let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    private let scanUUID    = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    private let configUUID  = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a9")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func connect(to discovered: DiscoveredDevice) {
        centralManager.stopScan()
        self.peripheral = discovered.peripheral
        self.connectionStatus = .connecting
        centralManager.connect(discovered.peripheral, options: nil)
    }

    // MARK: - Delegate Bluetooth
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { startScanning() }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(where: { $0.id == peripheral.identifier }) {
            let name = peripheral.name ?? "ESP32-Sensor"
            discoveredDevices.append(DiscoveredDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue, peripheral: peripheral))
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Ligado ao hardware. A descobrir serviços...")
        self.connectionStatus = .connected
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print("📦 Serviço encontrado: \(service.uuid)")
            peripheral.discoverCharacteristics([scanUUID, configUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == scanUUID {
                self.scanChar = char
                print("🔍 Característica de SCAN encontrada. A pedir redes...")
                // ✅ DISPARA O SCAN AUTOMATICAMENTE AO ENCONTRAR A CARACTERÍSTICA
                scanWiFiNetworks()
            }
            if char.uuid == configUUID {
                self.configChar = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    func scanWiFiNetworks() {
        guard let char = scanChar else {
            print("❌ Erro: Característica de scan não disponível.")
            return
        }
        DispatchQueue.main.async { self.isScanning = true }
        print("📡 A ler redes do ESP32...")
        peripheral?.readValue(for: char)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Erro na leitura: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value, let msg = String(data: data, encoding: .utf8) else { return }
        
        DispatchQueue.main.async {
            if characteristic.uuid == self.scanUUID {
                print("📩 Redes recebidas: \(msg)")
                self.parseNetworks(msg)
            } else if characteristic.uuid == self.configUUID {
                self.statusMessage = msg == "OK" ? "✅ Configurado com sucesso!" : "ESP32: \(msg)"
            }
        }
    }

    private func parseNetworks(_ string: String) {
        let parts = string.split(separator: ";")
        self.networks = parts.compactMap { net in
            let fields = net.split(separator: ":")
            guard fields.count == 3 else { return nil }
            return WiFiNetwork(ssid: String(fields[0]), rssi: Int(fields[1]) ?? -100, secure: fields[2] == "1")
        }
        self.isScanning = false
        if networks.isEmpty { self.statusMessage = "Nenhuma rede encontrada." }
    }
    
    func configureWiFi(ssid: String, password: String) {
        guard let char = configChar, let data = "\(ssid):\(password)".data(using: .utf8) else { return }
        peripheral?.writeValue(data, for: char, type: .withResponse)
    }

    func disconnect() {
        if let p = peripheral { centralManager.cancelPeripheralConnection(p) }
        connectionStatus = .disconnected
    }
}
