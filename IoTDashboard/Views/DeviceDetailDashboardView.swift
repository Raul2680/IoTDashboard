import SwiftUI

struct DeviceDetailDashboardView: View {
    let device: Device
    @ObservedObject var deviceVM: DeviceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InfoBox(title: "Informações") {
                    InfoRow(icon: "globe", label: "IP", value: device.ip)
                    InfoRow(icon: "tag", label: "Nome", value: device.name)
                    InfoRow(
                        icon: "wifi",
                        label: "Status",
                        value: device.isOnline ? "Online" : "Offline",
                        valueColor: device.isOnline ? .green : .red
                    )
                }

                InfoBox(title: "Sensores") {
                    if let data = device.sensorData {
                        InfoRow(icon: "thermometer", label: "Temperatura", value: data.formattedTemperature)
                        InfoRow(icon: "drop.fill", label: "Humidade", value: data.formattedHumidity)
                        InfoRow(icon: "clock.fill", label: "Atualizado", value: data.formattedDate)
                    } else if let gas = device.gasData {
                         InfoRow(icon: "exclamationmark.triangle", label: "Nível Gás", value: "\(gas.mq2)", valueColor: gas.status == 2 ? .red : .primary)
                    } else {
                        InfoRow(icon: "exclamationmark.triangle", label: "Sensor", value: "Sem dados", valueColor: .red)
                    }
                }

                Button("Remover dispositivo") {
                    // ✅ CORREÇÃO: Chamamos o método sem o símbolo '$'
                    deviceVM.removeDevice(device)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.red))
            }
            .padding([.leading, .trailing], 18)
            .padding(.top, 20)
        }
        .navigationTitle(device.name)
    }
}

// Estruturas auxiliares (mantenha-as no mesmo ficheiro ou num ficheiro de UI separado)
struct InfoBox<Content: View>: View {
    let title: String
    var color: Color = .primary
    let content: Content

    init(title: String, color: Color = .primary, @ViewBuilder content: () -> Content) {
        self.title = title
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title).font(.headline).foregroundColor(color)
            content
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 17).fill(Color(.secondarySystemBackground)))
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundColor(.blue)
            Text(label + ":")
                .fontWeight(.semibold)
            Spacer()
            Text(value).foregroundColor(valueColor)
        }
        .font(.system(size: 17))
    }
}
