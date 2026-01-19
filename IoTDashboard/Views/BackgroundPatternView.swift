import SwiftUI

struct BackgroundPatternView: View {
    let theme: AppTheme
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    Image(systemName: theme.patternIcons[i % theme.patternIcons.count])
                        .font(.system(size: CGFloat.random(in: 20...50)))
                        .foregroundColor(theme.accentColor.opacity(0.05))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .rotationEffect(.degrees(Double.random(in: 0...360)))
                }
            }
            .drawingGroup()
        }
    }
}
