import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager // Sincronização com o tema
    @Environment(\.dismiss) var dismiss
    
    @State private var username = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var success = false
    @State private var error = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmVisible = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // 1. Fundo Base do Tema (Sincronizado com Home/Login)
            themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
            
            // 2. Padrão Geométrico
            if themeManager.currentTheme != .light {
                BackgroundPatternView(theme: themeManager.currentTheme)
                    .opacity(0.3)
            }
            
            // 3. Brilho de Acento Superior (Vindo do estilo da HomeView)
            LinearGradient(
                colors: [themeManager.accentColor.opacity(0.15), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    Spacer().frame(height: 40)
                    
                    // Header com Ícone Glass
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(Circle().stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1))
                            
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 35))
                                .foregroundColor(themeManager.accentColor)
                        }
                        .shadow(color: themeManager.accentColor.opacity(0.3), radius: 15, x: 0, y: 8)
                        
                        Text("Criar Conta")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
                        
                        Text("Começa a monitorizar os teus sensores")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Card de Registo Estilo Glass
                    VStack(spacing: 18) {
                        // Campo Email/User
                        customInputField(icon: "person.fill", placeholder: "Utilizador", text: $username)
                        
                        // Campo Senha
                        customPasswordField(icon: "lock.fill", placeholder: "Senha", text: $password, isVisible: $isPasswordVisible)
                        
                        // Campo Confirmar Senha
                        customPasswordField(icon: "lock.shield.fill", placeholder: "Confirmar senha", text: $confirm, isVisible: $isConfirmVisible)
                        
                        // Mensagens de Feedback (Erro/Sucesso)
                        if !error.isEmpty || success {
                            feedbackMessage
                        }
                        
                        // Botão Registrar Premium
                        Button(action: handleRegister) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Registrar").bold()
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(themeManager.accentColor.gradient)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(isLoading)
                        .padding(.top, 10)
                    }
                    .padding(25)
                    .background(themeManager.currentTheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.06))
                    .cornerRadius(28)
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    .padding(.horizontal, 25)
                    
                    // Botão Voltar
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Já tens conta? Entrar")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(themeManager.accentColor)
                    }
                    .padding(.top, 10)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Componentes Customizados
    
    private func customInputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(themeManager.accentColor).frame(width: 20)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(.gray.opacity(0.5)))
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(14)
    }
    
    private func customPasswordField(icon: String, placeholder: String, text: Binding<String>, isVisible: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(themeManager.accentColor).frame(width: 20)
            if isVisible.wrappedValue {
                TextField("", text: text, prompt: Text(placeholder).foregroundColor(.gray.opacity(0.5)))
            } else {
                SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.gray.opacity(0.5)))
            }
            Button { isVisible.wrappedValue.toggle() } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill").foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(14)
    }
    
    private var feedbackMessage: some View {
        HStack {
            Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            Text(success ? "Conta criada! Faz login." : error)
        }
        .font(.caption.bold())
        .foregroundColor(success ? .green : .red)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Lógica de Registro
    private func handleRegister() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        guard password == confirm else {
            withAnimation { error = "As senhas não coincidem" }
            return
        }
        
        guard !username.isEmpty && password.count >= 4 else {
            withAnimation { error = "Preencha tudo (Senha min. 4 caracteres)" }
            return
        }
        
        isLoading = true
        error = ""
        
        authVM.register(username: username, password: password) { success, errorMessage in
            isLoading = false
            if success {
                self.success = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            } else {
                withAnimation { self.error = errorMessage ?? "Erro ao criar conta" }
            }
        }
    }
}
