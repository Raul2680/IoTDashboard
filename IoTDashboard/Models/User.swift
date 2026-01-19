import Foundation

struct User: Codable {
    let username: String
    let passwordHash: String
    
    init(username: String, password: String) {
        self.username = username
        self.passwordHash = password
        // Não usar em produção, aqui basta simulação!
    }
}
