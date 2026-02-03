import SwiftUI

struct AutomationDetailView: View {
    let automation: Automation
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var automationVM: AutomationViewModel
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            // MARK: - Background Dinâmico
            themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
            
            // Brilho de cor da automação no fundo
            RadialGradient(
                colors: [automation.uiColor.opacity(0.15), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            ).ignoresSafeArea()
            
            BackgroundPatternView(theme: themeManager.currentTheme).opacity(0.15)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // MARK: - Header Premium
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(automation.uiColor.opacity(0.15))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .stroke(automation.uiColor.opacity(0.3), lineWidth: 2)
                                )
                            
                            Image(systemName: automation.isEnabled ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundColor(automation.uiColor)
                                .shadow(color: automation.uiColor.opacity(0.5), radius: 10)
                        }
                        
                        VStack(spacing: 6) {
                            Text(automation.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(automation.isEnabled ? "Automação Ativa" : "Automação Pausada")
                                .font(.subheadline.bold())
                                .foregroundColor(automation.isEnabled ? .green : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(automation.isEnabled ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 20)

                    // MARK: - Cartão de Estatísticas (Glassmorphism)
                    VStack(spacing: 0) {
                        DetailRow(label: "Execuções Totais", value: "\(automation.executionCount)", icon: "play.fill", color: .blue)
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 40)
                        DetailRow(label: "Última Atividade", value: automation.lastTriggered?.formatted(date: .abbreviated, time: .shortened) ?? "Nunca", icon: "clock.fill", color: .purple)
                    }
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    .padding(.horizontal)

                    // MARK: - Fluxo da Automação (Visual Step-by-Step)
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Fluxo de Trabalho")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 5)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            LogicStepView(
                                title: "SE ESTA CONDIÇÃO FOR ATENDIDA",
                                description: automation.conditionsDescription,
                                icon: "arrow.right.circle.fill",
                                color: themeManager.accentColor,
                                isFirst: true
                            )
                            
                            Rectangle()
                                .fill(LinearGradient(colors: [themeManager.accentColor, .green], startPoint: .top, endPoint: .bottom))
                                .frame(width: 2, height: 30)
                                .padding(.leading, 34)
                            
                            LogicStepView(
                                title: "ENTÃO EXECUTAR ESTA AÇÃO",
                                description: automation.actionsDescription,
                                icon: "play.circle.fill",
                                color: .green,
                                isFirst: false
                            )
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Botões de Ação
                    VStack(spacing: 12) {
                        // Ativar / Pausar
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            automationVM.toggleAutomation(automation)
                        }) {
                            HStack {
                                Image(systemName: automation.isEnabled ? "pause.fill" : "play.fill")
                                Text(automation.isEnabled ? "Pausar Automação" : "Ativar Automação")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(automation.isEnabled ? Color.orange.opacity(0.8) : themeManager.accentColor.opacity(0.8))
                            .cornerRadius(16)
                        }

                        // REMOVER AUTOMAÇÃO
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Remover Automação")
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Detalhes")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remover Automação", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Remover", role: .destructive) {
                if let index = automationVM.automations.firstIndex(where: { $0.id == automation.id }) {
                    automationVM.automations.remove(at: index)
                    dismiss()
                }
            }
        } message: {
            Text("Tens a certeza que desejas eliminar esta regra permanentemente?")
        }
    }
}

// MARK: - COMPONENTES AUXILIARES

struct LogicStepView: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isFirst: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(color)
                    .tracking(1)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(color.opacity(0.1)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            }
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding()
    }
}
