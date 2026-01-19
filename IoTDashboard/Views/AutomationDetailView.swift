import SwiftUI

struct AutomationDetailView: View {
    let automation: Automation
    
    var body: some View {
        List {
            Section(header: Text("Detalhes")) {
                LabeledContent("Nome", value: automation.name)
                LabeledContent("Estado", value: automation.isEnabled ? "Ativo" : "Inativo")
                LabeledContent("Último Disparo", value: automation.lastTriggered?.formatted() ?? "Nunca")
            }
            
            Section(header: Text("Lógica")) {
                LabeledContent("Condição", value: automation.conditionsDescription)
                LabeledContent("Ação", value: automation.actionsDescription)
            }
        }
        .navigationTitle(automation.name)
    }
}
