import SwiftUI

struct LedControlView: View {
    @ObservedObject var deviceVM: DeviceViewModel
    let device: Device
    
    @State private var color: Color = .white
    @State private var brightness: Double = 0.5
    @State private var isPowerOn: Bool = true
    
    var body: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(isPowerOn ? color : .gray)
                .frame(width: 200)
                .onTapGesture { togglePower() }
            
            ColorPicker("Cor", selection: $color)
                .padding()
            
            Slider(value: $brightness, in: 0.01...1)
                .padding()
        }
        .navigationTitle(device.name)
        .onChange(of: color) { _ in updateDevice() }
        .onChange(of: brightness) { _ in updateDevice() }
    }
    
    private func togglePower() {
        isPowerOn.toggle()
        updateDevice()
    }
    
    private func updateDevice() {
        sendUDPUpdate()
    }
    
    private func sendUDPUpdate() {
        let components = UIColor(color).cgColor.components ?? [0, 0, 0]
        let r = isPowerOn ? Int(components[0] * 255) : 0
        let g = isPowerOn ? Int(components[1] * 255) : 0
        let b = isPowerOn ? Int(components[2] * 255) : 0
        
        // ✅ CORRETO
        let udpService = UDPService(ip: device.ip)
        udpService.sendColor(r: r, g: g, b: b, brightness: Int(brightness * 100))
        
        print("🔵 UDP Enviado - R:\(r) G:\(g) B:\(b) Brilho:\(Int(brightness * 100)) para \(device.ip)")
        
        // Fecha conexão após 0.5 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            udpService.stop()
        }
    }
}
