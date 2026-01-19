//
//  SSDPDevicesView.swift
//  IoTDashboard
//
//  Created by Raul Ferreira on 12/5/25.
//


import SwiftUI

struct SSDPDevicesView: View {
    @StateObject private var ssdpService = SSDPService()
    
    var body: some View {
        NavigationStack {
            List(ssdpService.foundDevices) { device in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: getIcon(for: device.server))
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(device.server)
                                .font(.headline)
                            Text(device.ip)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text(device.location)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Scanner SSDP")
            .onAppear {
                ssdpService.startDiscovery()
            }
            .onDisappear {
                ssdpService.stopDiscovery()
            }
            .toolbar {
                Button("Scan") {
                    ssdpService.startDiscovery()
                }
            }
        }
    }
    
    // Tenta adivinhar o ícone pelo nome do servidor
    func getIcon(for server: String) -> String {
        let lower = server.lowercased()
        if lower.contains("tv") || lower.contains("samsung") || lower.contains("lg") { return "tv" }
        if lower.contains("sonos") || lower.contains("sound") { return "speaker.wave.2.fill" }
        if lower.contains("philips") || lower.contains("hue") { return "lightbulb.fill" }
        if lower.contains("gateway") || lower.contains("router") { return "router" }
        return "network"
    }
}
