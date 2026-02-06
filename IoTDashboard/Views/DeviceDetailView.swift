import SwiftUI
import Charts // Necessário para os gráficos (iOS 16+)

struct DeviceDetailView: View {
    @ObservedObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    let device: Device
    
    // Estados Locais
    @State private var localState: LedState?
    @State private var showWiFiConfig = false // ✅ Recuperado para abrir o WiFiConfigView
    
    // Estados para Edição
    @State private var isEditingName = false
    @State private var editedName: String = ""
    @State private var selectedRoom: String = "Sem Divisão"
    
    // Lista de divisões consistente
    let availableRooms = ["Sala", "Cozinha", "Quarto", "Escritório", "Casa de Banho", "Garagem", "Exterior"]
    
    private var currentDevice: Device {
        deviceVM.devices.first(where: { $0.id == device.id }) ?? device
    }
    
    var body: some View {
        ZStack {
            // MARK: - Background Dinâmico
            themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
            
            if themeManager.currentTheme != .light {
                BackgroundPatternView(theme: themeManager.currentTheme).opacity(0.3)
            }
            
            LinearGradient(
                colors: [themeManager.accentColor.opacity(0.15), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            // MARK: - Conteúdo
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    headerSection
                    
                    if currentDevice.type == .sensor {
                        HistoryChartSection(color: themeManager.accentColor)
                    }
                    
                    contentSection
                    
                    Spacer(minLength: 30)
                    
                    removeButtonSection
                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // ✅ Botão para abrir configuração de WiFi restaurado
                Button {
                    showWiFiConfig = true
                } label: {
                    Image(systemName: "wifi.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(themeManager.accentColor)
                        .font(.title3)
                }
            }
        }
        // ✅ Sheet de configuração WiFi restaurada
        .sheet(isPresented: $showWiFiConfig) {
            WiFiConfigView(device: currentDevice)
        }
        .alert("Renomear Dispositivo", isPresented: $isEditingName) {
            TextField("Nome", text: $editedName)
            Button("Cancelar", role: .cancel) { }
            Button("Guardar") {
                deviceVM.updateDeviceDetails(device: currentDevice, newName: editedName, newRoom: selectedRoom)
            }
        }
        .onAppear {
            if let state = currentDevice.ledState { localState = state }
            editedName = currentDevice.name
            selectedRoom = currentDevice.room ?? "Sem Divisão"
        }
    }
    
    // MARK: - CABEÇALHO
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                HStack {
                    Text(currentDevice.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                    
                    Button {
                        editedName = currentDevice.name
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                
                Spacer()
                StatusBadge(isOnline: currentDevice.isOnline)
            }
            
            HStack {
                Text(currentDevice.ip)
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Menu {
                    ForEach(availableRooms, id: \.self) { room in
                        Button {
                            selectedRoom = room
                            deviceVM.updateDeviceDetails(device: currentDevice, newName: currentDevice.name, newRoom: room)
                        } label: {
                            Label(room, systemImage: iconForRoom(room))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: iconForRoom(currentDevice.room ?? "Sem Divisão"))
                        Text(currentDevice.room ?? "Atribuir Sala")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(themeManager.accentColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(themeManager.accentColor.opacity(0.1))
                    .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
    }

    private func iconForRoom(_ room: String) -> String {
        switch room {
        case "Sala": return "sofa.fill"
        case "Cozinha": return "refrigerator.fill"
        case "Quarto": return "bed.double.fill"
        case "Escritório": return "desktopcomputer"
        case "Casa de Banho": return "bathtub.fill"
        case "Garagem": return "car.fill"
        case "Exterior": return "leaf.fill"
        default: return "house.fill"
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 20) {
            if currentDevice.type == .led {
                let ledState = localState ?? currentDevice.ledState ?? LedState(isOn: false, r: 255, g: 255, b: 255, brightness: 50)
                SimpleLedControl(device: currentDevice, state: ledState, deviceVM: deviceVM) { newState in
                    localState = newState
                }
            } else if currentDevice.type == .gas {
                if let gas = currentDevice.gasData {
                    GasDisplayView(data: gas).environmentObject(themeManager)
                } else {
                    LoadingView(text: "A obter dados do sensor de gás...")
                }
            } else if currentDevice.type == .sensor {
                if let data = currentDevice.sensorData {
                    SensorDisplayView(sensorData: data).environmentObject(themeManager)
                } else {
                    LoadingView(text: "A ligar ao sensor...")
                }
            } else {
                UnknownDeviceView(type: currentDevice.type.rawValue)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var removeButtonSection: some View {
        Button(role: .destructive) {
            deviceVM.removeDevice(currentDevice)
            dismiss()
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("Remover Dispositivo")
            }
            .font(.headline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.1)))
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - COMPONENTES AUXILIARES

struct HistoryChartSection: View {
    let color: Color
    let mockData: [Double] = [20.1, 20.5, 21.2, 21.8, 22.1, 21.5, 20.8, 20.3]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Histórico (Últimas 24h)").font(.caption.bold()).foregroundColor(.secondary).padding(.leading, 5)
            Chart {
                ForEach(Array(mockData.enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("Hora", index), y: .value("Valor", value)).interpolationMethod(.catmullRom).foregroundStyle(color)
                    AreaMark(x: .value("Hora", index), y: .value("Valor", value)).interpolationMethod(.catmullRom).foregroundStyle(LinearGradient(colors: [color.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                }
            }.frame(height: 120).padding().background(Color.white.opacity(0.05)).cornerRadius(16)
        }.padding(.horizontal, 20)
    }
}

struct SimpleLedControl: View {
    let device: Device; let state: LedState; let deviceVM: DeviceViewModel; let onUpdate: (LedState) -> Void
    @State private var color: Color; @State private var brightness: Double
    init(device: Device, state: LedState, deviceVM: DeviceViewModel, onUpdate: @escaping (LedState) -> Void) {
        self.device = device; self.state = state; self.deviceVM = deviceVM; self.onUpdate = onUpdate
        _color = State(initialValue: Color(red: Double(state.r)/255, green: Double(state.g)/255, blue: Double(state.b)/255))
        _brightness = State(initialValue: Double(state.brightness) / 100.0)
    }
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(state.isOn ? color : Color.gray.opacity(0.2)).frame(width: 140, height: 140).blur(radius: state.isOn ? 20 : 0)
                Image(systemName: state.isOn ? "lightbulb.fill" : "lightbulb").font(.system(size: 60)).foregroundColor(state.isOn ? color : .secondary)
            }.padding(.vertical, 20)
            VStack(spacing: 16) {
                VStack(alignment: .leading) {
                    HStack { Text("Brilho"); Spacer(); Text("\(Int(brightness * 100))%") }.font(.subheadline.bold()).foregroundColor(.secondary)
                    CustomSlider(value: $brightness, range: 0...1, accentColor: color).frame(height: 40).onChange(of: brightness) { _ in sendUpdate() }
                }.padding().background(Color.white.opacity(0.05)).cornerRadius(20)
                ColorPicker("Cor", selection: $color, supportsOpacity: false).font(.headline).padding().background(Color.white.opacity(0.05)).cornerRadius(20).onChange(of: color) { _ in sendUpdate() }
                Button(action: togglePower) {
                    HStack { Image(systemName: "power"); Text(state.isOn ? "Desligar" : "Ligar") }
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(state.isOn ? Color.red.opacity(0.8) : Color.green.opacity(0.8)).cornerRadius(20)
                }
            }
        }
    }
    private func sendUpdate(isPowerToggle: Bool = false) {
        let uiColor = UIColor(color); var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let briInt = Int(brightness * 100); var isOn = briInt > 0
        if isPowerToggle { isOn = !state.isOn }
        let newState = LedState(isOn: isOn, r: Int(r*255), g: Int(g*255), b: Int(b*255), brightness: briInt)
        onUpdate(newState)
        deviceVM.controlLEDviaUDP(device: device, power: isOn, r: Int(r*255), g: Int(g*255), b: Int(b*255), brightness: briInt)
    }
    private func togglePower() { UIImpactFeedbackGenerator(style: .light).impactOccurred(); sendUpdate(isPowerToggle: true) }
}

struct CustomSlider: View {
    @Binding var value: Double; var range: ClosedRange<Double>; var accentColor: Color
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(accentColor).frame(width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            }.gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let percent = Double(gesture.location.x / geometry.size.width)
                value = min(max(range.lowerBound + percent * (range.upperBound - range.lowerBound), range.lowerBound), range.upperBound)
            })
        }
    }
}

struct StatusBadge: View {
    let isOnline: Bool
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(isOnline ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(isOnline ? "ONLINE" : "OFFLINE").font(.system(size: 10, weight: .black))
        }.padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(isOnline ? Color.green.opacity(0.1) : Color.red.opacity(0.1))).foregroundColor(isOnline ? .green : .red)
    }
}

struct SensorDisplayView: View {
    let sensorData: SensorData; @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        HStack(spacing: 15) {
            sensorCard(title: "Temperatura", value: String(format: "%.1f°C", sensorData.temperature), icon: "thermometer.medium", color: .orange)
            sensorCard(title: "Humidade", value: String(format: "%.0f%%", sensorData.humidity), icon: "humidity.fill", color: .blue)
        }
    }
    private func sensorCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) { Text(value).font(.system(size: 24, weight: .bold, design: .rounded)); Text(title).font(.caption).foregroundColor(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color.white.opacity(0.05)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct GasDisplayView: View {
    let data: GasData
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundColor(data.status == 2 ? .red : .green)
                
                VStack(alignment: .leading) {
                    Text("Monitorização de Gases")
                        .font(.headline)
                    Text(data.status == 2 ? "PERIGO: Fuga Detetada!" : "Ambiente Seguro")
                        .font(.subheadline)
                        .foregroundColor(data.status == 2 ? .red : .secondary)
                }
                Spacer()
            }
            .padding(.bottom, 5)
            
            // ✅ Grelha com os 3 Sensores
            HStack(spacing: 10) {
                gasValuePill(label: "MQ-2", value: data.mq2, color: .orange)
                gasValuePill(label: "MQ-4", value: data.mq4 ?? 0, color: .blue)
                gasValuePill(label: "MQ-7", value: data.mq7, color: .purple)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(data.status == 2 ? Color.red.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private func gasValuePill(label: String, value: Int, color: Color) -> some View {
        VStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(.body, design: .rounded))
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

struct UnknownDeviceView: View {
    let type: String
    var body: some View { VStack { Image(systemName: "questionmark.circle").font(.largeTitle).foregroundColor(.orange); Text("Tipo desconhecido: \(type)").foregroundColor(.secondary) }.padding() }
}

struct LoadingView: View {
    let text: String
    var body: some View { VStack(spacing: 15) { ProgressView(); Text(text).font(.headline).foregroundColor(.secondary) }.frame(height: 180).frame(maxWidth: .infinity).background(Color.white.opacity(0.05)).cornerRadius(20) }
}
