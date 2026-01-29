import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var success = false
    @State private var error = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmVisible = false
    
    var body: some View {
        ZStack {
            // Gradiente de fundo (rosa/roxo)
            LinearGradient(
                colors: [
                    Color(red: 0.8, green: 0.3, blue: 0.9),
                    Color(red: 0.9, green: 0.4, blue: 0.8),
                    Color(red: 1.0, green: 0.5, blue: 0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Círculos decorativos
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 250, height: 250)
                .offset(x: -120, y: -250)
            
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 180, height: 180)
                .offset(x: 140, y: 350)
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Ícone e título
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                        
                        Text("Criar Conta")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Começa a monitorizar os teus sensores")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 10)
                    
                    // Campos de registo
                    VStack(spacing: 16) {
                        // Campo Usuário
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 20)
                            
                            TextField("", text: $username, prompt: Text("Utilizador")
                                .foregroundColor(.white.opacity(0.5)))
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
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
                                TextField("", text: $password, prompt: Text("Senha")
                                    .foregroundColor(.white.opacity(0.5)))
                                .foregroundColor(.white)
                            } else {
                                SecureField("", text: $password, prompt: Text("Senha")
                                    .foregroundColor(.white.opacity(0.5)))
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
                        
                        // Campo Confirmar Senha
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 20)
                            
                            if isConfirmVisible {
                                TextField("", text: $confirm, prompt: Text("Confirmar senha")
                                    .foregroundColor(.white.opacity(0.5)))
                                .foregroundColor(.white)
                            } else {
                                SecureField("", text: $confirm, prompt: Text("Confirmar senha")
                                    .foregroundColor(.white.opacity(0.5)))
                                .foregroundColor(.white)
                            }
                            
                            Button(action: { isConfirmVisible.toggle() }) {
                                Image(systemName: isConfirmVisible ? "eye.slash.fill" : "eye.fill")
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
                        
                        // Mensagem de sucesso
                        if success {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Conta criada! Faz login.")
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Botão Registrar
                    Button(action: handleRegister) {
                        HStack {
                            Text("Registrar")
                                .font(.headline)
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.9))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    
                    // Link voltar ao login
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Já tens conta? Entrar")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func handleRegister() {
        withAnimation {
            error = ""
            success = false
            
            if password != confirm {
                error = "As senhas não coincidem"
                return
            }
            
            if username.isEmpty || password.count < 4 {
                error = "Preencha todos os campos (senha min. 4 caracteres)"
                return
            }
            
            authVM.register(username: username, password: password) { success, errorMessage in
                if success {
                    self.success = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                } else {
                    self.error = errorMessage ?? "Erro ao criar conta"
                }
            }
        }
    }
}
