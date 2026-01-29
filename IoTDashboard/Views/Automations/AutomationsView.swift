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
                // Fundo dinâmico baseado no tema selecionado
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                BackgroundPatternView(theme: themeManager.currentTheme).opacity(0.3)
                
                if automationVM.automations.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(automationVM.automations) { automation in
                                // FIX: NavigationLink para abrir a AutomationDetailView
                                NavigationLink(destination: AutomationDetailView(automation: automation)) {
                                    AutomationCard(automation: automation, vm: automationVM)
                                }
                                .buttonStyle(PlainButtonStyle()) // Mantém as cores originais do card
                                .transition(.asymmetric(insertion: .scale, removal: .opacity))
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Automações")
            .toolbar {
                // Botão de Histórico (Esquerda)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                
                // Botão de Adicionar (Direita)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(themeManager.accentColor))
                            .shadow(color: themeManager.accentColor.opacity(0.4), radius: 5)
                    }
                }
            }
            // Sheets para as subviews
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
    
    // Estado vazio quando não há automações criadas
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.badge.clock.fill")
                .font(.system(size: 70))
                .foregroundColor(themeManager.accentColor.opacity(0.5))
            
            Text("Sem Automações")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Crie regras inteligentes para automatizar a sua casa.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - CARTÃO DE AUTOMAÇÃO (CORRIGIDO)
struct AutomationCard: View {
    let automation: Automation
    @ObservedObject var vm: AutomationViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Cabeçalho: Ícone, Nome e Toggle
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
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(automation.isEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(automation.isEnabled ? "Ativo" : "Pausado")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Toggle para ativar/desativar rapidamente
                Toggle("", isOn: Binding(
                    get: { automation.isEnabled },
                    set: { _ in vm.toggleAutomation(automation) }
                ))
                .labelsHidden()
                .tint(themeManager.accentColor)
                // Impede que o clique no Toggle abra o NavigationLink
                .onTapGesture {}
            }
            .padding()
            
            Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
            
            // Lógica SE -> ENTÃO (Visual)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SE")
                        .font(.caption2.bold())
                        .foregroundColor(themeManager.accentColor)
                    
                    Text(automation.conditionsDescription)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(themeManager.accentColor.opacity(0.6))
                    .font(.system(size: 14, weight: .black))
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ENTÃO")
                        .font(.caption2.bold())
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("\(automation.actions.count) ações")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(Color.white.opacity(0.04))
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelectedBorder, lineWidth: 1)
        )
        .opacity(automation.isEnabled ? 1.0 : 0.6)
        
        // --- FUNCIONALIDADE: SEGURAR PARA APAGAR ---
        .contextMenu {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Apagar Automação", systemImage: "trash")
            }
        }
        // ------------------------------------------
        
        .alert("Remover Automação", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Remover", role: .destructive) {
                withAnimation {
                    vm.deleteAutomation(automation)
                }
            }
        } message: {
            Text("Tens a certeza que queres apagar '\(automation.name)'?")
        }
    }
    
    private var isSelectedBorder: Color {
        automation.isEnabled ? themeManager.accentColor.opacity(0.3) : Color.white.opacity(0.1)
    }
    
    private func iconForTrigger(_ type: AutomationTriggerType) -> String {
        switch type {
        case .time: return "clock.fill"
        case .temperature: return "thermometer.medium"
        case .location: return "location.fill"
        case .sunset: return "sunset.fill"
        default: return "bolt.fill"
        }
    }
}
