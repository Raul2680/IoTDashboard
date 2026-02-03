import SwiftUI
import FirebaseAuth

// MARK: - ENUMS
enum HomeMenuAction {
    case edit
    case delete
}

// MARK: - VIEW PRINCIPAL
struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var showAddDevice = false
    @State private var showAdminPanel = false
    @State private var temperatureData: Double = 0
    @State private var updateTimer: Timer?
    
    @State private var deviceToEdit: Device?
    @State private var showDeleteConfirmation = false
    @State private var deviceToDelete: Device?
    
    let ADMIN_EMAIL = "f.raul2603@gmail.com"
    let availableRooms = ["Sala", "Cozinha", "Quarto", "Escritório", "Casa de Banho", "Garagem", "Exterior"]
    
    private var devicesByRoom: [String: [Device]] {
        Dictionary(grouping: deviceVM.devices) { $0.room ?? "Sem Divisão" }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                // Padrão de Fundo (Struct corrigida abaixo)
                if themeManager.currentTheme != .light {
                    BackgroundPatternView(theme: themeManager.currentTheme).opacity(0.4)
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
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showAddDevice) { AddDeviceView(deviceVM: deviceVM) }
        .sheet(isPresented: $showAdminPanel) { AdminDashboardView().environmentObject(deviceVM).environmentObject(themeManager) }
        .sheet(item: $deviceToEdit) { device in EditDeviceView(device: device, deviceVM: deviceVM) }
        .alert("Remover Equipamento", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Remover", role: .destructive) { if let d = deviceToDelete { deviceVM.removeDevice(d) } }
        } message: { Text("Desejas remover '\(deviceToDelete?.name ?? "")'?") }
        .onAppear { startDataRefresh() }
        .onDisappear { stopDataRefresh() }
    }
}

// MARK: - EXTENSÕES UI
extension HomeView {
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("A minha casa")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            }
            Spacer()
            
            // ✅ CORREÇÃO: Acesso direto sem '$'
            if authVM.currentUser?.email == ADMIN_EMAIL {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAdminPanel = true
                } label: {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.orange.opacity(0.15)))
                }
                .padding(.trailing, 8)
            }
            
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
                let lightsOn = deviceVM.devices.filter { ($0.type == .light || $0.type == .led) && $0.state }.count
                quickPill(icon: "lightbulb.fill", title: "Luzes", value: "\(lightsOn) On", color: .yellow)
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
            ForEach(devicesByRoom.keys.sorted(), id: \.self) { roomName in
                VStack(alignment: .leading, spacing: 15) {
                    Text(roomName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(.horizontal, 25)
                        .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                    
                    DeviceGridView(
                        devices: devicesByRoom[roomName] ?? [],
                        deviceVM: deviceVM,
                        availableRooms: availableRooms,
                        onAction: handleMenuAction,
                        onOpenControl: { device in
                            deviceVM.selectedDeviceForOverlay = device
                            withAnimation(.spring()) { deviceVM.showQuickControl = true }
                        }
                    )
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.and.signal").font(.system(size: 50)).foregroundColor(.gray.opacity(0.4))
            Text("Sem dispositivos").foregroundColor(.gray)
        }.frame(maxWidth: .infinity).padding(.top, 60)
    }
    
    private func handleMenuAction(_ action: HomeMenuAction, for device: Device) {
        switch action {
        case .edit: self.deviceToEdit = device
        case .delete: self.deviceToDelete = device; self.showDeleteConfirmation = true
        }
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

// MARK: - STRUCTS AUXILIARES

struct DeviceGridView: View {
    let devices: [Device]
    let deviceVM: DeviceViewModel
    let availableRooms: [String]
    let onAction: (HomeMenuAction, Device) -> Void
    let onOpenControl: (Device) -> Void
    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(devices) { device in
                AppleHomeDeviceCard(device: device, deviceVM: deviceVM)
                    .onTapGesture {
                        if device.type == .led || device.type == .light { onOpenControl(device) }
                        else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    }
                    .contextMenu {
                        Button { onAction(.edit, device) } label: { Label("Editar", systemImage: "pencil") }
                        Menu {
                            ForEach(availableRooms, id: \.self) { room in
                                Button { deviceVM.updateDeviceDetails(device: device, newName: device.name, newRoom: room) } label: { Label(room, systemImage: "folder") }
                            }
                        } label: { Label("Mover", systemImage: "arrow.right.circle") }
                        Divider()
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
            ZStack {
                Circle()
                    .fill(device.state && device.isOnline ? themeManager.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(device.state && device.isOnline ? themeManager.accentColor : .gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white).lineLimit(1)
                Text(statusText).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20).fill(themeManager.currentTheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.06)))
    }
    
    private var iconName: String {
        if device.type == .sensor { return "thermometer.medium" }
        return device.state ? "lightbulb.fill" : "lightbulb"
    }
    
    private var statusText: String {
        if !device.isOnline { return "Sem Resposta" }
        if device.type == .sensor {
            if let temp = device.sensorData?.temperature { return String(format: "%.1f°C", temp) }
            return "--°C"
        }
        return device.state ? "Ligado" : "Desligado"
    }
}

