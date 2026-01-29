import SwiftUI

struct LedControlView: View {
    @ObservedObject var deviceVM: DeviceViewModel
    let device: Device
    @Environment(\.dismiss) var dismiss
    
    @State private var brightness: Double = 0
    @State private var selectedColor: Color = .white
    @State private var showColorPicker = false
    
    // Cores predefinidas (Usei cores fixas para garantir o envio correto de RGB)
    private let presetColors: [Color] = [
        Color(red: 1, green: 1, blue: 1),       // Branco
        Color(red: 1, green: 0.64, blue: 0),    // Laranja
        Color(red: 1, green: 0.0, blue: 0.5),   // Rosa
        Color(red: 0.5, green: 0.0, blue: 0.5), // Roxo
        Color(red: 0, green: 0, blue: 1)        // Azul
    ]
    
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
                
                // Cabeçalho
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
                        let newBri = brightness > 0 ? 0.0 : 100.0
                        self.brightness = newBri
                        updateDevice() // Envia imediato
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
                
                // MARK: - SLIDER VERTICAL
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // Fundo
                        RoundedRectangle(cornerRadius: 45)
                            .fill(Color.white.opacity(0.15))
                        
                        // Preenchimento (Usa a cor selecionada em vez de sempre amarelo)
                        RoundedRectangle(cornerRadius: 45)
                            .fill(selectedColor.opacity(0.8)) // ✅ A barra agora tem a cor da luz
                            .frame(height: geo.size.height * CGFloat(max(0, brightness / 100)))
                        
                        // Ícone
                        VStack {
                            Spacer()
                            Image(systemName: brightness > 0 ? "lightbulb.fill" : "lightbulb.slash.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(brightness > 15 ? .black.opacity(0.5) : .white.opacity(0.5))
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
                                // Só envia quando largar para não entupir a rede
                                updateDevice()
                            }
                    )
                }
                .frame(width: 130, height: 340)
                
                Spacer()
                
                // MARK: - CORES
                HStack(spacing: 15) {
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
                    
                    // Picker Customizado
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
                    ColorPicker("Escolha a cor", selection: $selectedColor, supportsOpacity: false)
                        .padding()
                        .labelsHidden() // Picker grande
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
            // ✅ CORREÇÃO CRÍTICA: Carregar a cor atual do dispositivo
            if let state = device.ledState {
                self.brightness = Double(state.brightness)
                
                // Reconstrói a cor a partir do RGB recebido (0-255)
                self.selectedColor = Color(
                    red: Double(state.r) / 255.0,
                    green: Double(state.g) / 255.0,
                    blue: Double(state.b) / 255.0
                )
            }
        }
    }
    
    private func updateDevice() {
        // Converte SwiftUI Color para RGB (0-255)
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
