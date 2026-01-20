import SwiftUI

struct LedControlView: View {
    @ObservedObject var deviceVM: DeviceViewModel
    let device: Device
    @Environment(\.dismiss) var dismiss
    
    @State private var brightness: Double = 0
    @State private var selectedColor: Color = .white
    @State private var showColorPicker = false
    
    // Cores predefinidas estilo Apple Home
    private let presetColors: [Color] = [.white, .orange, .pink, .purple, .blue]
    
    var body: some View {
        ZStack {
            // Fundo com material desfocado
            VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: 20) {
                // Indicador superior
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                // Cabeçalho com Nome, Brilho e Botão Power
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text(brightness > 0 ? "\(Int(brightness))%" : "Desligado")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    
                    Button(action: {
                        brightness = brightness > 0 ? 0 : 100
                        updateDevice()
                    }) {
                        Image(systemName: "power")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(brightness > 0 ? .black : .white)
                            .frame(width: 44, height: 44)
                            .background(brightness > 0 ? Color.white : Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                Spacer()
                
                // MARK: - SLIDER VERTICAL (Lâmpada Fixa)
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // 1. Calha/Fundo da barra
                        RoundedRectangle(cornerRadius: 45)
                            .fill(Color.white.opacity(0.15))
                        
                        // 2. Preenchimento (Sobe e desce)
                        RoundedRectangle(cornerRadius: 45)
                            .fill(Color.yellow)
                            .frame(height: geo.size.height * CGFloat(brightness / 100))
                        
                        // 3. Ícone FIXO (Fica sempre no mesmo sítio enquanto o preenchimento passa)
                        VStack {
                            Spacer()
                            Image(systemName: brightness > 0 ? "lightbulb.fill" : "lightbulb.slash.fill")
                                .font(.system(size: 32, weight: .medium))
                                // O contraste muda conforme o preenchimento amarelo sobe
                                .foregroundColor(brightness > 15 ? .black.opacity(0.3) : .white.opacity(0.5))
                                .padding(.bottom, 30)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 45))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percent = 1.0 - Double(value.location.y / geo.size.height)
                                self.brightness = max(0, min(100, percent * 100))
                            }
                            .onEnded { _ in
                                updateDevice()
                            }
                    )
                }
                .frame(width: 130, height: 340)
                
                Spacer()
                
                // MARK: - ROW DE CORES (Estilo Apple Home)
                HStack(spacing: 15) {
                    // Círculos de cores predefinidas
                    ForEach(presetColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 55, height: 55)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .onTapGesture {
                                self.selectedColor = color
                                if brightness == 0 { brightness = 80 }
                                updateDevice()
                            }
                    }
                    
                    // Último círculo: Seletor de Cores (Ícone Arco-íris)
                    ZStack {
                        Circle()
                            .fill(AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]), center: .center))
                            .frame(width: 55, height: 55)
                            .overlay(
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold))
                            )
                    }
                    .onTapGesture {
                        showColorPicker = true
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showColorPicker) {
            NavigationView {
                VStack {
                    ColorPicker("Escolha a cor da luz", selection: $selectedColor, supportsOpacity: false)
                        .padding()
                    Spacer()
                }
                .navigationTitle("Cores")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button("Concluído") {
                        showColorPicker = false
                        updateDevice()
                    }
                }
            }
        }
        .onAppear {
            if let state = device.ledState {
                self.brightness = Double(state.brightness)
            }
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
