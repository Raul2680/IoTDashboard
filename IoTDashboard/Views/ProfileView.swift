import SwiftUI
import FirebaseAuth

// MARK: - VISTA PRINCIPAL DO PERFIL
struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var homeAssistantService: HomeAssistantService

    @State private var showLogoutAlert = false
    @State private var showChangePasswordSheet = false
    @State private var showAboutSheet = false
    @State private var showHAConfig = false
    @State private var haEnabled = false
    
    // Variáveis para troca de password
    @State private var newPassword = ""
    @State private var changePasswordError = ""
    @State private var isPasswordChanging = false
    @State private var passwordChangeSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                AppBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Menu Conta
                        VStack(spacing: 0) {
                            SectionHeader(title: "Conta")
                            ProfileMenuItem(icon: "person.fill", title: "Nome", value: authVM.currentUserName, color: themeManager.accentColor)
                            Divider().padding(.leading, 60)
                            ProfileMenuItem(icon: "envelope.fill", title: "Email", value: authVM.currentUserEmail, color: .green)
                            Divider().padding(.leading, 60)
                            Button { showChangePasswordSheet = true } label: {
                                ProfileMenuItem(icon: "lock.fill", title: "Mudar Password", showChevron: true, color: .orange)
                            }
                        }
                        .modifier(CardBackgroundModifier(theme: themeManager.currentTheme))

                        // ✅ NOVO: Home Assistant
                        VStack(spacing: 0) {
                            SectionHeader(title: "🏠 Home Assistant")
                            
                            Toggle(isOn: $haEnabled) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "house.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 16))
                                    }
                                    Text("Ativar Integração")
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .tint(themeManager.accentColor)
                            .onChange(of: haEnabled) { enabled in
                                if let config = homeAssistantService.config {
                                    var newConfig = config
                                    newConfig.isEnabled = enabled
                                    homeAssistantService.saveConfig(newConfig)
                                    
                                    if enabled {
                                        syncHomeAssistantDevices()
                                    }
                                } else if enabled {
                                    showHAConfig = true
                                }
                            }
                            
                            if haEnabled {
                                Divider().padding(.leading, 60)
                                
                                Button {
                                    showHAConfig = true
                                } label: {
                                    ProfileMenuItem(icon: "gear", title: "Configurar", showChevron: true, color: .blue)
                                }
                                
                                Divider().padding(.leading, 60)
                                
                                if homeAssistantService.isConnected {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Conectado")
                                            .foregroundColor(.green)
                                            .font(.subheadline)
                                        Spacer()
                                        Button("🔄 Sincronizar") {
                                            syncHomeAssistantDevices()
                                        }
                                        .font(.caption)
                                        .foregroundColor(themeManager.accentColor)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                } else if let error = homeAssistantService.errorMessage {
                                    HStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .modifier(CardBackgroundModifier(theme: themeManager.currentTheme))

                        // Menu Preferências
                        VStack(spacing: 0) {
                            SectionHeader(title: "Preferências")
                            NavigationLink(destination: NotificationsSettingsView()) {
                                ProfileMenuItem(icon: "bell.fill", title: "Notificações", showChevron: true, color: .red)
                            }
                            Divider().padding(.leading, 60)
                            NavigationLink(destination: AppearanceSettingsView()) {
                                ProfileMenuItem(icon: "paintbrush.fill", title: "Aparência", value: themeManager.currentTheme.rawValue, showChevron: true, color: themeManager.accentColor)
                            }
                            Divider().padding(.leading, 60)
                            NavigationLink(destination: DataSettingsView()) {
                                ProfileMenuItem(icon: "server.rack", title: "Dados e Privacidade", showChevron: true, color: .purple)
                            }
                        }
                        .modifier(CardBackgroundModifier(theme: themeManager.currentTheme))

                        // Menu Suporte
                        VStack(spacing: 0) {
                            SectionHeader(title: "Suporte")
                            NavigationLink(destination: HelpView()) {
                                ProfileMenuItem(icon: "questionmark.circle.fill", title: "Ajuda e Suporte", showChevron: true, color: .cyan)
                            }
                            Divider().padding(.leading, 60)
                            Button { showAboutSheet = true } label: {
                                ProfileMenuItem(icon: "info.circle.fill", title: "Sobre a App", value: "v3.5.0", showChevron: true, color: .blue)
                            }
                        }
                        .modifier(CardBackgroundModifier(theme: themeManager.currentTheme))

                        // Botão Sair
                        logoutButton
                    }
                }
            }
            .navigationTitle("Perfil")
            .alert("Sair", isPresented: $showLogoutAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Sair", role: .destructive) { authVM.logout() }
            }
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordView(newPassword: $newPassword, error: $changePasswordError, isChanging: $isPasswordChanging, onSuccess: {
                    passwordChangeSuccess = true
                    showChangePasswordSheet = false
                }, onCancel: { showChangePasswordSheet = false })
            }
            .sheet(isPresented: $showHAConfig) {
                HomeAssistantConfigView()
                    .environmentObject(homeAssistantService)
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutSheet()
            }
            .onAppear {
                haEnabled = homeAssistantService.config?.isEnabled ?? false
            }
        }
    }
    
    // ✅ Sincroniza dispositivos do Home Assistant
    private func syncHomeAssistantDevices() {
        deviceVM.syncHomeAssistantDevices(haService: homeAssistantService)
    }

    // --- Sub-Views ---
    var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Text(authVM.currentUserName.prefix(1).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text(authVM.currentUserName.isEmpty ? "Utilizador" : authVM.currentUserName)
                .font(.title2.bold())
                .foregroundColor(themeManager.currentTheme == .light ? .primary : .white)
            
            Text(authVM.currentUserEmail)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme == .light ? .secondary : .white.opacity(0.6))
        }
        .padding(.top, 20)
    }

    var logoutButton: some View {
        Button(action: { showLogoutAlert = true }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sair da Conta")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeManager.accentColor)
            .cornerRadius(16)
            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}

// MARK: - COMPONENTES E PÁGINAS SECUNDÁRIAS
// NOTIFICAÇÕES
struct NotificationsSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("pushEnabled") private var pushEnabled = true
    @AppStorage("alertsEnabled") private var alertsEnabled = true
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(spacing: 20) {
                    CustomToggleCard(title: "Notificações Push", subtitle: "Avisos gerais", icon: "bell.badge.fill", isOn: $pushEnabled, color: themeManager.accentColor)
                    if pushEnabled {
                        CustomToggleCard(title: "Alertas Críticos", subtitle: "Gás, Fogo, Offline", icon: "exclamationmark.triangle.fill", isOn: $alertsEnabled, color: .red)
                    }
                }.padding(.top)
            }
        }.navigationTitle("Notificações")
    }
}

struct CustomToggleCard: View {
    let title: String; let subtitle: String; let icon: String; @Binding var isOn: Bool; let color: Color
    var body: some View {
        HStack {
            Image(systemName: icon).font(.title2).foregroundColor(isOn ? .white : color).frame(width: 50, height: 50).background(isOn ? color : color.opacity(0.1)).clipShape(Circle())
            VStack(alignment: .leading) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundColor(.secondary) }
            Spacer(); Toggle("", isOn: $isOn).labelsHidden().tint(color)
        }.padding().background(Color(.secondarySystemGroupedBackground).opacity(0.8)).cornerRadius(16).padding(.horizontal)
    }
}

// DADOS (Legal)
struct DataSettingsView: View {
    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LEGAL").font(.caption.bold()).foregroundColor(.secondary).padding(.leading)
                        VStack(spacing: 1) {
                            NavigationLink(destination: PrivacyPolicyView()) { SettingsRow(icon: "hand.raised.fill", title: "Política de Privacidade", color: .blue) }
                            Divider().padding(.leading, 50)
                            NavigationLink(destination: TermsView()) { SettingsRow(icon: "doc.text.fill", title: "Termos de Uso", color: .purple) }
                        }.background(Color(.secondarySystemGroupedBackground).opacity(0.8)).cornerRadius(12)
                    }.padding(.horizontal)
                }.padding(.top)
            }
        }.navigationTitle("Dados")
    }
}

// PÁGINAS LEGAIS
struct PrivacyPolicyView: View {
    var body: some View {
        LegalLayoutView(title: "Privacidade", icon: "hand.raised.fill", lastUpdated: "2026") {
            LegalSection(header: "1. Recolha", content: "Recolhemos apenas email e estado dos dispositivos.")
            LegalSection(header: "2. Segurança", content: "Utilizamos encriptação Firebase.")
        }
    }
}

struct TermsView: View {
    var body: some View {
        LegalLayoutView(title: "Termos", icon: "doc.text.fill", lastUpdated: "2026") {
            LegalSection(header: "1. Uso", content: "O utilizador é responsável pelos seus dispositivos.")
        }
    }
}

// MARK: - STRUCTS LEGAIS
struct LegalLayoutView<Content: View>: View {
    let title: String; let icon: String; let lastUpdated: String; let content: Content
    
    init(title: String, icon: String, lastUpdated: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.icon = icon; self.lastUpdated = lastUpdated; self.content = content()
    }
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Image(systemName: icon).font(.system(size: 40)).foregroundColor(.blue); VStack(alignment: .leading) { Text(title).font(.title.bold()); Text("Atualizado: \(lastUpdated)").font(.caption).foregroundColor(.secondary) } }.padding(.bottom)
                    VStack(alignment: .leading, spacing: 24) { content }.padding().background(Color(.secondarySystemGroupedBackground).opacity(0.9)).cornerRadius(16)
                }.padding()
            }
        }.navigationTitle(title)
    }
}

struct LegalSection: View {
    let header: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header).font(.headline)
            Text(content).font(.body).foregroundColor(.secondary)
        }
    }
}

// MARK: - AJUDA E REPORT
struct HelpView: View {
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                VStack(spacing: 20) {
                    Link(destination: URL(string: "mailto:suporte@iot.com")!) {
                        HStack { Image(systemName: "envelope.fill"); Text("Contactar Suporte"); Spacer() }
                        .padding().background(Color(.secondarySystemGroupedBackground)).cornerRadius(16)
                    }
                }.padding()
            }
        }.navigationTitle("Ajuda")
    }
}

// MARK: - COMPONENTES AUXILIARES GERAIS
struct CardBackgroundModifier: ViewModifier {
    let theme: AppTheme
    func body(content: Content) -> some View {
        content.background(theme == .light ? Color(.secondarySystemBackground) : Color.white.opacity(0.05)).cornerRadius(16).padding(.horizontal)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View { HStack { Text(title).font(.headline).foregroundColor(.secondary).padding(.leading, 4); Spacer() }.padding(.horizontal).padding(.top, 12).padding(.bottom, 4) }
}

struct ProfileMenuItem: View {
    let icon: String; let title: String; var value: String = ""; var showChevron: Bool = false; let color: Color
    var body: some View {
        HStack(spacing: 16) {
            ZStack { Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36); Image(systemName: icon).foregroundColor(color).font(.system(size: 16)) }
            Text(title).foregroundColor(.primary); Spacer()
            if !value.isEmpty { Text(value).foregroundColor(.secondary).font(.subheadline) }
            if showChevron { Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray) }
        }.padding(.horizontal).padding(.vertical, 12)
    }
}

struct SettingsRow: View {
    let icon: String; let title: String; let color: Color
    var body: some View {
        HStack { Image(systemName: icon).foregroundColor(color).frame(width: 30); Text(title).foregroundColor(.primary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray) }.padding()
    }
}

// MARK: - OUTROS
struct ChangePasswordView: View {
    @Binding var newPassword: String; @Binding var error: String; @Binding var isChanging: Bool
    var onSuccess: () -> Void; var onCancel: () -> Void
    var body: some View { VStack { Text("Mudar Password"); Button("Fechar", action: onCancel) } }
}

struct AboutSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    // URL do teu projeto (substitui pelo teu link real)
    let githubURL = URL(string: "https://github.com/Raul2680/IoTDashboard")!

    var body: some View {
        ZStack {
            themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
            
            BackgroundPatternView(theme: themeManager.currentTheme)
                .opacity(0.3)
            
            VStack(spacing: 20) {
                // Barra superior de fecho
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 6)
                    .padding(.top, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // Header com Logótipo
                        headerSection
                        
                        // Secção: Tecnologias (Escola)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Tecnologias")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                                .padding(.leading, 5)
                            
                            VStack(spacing: 12) {
                                technologyRow(icon: "swift", label: "Desenvolvido em Swift", color: .orange)
                                technologyRow(icon: "iphone", label: "Interface SwiftUI", color: .blue)
                            }
                            .padding()
                            .background(glassBackground)
                        }
                        .padding(.horizontal, 25)
                        
                        // Secção: Repositório (GitHub)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Código Aberto")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                                .padding(.leading, 5)
                            
                            Link(destination: githubURL) {
                                HStack {
                                    Image(systemName: "terminal.fill")
                                        .foregroundColor(themeManager.accentColor)
                                    Text("Ver no GitHub")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                                .padding()
                                .background(themeManager.accentColor.opacity(0.1))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 25)
                        
                        // Informação de Versão
                        VStack(spacing: 4) {
                            Text("© 2026 Raul - Projeto Académico")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 100) // Espaço para o botão fixo
                }
            }
            
            // Botão Fechar Fixo em baixo
            VStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Text("Concluído")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.accentColor)
                        .clipShape(Capsule())
                        .shadow(color: themeManager.accentColor.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
        }
    }

    // --- Componentes Auxiliares ---

    var headerSection: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(themeManager.accentColor.opacity(0.15))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "cpu.fill")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.accentColor)
            }
            
            VStack(spacing: 5) {
                Text("IoT Dashboard")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Versão 3.5.0")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 20)
    }

    func technologyRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.body)
            Spacer()
        }
    }

    var glassBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(themeManager.colorScheme == .light ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
    }
}
