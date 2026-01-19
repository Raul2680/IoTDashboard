import SwiftUI

struct AutomationHistoryView: View {
    @Environment(\.dismiss) var dismiss
    let history: [AutomationExecution]
    
    var body: some View {
        NavigationView {
            List {
                if history.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Sem histórico")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("As execuções de automações aparecerão aqui")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(history) { execution in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: execution.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(execution.success ? .green : .red)
                                
                                Text(execution.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(execution.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let message = execution.message {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Histórico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
