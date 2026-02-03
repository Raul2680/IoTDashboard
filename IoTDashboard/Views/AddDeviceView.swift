import SwiftUI
import FirebaseFirestore

// MARK: - VIEW PRINCIPAL
struct AddDeviceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var deviceVM: DeviceViewModel
    
    // Serviços de Descoberta Reais
    @StateObject private var bonjourService = BonjourService()
    @StateObject private var ssdpService = SSDPService()
    
    // Estados de UI
    @State private var isScanning = false
    @State private var manualIP = ""
    @State private var manualName = ""
    @State private var selectedType: DeviceType = .sensor
    @State private var showEditSheet = false
    @State private var deviceToEdit: Device?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fundo Base do Tema Selecionado
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                // Padrão Geométrico
                BackgroundPatternView(theme: themeManager.currentTheme)
                    .opacity(0.3)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 1. HEADER DE SCAN
                        scanHeaderSection
                        
                        // 2. SIMULADOR (MODO ESCOLA)
                        simulatorSection
                        
                        // 3. RESULTADOS BONJOUR
                        if !bonjourService.discoveredIPs.isEmpty {
                            discoverySection(
                                title: "Bonjour / mDNS",
                                icon: "bolt.horizontal.circle.fill",
                                ips: bonjourService.discoveredIPs
                            )
                        }
                        
                        // 4. ADIÇÃO MANUAL
                        manualAddSection
                        
                        // 5. DISPOSITIVOS EXISTENTES
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
        }
    }
}

// MARK: - LÓGICA DE FUNCIONAMENTO (CORREÇÕES DA IMAGEM)
extension AddDeviceView {
    
    private func startScan() {
        isScanning = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        bonjourService.start()
        ssdpService.startDiscovery()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { isScanning = false }
    }
    
    // ✅ CORREÇÃO: connectionProtocol adicionado e timestamp convertido para Int
    private func addSimulatedDevice() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let types: [DeviceType] = [.sensor, .led, .gas]
        let randomType = types.randomElement() ?? .sensor
        
        var mockDevice = Device(
            id: UUID().uuidString,
            name: "Simulado \(randomType.displayName)",
            type: randomType,
            ip: "127.0.0.1",
            connectionProtocol: .http, // Fix do erro de parâmetro na imagem
            isOnline: true
        )
        
        if randomType == .sensor {
            mockDevice.sensorData = SensorData(
                temperature: Double.random(in: 20...26),
                humidity: Double.random(in: 45...55),
                timestamp: Int(Date().timeIntervalSince1970) // Fix do erro de tipo na imagem
            )
        }
        
        deviceVM.devices.append(mockDevice)
        dismiss()
    }

    // ✅ CORREÇÃO: connectionProtocol adicionado no modo manual
    private func addManualDevice() {
        let newDevice = Device(
            id: UUID().uuidString,
            name: manualName,
            type: selectedType,
            ip: manualIP,
            connectionProtocol: selectedType == .led ? .udp : .http, // Fix do erro de parâmetro na imagem
            isOnline: true
        )
        deviceVM.devices.append(newDevice)
        dismiss()
    }

    // ✅ CORREÇÃO: connectionProtocol adicionado no modo auto
    private func testAndAddDevice(ip: String) {
        let newDevice = Device(
            id: UUID().uuidString,
            name: "ESP32 Auto",
            type: .sensor,
            ip: ip,
            connectionProtocol: .http, // Fix do erro de parâmetro na imagem
            isOnline: true
        )
        deviceVM.devices.append(newDevice)
    }

    private func isValidIP(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { Int($0) != nil }
    }
}

// MARK: - COMPONENTES DE UI (ESTRUTURA COMPLETA)

extension AddDeviceView {
    
    private var scanHeaderSection: some View {
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
    
    private var simulatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Modo Escola (Simulador)", systemImage: "flask.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.orange)
                .textCase(.uppercase)
                .padding(.leading, 4)
            
            Button(action: addSimulatedDevice) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Simular Hardware ESP32")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Gera dados fictícios (IP 127.0.0.1)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "plus.viewfinder")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.15))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }
        }
    }
    
    private var manualAddSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Adição Manual", systemImage: "plus.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            
            ManualAddContainer {
                VStack(spacing: 18) {
                    CustomInputField(icon: "tag.fill", placeholder: "Nome do Dispositivo", text: $manualName)
                    CustomInputField(icon: "network", placeholder: "Endereço IP", text: $manualIP, keyboard: .numbersAndPunctuation)
                    
                    HardwarePickerMenu(selectedType: $selectedType)
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        addManualDevice()
                    }) {
                        Text("Configurar Dispositivo")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                if manualName.isEmpty || !isValidIP(manualIP) {
                                    Color.gray.opacity(0.3)
                                } else {
                                    Rectangle().fill(themeManager.accentColor.gradient)
                                }
                            }
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(manualName.isEmpty || !isValidIP(manualIP))
                }
            }
        }
    }

    private func discoverySection(title: String, icon: String, ips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.caption.bold()).foregroundColor(.gray)
            VStack(spacing: 0) {
                ForEach(ips, id: \.self) { ip in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ip).font(.headline).foregroundColor(.white)
                            Text("Protocolo mDNS").font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Button("Add") { testAndAddDevice(ip: ip) }
                            .buttonStyle(.bordered)
                            .tint(themeManager.accentColor)
                    }
                    .padding()
                    if ip != ips.last { Divider().background(Color.white.opacity(0.1)) }
                }
            }
            .background(Color.white.opacity(0.05)).cornerRadius(16)
        }
    }

    private var existingDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dispositivos na Rede").font(.caption.bold()).foregroundColor(.gray)
            VStack(spacing: 0) {
                ForEach(deviceVM.devices) { device in
                    HStack {
                        Image(systemName: device.type == .sensor ? "thermometer.medium" : "lightbulb.fill")
                            .foregroundColor(themeManager.accentColor).frame(width: 30)
                        VStack(alignment: .leading) {
                            Text(device.name).font(.subheadline.bold()).foregroundColor(.white)
                            Text(device.ip).font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Circle().fill(device.isOnline ? .green : .red).frame(width: 8, height: 8)
                    }
                    .padding()
                }
            }
            .background(Color.white.opacity(0.05)).cornerRadius(16)
        }
    }
}

// MARK: - STRUCTS DE SUPORTE (INDISPENSÁVEIS)
struct ManualAddContainer<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(20).background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 0.5)))
    }
}

struct HardwarePickerMenu: View {
    @Binding var selectedType: DeviceType
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        Menu {
            ForEach(DeviceType.allCases) { type in
                Button(type.displayName) { selectedType = type }
            }
        } label: {
            HStack {
                Text(selectedType.displayName).foregroundColor(.white)
                Spacer(); Image(systemName: "chevron.down").font(.caption).foregroundColor(.secondary)
            }.padding().background(Color.black.opacity(0.3)).cornerRadius(12)
        }
    }
}

struct CustomInputField: View {
    let icon: String; let placeholder: String; @Binding var text: String; var keyboard: UIKeyboardType = .default
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.secondary).frame(width: 20)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.gray.opacity(0.5))).foregroundColor(.white)
        }.padding().background(Color.black.opacity(0.3)).cornerRadius(12).keyboardType(keyboard)
    }
}
