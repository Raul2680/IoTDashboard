import Foundation
import Combine
import UserNotifications

class AutomationEngine: ObservableObject {
    @Published var executionHistory: [AutomationExecution] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    // Dependências
    var deviceViewModel: DeviceViewModel?
    var locationManager: LocationManager?
    
    init() {
        setupNotificationObservers()
        startEngine()
        loadHistory()
    }
    
    // MARK: - Iniciar Motor
    func startEngine() {
        print("⚙️ [Automation] Motor iniciado")
        
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkTimeBasedAutomations()
        }
        
        checkTimeBasedAutomations()
    }
    
    func stopEngine() {
        timer?.invalidate()
        print("⚙️ [Automation] Motor parado")
    }
    
    // MARK: - Verificação de Automações por Horário
    private func checkTimeBasedAutomations() {
        guard let automations = loadAutomations() else { return }
        
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now) - 1
        
        for automation in automations where automation.isEnabled && automation.triggerType == .time {
            guard let triggerTime = automation.triggerTime else { continue }
            
            if let days = automation.triggerDays, !days.isEmpty {
                if !days.contains(currentWeekday) {
                    continue
                }
            }
            
            let triggerHour = calendar.component(.hour, from: triggerTime)
            let triggerMinute = calendar.component(.minute, from: triggerTime)
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            
            if triggerHour == currentHour && triggerMinute == currentMinute {
                if let lastTriggered = automation.lastTriggered {
                    let timeSinceLastTrigger = now.timeIntervalSince(lastTriggered)
                    if timeSinceLastTrigger < 60 {
                        continue
                    }
                }
                
                print("⏰ [Automation] Disparada: \(automation.name)")
                executeAutomation(automation)
            }
        }
    }
    
    // MARK: - Verificação de Sensores (COM TRAVA DE SPAM)
    func checkSensorAutomations(device: Device) {
        guard let automations = loadAutomations() else { return }
        let now = Date()
        
        for automation in automations where automation.isEnabled {
            
            // ✅ TRAVA DE SEGURANÇA: Se disparou há menos de 60 segundos, ignora para não spamar
            if let lastTriggered = automation.lastTriggered {
                if now.timeIntervalSince(lastTriggered) < 60 {
                    continue
                }
            }
            
            // Temperatura
            if automation.triggerType == .temperature,
               automation.triggerDeviceId == device.id,
               let temp = device.sensorData?.temperature,
               let targetValue = automation.triggerValue,
               let op = automation.comparisonOperator {
                
                let shouldTrigger = compareValues(temp, targetValue, op)
                if shouldTrigger {
                    print("🌡️ [Automation] Temperatura disparada: \(automation.name)")
                    executeAutomation(automation)
                }
            }
            
            // Humidade
            if automation.triggerType == .humidity,
               automation.triggerDeviceId == device.id,
               let humidity = device.sensorData?.humidity,
               let targetValue = automation.triggerValue,
               let op = automation.comparisonOperator {
                
                let shouldTrigger = compareValues(humidity, targetValue, op)
                if shouldTrigger {
                    print("💧 [Automation] Humidade disparada: \(automation.name)")
                    executeAutomation(automation)
                }
            }
            
            // Gás
            if automation.triggerType == .gasDetected,
               automation.triggerDeviceId == device.id,
               let gasData = device.gasData,
               gasData.status == 1 {
                
                print("🚨 [Automation] Gás detetado: \(automation.name)")
                executeAutomation(automation)
            }
        }
    }
    
    // MARK: - Execução de Automação
    func executeAutomation(_ automation: Automation) {
        print("▶️ [Automation] A executar: \(automation.name)")
        
        var success = true
        var messages: [String] = []
        
        for action in automation.actions {
            let result = executeAction(action, automationName: automation.name)
            if !result.success {
                success = false
            }
            messages.append(result.message)
        }
        
        let execution = AutomationExecution(
            automationId: automation.id,
            timestamp: Date(),
            success: success,
            message: messages.joined(separator: "; ")
        )
        executionHistory.insert(execution, at: 0)
        
        // Esta função grava a data atual em 'lastTriggered' no UserDefaults
        updateLastTriggered(automationId: automation.id)
        
        if executionHistory.count > 50 {
            executionHistory = Array(executionHistory.prefix(50))
        }
        
        saveHistory()
    }
    
    // MARK: - Execução de Ações
    private func executeAction(_ action: AutomationAction, automationName: String) -> (success: Bool, message: String) {
        guard let deviceId = action.targetDeviceId,
              let device = deviceViewModel?.devices.first(where: { $0.id == deviceId }) else {
            return (false, "Dispositivo não encontrado")
        }
        
        switch action.type {
        case .turnOn:
            sendCommand(to: device, command: "ON")
            return (true, "Ligado: \(device.name)")
            
        case .turnOff:
            sendCommand(to: device, command: "OFF")
            return (true, "Desligado: \(device.name)")
            
        case .setColor:
            if let colorHex = action.value {
                sendColorCommand(to: device, color: colorHex)
                return (true, "Cor alterada: \(device.name)")
            }
            return (false, "Cor inválida")
            
        case .setBrightness:
            if let brightnessStr = action.value, let brightness = Int(brightnessStr) {
                sendBrightnessCommand(to: device, brightness: brightness)
                return (true, "Brilho: \(brightness)%")
            }
            return (false, "Brilho inválido")
            
        case .notify:
            let message = action.value ?? "Automação disparada"
            sendNotification(title: automationName, body: message)
            return (true, "Notificação enviada")
            
        case .sendEmail:
            return (true, "Email agendado")
        }
    }
    
    // MARK: - Comandos para Dispositivos
    private func sendCommand(to device: Device, command: String) {
        let udpService = UDPService(ip: device.ip)
        udpService.sendCommand(command)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { udpService.stop() }
    }
    
    private func sendColorCommand(to device: Device, color: String) {
        let rgb = hexToRGB(color)
        let udpService = UDPService(ip: device.ip)
        udpService.sendColor(r: rgb.r, g: rgb.g, b: rgb.b, brightness: 100)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { udpService.stop() }
    }
    
    private func sendBrightnessCommand(to device: Device, brightness: Int) {
        let udpService = UDPService(ip: device.ip)
        if let ledState = device.ledState {
            udpService.sendColor(r: ledState.r, g: ledState.g, b: ledState.b, brightness: brightness)
        } else {
            udpService.sendColor(r: 255, g: 255, b: 255, brightness: brightness)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { udpService.stop() }
    }
    
    // MARK: - Notificações Push
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [Notification] Erro: \(error)")
            } else {
                print("✅ [Notification] Enviada: \(title)")
            }
        }
    }
    
    // MARK: - Helpers
    private func compareValues(_ value: Double, _ target: Double, _ op: ComparisonOperator) -> Bool {
        switch op {
        case .greaterThan: return value > target
        case .lessThan: return value < target
        case .equals: return abs(value - target) < 0.1
        case .notEquals: return abs(value - target) >= 0.1
        }
    }
    
    private func hexToRGB(_ hex: String) -> (r: Int, g: Int, b: Int) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = Int((rgb & 0xFF0000) >> 16)
        let g = Int((rgb & 0x00FF00) >> 8)
        let b = Int(rgb & 0x0000FF)
        return (r, g, b)
    }
    
    // MARK: - Observers de Localização
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGeofenceTrigger(_:)),
            name: .geofenceTriggered,
            object: nil
        )
    }
    
    @objc private func handleGeofenceTrigger(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let automationId = userInfo["automationId"] as? String,
              let didEnter = userInfo["didEnter"] as? Bool,
              let automations = loadAutomations(),
              let automation = automations.first(where: { $0.id == automationId && $0.isEnabled }) else {
            return
        }
        
        if automation.locationTriggerType == .enter && didEnter {
            executeAutomation(automation)
        } else if automation.locationTriggerType == .exit && !didEnter {
            executeAutomation(automation)
        }
    }
    
    // MARK: - Persistência
    private func loadAutomations() -> [Automation]? {
        guard let data = UserDefaults.standard.data(forKey: "automations"),
              let automations = try? JSONDecoder().decode([Automation].self, from: data) else {
            return nil
        }
        return automations
    }
    
    private func updateLastTriggered(automationId: String) {
        guard var automations = loadAutomations(),
              let index = automations.firstIndex(where: { $0.id == automationId }) else {
            return
        }
        
        automations[index].lastTriggered = Date()
        automations[index].executionCount += 1
        
        if let encoded = try? JSONEncoder().encode(automations) {
            UserDefaults.standard.set(encoded, forKey: "automations")
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(executionHistory) {
            UserDefaults.standard.set(encoded, forKey: "automationHistory")
        }
    }
    
    func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "automationHistory"),
              let history = try? JSONDecoder().decode([AutomationExecution].self, from: data) else {
            return
        }
        executionHistory = history
    }
}
