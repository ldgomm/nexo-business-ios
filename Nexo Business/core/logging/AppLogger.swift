//
//  AppLogger.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol AppLogging: Sendable {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

public final class AppLogger: AppLogging, @unchecked Sendable {
    public static let shared = AppLogger()

    private init() {}

    public func info(_ message: String) {
        log(level: "INFO", message: message)
    }

    public func warning(_ message: String) {
        log(level: "WARN", message: message)
    }

    public func error(_ message: String) {
        log(level: "ERROR", message: message)
    }

    private func log(level: String, message: String) {
        #if DEBUG
        print("[NexoBusiness][\(level)] \(SecureLogSanitizer.sanitize(message))")
        #endif
    }
}

public final class MemoryAppLogger: AppLogging, @unchecked Sendable {
    public private(set) var entries: [String] = []

    public init() {}

    public func info(_ message: String) {
        entries.append("INFO: \(SecureLogSanitizer.sanitize(message))")
    }

    public func warning(_ message: String) {
        entries.append("WARN: \(SecureLogSanitizer.sanitize(message))")
    }

    public func error(_ message: String) {
        entries.append("ERROR: \(SecureLogSanitizer.sanitize(message))")
    }
}
