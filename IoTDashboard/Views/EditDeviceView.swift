//
//  EditDeviceView.swift
//  IoTDashboard
//
//  Created by Raul Ferreira on 10/01/2026.
//


import SwiftUI

struct EditDeviceView: View {
    let device: Device
    @ObservedObject var deviceVM: DeviceViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var type: DeviceType
    
    init(device: Device, deviceVM: DeviceViewModel) {
        self.device = device
        self.deviceVM = deviceVM
        _name = State(initialValue: device.name)
        _type = State(initialValue: device.type)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Nome", text: $name)
                    
                    Picker("Tipo", selection: $type) {
                        Text("💡 LED").tag(DeviceType.led)
                        Text("🌡️ Sensor").tag(DeviceType.sensor)
                        Text("💨 Gás").tag(DeviceType.gas)
                        Text("🔆 Luz").tag(DeviceType.light)
                    }
                } header: {
                    Text("Informações")
                }
                
                Section {
                    HStack {
                        Text("IP")
                        Spacer()
                        Text(device.ip)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Protocolo")
                        Spacer()
                        Text(device.connectionProtocol == .http ? "HTTP" : "UDP")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Detalhes")
                }
            }
            .navigationTitle("Editar Dispositivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveChanges() {
        if let index = deviceVM.devices.firstIndex(where: { $0.id == device.id }) {
            deviceVM.devices[index].name = name
            deviceVM.devices[index].type = type
            deviceVM.saveDevices()
            print("✅ Dispositivo atualizado: \(name)")
        }
        dismiss()
    }
}
