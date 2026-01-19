import SwiftUI

struct DeviceDetailView: View {
    @ObservedObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let device: Device
    
    @State private var localState: LedState?
    @State private var showWiFiConfig = false
    
    private var currentDevice: Device {
        deviceVM.devices.first(where: { $0.id == device.id }) ?? device
    }
    
    var body: some View {
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
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Cabeçalho
                    HStack {
                        VStack(alignment: .leading) {
                            Text(currentDevice.name)
                                .font(.largeTitle).bold()
                                .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                            Text(currentDevice.ip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        StatusBadge(isOnline: currentDevice.isOnline)
                    }
                    .padding()
                    
                    // MARK: - Dashboard por Tipo
                    Group {
                        if currentDevice.type == .led {
                            // ✅ CORRIGIDO - Usa estado local, do dispositivo ou default
                            let ledState = localState ?? currentDevice.ledState ?? LedState(
                                isOn: false,
                                r: 255,
                                g: 255,
                                b: 255,
                                brightness: 50
                            )
                            
                            SimpleLedControl(
                                device: currentDevice,
                                state: ledState,
                                deviceVM: deviceVM,
                                onUpdate: { newState in
                                    localState = newState
                                }
                            )
                        } else if currentDevice.type == .gas {
                            if let gas = currentDevice.gasData {
                                GasDisplayView(data: gas)
                                    .environmentObject(themeManager)
                            } else {
                                LoadingView(text: "A obter dados do sensor de gás...")
                            }
                        } else if currentDevice.type == .sensor {
                            if let data = currentDevice.sensorData {
                                SensorDisplayView(sensorData: data)
                                    .environmentObject(themeManager)
                            } else {
                                LoadingView(text: "A ligar ao sensor...")
                            }
                        } else {
                            UnknownDeviceView(type: currentDevice.type.rawValue)
                        }
                    }

                    
                    Spacer()
                    
                    // MARK: - Botão Remover
                    Button(role: .destructive) {
                        deviceVM.removeDevice(currentDevice)
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remover Dispositivo")
                        }
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .navigationTitle(currentDevice.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showWiFiConfig = true
                } label: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(themeManager.accentColor))
                }
            }
        }
        .sheet(isPresented: $showWiFiConfig) {
            WiFiConfigView(device: currentDevice)
        }
        .onAppear {
            if let state = currentDevice.ledState {
                localState = state
            }
        }
    }
}

// MARK: - Controlo LED Simplificado
struct SimpleLedControl: View {
    let device: Device
    let state: LedState
    let deviceVM: DeviceViewModel
    let onUpdate: (LedState) -> Void
    
    @State private var color: Color
    @State private var brightness: Double
    
    init(device: Device, state: LedState, deviceVM: DeviceViewModel, onUpdate: @escaping (LedState) -> Void) {
        self.device = device
        self.state = state
        self.deviceVM = deviceVM
        self.onUpdate = onUpdate
        _color = State(initialValue: Color(
            red: Double(state.r)/255,
            green: Double(state.g)/255,
            blue: Double(state.b)/255
        ))
        _brightness = State(initialValue: Double(state.brightness) / 100.0)
    }
    
    var body: some View {
        VStack(spacing: 25) {
            // Indicador Visual
            ZStack {
                Circle()
                    .fill(state.isOn ? color : Color.gray)
                    .frame(width: 120, height: 120)
                    .shadow(color: state.isOn ? color.opacity(0.5) : .clear, radius: 15)
                
                Text(state.isOn ? "\(Int(brightness * 100))%" : "OFF")
                    .font(.title.bold())
                    .foregroundColor(.white)
            }
            
            // Color Picker
            ColorPicker("Cor", selection: $color, supportsOpacity: false)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            
            // Slider Brilho
            HStack {
                Image(systemName: "sun.min.fill").foregroundColor(.gray)
                Slider(value: $brightness, in: 0...1)
                    .onChange(of: brightness) { _ in
                        sendUpdate()
                    }
                Image(systemName: "sun.max.fill").foregroundColor(.yellow)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            
            // Botão Power
            Button {
                togglePower()
            } label: {
                Text(state.isOn ? "DESLIGAR" : "LIGAR")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(state.isOn ? Color.red : Color.green)
                    .cornerRadius(16)
                    .shadow(radius: 4)
            }
        }
        .padding()
        .onChange(of: color) { _ in
            sendUpdate()
        }
    }
    
    private func sendUpdate(isPowerToggle: Bool = false) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let red = Int(r * 255)
        let green = Int(g * 255)
        let blue = Int(b * 255)
        let briInt = Int(brightness * 100)
        
        var isOn = briInt > 0
        if isPowerToggle {
            isOn = !state.isOn
        }
        
        let newState = LedState(isOn: isOn, r: red, g: green, b: blue, brightness: briInt)
        onUpdate(newState)
        
        // ✅ Envia via UDP
        let udpService = UDPService(ip: device.ip)
        if isPowerToggle {
            let command = isOn ? "ON" : "OFF"
            udpService.sendCommand(command)
        } else {
            udpService.sendColor(r: red, g: green, b: blue, brightness: briInt)
        }
        
        // Fecha conexão após 0.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            udpService.stop()
        }
        
        print("✅ UDP enviado: R:\(red) G:\(green) B:\(blue) Brilho:\(briInt) Power:\(isOn)")
    }
    
    private func togglePower() {
        sendUpdate(isPowerToggle: true)
    }
}

// MARK: - Componentes Auxiliares
struct StatusBadge: View {
    let isOnline: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isOnline ? "Online" : "Offline")
                .font(.caption.bold())
                .foregroundColor(isOnline ? .green : .red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().stroke(isOnline ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
        )
    }
}

struct LoadingView: View {
    let text: String
    
    var body: some View {
        VStack(spacing: 15) {
            ProgressView().scaleEffect(1.5)
            Text(text).font(.headline).foregroundColor(.secondary)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
        .padding()
    }
}

struct UnknownDeviceView: View {
    let type: String
    
    var body: some View {
        VStack {
            Image(systemName: "questionmark.circle").font(.largeTitle).foregroundColor(.orange)
            Text("Tipo desconhecido: \(type)").foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - SensorDisplayView
struct SensorDisplayView: View {
    let sensorData: SensorData
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Temperatura
            VStack {
                Image(systemName: "thermometer")
                    .font(.title)
                    .foregroundColor(.orange)
                    .padding(.bottom, 5)
                Text(String(format: "%.1f°C", sensorData.temperature))
                    .font(.title2.bold())
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                Text("Temperatura")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(16)
            
            // Humidade
            VStack {
                Image(systemName: "humidity")
                    .font(.title)
                    .foregroundColor(.blue)
                    .padding(.bottom, 5)
                Text(String(format: "%.0f%%", sensorData.humidity))
                    .font(.title2.bold())
                    .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                Text("Humidade")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)
        }
        .padding()
    }
}

// MARK: - GasDisplayView
struct GasDisplayView: View {
    let data: GasData
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundColor(data.status == 2 ? .red : themeManager.accentColor)
                
                VStack(alignment: .leading) {
                    Text("Sensor de Gás")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                    Text(data.statusText)
                        .font(.subheadline)
                        .foregroundColor(data.status == 2 ? .red : .secondary)
                }
                Spacer()
            }
            
            HStack {
                VStack {
                    Text("MQ-2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(data.mq2)")
                        .font(.title2.bold())
                        .foregroundColor(themeManager.accentColor)
                }
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: themeManager.accentColor.opacity(0.2), radius: 8)
        .padding()
    }
}
