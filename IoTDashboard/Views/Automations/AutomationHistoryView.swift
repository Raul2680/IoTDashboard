import SwiftUI

struct AutomationHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    let history: [AutomationExecution]
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                
                if history.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "clock.badge.exclamationmark").font(.largeTitle).foregroundColor(.secondary)
                        Text("Sem registos recentes").foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(history) { log in
                            HStack(spacing: 15) {
                                Circle()
                                    .fill(log.success ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: log.success ? .green : .red, radius: 4)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(log.message ?? "Automação executada")
                                        .font(.subheadline.bold())
                                    Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(log.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                            .padding(.vertical, 4)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Histórico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Concluído") { dismiss() }.fontWeight(.bold) }
        }
    }
}
