import Foundation
import FirebaseFirestore
import Combine

// Modelo de Utilizador para a lista de Admin
struct AppUser: Identifiable, Codable {
    let id: String
    let username: String
    let email: String
    let role: String?
}

class AdminService: ObservableObject {
    @Published var registeredUsers: [AppUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let db = Firestore.firestore()
    
    func fetchUsers() {
        self.isLoading = true
        self.errorMessage = nil
        
        // Acede à coleção 'users' no Firestore
        db.collection("users").getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Erro ao buscar utilizadores: \(error.localizedDescription)")
                    self?.errorMessage = "Erro ao carregar utilizadores."
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ Nenhum documento encontrado.")
                    return
                }
                
                self?.registeredUsers = documents.compactMap { doc -> AppUser? in
                    let data = doc.data()
                    let id = doc.documentID
                    let email = data["email"] as? String ?? "Sem Email"
                    let username = data["username"] as? String ?? data["name"] as? String ?? "Sem Nome"
                    let role = data["role"] as? String ?? "user"
                    
                    return AppUser(id: id, username: username, email: email, role: role)
                }
                
                print("✅ \(self?.registeredUsers.count ?? 0) utilizadores carregados.")
            }
        }
    }
    
    func deleteUser(userId: String) {
        db.collection("users").document(userId).delete { [weak self] error in
            if let error = error {
                print("❌ Erro ao apagar: \(error.localizedDescription)")
            } else {
                print("✅ Utilizador apagado.")
                self?.fetchUsers() // Atualiza a lista
            }
        }
    }
}
