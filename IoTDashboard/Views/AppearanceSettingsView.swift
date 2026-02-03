import SwiftUI
import Combine

// MARK: - VIEW PRINCIPAL (APARÊNCIA)
struct AppearanceSettingsView: View {
    @Environment(\.dismiss) var dismiss // ✅ Adicionado para fechar a vista
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Fundo que muda de cor consoante o tema selecionado
            themeManager.currentTheme.deepBaseColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: themeManager.currentTheme)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss() // ✅ Fecha ao carregar no X
                    }) {
                        Image(systemName: "xmark")
                            .modifier(CircleButtonModifier())
                    }
                    Spacer()
                    Text("Aparência")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.colorScheme == .light ? .black : .white)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                Text("Personaliza o visual do teu dashboard")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 10)

                // Carrossel de Temas (Mockups)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 25) {
                        ForEach(AppTheme.allCases) { theme in
                            ThemeSelectionCard(theme: theme, isSelected: themeManager.currentTheme == theme)
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        themeManager.currentTheme = theme
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 40)
                }
                
                Spacer()
                
                // Botão de Confirmação
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss() // ✅ Fecha ao confirmar
                }) {
                    Text("Confirmar Tema")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .font(.system(size: 16, weight: .bold))
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(themeManager.colorScheme)
    }
}

// MARK: - COMPONENTE MOCKUP (TELEFONE)
struct ThemeSelectionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            
            VStack(spacing: 12) {
                ZStack {
                    // FUNDO BASEADO NO THEME MANAGER
                    Group {
                        if let imageName = theme.backgroundResource {
                            Image(imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: w, height: h)
                        } else {
                            LinearGradient(
                                colors: [theme.accentColor.opacity(0.8), theme.deepBaseColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: w * 0.14))

                    // Mockup da Interface
                    VStack(spacing: h * 0.05) {
                        Capsule().fill(.white.opacity(0.2)).frame(width: w * 0.3, height: h * 0.04).padding(.top, 20)
                        
                        Text("A minha casa")
                            .font(.system(size: w * 0.06, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: theme.icon)
                            .font(.title)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.black.opacity(0.3))
                            .frame(width: w * 0.8, height: h * 0.3)
                            .blur(radius: 1)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: w * 0.14)
                        .stroke(isSelected ? theme.accentColor : .white.opacity(0.1), lineWidth: isSelected ? 4 : 1)
                )
                
                Text(theme.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? theme.accentColor : .white.opacity(0.6))
            }
        }
        .frame(width: 210, height: 420)
        .scaleEffect(isSelected ? 1.05 : 0.95)
    }
}

// MARK: - AUXILIARES DE ESTILO
struct CircleButtonModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .bold))
            .padding(12)
            .background(Circle().fill(themeManager.currentTheme.colorScheme == .light ? Color.black.opacity(0.05) : Color.white.opacity(0.1)))
            .foregroundColor(themeManager.currentTheme.colorScheme == .light ? .black : .white)
    }
}
