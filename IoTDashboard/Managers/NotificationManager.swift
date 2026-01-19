import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // 1. Pedir Permissão
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Permissão de notificações concedida")
            } else if let error = error {
                print("❌ Erro ao pedir permissão: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Enviar Notificação Local
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Disparar imediatamente (após 1 segundo)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Erro ao agendar notificação: \(error)")
            }
        }
    }
    
    // 3. Mostrar notificação mesmo com a app ABERTA (Foreground)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Força aparecer o banner e tocar som
        completionHandler([.banner, .sound, .list])
    }
}
