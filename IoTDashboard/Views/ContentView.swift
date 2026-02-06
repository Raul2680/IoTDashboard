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
            // ✅ CORREÇÃO DO ZOOM: Usamos easeInOut e valores mais subtis para evitar o glitch visual
            .blur(radius: deviceVM.showQuickControl ? 6 : 0)
            .scaleEffect(deviceVM.showQuickControl ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.35), value: deviceVM.showQuickControl)
            
            // MARK: - CAMADA 2: OVERLAY GLOBAL (Novo LedControlView)
            if authVM.isLoggedIn && deviceVM.showQuickControl, let device = deviceVM.selectedDeviceForOverlay {
                ZStack {
                    // Fundo escuro desfocado que fecha ao tocar fora
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                deviceVM.showQuickControl = false
                            }
                        }
                    
                    // ✅ CHAMADA DO NOVO COMPONENTE PREMIUM
                    LedControlView(deviceVM: deviceVM, device: device)
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

// MARK: - COMPONENTES AUXILIARES
// Mantemos apenas o VisualEffectView se for usado noutras partes,
// caso contrário, o .ultraThinMaterial nativo é preferível.
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: effect) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = effect }
}
