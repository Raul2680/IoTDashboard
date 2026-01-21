import SwiftUI

struct EditDeviceView: View {
    let device: Device
    @ObservedObject var deviceVM: DeviceViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var room: String
    
    init(device: Device, deviceVM: DeviceViewModel) {
        self.device = device
        self.deviceVM = deviceVM
        _name = State(initialValue: device.name)
        _room = State(initialValue: device.room ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informações Gerais")) {
                    TextField("Nome do Equipamento", text: $name)
                    TextField("Divisão", text: $room)
                }
                
                Section(header: Text("Dados Técnicos")) {
                    LabeledContent("Tipo", value: "\(device.type)")
                    LabeledContent("IP", value: device.ip)
                }
            }
            .navigationTitle("Editar Equipamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        deviceVM.updateDeviceDetails(device: device, newName: name, newRoom: room)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
