import Foundation

struct SensorData: Codable, Identifiable, Hashable  {
    // ID único para cada leitura
    var id: String
    
    var temperature: Double
    var humidity: Double
    var timestamp: Int
    var energy: Double?
    
    // Inicializador que aceita todos os parâmetros
    init(
        id: String? = nil,
        temperature: Double,
        humidity: Double,
        timestamp: Int,
        energy: Double? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.temperature = temperature
        self.humidity = humidity
        self.timestamp = timestamp
        self.energy = energy
    }
}

// MARK: - Extensions
extension SensorData {
    var formattedTemperature: String {
        String(format: "%.1f°C", temperature)
    }
    
    var formattedHumidity: String {
        String(format: "%.1f%%", humidity)
    }
    
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return SensorData.dateFormatter.string(from: date)
    }
    
    // Formatador estático para evitar criação repetida (performance)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
    
}
