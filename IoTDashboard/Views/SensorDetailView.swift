//
//  SensorDetailView.swift
//  IoTDashboard
//
//  Created by Raul Ferreira on 04/01/2026.
//


import SwiftUI

struct SensorDetailView: View {
    let device: Device
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            AppBackgroundView() // Aplica o fundo dinâmico do tema
            
            ScrollView {
                VStack(spacing: 25) {
                    // Header Informativo
                    VStack(spacing: 8) {
                        Image(systemName: "sensor.fill")
                            .font(.system(size: 50))
                            .foregroundColor(themeManager.accentColor)
                        Text(device.name).font(.title.bold())
                        Text(device.ip).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // Cartões de Sensores
                    VStack(spacing: 15) {
                        if let temp = device.temperature {
                            SensorDataCard(title: "Temperatura", value: "\(temp)°C", icon: "thermometer", color: .orange)
                        }
                        if let hum = device.humidity {
                            SensorDataCard(title: "Humidade", value: "\(hum)%", icon: "humidity", color: .blue)
                        }
                        if let gas = device.gasLevel {
                            SensorDataCard(title: "Nível de Gás", value: "\(gas) PPM", icon: "smoke.fill", color: gas > 300 ? .red : .green)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Dados do Dispositivo")
    }
}

struct SensorDataCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).font(.title2)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.headline)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}