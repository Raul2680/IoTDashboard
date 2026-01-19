import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isInsideGeofence: [String: Bool] = [:] // [automationId: isInside]
    
    private let locationManager = CLLocationManager()
    private var monitoredRegions: [String: AutomationLocation] = [:] // [automationId: location]
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Atualiza a cada 50 metros
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startMonitoring() {
        locationManager.startUpdatingLocation()
        print("📍 [Location] A monitorizar localização")
    }
    
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        print("📍 [Location] Parou monitorização")
    }
    
    // MARK: - Geofencing
    func addGeofence(for automationId: String, location: AutomationLocation) {
        monitoredRegions[automationId] = location
        
        // Regista geofence no iOS
        let center = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        let region = CLCircularRegion(center: center, radius: location.radius, identifier: automationId)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationManager.startMonitoring(for: region)
        print("📍 [Geofence] A monitorizar: \(location.name) (raio: \(location.radius)m)")
    }
    
    func removeGeofence(for automationId: String) {
        monitoredRegions.removeValue(forKey: automationId)
        
        if let region = locationManager.monitoredRegions.first(where: { $0.identifier == automationId }) {
            locationManager.stopMonitoring(for: region)
            print("📍 [Geofence] Removida: \(automationId)")
        }
    }
    
    func checkGeofences() {
        guard let location = currentLocation else { return }
        
        for (id, geofenceLocation) in monitoredRegions {
            let wasInside = isInsideGeofence[id] ?? false
            let isNowInside = geofenceLocation.contains(location)
            
            if wasInside != isNowInside {
                print("📍 [Geofence] \(geofenceLocation.name): \(isNowInside ? "ENTROU" : "SAIU")")
                isInsideGeofence[id] = isNowInside
                
                // Publica notificação para o AutomationEngine
                NotificationCenter.default.post(
                    name: .geofenceTriggered,
                    object: nil,
                    userInfo: ["automationId": id, "didEnter": isNowInside]
                )
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        checkGeofences()
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("✅ [Geofence] ENTROU na região: \(region.identifier)")
        isInsideGeofence[region.identifier] = true
        NotificationCenter.default.post(
            name: .geofenceTriggered,
            object: nil,
            userInfo: ["automationId": region.identifier, "didEnter": true]
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("🚪 [Geofence] SAIU da região: \(region.identifier)")
        isInsideGeofence[region.identifier] = false
        NotificationCenter.default.post(
            name: .geofenceTriggered,
            object: nil,
            userInfo: ["automationId": region.identifier, "didEnter": false]
        )
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 [Location] Estado de autorização: \(authorizationStatus.rawValue)")
        
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startMonitoring()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [Location] Erro: \(error.localizedDescription)")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let geofenceTriggered = Notification.Name("geofenceTriggered")
}
