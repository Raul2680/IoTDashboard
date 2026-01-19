import SwiftUI

struct AppBackgroundView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
            
            if themeManager.currentTheme != .light {
                GeometryReader { geo in
                    ZStack {
                        ForEach(0..<15, id: \.self) { i in
                            Image(systemName: themeManager.currentTheme.patternIcons[i % themeManager.currentTheme.patternIcons.count])
                                .font(.system(size: CGFloat.random(in: 20...40)))
                                .foregroundColor(themeManager.accentColor.opacity(0.05))
                                .position(
                                    x: CGFloat.random(in: 0...geo.size.width),
                                    y: CGFloat.random(in: 0...geo.size.height)
                                )
                                .rotationEffect(.degrees(Double.random(in: 0...360)))
                        }
                    }
                }
                .drawingGroup()
            }
        }
    }
}
