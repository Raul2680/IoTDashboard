import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                MainTabView()
                    .onAppear {
                        // ✅ Usa o currentUserEmail do AuthViewModel
                        if !authVM.currentUserEmail.isEmpty {
                            deviceVM.setUser(userId: authVM.currentUserEmail)
                            print("✅ Utilizador configurado: \(authVM.currentUserEmail)")
                        }
                    }
            } else {
                LoginView()
            }
        }
        .tint(themeManager.accentColor)
        .preferredColorScheme(themeManager.colorScheme)
        .animation(.easeInOut, value: themeManager.currentTheme)
        .onChange(of: authVM.isLoggedIn) { isLoggedIn in
            if !isLoggedIn {
                // ✅ Limpa dispositivos ao fazer logout
                deviceVM.clearUserDevices()
                print("🔴 Logout - Dispositivos limpos")
            } else {
                // ✅ Carrega dispositivos ao fazer login
                if !authVM.currentUserEmail.isEmpty {
                    deviceVM.setUser(userId: authVM.currentUserEmail)
                    print("✅ Login - Dispositivos carregados para: \(authVM.currentUserEmail)")
                }
            }
        }
    }
}
