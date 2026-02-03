import SwiftUI

struct WiFiConfigView: View {
    @StateObject private var bleManager = BLEWiFiConfigManager()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedNetwork: WiFiNetwork?
    @State private var showPasswordInput = false
    let device: Device

    var body: some View {
        NavigationView {
            ZStack {
                // Fundo Consistente
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                LinearGradient(
                    colors: [themeManager.accentColor.opacity(0.1), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    StatusBannerView(status: bleManager.connectionStatus)
                        .padding(.vertical)

                    ScrollView {
                        VStack(spacing: 16) {
                            if bleManager.connectionStatus == .disconnected {
                                // ETAPA 1: PROCURAR DISPOSITIVOS
                                sectionHeader(title: "Sensores Próximos", icon: "dot.radiowaves.left.and.right")
                                
                                ForEach(bleManager.discoveredDevices) { discovered in
                                    BLEDeviceCard(name: discovered.name) {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        bleManager.connect(to: discovered)
                                    }
                                }
                            } else if bleManager.isScanning {
                                // ETAPA 2: PROCURAR REDES
                                VStack(spacing: 30) {
                                    Spacer(minLength: 50)
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .tint(themeManager.accentColor)
                                    Text("O sensor está a procurar redes Wi-Fi...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                // ETAPA 3: LISTA DE REDES WIFI
                                sectionHeader(title: "Redes Encontradas", icon: "wifi")
                                
                                ForEach(bleManager.networks) { network in
                                    WiFiNetworkCard(network: network) {
                                        selectedNetwork = network
                                        if network.secure {
                                            showPasswordInput = true
                                        } else {
                                            bleManager.configureWiFi(ssid: network.ssid, password: "")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Configurar Wi-Fi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fechar") {
                        bleManager.disconnect()
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showPasswordInput) {
                if let network = selectedNetwork {
                    PasswordInputView(networkName: network.ssid) { pass in
                        bleManager.configureWiFi(ssid: network.ssid, password: pass)
                        showPasswordInput = false
                    }
                    .environmentObject(themeManager)
                }
            }
            .onAppear { bleManager.startScanning() }
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
        }
        .font(.caption.bold())
        .foregroundColor(.secondary)
        .padding(.leading, 5)
    }
}

// MARK: - COMPONENTES REUTILIZÁVEIS

struct BLEDeviceCard: View {
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 40, height: 40)
                    Image(systemName: "bolt.bluetooth.fill").foregroundColor(.blue)
                }
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

struct WiFiNetworkCard: View {
    let network: WiFiNetwork
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                Text(network.ssid)
                    .font(.body.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                if network.secure {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

struct StatusBannerView: View {
    let status: ConnectionStatus
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status == .connected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .shadow(color: status == .connected ? .green : .orange, radius: 4)
            
            Text(status == .connected ? "Ligado ao Sensor" : "Bluetooth: À procura...")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(status == .connected ? .primary : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }
}

struct PasswordInputView: View {
    let networkName: String
    let onSubmit: (String) -> Void
    @State private var password = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                VStack(spacing: 25) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(themeManager.accentColor)
                        .padding(.top, 40)
                    
                    VStack(spacing: 8) {
                        Text("Introduza a Password")
                            .font(.title2.bold())
                        Text("Para a rede \(networkName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    SecureField("Password Wi-Fi", text: $password)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    Button {
                        onSubmit(password)
                        dismiss()
                    } label: {
                        Text("Configurar Sensor")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.accentColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
