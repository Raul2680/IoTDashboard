import Foundation

struct GasData: Codable, Identifiable, Hashable  {
    var id: String
    var mq2: Int
    var mq7: Int
    var status: Int
    var timestamp: Int
    
    // Inicializador
    init(
        id: String? = nil,
        mq2: Int,
        mq7: Int = 0,
        status: Int,
        timestamp: Int
    ) {
        self.id = id ?? UUID().uuidString
        self.mq2 = mq2
        self.mq7 = mq7
        self.status = status
        self.timestamp = timestamp
    }
    
    // Texto do status
    var statusText: String {
        switch status {
        case 2: return "PERIGO DETETADO"
        case 1: return "Aviso"
        default: return "Normal"
        }
    }
}

// MARK: - Extensions
extension GasData {
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
