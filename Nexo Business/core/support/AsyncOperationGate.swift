//
//  AsyncOperationGate.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public actor AsyncOperationGate {
    private var activeOperationIds: Set<String> = []

    public init() {}

    public func begin(_ id: String) -> Bool {
        guard !activeOperationIds.contains(id) else { return false }
        activeOperationIds.insert(id)
        return true
    }

    public func end(_ id: String) {
        activeOperationIds.remove(id)
    }

    public func withLock<T: Sendable>(
        id: String,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        guard begin(id) else {
            throw OperationGateError.alreadyRunning(id)
        }

        defer {
            Task { await self.end(id) }
        }

        return try await operation()
    }
}

public enum OperationGateError: Error, Equatable, Sendable {
    case alreadyRunning(String)

    public var userMessage: String {
        switch self {
        case .alreadyRunning:
            return "Ya hay una operación en proceso. Espera un momento."
        }
    }
}
