import Foundation

struct HomeAssistantConfig: Codable {
    var serverURL: String          // ex: http://192.168.1.100:8123
    var accessToken: String         // Long-Lived Access Token
    var isEnabled: Bool = false
    
    var isValid: Bool {
        return !serverURL.isEmpty && !accessToken.isEmpty
    }
}
