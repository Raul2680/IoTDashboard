import SwiftUI

struct AddDeviceView: View {
    // ✅ TODAS as variáveis de estado NO INÍCIO
    @Environment(\.dismiss) var dismiss
    @ObservedObject var deviceVM: DeviceViewModel
    
    @StateObject private var bonjourService = BonjourService()
    @StateObject private var ssdpService = SSDPService()
    
    @State private var isScanning = false
    @State private var manualIP = ""
    @State private var manualName = ""
    @State private var selectedType: DeviceType = .sensor
    @State private var showEditSheet = false
    @State private var deviceToEdit: Device?
    
    let availableIcons = ["lightbulb.fill", "thermometer.medium", "exclamationmark.triangle.fill", "tv", "speaker.wave.3.fill", "hub.fill", "network", "smoke.fill"]
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Scan Section
                Section {
                    Button(action: startScan) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text(isScanning ? "A procurar..." : "Procurar Dispositivos")
                            Spacer()
                            if isScanning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isScanning)
                } header: {
                    Text("Descoberta Automática")
                }
                
                // MARK: - Dispositivos Encontrados Bonjour
                if !bonjourService.discoveredIPs.isEmpty {
                    Section {
                        ForEach(bonjourService.discoveredIPs, id: \.self) { ip in
                            HStack {
                                Image(systemName: "network")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("Dispositivo em \(ip)")
                                        .font(.headline)
                                    Text("mDNS/Bonjour")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Adicionar") {
                                    testAndAddDevice(ip: ip)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } header: {
                        Text("Encontrados via Bonjour (\(bonjourService.discoveredIPs.count))")
                    }
                }
                
                // MARK: - Dispositivos Encontrados SSDP
                if !ssdpService.foundDevices.isEmpty {
                    Section {
                        ForEach(ssdpService.foundDevices) { device in
                            HStack {
                                Image(systemName: "network")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text(device.ip)
                                        .font(.headline)
                                    Text(device.server)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Adicionar") {
                                    testAndAddDevice(ip: device.ip)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } header: {
                        Text("Encontrados via SSDP (\(ssdpService.foundDevices.count))")
                    }
                }
                
                // MARK: - Adição Manual
                Section {
                    TextField("Nome do Dispositivo", text: $manualName)
                    
                    TextField("IP (ex: 192.168.1.100)", text: $manualIP)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Picker("Tipo", selection: $selectedType) {
                        Text("💡 LED").tag(DeviceType.led)
                        Text("🌡️ Sensor").tag(DeviceType.sensor)
                        Text("💨 Gás").tag(DeviceType.gas)
                        Text("🔆 Luz").tag(DeviceType.light)
                    }
                    
                    Button("Adicionar Manualmente") {
                        addManualDevice()
                    }
                    .disabled(manualIP.isEmpty || manualName.isEmpty)
                } header: {
                    Text("Adicionar Manualmente")
                } footer: {
                    Text("Insere o IP do teu ESP32 manualmente se não for descoberto automaticamente.")
                }
                
                // MARK: - Dispositivos já Adicionados
                if !deviceVM.devices.isEmpty {
                    Section {
                        ForEach(deviceVM.devices) { device in
                            HStack {
                                Image(systemName: iconName(for: device.type))
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.headline)
                                    Text(device.ip)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Circle()
                                    .fill(device.isOnline ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                deviceToEdit = device
                                showEditSheet = true
                            }
                        }
                        .onDelete(perform: deleteDevices)
                    } header: {
                        Text("Já Adicionados (\(deviceVM.devices.count))")
                    }
                }
            }
            .navigationTitle("Adicionar Dispositivo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                startScan()
            }
            .sheet(isPresented: $showEditSheet) {
                if let device = deviceToEdit {
                    EditDeviceView(device: device, deviceVM: deviceVM)
                }
            }
        }
    }
    
    // MARK: - Funções
    private func startScan() {
        isScanning = true
        bonjourService.discoveredIPs.removeAll()
        ssdpService.foundDevices.removeAll()
        
        bonjourService.start()
        ssdpService.startDiscovery()
        
        print("🔍 A procurar dispositivos na rede...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            isScanning = false
            print("✅ Scan concluído. Encontrados: \(bonjourService.discoveredIPs.count + ssdpService.foundDevices.count)")
        }
    }
    
    private func testAndAddDevice(ip: String) {
        guard let url = URL(string: "http://\(ip)/status") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Não foi possível obter dados de \(ip)")
                return
            }
            
            DispatchQueue.main.async {
                var type = DeviceType.sensor
                var name = "Dispositivo"
                
                if json["temperature"] != nil {
                    type = .sensor
                    name = "Sensor DHT"
                } else if json["gas"] != nil {
                    type = .gas
                    name = "Sensor Gás"
                } else if json["red"] != nil || json["r"] != nil {
                    type = .led
                    name = "LED RGB"
                }
                
                let newDevice = Device(
                    id: UUID().uuidString,
                    name: name,
                    type: type,
                    ip: ip,
                    connectionProtocol: .http,
                    isOnline: true
                )
                
                deviceVM.devices.append(newDevice)
                print("✅ Dispositivo adicionado: \(name) em \(ip)")
            }
        }.resume()
    }
    
    private func addManualDevice() {
        let newDevice = Device(
            id: UUID().uuidString,
            name: manualName,
            type: selectedType,
            ip: manualIP,
            connectionProtocol: selectedType == .led ? .udp : .http,
            isOnline: false
        )
        
        deviceVM.devices.append(newDevice)
        
        manualName = ""
        manualIP = ""
        
        print("✅ Dispositivo manual adicionado: \(newDevice.name)")
    }
    
    private func deleteDevices(at offsets: IndexSet) {
        deviceVM.devices.remove(atOffsets: offsets)
    }
    
    private func iconName(for type: DeviceType) -> String {
        switch type {
        case .light, .led:
            return "lightbulb.fill"
        case .sensor:
            return "thermometer.medium"
        case .gas:
            return "smoke.fill"
        }
    }
}
