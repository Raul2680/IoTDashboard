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
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    // ✅ NOVO: Liga DeviceVM ao HA Service
                    deviceVM.homeAssistantService = homeAssistantService
                    
                    locationManager.requestAlwaysPermission()
                    print("📍 [App] Permissão de localização solicitada")
                }
        }
    }
}


struct MainTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var locationManager: LocationManager

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
    }
}
