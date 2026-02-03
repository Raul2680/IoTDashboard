import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager // Sincronização com o tema
    
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
                // 1. Fundo Base do Tema
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                // 2. Padrão Geométrico (Apenas se não for Light Mode, conforme a tua HomeView)
                if themeManager.currentTheme != .light {
                    BackgroundPatternView(theme: themeManager.currentTheme)
                        .opacity(0.3)
                }
                
                // 3. Brilho de Acento (Vindo da HomeView)
                LinearGradient(
                    colors: [themeManager.accentColor.opacity(0.15), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        Spacer().frame(height: 50)
                        
                        // Logo e Header
                        headerSection
                        
                        // Card de Login (Glassmorphism)
                        loginCard
                        
                        // Divisor "ou"
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("ou continua com").font(.caption).foregroundColor(.secondary)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                        .padding(.horizontal, 40)
                        
                        // Botão Google Premium
                        googleSignInButton
                        
                        // Link de Registro
                        NavigationLink(destination: RegisterView()) {
                            HStack(spacing: 4) {
                                Text("Ainda não tens conta?")
                                    .foregroundColor(.secondary)
                                Text("Regista-te")
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.accentColor)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.bottom, 20)
                }
                
                // Overlay de Erro Flutuante
                if !error.isEmpty {
                    errorToast
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Subcomponentes de UI
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(themeManager.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(Circle().stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1))
                
                Image(systemName: "homekit")
                    .font(.system(size: 50))
                    .foregroundColor(themeManager.accentColor)
                    .shadow(color: themeManager.accentColor.opacity(0.5), radius: 10)
            }
            
            Text("IoT Dashboard")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            
            Text("Monitoriza a tua casa inteligente")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var loginCard: some View {
        VStack(spacing: 20) {
            // Campos de Texto
            VStack(spacing: 16) {
                loginInputField(icon: "envelope.fill", placeholder: "Email", text: $username)
                
                loginPasswordField(icon: "lock.fill", placeholder: "Senha", text: $password)
            }
            
            // Esqueci a password
            HStack {
                Spacer()
                Button("Esqueci a password") { showResetPasswordSheet = true }
                    .font(.caption2.bold())
                    .foregroundColor(themeManager.accentColor)
            }
            
            // Botão Login
            Button(action: handleLogin) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Entrar").bold()
                        Image(systemName: "arrow.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(themeManager.accentColor.gradient)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(isLoading || username.isEmpty || password.isEmpty)
            .opacity((username.isEmpty || password.isEmpty) ? 0.6 : 1)
        }
        .padding(25)
        .background(themeManager.currentTheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.06))
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        .padding(.horizontal, 25)
    }
    
    private var googleSignInButton: some View {
        Button(action: handleGoogleSignIn) {
            HStack(spacing: 12) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20))
                Text("Entrar com o Google")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal, 25)
    }
    
    private var errorToast: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.octagon.fill").foregroundColor(.red)
                Text(error).font(.subheadline).foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(BlurView(style: .systemUltraThinMaterialDark))
            .cornerRadius(15)
            .padding()
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation { error = "" }
            }
        }
    }
    
    // MARK: - Helpers de Input
    
    private func loginInputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(themeManager.accentColor).frame(width: 20)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(.gray.opacity(0.5)))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(14)
    }
    
    private func loginPasswordField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(themeManager.accentColor).frame(width: 20)
            if isPasswordVisible {
                TextField("", text: text, prompt: Text(placeholder).foregroundColor(.gray.opacity(0.5)))
            } else {
                SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.gray.opacity(0.5)))
            }
            Button { isPasswordVisible.toggle() } label: {
                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill").foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(14)
    }

    // MARK: - Lógica (Sincronizada com o teu AuthVM)
    private func handleLogin() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isLoading = true
        error = ""
        authVM.login(username: username, password: password) { success, errorMessage in
            isLoading = false
            if !success { withAnimation { error = errorMessage ?? "Erro ao entrar" } }
        }
    }
    
    // MARK: - Google Sign-In
    private func handleGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        
        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            self.isLoading = false
            if let error = error { self.error = error.localizedDescription; return }
            
            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error { self.error = error.localizedDescription }
                else if let firebaseUser = authResult?.user { authVM.loginWithFirebase(user: firebaseUser) }
            }
        }
    }
}

// Componente auxiliar para o Toast de erro
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: style)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = UIBlurEffect(style: style) }
}
