import SwiftUI

struct BackgroundPatternView: View {
    let theme: AppTheme
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size // Extraído para facilitar a inferência de tipo
            
            ZStack {
                if let imageName = theme.backgroundImageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .overlay(theme.deepBaseColor.opacity(0.4))
                }
                else if theme == .goldLines {
                    TopographyPathView(color: theme.accentColor.opacity(0.2))
                        .rotationEffect(.degrees(-15))
                        .scaleEffect(1.5)
                }
                else {
                    // Passamos apenas o tamanho necessário para a Grid
                    GridPatternView(theme: theme, viewSize: size)
                }
            }
        }
        .ignoresSafeArea()
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
