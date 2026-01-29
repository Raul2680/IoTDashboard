import SwiftUI
import MapKit

struct AddAutomationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var automationVM: AutomationViewModel
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var locationManager: LocationManager
    
    // Estados Básicos
    @State private var name = ""
    @State private var selectedColor = "blue"
    @State private var selectedTrigger: AutomationTriggerType = .time
    
    // Gatilho: Horário
    @State private var selectedTime = Date()
    @State private var selectedDays: Set<Int> = []
    
    // Gatilho: Sensor
    @State private var selectedTriggerDevice: Device?
    @State private var comparisonOperator: ComparisonOperator = .greaterThan
    @State private var triggerValue: String = ""
    
    // Gatilho: Localização
    @State private var locationName = ""
    @State private var locationRadius: Double = 100
    @State private var locationType: LocationTriggerType = .enter
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showMapPicker = false
    
    // Ações (Múltiplas)
    @State private var actions: [AutomationAction] = []
    @State private var showAddAction = false
    
    let colors = ["blue", "purple", "orange", "green", "red", "pink", "cyan"]
    let weekDays = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Nome e Cor
                Section(header: Text("Informação Básica")) {
                    TextField("Nome da Automação", text: $name)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(getColor(color))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14, weight: .bold))
                                            .opacity(selectedColor == color ? 1 : 0)
                                    )
                                    .onTapGesture { selectedColor = color }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // MARK: - Tipo de Gatilho
                Section(header: Text("Quando... (Gatilho)")) {
                    Picker("Tipo de Gatilho", selection: $selectedTrigger) {
                        ForEach(AutomationTriggerType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    // Configurações específicas por tipo
                    triggerConfigView
                }
                
                // MARK: - Ações
                Section(header: Text("Fazer... (Ações)")) {
                    if actions.isEmpty {
                        Text("Sem ações configuradas")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(actions) { action in
                            HStack {
                                Image(systemName: iconForAction(action.type))
                                    .foregroundColor(getColor(selectedColor))
                                
                                VStack(alignment: .leading) {
                                    Text(action.type.rawValue)
                                        .font(.headline)
                                    
                                    if let deviceId = action.targetDeviceId,
                                       let device = deviceVM.devices.first(where: { $0.id == deviceId }) {
                                        Text(device.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button {
                                    actions.removeAll { $0.id == action.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Button {
                        showAddAction = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Adicionar Ação")
                        }
                        .foregroundColor(getColor(selectedColor))
                    }
                }
            }
            .navigationTitle("Nova Automação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        saveAutomation()
                    }
                    .disabled(name.isEmpty || actions.isEmpty)
                }
            }
            .sheet(isPresented: $showAddAction) {
                AddActionView(actions: $actions)
                    .environmentObject(deviceVM)
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showMapPicker) {
                MapLocationPicker(coordinate: $selectedCoordinate, locationName: $locationName)
            }
        }
    }
    
    // MARK: - Configuração de Gatilho (Dinâmica)
    @ViewBuilder
    var triggerConfigView: some View {
        switch selectedTrigger {
        case .time:
            DatePicker("Horário", selection: $selectedTime, displayedComponents: .hourAndMinute)
            
            VStack(alignment: .leading) {
                Text("Dias da Semana")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    ForEach(0..<7, id: \.self) { day in
                        Button {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        } label: {
                            Text(weekDays[day])
                                .font(.caption)
                                .fontWeight(selectedDays.contains(day) ? .bold : .regular)
                                .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(selectedDays.contains(day) ? getColor(selectedColor) : Color.gray.opacity(0.2))
                                )
                        }
                    }
                }
            }
            
        case .temperature, .humidity:
            Picker("Dispositivo", selection: $selectedTriggerDevice) {
                Text("Selecione...").tag(nil as Device?)
                ForEach(deviceVM.devices.filter { $0.type == .sensor }) { device in
                    Text(device.name).tag(device as Device?)
                }
            }
            
            if selectedTriggerDevice != nil {
                HStack {
                    Picker("Operador", selection: $comparisonOperator) {
                        ForEach(ComparisonOperator.allCases, id: \.self) { op in
                            Text(op.rawValue).tag(op)
                        }
                    }
                    .frame(maxWidth: 100)
                    
                    TextField("Valor", text: $triggerValue)
                        .keyboardType(.decimalPad)
                    
                    Text(selectedTrigger == .temperature ? "°C" : "%")
                        .foregroundColor(.secondary)
                }
            }
            
        case .gasDetected:
            Picker("Sensor de Gás", selection: $selectedTriggerDevice) {
                Text("Selecione...").tag(nil as Device?)
                ForEach(deviceVM.devices.filter { $0.type == .gas }) { device in
                    Text(device.name).tag(device as Device?)
                }
            }
            
        case .location:
            TextField("Nome do Local", text: $locationName)
                .placeholder(when: locationName.isEmpty) {
                    Text("Ex: Casa, Trabalho")
                }
            
            Picker("Quando", selection: $locationType) {
                ForEach(LocationTriggerType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            
            HStack {
                Text("Raio:")
                Slider(value: $locationRadius, in: 50...1000, step: 50)
                Text("\(Int(locationRadius))m")
                    .frame(width: 60)
                    .foregroundColor(.secondary)
            }
            
            Button {
                showMapPicker = true
            } label: {
                HStack {
                    Image(systemName: "map")
                    Text(selectedCoordinate == nil ? "Escolher no Mapa" : "Localização Definida")
                }
                .foregroundColor(getColor(selectedColor))
            }
            
            if selectedCoordinate != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Coordenadas: \(String(format: "%.4f, %.4f", selectedCoordinate!.latitude, selectedCoordinate!.longitude))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        case .sunset, .sunrise:
            Text("Usa a localização atual do dispositivo")
                .font(.caption)
                .foregroundColor(.secondary)
            
        case .deviceState:
            Picker("Dispositivo", selection: $selectedTriggerDevice) {
                Text("Selecione...").tag(nil as Device?)
                ForEach(deviceVM.devices) { device in
                    Text(device.name).tag(device as Device?)
                }
            }
        }
    }
    
    // MARK: - Guardar Automação
    private func saveAutomation() {
        var automation = Automation(
            name: name.isEmpty ? "Nova Automação" : name,
            color: selectedColor,
            triggerType: selectedTrigger,
            actions: actions
        )
        
        // Configuração específica do gatilho
        switch selectedTrigger {
        case .time:
            automation.triggerTime = selectedTime
            automation.triggerDays = selectedDays.isEmpty ? nil : Array(selectedDays)
            
        case .temperature, .humidity:
            automation.triggerDeviceId = selectedTriggerDevice?.id
            automation.comparisonOperator = comparisonOperator
            automation.triggerValue = Double(triggerValue)
            
        case .gasDetected, .deviceState:
            automation.triggerDeviceId = selectedTriggerDevice?.id
            
        case .location:
            if let coord = selectedCoordinate {
                automation.triggerLocation = AutomationLocation(
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    radius: locationRadius,
                    name: locationName
                )
                automation.locationTriggerType = locationType
            }
            
        default:
            break
        }
        
        automationVM.addAutomation(automation)
        dismiss()
    }
    
    // MARK: - Helpers
    private func getColor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .blue
        }
    }
    
    private func iconForAction(_ type: AutomationActionType) -> String {
        switch type {
        case .turnOn: return "power"
        case .turnOff: return "power"
        case .setColor: return "paintpalette"
        case .setBrightness: return "light.max"
        case .notify: return "bell.badge"
        case .sendEmail: return "envelope"
        }
    }
}

// MARK: - AddActionView (Sheet para adicionar ação)
struct AddActionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var actions: [AutomationAction]
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedActionType: AutomationActionType = .turnOn
    @State private var selectedDevice: Device?
    @State private var actionValue = ""
    @State private var selectedColor = Color.blue
    @State private var brightness: Double = 100
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tipo de Ação")) {
                    Picker("Ação", selection: $selectedActionType) {
                        ForEach(AutomationActionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section(header: Text("Dispositivo")) {
                    Picker("Selecione o Dispositivo", selection: $selectedDevice) {
                        Text("Nenhum").tag(nil as Device?)
                        ForEach(deviceVM.devices) { device in
                            Text(device.name).tag(device as Device?)
                        }
                    }
                }
                
                // Configurações específicas
                if selectedActionType == .setColor {
                    Section(header: Text("Cor")) {
                        ColorPicker("Escolha a Cor", selection: $selectedColor)
                    }
                }
                
                if selectedActionType == .setBrightness {
                    Section(header: Text("Brilho")) {
                        HStack {
                            Slider(value: $brightness, in: 0...100, step: 1)
                            Text("\(Int(brightness))%")
                                .frame(width: 50)
                        }
                    }
                }
                
                if selectedActionType == .notify {
                    Section(header: Text("Mensagem")) {
                        TextField("Mensagem da notificação", text: $actionValue)
                    }
                }
            }
            .navigationTitle("Nova Ação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Adicionar") {
                        addAction()
                    }
                    .disabled(selectedDevice == nil && selectedActionType != .notify)
                }
            }
        }
    }
    
    private func addAction() {
        var action = AutomationAction(
            type: selectedActionType,
            targetDeviceId: selectedDevice?.id
        )
        
        switch selectedActionType {
        case .setColor:
            action.value = selectedColor.toHex()
        case .setBrightness:
            action.value = String(Int(brightness))
        case .notify:
            action.value = actionValue
        default:
            break
        }
        
        actions.append(action)
        dismiss()
    }
}

// MARK: - Map Location Picker
struct MapLocationPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var coordinate: CLLocationCoordinate2D?
    @Binding var locationName: String
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.7223, longitude: -9.1393), // Lisboa
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedLocation: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: selectedLocation != nil ? [MapPin(coordinate: selectedLocation!)] : []) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: .blue)
                }
                .onTapGesture(perform: handleMapTap)
                
                VStack {
                    Spacer()
                    
                    if selectedLocation != nil {
                        VStack(spacing: 8) {
                            Text("📍 Localização Selecionada")
                                .font(.headline)
                            Text("Toque em 'Confirmar' para usar esta localização")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding()
                    }
                }
            }
            .navigationTitle("Escolher Localização")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirmar") {
                        coordinate = selectedLocation
                        dismiss()
                    }
                    .disabled(selectedLocation == nil)
                }
            }
        }
    }
    
    private func handleMapTap() {
        // Usa o centro do mapa como localização selecionada
        selectedLocation = region.center
    }
}

// Helper para o mapa
struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

extension Color {
    func toHex() -> String {
        let components = UIColor(self).cgColor.components
        let r = Float(components?[0] ?? 0)
        let g = Float(components?[1] ?? 0)
        let b = Float(components?[2] ?? 0)
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}
