import SwiftUI

struct AutomationDetailView: View {
    let automation: Automation
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Fundo consistente
            themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
            BackgroundPatternView(theme: themeManager.currentTheme).opacity(0.2)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header com Ícone Grande
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(automation.uiColor.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "bolt.fill") // Ou o ícone do trigger
                                .font(.system(size: 40))
                                .foregroundColor(automation.uiColor)
                        }
                        
                        Text(automation.name)
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        Text(automation.isEnabled ? "Automação Ativa" : "Automação Pausada")
                            .font(.subheadline)
                            .foregroundColor(automation.isEnabled ? .green : .gray)
                    }
                    .padding(.vertical, 30)

                    // Cartão de Estatísticas
                    VStack(spacing: 15) {
                        DetailRow(label: "Execuções", value: "\(automation.executionCount)", icon: "play.circle")
                        DetailRow(label: "Último Disparo", value: automation.lastTriggered?.formatted(date: .abbreviated, time: .shortened) ?? "Nunca", icon: "clock")
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal)

                    // Cartão de Lógica (SE -> ENTÃO)
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Lógica da Automação")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(alignment: .top, spacing: 15) {
                            VStack(alignment: .leading) {
                                Text("SE")
                                    .font(.caption.bold())
                                    .foregroundColor(themeManager.accentColor)
                                Text(automation.conditionsDescription)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("ENTÃO")
                                    .font(.caption.bold())
                                    .foregroundColor(themeManager.accentColor)
                                Text(automation.actionsDescription)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Detalhes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Subview para as linhas de detalhe
struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}
