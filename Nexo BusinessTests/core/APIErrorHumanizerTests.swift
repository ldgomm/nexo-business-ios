//
//  APIErrorHumanizerTests.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class APIErrorHumanizerTests: XCTestCase {
    func testMapsRevisionErrorsToHumanMessage() {
        let error = APIError.server(
            statusCode: 428,
            code: "missing_required_revision",
            message: "Precondition required",
            requestId: "req_1"
        )

        XCTAssertEqual(
            error.userMessage,
            "Falta una revisión requerida de catálogo o configuración tributaria. Actualiza el contexto."
        )
    }

    func testMapsConflictToRefreshContextMessage() {
        let error = APIError.server(
            statusCode: 409,
            code: "stale_catalog_revision",
            message: "Conflict",
            requestId: "req_1"
        )

        XCTAssertEqual(
            error.userMessage,
            "La información del negocio cambió. Actualiza el contexto e inténtalo otra vez."
        )
    }
}
