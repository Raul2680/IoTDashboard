import SwiftUI

struct LedControlView: View {
    @ObservedObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let device: Device
    @Environment(\.dismiss) var dismiss
    
    // Estados de controlo
    @State private var brightness: Double = 0
    @State private var selectedColor: Color = .white
    @State private var showColorPicker = false
    
    // Estados de animação e feedback
    @State private var isDragging = false
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    
    // Cores predefinidas
    private let presetColors: [Color] = [
        Color(red: 1, green: 1, blue: 1),       // Branco
        Color(red: 1, green: 0.64, blue: 0),    // Laranja
        Color(red: 1, green: 0.0, blue: 0.5),   // Rosa
        Color(red: 0.5, green: 0.0, blue: 0.5), // Roxo
        Color(red: 0, green: 0, blue: 1)        // Azul
    ]
    
    var body: some View {
        ZStack {
            // Fundo com material desfocado estilo Apple
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: 0) {
                // Indicador superior de fecho
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                // Cabeçalho (Nome e Botão Power)
                headerSection
                
                Spacer()
                
                // MARK: - SLIDER VERTICAL ESTILO APPLE
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // Fundo do trilho
                        RoundedRectangle(cornerRadius: 45)
                            .fill(Color.white.opacity(0.1))
                        
                        // Preenchimento com a cor selecionada
                        RoundedRectangle(cornerRadius: 45)
                            .fill(brightness > 0 ? selectedColor : Color.white.opacity(0.2))
                            .frame(height: geo.size.height * CGFloat(brightness / 100))
                            .animation(.interactiveSpring(), value: brightness)
                        
                        // Ícone dinâmico interno
                        VStack {
                            Spacer()
                            Image(systemName: brightness > 0 ? "lightbulb.fill" : "lightbulb.slash.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundColor(brightness > 25 ? .black.opacity(0.6) : .white.opacity(0.4))
                                .padding(.bottom, 40)
                                .scaleEffect(isDragging ? 1.1 : 1.0)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 45))
                    // Efeito de expansão ao tocar (igual ao iOS 17/18)
                    .scaleEffect(isDragging ? 1.06 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    impactMedium.prepare()
                                }
                                
                                let percent = 1.0 - Double(value.location.y / geo.size.height)
                                let newBri = max(0, min(100, percent * 100))
                                
                                // Feedback tátil nos limites
                                if (newBri >= 100 && brightness < 100) || (newBri <= 0 && brightness > 0) {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                }
                                
                                self.brightness = newBri
                            }
                            .onEnded { _ in
                                isDragging = false
                                updateDevice()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    )
                }
                .frame(width: 140, height: 360)
                
                Spacer()
                
                // Seleção de Cores e ColorPicker
                colorSelectorSection
            }
        }
        .onAppear { loadCurrentState() }
    }
}

// MARK: - COMPONENTES DE INTERFACE
extension LedControlView {
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(brightness > 0 ? "\(Int(brightness))%" : "Desligado")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring()) {
                    brightness = brightness > 0 ? 0 : 100
                }
                updateDevice()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(brightness > 0 ? .black : .white)
                    .frame(width: 50, height: 50)
                    .background(brightness > 0 ? Color.white : Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(30)
    }
    
    private var colorSelectorSection: some View {
        HStack(spacing: 15) {
            ForEach(presetColors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selectedColor == color ? 4 : 0)
                            .padding(-4)
                    )
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.easeInOut) {
                            self.selectedColor = color
                            if brightness == 0 { brightness = 80 }
                        }
                        updateDevice()
                    }
            }
            
            // ✅ MENU ESTILO APPLE HOME (Toque rápido vs Toque longo)
            Menu {
                Section("Opções de Luz") {
                    Button {
                        showColorPicker = true
                    } label: {
                        Label("Paleta de Cores", systemImage: "paintpalette")
                    }
                    
                    Button {
                        withAnimation { selectedColor = Color(red: 1, green: 0.9, blue: 0.8) }
                        updateDevice()
                    } label: {
                        Label("Temperatura de Cor", systemImage: "thermometer.medium")
                    }
                }
                
                Button(role: .destructive) {
                    // Ação para redefinir favoritos
                } label: {
                    Label("Redefinir Favoritos", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Circle()
                    .fill(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    )
            } primaryAction: {
                // Ação de clique rápido: Abre logo a paleta
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showColorPicker = true
            }
        }
        .padding(.bottom, 50)
        .sheet(isPresented: $showColorPicker) {
            colorPickerSheet
        }
    }
    
    private var colorPickerSheet: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Pré-visualização da Cor Selecionada
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 120, height: 120)
                                .shadow(color: selectedColor.opacity(0.5), radius: 20, x: 0, y: 10)
                            
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
                                .frame(width: 120, height: 120)
                        }
                        Text("Cor Selecionada")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // ColorPicker de Sistema
                    VStack(spacing: 20) {
                        Text("Toca no círculo abaixo para abrir a paleta")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                            .scaleEffect(3.0)
                            .labelsHidden()
                            .frame(width: 100, height: 100)
                    }
                    
                    Spacer()
                }
                .navigationTitle("Paleta de Cores")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Concluído") {
                            showColorPicker = false
                            updateDevice()
                        }
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.accentColor)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showColorPicker = false }
                            .foregroundColor(.red)
                    }
                }
            }
            .environment(\.colorScheme, .dark)
        }
    }

    private func loadCurrentState() {
        if let state = device.ledState {
            self.brightness = Double(state.brightness)
            self.selectedColor = Color(
                red: Double(state.r) / 255.0,
                green: Double(state.g) / 255.0,
                blue: Double(state.b) / 255.0
            )
        }
    }

    private func updateDevice() {
        let uiColor = UIColor(selectedColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        deviceVM.controlLEDviaUDP(
            device: device,
            power: brightness > 0,
            r: Int(r * 255),
            g: Int(g * 255),
            b: Int(b * 255),
            brightness: Int(brightness)
        )
    }
}
