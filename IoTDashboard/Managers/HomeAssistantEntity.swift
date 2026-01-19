import Foundation

// MARK: - Home Assistant Entity Model
struct HomeAssistantEntity: Codable {
    let entity_id: String
    let state: String
    let attributes: EntityAttributes
}

struct EntityAttributes: Codable {
    let friendly_name: String?
    let area_id: String?
    let device_class: String?
    let unit_of_measurement: String?
    let brightness: Int?
    let rgb_color: [Int]?
    let temperature: Double?
    let humidity: Double?
    
    enum CodingKeys: String, CodingKey {
        case friendly_name
        case area_id
        case device_class
        case unit_of_measurement
        case brightness
        case rgb_color
        case temperature
        case humidity
    }
}
