//
//  SecureLogSanitizerTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class SecureLogSanitizerTests: XCTestCase {
    func testRedactsAuthorizationBearerTokenPreservingScheme() {
        let sanitized = SecureLogSanitizer.sanitize(
            "Authorization: Bearer abc.def.ghi"
        )

        XCTAssertFalse(sanitized.contains("abc.def.ghi"))
        XCTAssertEqual(sanitized, "Authorization: Bearer <redacted>")
        XCTAssertTrue(sanitized.contains("Bearer <redacted>"))
    }

    func testRedactsStandaloneBearerTokenPreservingScheme() {
        let sanitized = SecureLogSanitizer.sanitize(
            "Bearer abc.def.ghi"
        )

        XCTAssertFalse(sanitized.contains("abc.def.ghi"))
        XCTAssertEqual(sanitized, "Bearer <redacted>")
    }

    func testRedactsRawAuthorizationValue() {
        let sanitized = SecureLogSanitizer.sanitize(
            "Authorization: raw-token-value"
        )

        XCTAssertFalse(sanitized.contains("raw-token-value"))
        XCTAssertEqual(sanitized, "Authorization: <redacted>")
    }

    func testRedactsPasswordsAndSecrets() {
        let sanitized = SecureLogSanitizer.sanitize(
            "password=SuperSecret123 token=jwt-token secret=my-secret accessToken=abc refreshToken=def"
        )

        XCTAssertFalse(sanitized.contains("SuperSecret123"))
        XCTAssertFalse(sanitized.contains("jwt-token"))
        XCTAssertFalse(sanitized.contains("my-secret"))
        XCTAssertFalse(sanitized.contains("abc"))
        XCTAssertFalse(sanitized.contains("def"))
    }

    func testRedactsIdempotencyKey() {
        let sanitized = SecureLogSanitizer.sanitize(
            "Idempotency-Key: payment-register-123"
        )

        XCTAssertFalse(sanitized.contains("payment-register-123"))
        XCTAssertEqual(sanitized, "Idempotency-Key: <redacted>")
    }
}
