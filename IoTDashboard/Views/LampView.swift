import SwiftUI

struct LampView: View {
    @State private var isOn: Bool = false
    @State private var brightness: Double = 50
    @State private var selectedColor: Color = .white
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Quarto")
                .font(.largeTitle)
                .bold()
            
            // Ícone da Lâmpada
            ZStack {
                Circle()
                    .fill(isOn ? selectedColor.opacity(0.3) : Color.gray.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: isOn ? 20 : 0)
                
                Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(isOn ? selectedColor : .gray)
            }
            .onTapGesture {
                isOn.toggle()
                print("💡 Lâmpada: \(isOn ? "Ligada" : "Desligada")")
                // TODO: Adicionar lógica de controlo quando necessário
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "sun.max.fill")
                    Text("Brilho: \(Int(brightness))%")
                }
                .foregroundColor(.secondary)
                
                Slider(value: $brightness, in: 1...100, onEditingChanged: { editing in
                    if !editing {
                        print("🔆 Brilho alterado para: \(Int(brightness))%")
                        // TODO: Enviar comando de brilho quando necessário
                    }
                })
                .accentColor(.yellow)
            }
            .padding(.horizontal)
            
            // Seleção de Cores
            VStack(alignment: .leading) {
                Text("Cores")
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    ColorCircle(color: .white, isSelected: selectedColor == .white) {
                        selectedColor = .white
                        print("🎨 Cor alterada para: Branco")
                    }
                    
                    ColorCircle(color: .red, isSelected: selectedColor == .red) {
                        selectedColor = .red
                        print("🎨 Cor alterada para: Vermelho")
                    }
                    
                    ColorCircle(color: .blue, isSelected: selectedColor == .blue) {
                        selectedColor = .blue
                        print("🎨 Cor alterada para: Azul")
                    }
                    
                    ColorCircle(color: .green, isSelected: selectedColor == .green) {
                        selectedColor = .green
                        print("🎨 Cor alterada para: Verde")
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct ColorCircle: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 45, height: 45)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
            )
            .shadow(radius: 2)
            .onTapGesture {
                action()
            }
    }
}
