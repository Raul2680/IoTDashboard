import SwiftUI

struct AutomationsView: View {
    @StateObject private var automationVM = AutomationViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var showAddSheet = false
    @State private var showHistory = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackgroundView()
                
                if automationVM.automations.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(automationVM.automations) { automation in
                                AutomationCard(automation: automation, vm: automationVM)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Automações")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(themeManager.accentColor))
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAutomationView(automationVM: automationVM)
                    .environmentObject(deviceVM)
                    .environmentObject(themeManager)
                    .environmentObject(locationManager)
            }
            .sheet(isPresented: $showHistory) {
                AutomationHistoryView(history: automationVM.executionHistory)
            }
            .onAppear {
                automationVM.setDependencies(deviceVM: deviceVM, locationManager: locationManager)
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.badge.clock.fill")
                .font(.system(size: 70))
                .foregroundColor(themeManager.accentColor.opacity(0.5))
            
            Text("Sem Automações")
                .font(.title2.bold())
                .foregroundColor(.secondary)
            
            Text("Crie regras inteligentes para automatizar a sua casa.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Cartão de Automação
struct AutomationCard: View {
    let automation: Automation
    @ObservedObject var vm: AutomationViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Cabeçalho
            HStack {
                ZStack {
                    Circle()
                        .fill(automation.uiColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: iconForTrigger(automation.triggerType))
                        .foregroundColor(automation.uiColor)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(automation.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(automation.isEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(automation.isEnabled ? "Ativo" : "Pausado")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let lastTriggered = automation.lastTriggered {
                            Text("• Última execução: \(lastTriggered, style: .relative)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { automation.isEnabled },
                    set: { _ in vm.toggleAutomation(automation) }
                ))
                .labelsHidden()
                .tint(automation.uiColor)
            }
            .padding()
            
            Divider()
                .padding(.horizontal)
            
            // Lógica SE → ENTÃO
            HStack(spacing: 12) {
                // SE (Gatilho)
                VStack(alignment: .leading, spacing: 4) {
                    Text("SE")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Text(automation.conditionsDescription)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Seta
                Image(systemName: "arrow.right")
                    .foregroundColor(automation.uiColor)
                    .font(.system(size: 16, weight: .bold))
                
                // ENTÃO (Ações)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ENTÃO")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Text("\(automation.actions.count) ação\(automation.actions.count != 1 ? "ões" : "")")
                        .font(.subheadline.bold())
                        .foregroundColor(automation.uiColor)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(Color.black.opacity(0.03))
            
            // Contador de Execuções
            if automation.executionCount > 0 {
                Divider()
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Executada \(automation.executionCount) vez\(automation.executionCount != 1 ? "es" : "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .background(themeManager.currentTheme == .light ? Color.white : Color.white.opacity(0.08))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .opacity(automation.isEnabled ? 1.0 : 0.6)
        .alert("Remover Automação", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Remover", role: .destructive) {
                vm.deleteAutomation(automation)
            }
        } message: {
            Text("Tem certeza que deseja remover '\(automation.name)'?")
        }
    }
    
    private func iconForTrigger(_ type: AutomationTriggerType) -> String {
        switch type {
        case .time: return "clock.fill"
        case .temperature: return "thermometer"
        case .humidity: return "humidity"
        case .gasDetected: return "exclamationmark.triangle.fill"
        case .deviceState: return "lightbulb.fill"
        case .location: return "location.fill"
        case .sunset: return "sunset.fill"
        case .sunrise: return "sunrise.fill"
        }
    }
}
