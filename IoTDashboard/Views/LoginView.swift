import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var error = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var showResetPasswordSheet = false
    @State private var resetEmail = ""
    @State private var resetError = ""
    @State private var resetSuccess = false
    @State private var isResettingPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradiente de fundo decorativo
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.3, blue: 0.9),
                        Color(red: 0.6, green: 0.4, blue: 0.95),
                        Color(red: 0.7, green: 0.5, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .offset(x: -150, y: -300)
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: 150, y: 400)
                
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer().frame(height: 60)
                        // Logo/Ícone
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "homekit")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                            Text("IoT Dashboard")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            Text("Monitoriza os teus sensores")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.bottom, 20)
                        
                        // Botão Google
                        Button(action: handleGoogleSignIn) {
                            HStack(spacing: 12) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 22))
                                Text("Entrar com Google")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 30)
                        
                        // Divisor "ou"
                        HStack(spacing: 12) {
                            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                            Text("ou")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.subheadline)
                            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                        }.padding(.horizontal, 40)
                        
                        // Login tradicional
                        VStack(spacing: 16) {
                            // Campo Usuário/Email
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20)
                                TextField("", text: $username, prompt: Text("Email ou utilizador").foregroundColor(.white.opacity(0.5)))
                                    .foregroundColor(.white)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            // Campo Senha
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20)
                                if isPasswordVisible {
                                    TextField("", text: $password, prompt: Text("Senha").foregroundColor(.white.opacity(0.5)))
                                        .foregroundColor(.white)
                                } else {
                                    SecureField("", text: $password, prompt: Text("Senha").foregroundColor(.white.opacity(0.5)))
                                        .foregroundColor(.white)
                                }
                                Button(action: { isPasswordVisible.toggle() }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            // Mensagem de erro
                            if !error.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(error)
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(12)
                                .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Botão Entrar
                        Button(action: handleLogin) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.5, green: 0.4, blue: 0.95)))
                                } else {
                                    Text("Entrar").font(.headline)
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                            }
                            .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.95))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isLoading || username.isEmpty || password.isEmpty)
                        .opacity((username.isEmpty || password.isEmpty) ? 0.6 : 1)
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                        
                        // Link Esqueci a password
                        Button {
                            showResetPasswordSheet = true
                        } label: {
                            Text("Esqueci a password")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 4)
                        
                        // Link Criar conta
                        NavigationLink(destination: RegisterView()) {
                            HStack(spacing: 4) {
                                Text("Novo aqui?")
                                    .foregroundColor(.white.opacity(0.9))
                                Text("Criar conta")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .font(.subheadline)
                        }
                        .padding(.top, 10)
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showResetPasswordSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("E-mail da conta")) {
                            TextField("Email", text: $resetEmail)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        if !resetError.isEmpty {
                            Text(resetError)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        if resetSuccess {
                            Text("Email enviado! Verifica o teu email.")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        Button("Redefinir Password") {
                            isResettingPassword = true
                            resetError = ""
                            Auth.auth().sendPasswordReset(withEmail: resetEmail) { error in
                                DispatchQueue.main.async {
                                    isResettingPassword = false
                                    if let error = error {
                                        resetError = error.localizedDescription
                                        resetSuccess = false
                                    } else {
                                        resetError = ""
                                        resetSuccess = true
                                    }
                                }
                            }
                        }
                        .disabled(resetEmail.isEmpty || isResettingPassword)
                    }
                    .navigationTitle("Recuperação Password")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Fechar") {
                                showResetPasswordSheet = false
                                resetEmail = ""
                                resetError = ""
                                resetSuccess = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Login tradicional
    private func handleLogin() {
        isLoading = true
        error = ""
        authVM.login(username: username, password: password) { success, errorMessage in
            isLoading = false
            if !success {
                withAnimation { error = errorMessage ?? "Erro ao entrar" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { error = "" }
                }
            }
        }
    }
    


    
    
    // MARK: - Login Google real via Firebase
    func getRootViewController() -> UIViewController {
        guard let scene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .first as? UIWindowScene,
            let rootVC = scene.windows
                .filter({ $0.isKeyWindow })
                .first?
                .rootViewController else {
            fatalError("Não foi possível encontrar a rootViewController.")
        }
        return rootVC
    }
    
    
    // MARK: - Google Sign-In (Updated for SDK 7+ and Firebase 2025)
    private func handleGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            error = "Erro: Client ID do Firebase não encontrado."
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootViewController = windowScene.windows
                .first(where: { $0.isKeyWindow })?.rootViewController else {
            error = "Erro interno: não foi possível apresentar o login."
            return
        }
        
        isLoading = true
        error = ""
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.error = "Falha ao obter token do Google"
                    return
                }
                
                let accessToken = user.accessToken.tokenString
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: accessToken
                )
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.error = error.localizedDescription
                        } else if let firebaseUser = authResult?.user {
                            authVM.loginWithFirebase(user: firebaseUser)
                        }
                    }
                }
            }
        }
    }




}
