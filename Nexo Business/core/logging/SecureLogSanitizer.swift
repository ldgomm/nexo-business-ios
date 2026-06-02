//
//  SecureLogSanitizer.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum SecureLogSanitizer {
    private static let sensitiveKeys = [
        "accessToken",
        "refreshToken",
        "password",
        "token",
        "secret",
        "certificate",
        "p12",
        "pfx",
        "firma",
        "key"
    ]

    static func sanitize(_ text: String) -> String {
        var sanitized = text

        // Keep the human-readable auth scheme while removing the credential.
        // This must run before generic key redaction.
        sanitized = sanitized.replacing(
            pattern: #"(?i)\b(Authorization\s*[:=]\s*)Bearer\s+[^\s,;}{]+"#,
            with: "$1Bearer <redacted>"
        )

        sanitized = sanitized.replacing(
            pattern: #"(?i)\b(Bearer)\s+[^\s,;}{]+"#,
            with: "$1 <redacted>"
        )

        // Raw Authorization values without Bearer.
        sanitized = sanitized.replacing(
            pattern: #"(?i)\b(Authorization\s*[:=]\s*)(?!Bearer\s+)[^\s,;}{]+"#,
            with: "$1<redacted>"
        )

        sanitized = sanitized.replacing(
            pattern: #"(?i)\b(Idempotency-Key\s*[:=]\s*)[^\s,;}{]+"#,
            with: "$1<redacted>"
        )

        for key in sensitiveKeys {
            let escapedKey = NSRegularExpression.escapedPattern(for: key)
            sanitized = sanitized.replacing(
                pattern: "(?i)\\b(" + escapedKey + "\\s*[:=]\\s*)[^\\s,;}\\{]+",
                with: "$1<redacted>"
            )
        }

        return sanitized
    }
}

private extension String {
    func replacing(pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }

        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: range,
            withTemplate: template
        )
    }
}
