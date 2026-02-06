import SwiftUI
import FirebaseFirestore

struct AddDeviceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var deviceVM: DeviceViewModel
    
    // ✅ Usamos StateObject para gerir o ciclo de vida dos serviços
    @StateObject private var bonjourService = BonjourService()
    @StateObject private var ssdpService = SSDPService()
    
    @State private var isScanning = false
    @State private var manualIP = ""
    @State private var manualName = ""
    @State private var selectedType: DeviceType = .sensor
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                BackgroundPatternView(theme: themeManager.currentTheme)
                    .opacity(0.3)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        scanHeaderSection
                        
                        simulatorSection
                        
                        // 🔍 Se houver IPs descobertos, mostra a secção
                        if !bonjourService.discoveredIPs.isEmpty {
                            discoverySection(
                                title: "Dispositivos Bonjour",
                                icon: "bolt.horizontal.circle.fill",
                                ips: bonjourService.discoveredIPs
                            )
                        }
                        
                        manualAddSection
                        
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

// MARK: - LÓGICA DE FUNCIONAMENTO
extension AddDeviceView {
    
    private func startScan() {
        isScanning = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        bonjourService.start()
        ssdpService.startDiscovery()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { isScanning = false }
    }
    
    // ✅ LÓGICA DE DESCOBERTA (Onde os erros aconteciam)
    private func testAndAddDevice(ip: String) {
        // CORREÇÃO: Aceder SEM o '$'. bonjourService.discoveredNames é um [String: String]
        let discoveredName = bonjourService.discoveredNames[ip] ?? "ESP32 Desconhecido"
        
        // Criar o dispositivo usando a extension inteligente do Device.swift
        let newDevice = Device(
            name: discoveredName,
            ip: ip,
            isOnline: true
        )
        
        deviceVM.devices.append(newDevice)
        deviceVM.saveDevices()
        dismiss()
    }

    private func addManualDevice() {
        let newDevice = Device(
            name: manualName,
            ip: manualIP,
            type: selectedType,
            isOnline: true
        )
        deviceVM.devices.append(newDevice)
        deviceVM.saveDevices()
        dismiss()
    }

    private func addSimulatedDevice() {
        let types: [DeviceType] = [.sensor, .led, .gas]
        let randomType = types.randomElement() ?? .sensor
        let mockDevice = Device(
            name: "Simulado \(randomType.displayName)",
            ip: "127.0.0.1",
            type: randomType,
            isOnline: true
        )
        deviceVM.devices.append(mockDevice)
        deviceVM.saveDevices()
        dismiss()
    }

    private func isValidIP(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { Int($0) != nil }
    }
}

// MARK: - COMPONENTES DE UI
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
                    .font(.headline).foregroundColor(.white)
                    .padding(.horizontal, 30).padding(.vertical, 12)
                    .background(isScanning ? Color.gray : themeManager.accentColor)
                    .clipShape(Capsule())
            }.disabled(isScanning)
        }.padding(.vertical)
    }

    private func discoverySection(title: String, icon: String, ips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.caption.bold()).foregroundColor(.gray)
            VStack(spacing: 0) {
                ForEach(ips, id: \.self) { ip in
                    HStack {
                        VStack(alignment: .leading) {
                            // ✅ CORREÇÃO: Acesso direto ao dicionário para o componente Text
                            Text(bonjourService.discoveredNames[ip] ?? "ESP32 Descoberto")
                                .font(.headline).foregroundColor(.white)
                            Text(ip).font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Button("Add") { testAndAddDevice(ip: ip) }
                            .buttonStyle(.bordered).tint(themeManager.accentColor)
                    }
                    .padding()
                    if ip != ips.last { Divider().background(Color.white.opacity(0.1)) }
                }
            }.background(Color.white.opacity(0.05)).cornerRadius(16)
        }
    }

    private var simulatorSection: some View {
        Button(action: addSimulatedDevice) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Modo Escola").font(.headline).foregroundColor(.white)
                    Text("Simular Hardware ESP32").font(.caption).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "flask.fill").foregroundColor(.orange)
            }.padding().background(Color.orange.opacity(0.2)).cornerRadius(16)
        }
    }

    private var manualAddSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Adição Manual", systemImage: "plus.circle.fill").font(.caption.bold()).foregroundColor(.secondary)
            VStack(spacing: 15) {
                CustomInputField(icon: "tag.fill", placeholder: "Nome", text: $manualName)
                CustomInputField(icon: "network", placeholder: "IP", text: $manualIP, keyboard: .numbersAndPunctuation)
                HardwarePickerMenu(selectedType: $selectedType)
                Button("Configurar Dispositivo") { addManualDevice() }
                    .frame(maxWidth: .infinity).padding().background(themeManager.accentColor).foregroundColor(.white).cornerRadius(12)
                    .disabled(manualName.isEmpty || !isValidIP(manualIP))
            }.padding().background(Color.white.opacity(0.05)).cornerRadius(16)
        }
    }

    private var existingDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dispositivos Salvos").font(.caption.bold()).foregroundColor(.gray)
            VStack(spacing: 0) {
                ForEach(deviceVM.devices) { device in
                    HStack {
                        Image(systemName: device.type == .gas ? "smoke.fill" : "cpu").foregroundColor(themeManager.accentColor)
                        Text(device.name).foregroundColor(.white)
                        Spacer()
                        Text(device.ip).font(.caption).foregroundColor(.gray)
                    }.padding()
                }
            }.background(Color.white.opacity(0.05)).cornerRadius(16)
        }
    }
}

// MARK: - STRUCTS DE SUPORTE
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
