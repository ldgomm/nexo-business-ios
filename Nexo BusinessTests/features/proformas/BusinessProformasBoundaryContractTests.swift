//
//  BusinessProformasBoundaryContractTests.swift
//  Nexo BusinessTests
//
//  21J.10 — Business iOS Proformas MVP
//

import XCTest

final class BusinessProformasBoundaryContractTests: XCTestCase {
    func testBusinessProformasSurfaceKeepsFiscalAndCashBoundaryTextual() throws {
        let source = try String(
            contentsOfFile: "Nexo Business/features/proformas/presentation/BusinessProformasView.swift",
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("no es factura"))
        XCTAssertTrue(source.contains("no cobra"))
        XCTAssertTrue(source.contains("no abre caja"))
        XCTAssertTrue(source.contains("no genera XML/RIDE"))
        XCTAssertTrue(source.contains("no llama al SRI"))
        XCTAssertTrue(source.contains("venta borrador"))
    }

    func testBusinessProformasApiDoesNotReferencePaymentCashInvoiceOrSriModules() throws {
        let source = try String(
            contentsOfFile: "Nexo Business/features/proformas/data/BusinessProformasAPIRepository.swift",
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("/api/v1/business/proformas"))
        XCTAssertTrue(source.contains("convert-to-sale"))
        XCTAssertFalse(source.contains("PaymentsAPIRepository"))
        XCTAssertFalse(source.contains("CashAPIRepository"))
        XCTAssertFalse(source.contains("BusinessDocumentsAPIRepository"))
        XCTAssertFalse(source.contains("electronic-documents"))
        XCTAssertFalse(source.contains("/invoice"))
        XCTAssertFalse(source.contains("SRI"))
    }
}
