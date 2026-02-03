import Foundation
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUserName: String = ""
    @Published var currentUserEmail: String = ""
    
    // ✅ CORREÇÃO: Especificamos 'FirebaseAuth.User' para não confundir com o teu 'User'
    var currentUser: FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
    
    init() {
        // Verifica se há utilizador autenticado no Firebase
        checkAuthStatus()
    }
    
    private func checkAuthStatus() {
        if let user = Auth.auth().currentUser {
            isLoggedIn = true
            currentUserEmail = user.email ?? ""
            currentUserName = user.displayName ?? user.email?.components(separatedBy: "@").first ?? "Utilizador"
        }
    }
    
    // MARK: - Login REAL com Firebase
    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let email = username.contains("@") ? username : "\(username)@iotdashboard.com"
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorMessage = self?.getErrorMessage(error) ?? "Erro ao entrar"
                    print("❌ Erro Firebase: \(error.localizedDescription)")
                    completion(false, errorMessage)
                    return
                }
                guard let user = result?.user else {
                    completion(false, "Erro ao obter utilizador")
                    return
                }
                print("✅ Login bem-sucedido: \(user.email ?? "")")
                self?.currentUserEmail = user.email ?? ""
                self?.currentUserName = user.displayName ?? username
                self?.isLoggedIn = true
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Login Google/Firebase universal (real)
    func loginWithFirebase(user: FirebaseAuth.User?) {
        currentUserEmail = user?.email ?? ""
        currentUserName = user?.displayName ?? user?.email?.components(separatedBy: "@").first ?? "Utilizador"
        isLoggedIn = true
        print("✅ Login Google/Firebase bem-sucedido: \(currentUserEmail)")
    }

    
    // MARK: - Registo REAL com Firebase
    func register(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let email = username.contains("@") ? username : "\(username)@iotdashboard.com"
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorMessage = self?.getErrorMessage(error) ?? "Erro ao criar conta"
                    print("❌ Erro ao registar: \(error.localizedDescription)")
                    completion(false, errorMessage)
                    return
                }
                guard let user = result?.user else {
                    completion(false, "Erro ao criar utilizador")
                    return
                }
                // Define o display name
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    if let error = error {
                        print("⚠️ Erro ao definir nome: \(error.localizedDescription)")
                    }
                }
                print("✅ Conta criada: \(email)")
                self?.currentUserEmail = email
                self?.currentUserName = username
                self?.isLoggedIn = true
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Logout
    func logout() {
        do {
            try Auth.auth().signOut()
            print("✅ Logout bem-sucedido")
            isLoggedIn = false
            currentUserName = ""
            currentUserEmail = ""
        } catch {
            print("❌ Erro ao fazer logout: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Mensagens de Erro
    private func getErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Senha incorreta"
        case AuthErrorCode.invalidEmail.rawValue:
            return "Email inválido"
        case AuthErrorCode.userNotFound.rawValue:
            return "Utilizador não encontrado"
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Este email já está em uso"
        case AuthErrorCode.weakPassword.rawValue:
            return "Senha muito fraca (mínimo 6 caracteres)"
        case AuthErrorCode.networkError.rawValue:
            return "Erro de conexão. Verifica a internet"
        case AuthErrorCode.invalidCredential.rawValue:
            return "Credenciais inválidas"
        default:
            return "Erro: \(error.localizedDescription)"
        }
    }
}
