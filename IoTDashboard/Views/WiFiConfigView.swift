import SwiftUI
import CoreBluetooth

// MARK: - Modelo de Rede Wi-Fi
struct WiFiNetwork: Identifiable, Codable {
    let ssid: String
    let rssi: Int
    let secure: Bool
    
    var id: String { ssid }
}

// MARK: - WiFi Config View
struct WiFiConfigView: View {
    @StateObject private var bleManager = BLEWiFiConfigManager()
    @Environment(\.dismiss) var dismiss
    @State private var selectedNetwork: WiFiNetwork?
    @State private var password = ""
    @State private var showPasswordInput = false
    
    let device: Device
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Estado da conexão BLE
                StatusBanner(status: bleManager.connectionStatus)
                
                if bleManager.isScanning {
                    ProgressView("A procurar redes...")
                        .padding()
                } else if bleManager.networks.isEmpty && bleManager.connectionStatus == .connected {
                    VStack {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Nenhuma rede encontrada")
                            .foregroundColor(.secondary)
                        
                        Button("Escanear Redes") {
                            bleManager.scanWiFiNetworks()
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                } else if bleManager.connectionStatus == .connected {
                    List {
                        ForEach(bleManager.networks) { network in
                            Button {
                                selectedNetwork = network
                                if network.secure {
                                    showPasswordInput = true
                                } else {
                                    bleManager.configureWiFi(ssid: network.ssid, password: "")
                                }
                            } label: {
                                HStack {
                                    Image(systemName: wifiIcon(for: network.rssi))
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading) {
                                        Text(network.ssid)
                                            .font(.headline)
                                        Text(signalStrength(network.rssi))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if network.secure {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    VStack {
                        ProgressView()
                        Text("A conectar ao dispositivo...")
                            .padding()
                    }
                }
                
                if !bleManager.statusMessage.isEmpty {
                    Text(bleManager.statusMessage)
                        .foregroundColor(bleManager.statusMessage.contains("✅") ? .green : .red)
                        .padding()
                }
            }
            .navigationTitle("Configurar Wi-Fi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        bleManager.disconnect()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bleManager.connectionStatus == .connected {
                        Button {
                            bleManager.scanWiFiNetworks()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPasswordInput) {
                if let network = selectedNetwork {
                    PasswordInputView(
                        networkName: network.ssid,
                        onSubmit: { pass in
                            bleManager.configureWiFi(ssid: network.ssid, password: pass)
                            showPasswordInput = false
                        }
                    )
                }
            }
            .onAppear {
                bleManager.connect(to: device)
            }
            .onDisappear {
                bleManager.disconnect()
            }
        }
    }
    
    func wifiIcon(for rssi: Int) -> String {
        if rssi > -50 { return "wifi" }
        if rssi > -70 { return "wifi" }
        return "wifi.slash"
    }
    
    func signalStrength(_ rssi: Int) -> String {
        if rssi > -50 { return "Excelente" }
        if rssi > -70 { return "Bom" }
        return "Fraco"
    }
}

// MARK: - Status Banner
struct StatusBanner: View {
    let status: ConnectionStatus
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            Text(statusText)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(statusColor.opacity(0.2)))
        .padding(.top, 10)
    }
    
    var statusIcon: String {
        switch status {
        case .disconnected: return "antenna.radiowaves.left.and.right.slash"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected: return .green
        }
    }
    
    var statusText: String {
        switch status {
        case .disconnected: return "Desconectado"
        case .connecting: return "A conectar via BLE..."
        case .connected: return "Conectado via Bluetooth"
        }
    }
}

// MARK: - Password Input View
struct PasswordInputView: View {
    let networkName: String
    let onSubmit: (String) -> Void
    @State private var password = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Rede: \(networkName)")
                    .font(.headline)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Conectar") {
                    onSubmit(password)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
            .padding()
            .navigationTitle("Password da Rede")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Connection Status Enum
enum ConnectionStatus {
    case disconnected, connecting, connected
}
