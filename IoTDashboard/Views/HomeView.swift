import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var showAddDevice = false
    @State private var temperatureData: Double = 0
    @State private var updateTimer: Timer?
    
    // ESTADOS PARA AS FUNÇÕES DO MENU
    @State private var deviceToEdit: Device?
    @State private var showDeleteConfirmation = false
    @State private var deviceToDelete: Device?
    
    // Agrupamento por divisão
    private var devicesByRoom: [String: [Device]] {
        Dictionary(grouping: deviceVM.devices) { device in
            device.room ?? "Sem Divisão"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 1. FUNDO ABSOLUTO
                themeManager.currentTheme.deepBaseColor
                    .ignoresSafeArea()
                
                // 2. CONTEÚDO PRINCIPAL (Refatorado para performance)
                mainViewContent
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(themeManager.currentTheme.deepBaseColor.ignoresSafeArea())
        
        // --- MODAIS E ALERTAS ---
        .sheet(isPresented: $showAddDevice) {
            AddDeviceView(deviceVM: deviceVM)
        }
        .sheet(item: $deviceToEdit) { device in
            EditDeviceView(device: device, deviceVM: deviceVM)
        }
        .alert("Remover Equipamento", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Remover", role: .destructive) {
                if let device = deviceToDelete { deviceVM.removeDevice(device) }
            }
        } message: {
            Text("Desejas remover '\(deviceToDelete?.name ?? "")'?")
        }
        .onAppear { startDataRefresh() }
        .onDisappear { stopDataRefresh() }
    }
    
    // MARK: - Sub-vistas para resolver erro de Type-Check
    
    private var mainViewContent: some View {
        ZStack {
            if themeManager.currentTheme != .light {
                BackgroundPatternView(theme: themeManager.currentTheme)
                    .opacity(0.4)
            }
            
            LinearGradient(
                colors: [themeManager.accentColor.opacity(0.15), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    quickSummarySection
                    
                    if !deviceVM.devices.isEmpty {
                        dynamicRoomsSections
                    } else {
                        emptyState
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .blur(radius: deviceVM.showQuickControl ? 10 : 0)
        .scaleEffect(deviceVM.showQuickControl ? 0.92 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: deviceVM.showQuickControl)
    }
    
    private var headerSection: some View {
        HStack {
            Text("A minha casa")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAddDevice = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(themeManager.accentColor)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 25).padding(.top, 20)
    }
    
    private var quickSummarySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                quickPill(icon: "thermometer.medium", title: "Clima", value: temperatureData == 0 ? "--" : String(format: "%.1f°", temperatureData), color: .blue)
                quickPill(icon: "lightbulb.fill", title: "Luzes", value: "\(deviceVM.devices.filter { ($0.type == .light || $0.type == .led) && $0.state }.count) On", color: .yellow)
                quickPill(icon: "cpu", title: "Devices", value: "\(deviceVM.devices.count)", color: themeManager.accentColor)
            }
            .padding(.horizontal, 25)
        }
    }

    private func quickPill(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                Text(value).font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.currentTheme == .light ? .black : .white)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(themeManager.currentTheme == .light ? Color.black.opacity(0.05) : Color.white.opacity(0.08))
        .cornerRadius(20)
    }

    private var dynamicRoomsSections: some View {
        VStack(alignment: .leading, spacing: 30) {
            // ✅ CORREÇÃO: ForEach com id: \.self para as chaves do dicionário
            ForEach(devicesByRoom.keys.sorted(), id: \.self) { roomName in
                VStack(alignment: .leading, spacing: 15) {
                    Text(roomName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(.horizontal, 25)
                        .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                    
                    DeviceGridView(devices: devicesByRoom[roomName] ?? [], deviceVM: deviceVM, onAction: handleMenuAction) { device in
                        deviceVM.selectedDeviceForOverlay = device
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            deviceVM.showQuickControl = true
                        }
                    }
                }
            }
        }
    }
    
    // ✅ CORREÇÃO: Usar HomeMenuAction (definido abaixo)
    private func handleMenuAction(_ action: HomeMenuAction, for device: Device) {
        switch action {
        case .edit: self.deviceToEdit = device
        case .delete: self.deviceToDelete = device; self.showDeleteConfirmation = true
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.and.signal").font(.system(size: 50)).foregroundColor(.gray.opacity(0.4))
            Text("Sem dispositivos").foregroundColor(.gray)
        }.frame(maxWidth: .infinity).padding(.top, 60)
    }

    private func startDataRefresh() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if let sensor = deviceVM.devices.first(where: { $0.type == .sensor }), let data = sensor.sensorData {
                self.temperatureData = data.temperature
            }
        }
    }
    private func stopDataRefresh() { updateTimer?.invalidate() }
}

// MARK: - COMPONENTES DE SUPORTE

// ✅ DEFINIÇÃO DO ENUM (Garante que o compilador encontra o tipo)
enum HomeMenuAction { case edit, delete }

struct DeviceGridView: View {
    let devices: [Device]
    let deviceVM: DeviceViewModel
    let onAction: (HomeMenuAction, Device) -> Void
    let onOpenControl: (Device) -> Void
    
    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(devices) { device in
                // ✅ Usamos um Group para decidir o tipo de interação
                Group {
                    if device.type == .led || device.type == .light {
                        // Para Luzes/LEDs, abre o Quick Control (Overlay)
                        AppleHomeDeviceCard(device: device, deviceVM: deviceVM)
                            .onTapGesture {
                                onOpenControl(device)
                            }
                    } else {
                        // Para Sensores, navega para o detalhe
                        NavigationLink(destination: DeviceDetailView(deviceVM: deviceVM, device: device)) {
                            AppleHomeDeviceCard(device: device, deviceVM: deviceVM)
                        }
                        .buttonStyle(PlainButtonStyle()) // Remove o efeito azul de link
                    }
                }
                .contentShape(Rectangle()) // ✅ Torna toda a área do card clicável
                .contextMenu {
                    Button { onAction(.edit, device) } label: { Label("Editar", systemImage: "pencil") }
                    Button(role: .destructive) { onAction(.delete, device) } label: { Label("Remover", systemImage: "trash") }
                }
            }
        }
        .padding(.horizontal, 25)
    }
}
struct AppleHomeDeviceCard: View {
    let device: Device
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var deviceVM: DeviceViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // ✅ ÍCONE COM TOGGLE
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                deviceVM.toggleDevice(device)
            } label: {
                ZStack {
                    Circle()
                        .fill(device.state && device.isOnline ? themeManager.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: device.type == .sensor ? "thermometer.medium" : (device.state ? "lightbulb.fill" : "lightbulb"))
                        .font(.system(size: 18))
                        .foregroundColor(device.state && device.isOnline ? themeManager.accentColor : .gray)
                }
            }
            .buttonStyle(PlainButtonStyle()) // ✅ Evita que o clique no ícone dispare o clique no card
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                    .lineLimit(1)
                
                // ✅ ESTE TEXTO AGORA ATUALIZA COM OS DADOS DO DEVICEVM
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(themeManager.currentTheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.06))
        )
    }
    
    private var statusText: String {
        // ✅ Procura o estado mais recente do device dentro do array do VM
        guard let latestDevice = deviceVM.devices.first(where: { $0.id == device.id }) else {
            return "Desconhecido"
        }
        
        if !latestDevice.isOnline { return "Offline" }
        
        if latestDevice.type == .sensor {
            if let temp = latestDevice.sensorData?.temperature {
                return String(format: "%.1f°C", temp)
            }
            return "--°C"
        }
        
        return latestDevice.state ? "Ligado" : "Desligado"
    }
}
 
