import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var showAddDevice = false
    @State private var temperatureData: Double = 0
    @State private var updateTimer: Timer?
    
    // ✅ ESTADOS PARA AS FUNÇÕES DO MENU
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
                // BACKGROUND TEMÁTICO
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                if themeManager.currentTheme != .light {
                    BackgroundPatternView(theme: themeManager.currentTheme)
                }
                
                LinearGradient(
                    colors: [themeManager.accentColor.opacity(0.15), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()
                
                ScrollView {
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
        .blur(radius: deviceVM.showQuickControl ? 10 : 0)
        .scaleEffect(deviceVM.showQuickControl ? 0.95 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deviceVM.showQuickControl)
        .sheet(isPresented: $showAddDevice) {
            AddDeviceView(deviceVM: deviceVM)
        }
        // ✅ Ecrã de Edição (Informações, Renomear, Divisão)
        .sheet(item: $deviceToEdit) { device in
            EditDeviceView(device: device, deviceVM: deviceVM)
        }
        // ✅ Alerta de Confirmação de Remoção
        .alert("Remover Equipamento", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Remover", role: .destructive) {
                if let device = deviceToDelete {
                    deviceVM.removeDevice(device)
                }
            }
        } message: {
            Text("Tem a certeza que deseja remover '\(deviceToDelete?.name ?? "")'? Esta ação não pode ser desfeita.")
        }
        .onAppear {
            startDataRefresh()
        }
        .onDisappear {
            stopDataRefresh()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Text("A minha casa")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            
            Spacer()
            
            Button {
                showAddDevice = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(themeManager.accentColor)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Quick Summary
    private var quickSummarySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                quickPill(icon: "sparkles", title: "Clima", value: temperatureData == 0 ? "--" : String(format: "%.1f°", temperatureData), color: .blue)
                quickPill(icon: "lightbulb.fill", title: "Luzes", value: "\(deviceVM.devices.filter { ($0.type == .light || $0.type == .led) && $0.state }.count) On", color: .yellow)
                quickPill(icon: "network", title: "Devices", value: "\(deviceVM.devices.count)", color: themeManager.accentColor)
            }
            .padding(.horizontal, 20)
        }
    }

    private func quickPill(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                Text(value).font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.7)).cornerRadius(55)
    }

    // MARK: - Divisões Dinâmicas
    private var dynamicRoomsSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(devicesByRoom.keys.sorted(), id: \.self) { roomName in
                VStack(alignment: .leading, spacing: 12) {
                    Text(roomName).font(.system(size: 20, weight: .semibold)).padding(.horizontal, 20)
                        .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                    
                    DeviceGridView(devices: devicesByRoom[roomName] ?? [], deviceVM: deviceVM, onAction: { action, device in
                        handleMenuAction(action, for: device)
                    }) { device in
                        deviceVM.selectedDeviceForOverlay = device
                        withAnimation(.spring()) {
                            deviceVM.showQuickControl = true
                        }
                    }
                }
            }
        }
    }
    
    // ✅ LÓGICA DO MENU
    private func handleMenuAction(_ action: HomeMenuAction, for device: Device) {
        switch action {
        case .edit:
            self.deviceToEdit = device
        case .delete:
            self.deviceToDelete = device
            self.showDeleteConfirmation = true
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.fill").font(.system(size: 60)).foregroundColor(.gray.opacity(0.5))
            Text("Nenhum dispositivo").font(.title2.bold()).foregroundColor(.gray)
        }.padding(.top, 80).frame(maxWidth: .infinity)
    }

    private func startDataRefresh() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let sensor = deviceVM.devices.first(where: { $0.type == .sensor }), let data = sensor.sensorData {
                self.temperatureData = data.temperature
            }
        }
    }
    private func stopDataRefresh() { updateTimer?.invalidate() }
}

// MARK: - COMPONENTES DE SUPORTE

enum HomeMenuAction { case edit, delete }

struct DeviceGridView: View {
    let devices: [Device]
    let deviceVM: DeviceViewModel
    let onAction: (HomeMenuAction, Device) -> Void
    let onOpenControl: (Device) -> Void
    
    var columns: [GridItem] { [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)] }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(devices) { device in
                Group {
                    if device.type == .led || device.type == .light {
                        AppleHomeDeviceCard(device: device, deviceVM: deviceVM)
                            .onTapGesture { onOpenControl(device) }
                    } else {
                        NavigationLink(destination: DeviceDetailView(deviceVM: deviceVM, device: device)) {
                            AppleHomeDeviceCard(device: device, deviceVM: deviceVM)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                // ✅ MENU DE CONTEXTO (LONG PRESS)
                .contextMenu {
                    Button { onAction(.edit, device) } label: {
                        Label("Informações", systemImage: "info.circle")
                    }
                    Button { onAction(.edit, device) } label: {
                        Label("Renomear", systemImage: "pencil")
                    }
                    Button { onAction(.edit, device) } label: {
                        Label("Alterar Divisão", systemImage: "house.and.flag")
                    }
                    Divider()
                    Button(role: .destructive) { onAction(.delete, device) } label: {
                        Label("Remover", systemImage: "trash")
                    }
                }
            }
        }.padding(.horizontal, 20)
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
                    .fill(device.state && device.isOnline ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: device.type == .sensor ? "thermometer.medium" : (device.state ? "lightbulb.fill" : "lightbulb"))
                    .foregroundColor(device.state && device.isOnline ? .yellow : .gray)
            }
            .onTapGesture {
                deviceVM.toggleDevice(device)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                Text(statusText).font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(height: 68)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.6)).cornerRadius(40)
    }
    
    private var statusText: String {
        if !device.isOnline { return "Sem Resposta" }
        if device.type == .sensor { return String(format: "%.1f°C", device.sensorData?.temperature ?? 0.0) }
        if let led = device.ledState { return led.isOn ? "\(led.brightness)%" : "Desligado" }
        return device.state ? "Ligado" : "Desligado"
    }
}
