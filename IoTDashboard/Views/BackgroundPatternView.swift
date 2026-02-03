import SwiftUI

struct BackgroundPatternView: View {
    let theme: AppTheme
    
    var body: some View {
        ZStack {
            // CASO 1: O tema tem uma imagem de fundo (ex: "Premium", "Metal")
            if let imageName = theme.backgroundImageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .overlay(theme.deepBaseColor.opacity(0.4)) // Escurece a imagem para contraste
            }
            // CASO 2: O tema usa ícones (ex: "Oceano", "Cyberpunk") - Usa Canvas para performance
            else {
                Canvas { context, size in
                    let spacing: CGFloat = 60
                    // Calcula quantas colunas e linhas cabem
                    for row in 0...Int(size.height / spacing) {
                        for col in 0...Int(size.width / spacing) {
                            // Escolhe um ícone aleatório do tema
                            if let icon = theme.patternIcons.randomElement() {
                                let point = CGPoint(x: CGFloat(col) * spacing, y: CGFloat(row) * spacing)
                                
                                // Define opacidade baixa para ser subtil
                                context.opacity = 0.15
                                
                                // Resolve o texto/imagem antes de desenhar (Correção do erro anterior)
                                let text = Text(Image(systemName: icon)).font(.title3)
                                let resolved = context.resolve(text)
                                
                                context.draw(resolved, at: point)
                            }
                        }
                    }
                }
                .foregroundStyle(theme.accentColor) // Pinta os ícones com a cor do tema
                .allowsHitTesting(false) // Garante que não bloqueia toques na Home
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - GRID PATTERN (CORRIGIDO)
struct GridPatternView: View {
    let theme: AppTheme
    let viewSize: CGSize
    
    private var columns: Int { Int(viewSize.width / 80) + 1 }
    private var rows: Int { Int(viewSize.height / 80) + 1 }
    
    var body: some View {
        VStack(spacing: 60) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 60) {
                    ForEach(0..<columns, id: \.self) { col in
                        // Usamos uma lógica segura para obter o ícone
                        let icons = theme.patternIcons
                        let iconName = icons.isEmpty ? "circle.fill" : icons[(row + col) % icons.count]
                        
                        Image(systemName: iconName)
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(theme.accentColor.opacity(0.12))
                    }
                }
            }
        }
        .opacity(0.6)
        .drawingGroup()
    }
}

// MARK: - TOPOGRAPHY (CORRIGIDO)
struct TopographyPathView: View {
    let color: Color
    
    var body: some View {
        Canvas { context, size in
            // Definimos o estilo de traço uma única vez
            let style = StrokeStyle(lineWidth: 1)
            
            for i in 0...12 {
                let yOffset = CGFloat(i) * 60
                var path = Path()
                
                path.move(to: CGPoint(x: 0, y: yOffset))
                
                // Quebramos a curva em pontos explícitos
                let cp1 = CGPoint(x: size.width * 0.3, y: yOffset - 50)
                let cp2 = CGPoint(x: size.width * 0.7, y: yOffset + 150)
                let dest = CGPoint(x: size.width, y: yOffset + 100)
                
                path.addCurve(to: dest, control1: cp1, control2: cp2)
                
                context.stroke(path, with: .color(color), style: style)
            }
        }
    }
}
