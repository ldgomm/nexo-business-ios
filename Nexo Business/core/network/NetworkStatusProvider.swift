//
//  NetworkStatusProvider.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

#if canImport(Network)
import Network
#endif

enum NetworkConnectionStatus: String, Equatable, Sendable {
    case unknown
    case satisfied
    case unsatisfied
    case constrained
    case expensive

    var isUsable: Bool {
        switch self {
        case .satisfied, .constrained, .expensive:
            return true
        case .unknown, .unsatisfied:
            return false
        }
    }

    var userMessage: String {
        switch self {
        case .unknown:
            return "No se pudo determinar el estado de red."
        case .satisfied:
            return "Conexión disponible."
        case .unsatisfied:
            return "Sin conexión disponible."
        case .constrained:
            return "Conexión limitada por el sistema."
        case .expensive:
            return "Conexión disponible, posiblemente con datos móviles."
        }
    }
}

protocol NetworkStatusProviding: Sendable {
    func currentStatus() async -> NetworkConnectionStatus
}

final class StaticNetworkStatusProvider: NetworkStatusProviding, @unchecked Sendable {
    private let status: NetworkConnectionStatus

    init(status: NetworkConnectionStatus) {
        self.status = status
    }

    func currentStatus() async -> NetworkConnectionStatus {
        status
    }
}

final class SystemNetworkStatusProvider: NetworkStatusProviding, @unchecked Sendable {
    init() {}

    func currentStatus() async -> NetworkConnectionStatus {
        #if canImport(Network)
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.nexo.business.network.status.once")
            var didResume = false

            monitor.pathUpdateHandler = { path in
                guard !didResume else { return }
                didResume = true

                let status: NetworkConnectionStatus
                if path.status != .satisfied {
                    status = .unsatisfied
                } else if path.isConstrained {
                    status = .constrained
                } else if path.isExpensive {
                    status = .expensive
                } else {
                    status = .satisfied
                }

                monitor.cancel()
                continuation.resume(returning: status)
            }

            monitor.start(queue: queue)
        }
        #else
        return .unknown
        #endif
    }
}
