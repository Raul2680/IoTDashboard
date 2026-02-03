import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var deviceVM: DeviceViewModel
    @StateObject private var adminService = AdminService()
    @Environment(\.dismiss) var dismiss
    
    @State private var showCreateUser = false
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                List {
                    // --- ESTATÍSTICAS ---
                    Section {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Total Utilizadores").font(.caption).foregroundColor(.secondary)
                                Text("\(adminService.registeredUsers.count)")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.accentColor)
                            }
                            Spacer()
                            Image(systemName: "server.rack")
                                .font(.title).foregroundColor(themeManager.accentColor.opacity(0.6))
                        }
                        .padding(.vertical, 8)
                    } header: { Text("Base de Dados") }
                    
                    // --- SIMULADOR (ESCOLA) ---
                    Section {
                        Button(action: addFiveSimulatedDevices) {
                            Label("Gerar 5 Equipamentos Ativos", systemImage: "cpu.fill")
                                .foregroundColor(.orange)
                        }
                        
                        Button(action: { deviceVM.devices.removeAll() }) {
                            Label("Limpar Todos os Dispositivos", systemImage: "trash.fill")
                                .foregroundColor(.red)
                        }
                    } header: { Text("Simulador de Testes") }
                    
                    // --- UTILIZADORES ---
                    Section {
                        if adminService.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else if adminService.registeredUsers.isEmpty {
                            Text("Nenhum utilizador encontrado.").foregroundColor(.secondary)
                        } else {
                            ForEach(adminService.registeredUsers) { user in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(user.username).font(.headline)
                                        Text(user.email).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "person.circle").foregroundColor(.gray)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        adminService.deleteUser(userId: user.id)
                                    } label: { Label("Banir", systemImage: "trash") }
                                }
                            }
                        }
                    } header: { Text("Utilizadores Registados") }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Consola Admin")
            .toolbar {
                Button("Fechar") { dismiss() }.fontWeight(.bold)
            }
            .onAppear {
                adminService.fetchUsers() // Carrega ao abrir
            }
        }
    }
    
    // ✅ CORREÇÃO: Cria dispositivos JÁ COM DADOS para não ficarem "mortos"
    private func addFiveSimulatedDevices() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let types: [DeviceType] = [.sensor, .led, .gas, .light, .sensor]
        
        for i in 0..<5 {
            let type = types[i]
            // Usamos IP 127.0.0.1 para indicar que é simulação local
            var newDevice = Device(
                id: UUID().uuidString,
                name: "Simulado \(type.displayName) \(i+1)",
                type: type,
                ip: "127.0.0.1",
                connectionProtocol: .http,
                isOnline: true // 👈 Força Online
            )
            
            // Se for sensor, injetamos dados falsos iniciais
            if type == .sensor {
                newDevice.sensorData = SensorData(
                    temperature: Double.random(in: 19...25),
                    humidity: Double.random(in: 40...60),
                    timestamp: Int(Date().timeIntervalSince1970)
                )
            }
            
            // Se for luz, ligamos algumas aleatoriamente
            if type == .light || type == .led {
                newDevice.state = Bool.random()
            }
            
            deviceVM.devices.append(newDevice)
        }
        dismiss()
    }
}
