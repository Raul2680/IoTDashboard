import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var showAddDevice = false
    @State private var temperatureData: Double = 0
    @State private var updateTimer: Timer?
    
    // ✅ NOVO: Agrupamento por divisão
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
                
                // Padrão de ícones
                if themeManager.currentTheme != .light {
                    BackgroundPatternView(theme: themeManager.currentTheme)
                }
                
                // Gradiente
                LinearGradient(
                    colors: [themeManager.accentColor.opacity(0.15), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Header com título e botão +
                        headerSection
                        
                        // MARK: - Quick Summary Pills
                        quickSummarySection
                        
                        // MARK: - Secções de Rooms DINÂMICAS
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
            .sheet(isPresented: $showAddDevice) {
                AddDeviceView(deviceVM: deviceVM)
            }
            .onAppear {
                startDataRefresh()
            }
            .onDisappear {
                stopDataRefresh()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("A minha casa")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            }
            
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
                quickPill(
                    icon: "sparkles",
                    title: "Climate",
                    value: temperatureData == 0 ? "--" : String(format: "%.1f°", temperatureData),
                    color: Color(red: 0.2, green: 0.8, blue: 0.9)
                )
                
                quickPill(
                    icon: "lightbulb.fill",
                    title: "Lights",
                    value: "\(deviceVM.devices.filter { $0.type == .light || $0.type == .led }.count) On",
                    color: Color(red: 1, green: 0.8, blue: 0)
                )
                
                quickPill(
                    icon: "network",
                    title: "Devices",
                    value: "\(deviceVM.devices.count)",
                    color: themeManager.accentColor
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Quick Pill Component
    private func quickPill(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.7))
        .cornerRadius(14)
    }
    
    // MARK: - ✅ NOVO: Divisões Dinâmicas
    private var dynamicRoomsSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Ordena as divisões alfabeticamente
            ForEach(devicesByRoom.keys.sorted(), id: \.self) { roomName in
                if let devices = devicesByRoom[roomName], !devices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Título da divisão
                        HStack {
                            HStack(spacing: 8) {
                                // Ícone da divisão
                                Image(systemName: roomIcon(for: roomName))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(themeManager.accentColor)
                                
                                Text(roomName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                                
                                // Badge com número de dispositivos
                                Text("\(devices.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(themeManager.accentColor.opacity(0.8))
                                    .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        
                        // Grid de dispositivos
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(devices) { device in
                                NavigationLink(destination: DeviceDetailView(deviceVM: deviceVM, device: device)) {
                                    AppleHomeDeviceCard(device: device, deviceVM: deviceVM)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - ✅ NOVO: Ícone para cada divisão
    private func roomIcon(for roomName: String) -> String {
        let name = roomName.lowercased()
        
        if name.contains("quarto") || name.contains("bedroom") {
            return "bed.double.fill"
        } else if name.contains("sala") || name.contains("living") {
            return "sofa.fill"
        } else if name.contains("cozinha") || name.contains("kitchen") {
            return "fork.knife"
        } else if name.contains("escritório") || name.contains("office") {
            return "desktopcomputer"
        } else if name.contains("casa de banho") || name.contains("bathroom") {
            return "shower.fill"
        } else if name.contains("garagem") || name.contains("garage") {
            return "car.fill"
        } else if name.contains("jardim") || name.contains("garden") {
            return "leaf.fill"
        } else {
            return "house.fill"
        }
    }
    
    // MARK: - Estado Vazio
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Nenhum dispositivo")
                .font(.title2.bold())
                .foregroundColor(.gray)
            
            Text("Toca em + para adicionar")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - Data Refresh Methods
    private func startDataRefresh() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            refreshDeviceData()
        }
        refreshDeviceData()
    }
    
    private func stopDataRefresh() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func refreshDeviceData() {
        let hasSensors = deviceVM.devices.contains { $0.type == .sensor }
        if !hasSensors {
            self.temperatureData = 0
        }
        
        for device in deviceVM.devices {
            if device.type == .sensor {
                fetchTemperature(for: device)
            }
        }
    }
    
    private func fetchTemperature(for device: Device) {
        let endpoints = ["/data", "/status", "/info"]
        
        for endpoint in endpoints {
            guard let url = URL(string: "http://\(device.ip)\(endpoint)") else { continue }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data else {
                    print("❌ Erro ao conectar em \(device.name)\(endpoint): \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                if let rawString = String(data: data, encoding: .utf8) {
                    print("📡 Raw response de \(device.name)\(endpoint): \(rawString)")
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("⚠️ Resposta não é JSON válido em \(endpoint)")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        // SENSOR - Temperatura
                        if let temperature = json["temperature"] as? Double ?? json["temp"] as? Double ?? json["T"] as? Double {
                            self.temperatureData = temperature
                            print("✅ Temperatura atualizada: \(temperature)°C de \(device.name)")
                            
                            if let index = self.deviceVM.devices.firstIndex(where: { $0.id == device.id }) {
                                let humidity = json["humidity"] as? Double ?? json["H"] as? Double ?? 0
                                
                                if self.deviceVM.devices[index].sensorData == nil {
                                    self.deviceVM.devices[index].sensorData = SensorData(
                                        temperature: temperature,
                                        humidity: humidity,
                                        timestamp: Int(Date().timeIntervalSince1970)
                                    )
                                } else {
                                    self.deviceVM.devices[index].sensorData?.temperature = temperature
                                    self.deviceVM.devices[index].sensorData?.humidity = humidity
                                    self.deviceVM.devices[index].sensorData?.timestamp = Int(Date().timeIntervalSince1970)
                                }
                            }
                            return
                        }
                        
                        // LED RGB
                        if let power = json["power"] as? Int,
                           let red = json["red"] as? Int ?? json["r"] as? Int,
                           let green = json["green"] as? Int ?? json["g"] as? Int,
                           let blue = json["blue"] as? Int ?? json["b"] as? Int,
                           let brightness = json["brightness"] as? Int {
                            
                            print("✅ LED atualizado: R:\(red) G:\(green) B:\(blue) Brilho:\(brightness) Power:\(power)")
                            
                            if let index = self.deviceVM.devices.firstIndex(where: { $0.id == device.id }) {
                                self.deviceVM.devices[index].ledState = LedState(
                                    isOn: power == 1,
                                    r: red,
                                    g: green,
                                    b: blue,
                                    brightness: brightness
                                )
                                self.deviceVM.devices[index].isOnline = true
                            }
                            return
                        }
                        
                        // GAS SENSOR
                        if let gasLevel = json["gas"] as? Int ?? json["gaz"] as? Int {
                            let status = gasLevel > 100 ? 2 : 1
                            print("✅ Sensor de Gás atualizado: \(gasLevel) ppm - Status: \(status)")
                            
                            if let index = self.deviceVM.devices.firstIndex(where: { $0.id == device.id }) {
                                self.deviceVM.devices[index].gasData = GasData(
                                    mq2: gasLevel,
                                    status: status,
                                    timestamp: Int(Date().timeIntervalSince1970)
                                )
                                self.deviceVM.devices[index].isOnline = true
                            }
                            return
                        }
                        
                        print("⚠️ Campos de dados não encontrados em \(endpoint)")
                        print("📋 Campos disponíveis: \(json.keys)")
                    }
                } catch {
                    print("❌ Erro ao parse JSON em \(endpoint): \(error.localizedDescription)")
                }
            }.resume()
        }
    }
}

// MARK: - Apple Home Device Card (mantém igual)
struct AppleHomeDeviceCard: View {
    let device: Device
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var deviceVM: DeviceViewModel
    
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var showRoomPicker = false
    @State private var selectedRoom = "Bedroom"
    
    let rooms = ["Quarto", "Sala", "Cozinha", "Escritório", "Casa de Banho", "Garagem", "Jardim"]
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(cardBgColor)
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                    .lineLimit(1)
                
                Text(statusText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 68)
        .background(
            Color(uiColor: .secondarySystemBackground).opacity(0.6)
        )
        .cornerRadius(14)
        .contextMenu {
            Section {
                Button(action: {
                    newName = device.name
                    showRenameAlert = true
                }) {
                    Label("Renomear", systemImage: "pencil")
                }
                
                Button(action: {
                    showRoomPicker = true
                }) {
                    Label("Alterar Divisão", systemImage: "arrow.left.arrow.right")
                }
            }
            
            Section {
                Button(role: .destructive, action: {
                    removeDevice()
                }) {
                    Label("Remover", systemImage: "trash")
                }
            }
        }
        .alert("Renomear Dispositivo", isPresented: $showRenameAlert) {
            TextField("Novo nome", text: $newName)
            Button("Cancelar", role: .cancel) { }
            Button("Guardar") {
                renameDevice(newName: newName)
            }
        }
        .sheet(isPresented: $showRoomPicker) {
            NavigationView {
                List {
                    ForEach(rooms, id: \.self) { room in
                        Button {
                            changeRoom(to: room)
                            showRoomPicker = false
                        } label: {
                            HStack {
                                Image(systemName: roomIconForPicker(room))
                                    .foregroundColor(themeManager.accentColor)
                                Text(room)
                                Spacer()
                                if device.room == room {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .navigationTitle("Selecionar Divisão")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Fechar") {
                            showRoomPicker = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    private func renameDevice(newName: String) {
        if let index = deviceVM.devices.firstIndex(where: { $0.id == device.id }) {
            deviceVM.devices[index].name = newName
            print("✅ Dispositivo renomeado para: \(newName)")
        }
    }
    
    private func changeRoom(to room: String) {
        if let index = deviceVM.devices.firstIndex(where: { $0.id == device.id }) {
            deviceVM.devices[index].room = room
            selectedRoom = room
            print("✅ Divisão alterada para: \(room)")
        }
    }
    
    private func removeDevice() {
        if let index = deviceVM.devices.firstIndex(where: { $0.id == device.id }) {
            deviceVM.devices.remove(at: index)
            print("✅ Dispositivo removido")
        }
    }
    
    private func roomIconForPicker(_ room: String) -> String {
        let name = room.lowercased()
        if name.contains("quarto") { return "bed.double.fill" }
        if name.contains("sala") { return "sofa.fill" }
        if name.contains("cozinha") { return "fork.knife" }
        if name.contains("escritório") { return "desktopcomputer" }
        if name.contains("banho") { return "shower.fill" }
        if name.contains("garagem") { return "car.fill" }
        if name.contains("jardim") { return "leaf.fill" }
        return "house.fill"
    }
    
    private var iconName: String {
        switch device.type {
        case .light, .led:
            return device.isOnline ? "lightbulb.fill" : "lightbulb"
        case .sensor:
            return "thermometer.medium"
        case .gas:
            return "smoke.fill"
        }
    }
    
    private var iconColor: Color {
        if !device.isOnline {
            return .gray
        }
        
        switch device.type {
        case .light, .led:
            return Color(red: 1, green: 0.8, blue: 0)
        case .sensor:
            return themeManager.accentColor
        case .gas:
            return Color(red: 1, green: 0.3, blue: 0.2)
        }
    }
    
    private var cardBgColor: Color {
        if !device.isOnline {
            return Color.gray.opacity(0.2)
        }
        
        switch device.type {
        case .light, .led:
            return Color(red: 1, green: 0.8, blue: 0).opacity(0.2)
        case .sensor:
            return themeManager.accentColor.opacity(0.2)
        case .gas:
            return Color(red: 1, green: 0.3, blue: 0.2).opacity(0.2)
        }
    }
    
    private var statusText: String {
        if !device.isOnline {
            return "Sem Resposta"
        }
        
        switch device.type {
        case .light, .led:
            return "23%"
        case .sensor:
            if let sensorData = device.sensorData {
                return String(format: "%.1f°C", sensorData.temperature)
            }
            return "A carregar..."
        case .gas:
            return "Normal"
        }
    }
}
