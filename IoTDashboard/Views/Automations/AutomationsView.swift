import SwiftUI

// MARK: - VIEW PRINCIPAL
struct AutomationsView: View {
    @StateObject private var automationVM = AutomationViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var deviceVM: DeviceViewModel
    
    @State private var showAddSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Consistente
                themeManager.currentTheme.deepBaseColor.ignoresSafeArea()
                BackgroundPatternView(theme: themeManager.currentTheme).opacity(0.15)
                
                if automationVM.automations.isEmpty {
                    emptyState
                } else {
                    // List usada para permitir Swipe nativo
                    List {
                        ForEach(automationVM.automations) { automation in
                            // ✅ SOLUÇÃO: ZStack com Link invisível remove a seta da direita
                            ZStack {
                                AutomationCard(automation: automation, vm: automationVM)
                                
                                NavigationLink(destination: AutomationDetailView(automation: automation)) {
                                    EmptyView()
                                }
                                .opacity(0) // Esconde a seta e o link visual
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteAutomation) // Swipe para apagar
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Automações")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // ✅ BOTÃO CORRIGIDO: Frame fixo para não ser cortado
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(themeManager.accentColor))
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAutomationView(automationVM: automationVM)
                    .environmentObject(deviceVM)
                    .environmentObject(themeManager)
            }
        }
    }
    
    private func deleteAutomation(at offsets: IndexSet) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        automationVM.automations.remove(atOffsets: offsets)
    }
    
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.badge.clock.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            Text("Sem Automações").font(.headline).foregroundColor(.secondary)
        }
    }
}

// MARK: - STRUCT: CARD DE AUTOMAÇÃO
struct AutomationCard: View {
    let automation: Automation
    @ObservedObject var vm: AutomationViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(automation.isEnabled ? themeManager.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 45, height: 45)
                
                Image(systemName: automation.isEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .foregroundColor(automation.isEnabled ? themeManager.accentColor : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(automation.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Text(automation.conditionsDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { automation.isEnabled },
                set: { _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vm.toggleAutomation(automation)
                }
            ))
            .labelsHidden()
            .tint(themeManager.accentColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - STRUCT: ADICIONAR AUTOMAÇÃO (RESOLVE O 0.0°C)
struct AddAutomationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var automationVM: AutomationViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var name = ""
    @State private var selectedTrigger: AutomationTriggerType = .time
    @State private var actions: [AutomationAction] = []
    @State private var showAddAction = false
    
    // Configurações do Gatilho
    @State private var selectedDevice: Device?
    @State private var triggerValue: Double = 25.0
    @State private var comparison: ComparisonOperator = .greaterThan

    var body: some View {
        NavigationView {
            Form {
                Section("Identificação") {
                    TextField("Nome da regra", text: $name)
                }

                Section("Quando... (Gatilho)") {
                    Picker("Gatilho", selection: $selectedTrigger) {
                        ForEach(AutomationTriggerType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    
                    if selectedTrigger == .temperature || selectedTrigger == .humidity {
                        Picker("Sensor", selection: $selectedDevice) {
                            Text("Selecionar Sensor...").tag(nil as Device?)
                            ForEach(deviceVM.devices.filter { $0.type == .sensor }) {
                                Text($0.name).tag($0 as Device?)
                            }
                        }
                        
                        HStack {
                            Picker("Condição", selection: $comparison) {
                                ForEach(ComparisonOperator.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            
                            Spacer()
                            
                            Stepper(value: $triggerValue, in: -10...100) {
                                Text("\(Int(triggerValue))\(selectedTrigger == .temperature ? "°C" : "%")")
                                    .bold()
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                    } else if selectedTrigger == .gas {
                        Picker("Sensor de Gás", selection: $selectedDevice) {
                            Text("Selecionar...").tag(nil as Device?)
                            ForEach(deviceVM.devices.filter { $0.type == .gas }) {
                                Text($0.name).tag($0 as Device?)
                            }
                        }
                    }
                }

                Section("Fazer... (Ações)") {
                    if actions.isEmpty {
                        Text("Nenhuma ação adicionada").foregroundColor(.secondary)
                    } else {
                        ForEach(actions) { action in
                            Text(action.type.rawValue).font(.subheadline)
                        }
                    }
                    Button("Adicionar Ação") { showAddAction = true }
                        .foregroundColor(themeManager.accentColor)
                }
            }
            .navigationTitle("Nova Regra")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") { save() }
                        .bold()
                        .disabled(name.isEmpty || actions.isEmpty)
                }
            }
            .sheet(isPresented: $showAddAction) {
                AddActionView(actions: $actions)
                    .environmentObject(deviceVM)
                    .environmentObject(themeManager)
            }
        }
    }

    // ✅ Lógica de salvamento corrigida para persistir o valor do sensor
    private func save() {
        var newAuto = Automation(name: name, triggerType: selectedTrigger, actions: actions)
        
        if selectedTrigger == .temperature || selectedTrigger == .humidity {
            newAuto.triggerDeviceId = selectedDevice?.id
            newAuto.triggerValue = triggerValue // RESOLVE O ERRO DO 0.0°C
            newAuto.comparisonOperator = comparison
        } else if selectedTrigger == .gas {
            newAuto.triggerDeviceId = selectedDevice?.id
        }
        
        automationVM.addAutomation(newAuto)
        dismiss()
    }
}

// MARK: - STRUCT: ADICIONAR AÇÃO
struct AddActionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var actions: [AutomationAction]
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedType: AutomationActionType = .turnOn
    @State private var targetDevice: Device?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Dispositivo") {
                    Picker("Onde executar", selection: $targetDevice) {
                        Text("Selecionar...").tag(nil as Device?)
                        ForEach(deviceVM.devices) { Text($0.name).tag($0 as Device?) }
                    }
                }
                
                Section("Ação") {
                    Picker("O que fazer?", selection: $selectedType) {
                        ForEach(AutomationActionType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
            }
            .navigationTitle("Adicionar Ação")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        let action = AutomationAction(type: selectedType, targetDeviceId: targetDevice?.id)
                        actions.append(action)
                        dismiss()
                    }
                    .disabled(targetDevice == nil)
                }
            }
        }
    }
}
