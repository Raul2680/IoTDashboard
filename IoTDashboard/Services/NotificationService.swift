import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, _ in
            if granted { self.setupCategories() }
        }
    }
    
    private func setupCategories() {
        // Ação para desligar dispositivo direto da notificação
        let turnOff = UNNotificationAction(identifier: "TURN_OFF_ACTION", title: "Desligar Agora", options: [.destructive])
        let category = UNNotificationCategory(identifier: "GAS_ALERT", actions: [turnOff], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func sendGasAlert(deviceName: String, status: Int) {
        guard status >= 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = status == 2 ? "⚠️ ALERTA CRÍTICO: GÁS" : "🟡 Aviso de Gás"
        content.body = "\(deviceName) detetou níveis anormais."
        content.sound = status == 2 ? .defaultCritical : .default
        content.categoryIdentifier = "GAS_ALERT" // Liga à categoria de ações
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendGenericNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
