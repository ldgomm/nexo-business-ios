//
//  AppLogger.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol AppLogging: Sendable {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

final class AppLogger: AppLogging, @unchecked Sendable {
    static let shared = AppLogger()

    private init() {}

    func info(_ message: String) {
        log(level: "INFO", message: message)
    }

    func warning(_ message: String) {
        log(level: "WARN", message: message)
    }

    func error(_ message: String) {
        log(level: "ERROR", message: message)
    }

    private func log(level: String, message: String) {
        #if DEBUG
        print("[NexoBusiness][\(level)] \(SecureLogSanitizer.sanitize(message))")
        #endif
    }
}

final class MemoryAppLogger: AppLogging, @unchecked Sendable {
    private(set) var entries: [String] = []

    init() {}

    func info(_ message: String) {
        entries.append("INFO: \(SecureLogSanitizer.sanitize(message))")
    }

    func warning(_ message: String) {
        entries.append("WARN: \(SecureLogSanitizer.sanitize(message))")
    }

    func error(_ message: String) {
        entries.append("ERROR: \(SecureLogSanitizer.sanitize(message))")
    }
}
