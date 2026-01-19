import Foundation
import Combine

class AutomationViewModel: ObservableObject {
    @Published var automations: [Automation] = []
    
    private let automationEngine = AutomationEngine()
    private let storageKey = "automations"
    
    init() {
        loadAutomations()
    }
    
    func setDependencies(deviceVM: DeviceViewModel, locationManager: LocationManager) {
        automationEngine.deviceViewModel = deviceVM
        automationEngine.locationManager = locationManager
        
        // Configura geofences para automações existentes
        for automation in automations where automation.triggerType == .location {
            if let location = automation.triggerLocation {
                locationManager.addGeofence(for: automation.id, location: location)
            }
        }
    }
    
    // MARK: - CRUD
    func addAutomation(_ automation: Automation) {
        automations.append(automation)
        saveAutomations()
        
        // Adiciona geofence se for automação de localização
        if automation.triggerType == .location, let location = automation.triggerLocation {
            automationEngine.locationManager?.addGeofence(for: automation.id, location: location)
        }
        
        print("✅ [Automation] Adicionada: \(automation.name)")
    }
    
    func updateAutomation(_ automation: Automation) {
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index] = automation
            saveAutomations()
            
            // Atualiza geofence
            if automation.triggerType == .location, let location = automation.triggerLocation {
                automationEngine.locationManager?.removeGeofence(for: automation.id)
                automationEngine.locationManager?.addGeofence(for: automation.id, location: location)
            }
        }
    }
    
    func deleteAutomation(_ automation: Automation) {
        automations.removeAll { $0.id == automation.id }
        saveAutomations()
        
        // Remove geofence
        automationEngine.locationManager?.removeGeofence(for: automation.id)
        
        print("🗑️ [Automation] Removida: \(automation.name)")
    }
    
    func toggleAutomation(_ automation: Automation) {
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index].isEnabled.toggle()
            saveAutomations()
            
            let status = automations[index].isEnabled ? "ATIVADA" : "DESATIVADA"
            print("🔄 [Automation] \(status): \(automation.name)")
        }
    }
    
    // MARK: - Chamada Manual de Sensores
    func checkSensorAutomations(for device: Device) {
        automationEngine.checkSensorAutomations(device: device)
    }
    
    // MARK: - Persistência
    private func saveAutomations() {
        if let encoded = try? JSONEncoder().encode(automations) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadAutomations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Automation].self, from: data) else {
            automations = []
            return
        }
        automations = decoded
    }
    
    // MARK: - Histórico
    var executionHistory: [AutomationExecution] {
        return automationEngine.executionHistory
    }
}
