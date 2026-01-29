import SwiftUI

struct AddDeviceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager // Adicionado para consistência
    @ObservedObject var deviceVM: DeviceViewModel
    
    @StateObject private var bonjourService = BonjourService()
    @StateObject private var ssdpService = SSDPService()
    
    @State private var isScanning = false
    @State private var manualIP = ""
    @State private var manualName = ""
    @State private var selectedType: DeviceType = .sensor
    @State private var showEditSheet = false
    @State private var deviceToEdit: Device?
    
    var body: some View {
        NavigationView {
            ZStack {
                // 1. Fundo Premium dinâmico
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                BackgroundPatternView(theme: themeManager.currentTheme)
                    .opacity(0.3)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header de Scan com animação
                        scanHeader
                        
                        // Resultados Bonjour
                        if !bonjourService.discoveredIPs.isEmpty {
                            discoverySection(
                                title: "Bonjour / mDNS",
                                icon: "bolt.horizontal.circle.fill",
                                ips: bonjourService.discoveredIPs
                            )
                        }
                        
                        // Resultados SSDP
                        if !ssdpService.foundDevices.isEmpty {
                            ssdpSection
                        }
                        
                        // Adicionar Manual (Card Glass)
                        manualAddSection
                        
                        // Lista de já adicionados
                        if !deviceVM.devices.isEmpty {
                            existingDevicesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Novo Dispositivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                }
            }
            .onAppear { startScan() }
            .sheet(isPresented: $showEditSheet) {
                if let device = deviceToEdit {
                    EditDeviceView(device: device, deviceVM: deviceVM)
                }
            }
        }
    }
    
    // MARK: - Componentes de UI (Estilo Premium)
    
    private var scanHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 30))
                    .foregroundColor(themeManager.accentColor)
                    .symbolEffect(.variableColor.iterative, isActive: isScanning)
            }
            
            Button(action: startScan) {
                Text(isScanning ? "A procurar..." : "Procurar Dispositivos")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(isScanning ? Color.gray : themeManager.accentColor)
                    .clipShape(Capsule())
            }
            .disabled(isScanning)
        }
        .padding(.vertical)
    }
    
    private func discoverySection(title: String, icon: String, ips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                ForEach(ips, id: \.self) { ip in
                    deviceDiscoveryRow(ip: ip, subtitle: "Protocolo mDNS")
                    if ip != ips.last { Divider().background(Color.white.opacity(0.1)) }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private var ssdpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SSDP / UPnP", systemImage: "network")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                ForEach(ssdpService.foundDevices) { device in
                    deviceDiscoveryRow(ip: device.ip, subtitle: device.server ?? "Dispositivo IoT")
                    if device.id != ssdpService.foundDevices.last?.id { Divider().background(Color.white.opacity(0.1)) }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
    
    private func deviceDiscoveryRow(ip: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(ip).font(.headline).foregroundColor(.white)
                Text(subtitle).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Button("Adicionar") { testAndAddDevice(ip: ip) }
                .buttonStyle(.bordered)
                .tint(themeManager.accentColor)
                .controlSize(.small)
        }
        .padding()
    }
    
    private var manualAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adição Manual")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .textCase(.uppercase)
            
            VStack(spacing: 16) {
                TextField("Nome do Dispositivo", text: $manualName)
                    .padding().background(Color.white.opacity(0.05)).cornerRadius(10)
                
                TextField("IP (ex: 192.168.1.100)", text: $manualIP)
                    .padding().background(Color.white.opacity(0.05)).cornerRadius(10)
                    .keyboardType(.numbersAndPunctuation)
                
                Picker("Tipo", selection: $selectedType) {
                    ForEach(DeviceType.allCases) { type in
                        Text(type.displayName)
                            .tag(type) // Importante para o binding do @State funcionar
                    }
                }
                .pickerStyle(.segmented)
                
                Button(action: addManualDevice) {
                    Text("Configurar Dispositivo")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(manualName.isEmpty || !isValidIP(manualIP))
                .opacity(manualName.isEmpty || !isValidIP(manualIP) ? 0.5 : 1)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
        }
    }
    
    private var existingDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Na sua rede (\(deviceVM.devices.count))")
                .font(.caption.bold())
                .foregroundColor(.gray)
            
            VStack(spacing: 0) {
                ForEach(deviceVM.devices) { device in
                    HStack {
                        Image(systemName: iconName(for: device.type))
                            .foregroundColor(themeManager.accentColor)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(device.name).foregroundColor(.white).font(.subheadline.bold())
                            Text(device.ip).foregroundColor(.gray).font(.caption)
                        }
                        Spacer()
                        Circle()
                            .fill(device.isOnline ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                    }
                    .padding()
                    .onTapGesture {
                        deviceToEdit = device
                        showEditSheet = true
                    }
                    
                    if device.id != deviceVM.devices.last?.id { Divider().background(Color.white.opacity(0.1)) }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }

    // MARK: - Funções de Lógica (Mantidas)
    
    private func startScan() {
        isScanning = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        bonjourService.discoveredIPs.removeAll()
        ssdpService.foundDevices.removeAll()
        bonjourService.start()
        ssdpService.startDiscovery()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isScanning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func testAndAddDevice(ip: String) {
        guard let url = URL(string: "http://\(ip)/status") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Erro ao ler JSON de \(ip)")
                return
            }
            
            print("DEBUG: JSON recebido de \(ip): \(json)") // Isto ajuda-te a ver o que o LED envia
            
            DispatchQueue.main.async {
                var type = DeviceType.sensor
                var name = "Dispositivo"
                
                // Lógica de detecção melhorada
                if json["temperature"] != nil || json["temp"] != nil {
                    type = .sensor
                    name = "Sensor DHT"
                }
                else if json["gas"] != nil || json["mq2"] != nil {
                    type = .gas
                    name = "Detector de Gás"
                }
                // Verifica várias possibilidades para o LED
                else if json["red"] != nil || json["r"] != nil || json["led"] != nil || json["rgb"] != nil {
                    type = .led
                    name = "LED RGB"
                }
                else if json["light"] != nil || json["relay"] != nil {
                    type = .light
                    name = "Luz Inteligente"
                }
                
                let newDevice = Device(
                    id: UUID().uuidString,
                    name: name,
                    type: type,
                    ip: ip,
                    connectionProtocol: .http,
                    isOnline: true
                )
                
                // Evita adicionar duplicados pelo IP
                if !deviceVM.devices.contains(where: { $0.ip == ip }) {
                    deviceVM.devices.append(newDevice)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }.resume()
    }

    private func addManualDevice() {
        let newDevice = Device(id: UUID().uuidString, name: manualName, type: selectedType, ip: manualIP, connectionProtocol: selectedType == .led ? .udp : .http, isOnline: false)
        deviceVM.devices.append(newDevice)
        manualName = ""; manualIP = ""
        dismiss()
    }

    private func isValidIP(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            if let num = Int(part), num >= 0 && num <= 255 { return true }
            return false
        }
    }

    private func iconName(for type: DeviceType) -> String {
        switch type {
        case .light, .led: return "lightbulb.fill"
        case .sensor: return "thermometer.medium"
        case .gas: return "smoke.fill"
        }
    }
}
