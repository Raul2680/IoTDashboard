import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // MARK: - CAMADA 1: LOGICA DE LOGIN E APP
            Group {
                if authVM.isLoggedIn {
                    MainTabView()
                        .onAppear {
                            if !authVM.currentUserEmail.isEmpty {
                                deviceVM.setUser(userId: authVM.currentUserEmail)
                                print("✅ Utilizador configurado: \(authVM.currentUserEmail)")
                            }
                        }
                } else {
                    LoginView()
                }
            }
            // Desfoca e encolhe a app por trás quando o overlay abre
            .blur(radius: deviceVM.showQuickControl ? 15 : 0)
            .scaleEffect(deviceVM.showQuickControl ? 0.95 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: deviceVM.showQuickControl)
            
            // MARK: - CAMADA 2: OVERLAY GLOBAL (Cobre a Dock/TabView)
            if authVM.isLoggedIn && deviceVM.showQuickControl, let device = deviceVM.selectedDeviceForOverlay {
                ZStack {
                    // Fundo transparente com desfoque real
                    VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                deviceVM.showQuickControl = false
                            }
                        }
                    
                    QuickControlContent(device: device)
                }
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
                .zIndex(10)
            }
        }
        .tint(themeManager.accentColor)
        .preferredColorScheme(themeManager.colorScheme)
        .animation(.easeInOut, value: themeManager.currentTheme)
        .onChange(of: authVM.isLoggedIn) { isLoggedIn in
            if !isLoggedIn {
                deviceVM.clearUserDevices()
                deviceVM.showQuickControl = false
                print("🔴 Logout - Dispositivos limpos")
            } else {
                if !authVM.currentUserEmail.isEmpty {
                    deviceVM.setUser(userId: authVM.currentUserEmail)
                }
            }
        }
    }
}

// MARK: - CONTEÚDO DO CONTROLO RÁPIDO
struct QuickControlContent: View {
    let device: Device
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var brightness: Double = 0
    @State private var selectedColor: Color = .white
    @State private var showColorPicker = false
    @State private var showWiFiConfig = false // Para abrir a tua WiFiConfigView
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text(device.name).font(.title2.bold()).foregroundColor(.white)
                Text(brightness > 0 ? "\(Int(brightness))%" : "Off")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 30)
            
            Spacer()
            
            // Slider Vertical Corrigido com Haptic Feedback
            AppleVerticalSlider(brightness: $brightness) {
                updateDevice()
            }
            
            Spacer()
            
            // MARK: - ZONA INFERIOR (Cores + Definições)
            ZStack(alignment: .bottom) {
                // Row de Cores Centralizada
                HStack(spacing: 15) {
                    ForEach([Color.white, Color.orange, Color.pink, Color.blue], id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 55, height: 55)
                            .overlay(Circle().stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0))
                            .onTapGesture {
                                self.selectedColor = color
                                updateDevice()
                            }
                    }
                    
                    Circle()
                        .fill(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center))
                        .frame(width: 55, height: 55)
                        .overlay(Image(systemName: "ellipsis").foregroundColor(.white).bold())
                        .onTapGesture { showColorPicker = true }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 60)
                
                // ✅ ÍCONE DE DEFINIÇÕES (Mais abaixo e à direita conforme pedido)
                HStack {
                    Spacer()
                    Button {
                        showWiFiConfig = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.trailing, 25)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            self.brightness = Double(device.ledState?.brightness ?? 0)
        }
        .fullScreenCover(isPresented: $showWiFiConfig) {
            WiFiConfigView(device: device) // Abre o teu gestor de Bluetooth/WiFi
        }
        .sheet(isPresented: $showColorPicker) {
            NavigationView {
                ColorPicker("Escolha a cor", selection: $selectedColor, supportsOpacity: false)
                    .padding()
                    .navigationTitle("Cores")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        Button("OK") { showColorPicker = false; updateDevice() }
                    }
            }
        }
    }
    
    private func updateDevice() {
        let rgb = selectedColor.getRGBValues() //
        deviceVM.controlLEDviaUDP(
            device: device,
            power: brightness > 0,
            r: Int(rgb.r * 255),
            g: Int(rgb.g * 255),
            b: Int(rgb.b * 255),
            brightness: Int(brightness)
        )
    }
}

// MARK: - COMPONENTES AUXILIARES

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: effect) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = effect }
}

struct AppleVerticalSlider: View {
    @Binding var brightness: Double
    var onUpdate: () -> Void
    private let feedback = UIImpactFeedbackGenerator(style: .medium) //
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 45)
                    .fill(Color.white.opacity(0.12))
                
                // Fix da barra amarela: Rectangle com clipShape
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: width, height: max(0, min(height, height * CGFloat(brightness / 100))))
                
                VStack {
                    Spacer()
                    Image(systemName: brightness > 0 ? "lightbulb.fill" : "lightbulb.slash.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(brightness > 20 ? .black.opacity(0.3) : .white.opacity(0.4))
                        .padding(.bottom, 35)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 45))
            .contentShape(RoundedRectangle(cornerRadius: 45))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let previous = self.brightness
                        let percent = 1.0 - Double(v.location.y / height)
                        let newVal = max(0, min(100, percent * 100))
                        
                        // Feedback tátil nos limites
                        if (newVal == 100 && previous < 100) || (newVal == 0 && previous > 0) {
                            feedback.prepare()
                            feedback.impactOccurred()
                        }
                        
                        withAnimation(.interactiveSpring()) {
                            self.brightness = newVal
                        }
                    }
                    .onEnded { _ in onUpdate() }
            )
        }
        .frame(width: 135, height: 350)
    }
}

extension Color {
    func getRGBValues() -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }
}
