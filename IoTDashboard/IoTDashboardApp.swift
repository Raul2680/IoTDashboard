import SwiftUI
import FirebaseCore
import UserNotifications

@main
struct IoTDashboardApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var deviceVM = DeviceViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var homeAssistantService = HomeAssistantService()
    // ✅ ADICIONADO: Criar o ViewModel das Automações
    @StateObject private var automationVM = AutomationViewModel()
    
    init() {
        FirebaseApp.configure()
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ [Notifications] Permissão concedida")
            } else if let error = error {
                print("❌ [Notifications] Erro: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(deviceVM)
                .environmentObject(themeManager)
                .environmentObject(locationManager)
                .environmentObject(homeAssistantService)
                // ✅ ADICIONADO: Disponibilizar o AutomationVM para a App
                .environmentObject(automationVM)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    deviceVM.homeAssistantService = homeAssistantService
                    
                    // ⚠️ A LINHA EM BAIXO É A QUE FALTAVA:
                    // Ela permite que o DeviceVM envie dados de temperatura para o motor
                    deviceVM.automationViewModel = automationVM
                    
                    // ✅ CRUCIAL: Isto liga o motor das automações aos teus dispositivos e localização
                    automationVM.setDependencies(
                        deviceVM: deviceVM,
                        locationManager: locationManager
                    )
                    
                    locationManager.requestAlwaysPermission()
                    print("📍 [App] Permissão de localização e dependências de automação configuradas")
                }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var locationManager: LocationManager
    // ✅ ADICIONADO: Acesso ao AutomationVM
    @EnvironmentObject var automationVM: AutomationViewModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }
            
            AutomationsView()
                .tabItem {
                    Label("Automação", systemImage: "bolt.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
        }
        .tint(themeManager.accentColor)
        .environmentObject(deviceVM)
        .environmentObject(locationManager)
        // ✅ ADICIONADO: Passar para as sub-vistas
        .environmentObject(automationVM)
    }
}
