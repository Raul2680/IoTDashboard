//
//  SensorResponse.swift
//  IoTDashboard
//
//  Created by Raul Ferreira on 11/15/25.
//


import Foundation

struct SensorResponse: Codable, Equatable {
    // Outras propriedades
    var r: Int? = nil
    var g: Int? = nil
    var b: Int? = nil
    var brightness: Int? = nil
    var temperature: Double? = nil
    var humidity: Double? = nil
    var type: String? = nil
    var watt: Double? = nil
    // Timestamp do último update
    var timestamp: String? = nil // ou Date? se o JSON vier como ISO8601 perfeito
}

