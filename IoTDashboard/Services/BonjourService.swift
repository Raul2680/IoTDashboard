import Foundation
import Network
import Combine

class BonjourService: ObservableObject {
    @Published var discoveredIPs: [String] = []
    private var browser: NWBrowser?
    private var activeResolutions: Set<NWEndpoint> = []

    func start() {
        discoveredIPs.removeAll()
        activeResolutions.removeAll()
        let params = NWParameters()
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi

        browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: params)
        browser?.stateUpdateHandler = { state in
            print("Bonjour State: \(state)")
        }
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            for result in results {
                if case let .service(name, _, _, _) = result.endpoint,
                   !self.activeResolutions.contains(result.endpoint) {
                    print("Encontrado Bonjour: \(name)")
                    self.activeResolutions.insert(result.endpoint)
                    self.resolve(endpoint: result.endpoint)
                }
            }
        }
        browser?.start(queue: .main)
    }

    private func resolve(endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                if let remote = connection.currentPath?.remoteEndpoint,
                   case let .hostPort(host, _) = remote {
                    var ip = host.debugDescription
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                    if let range = ip.range(of: "%") {
                        ip = String(ip[..<range.lowerBound])
                    }
                    DispatchQueue.main.async {
                        if !self.discoveredIPs.contains(ip) {
                            self.discoveredIPs.append(ip)
                            print("Bonjour resolve IP:", ip)
                        }
                    }
                }
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
}
