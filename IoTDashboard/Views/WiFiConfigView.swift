import SwiftUI

struct WiFiConfigView: View {
    @StateObject private var bleManager = BLEWiFiConfigManager()
    @Environment(\.dismiss) var dismiss
    @State private var selectedNetwork: WiFiNetwork?
    @State private var showPasswordInput = false
    let device: Device

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                StatusBannerView(status: bleManager.connectionStatus)
                
                if bleManager.connectionStatus == .disconnected {
                    List(bleManager.discoveredDevices) { discovered in
                        Button(action: { bleManager.connect(to: discovered) }) {
                            HStack {
                                Text(discovered.name).bold()
                                Spacer()
                                Image(systemName: "bolt.bluetooth.fill").foregroundColor(.blue)
                            }
                        }
                    }
                } else if bleManager.isScanning {
                    // ✅ MOSTRA O CARREGAMENTO ENQUANTO ESPERA PELO ESP32
                    VStack(spacing: 20) {
                        Spacer()
                        ProgressView()
                        Text("O sensor está a procurar redes Wi-Fi...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(bleManager.networks) { network in
                        Button(action: {
                            selectedNetwork = network
                            if network.secure { showPasswordInput = true }
                            else { bleManager.configureWiFi(ssid: network.ssid, password: "") }
                        }) {
                            HStack {
                                Image(systemName: "wifi").foregroundColor(.blue)
                                Text(network.ssid)
                                Spacer()
                                if network.secure { Image(systemName: "lock.fill").foregroundColor(.gray) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Configurar Wi-Fi")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { bleManager.disconnect(); dismiss() }
                }
            }
            .sheet(isPresented: $showPasswordInput) {
                if let network = selectedNetwork {
                    PasswordInputView(networkName: network.ssid) { pass in
                        bleManager.configureWiFi(ssid: network.ssid, password: pass)
                        showPasswordInput = false
                    }
                }
            }
            .onAppear { bleManager.startScanning() }
        }
    }
}

// MARK: - Sub-Views (Resolvendo Erros de Scope)
struct StatusBannerView: View {
    let status: ConnectionStatus
    var body: some View {
        HStack {
            Circle().fill(status == .connected ? .green : .orange).frame(width: 8, height: 8)
            Text(status == .connected ? "Ligado via Bluetooth" : "Procurar Sensores...")
                .font(.caption.bold())
        }
        .padding(10).background(Capsule().fill(Color.gray.opacity(0.1)))
    }
}

struct PasswordInputView: View {
    let networkName: String
    let onSubmit: (String) -> Void
    @State private var password = ""
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Rede: \(networkName)").font(.headline)
                SecureField("Password Wi-Fi", text: $password).textFieldStyle(.roundedBorder).padding()
                Button("Enviar") { onSubmit(password); dismiss() }.buttonStyle(.borderedProminent)
            }
            .toolbar { Button("Voltar") { dismiss() } }
        }
    }
}
