//
//  APIErrorHumanizerTests.swift
//  Nexo Business
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


    func testMapsReceivableRequiresIdentifiedCustomerToHumanMessage() {
        let error = APIError.server(
            statusCode: 422,
            code: "domain_rule_violation",
            message: "Accounts receivable require an identified customer. Select a customer before marking a sale as credit.",
            requestId: "req_receivable_customer"
        )

        XCTAssertEqual(
            error.userMessage,
            "Para dejar una venta por cobrar necesitas seleccionar un cliente identificado. Consumidor final no puede quedar fiado."
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
