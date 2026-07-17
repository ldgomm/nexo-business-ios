//
//  BusinessProformasBoundaryContractTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import XCTest

final class BusinessProformasBoundaryContractTests: XCTestCase {
    func testBusinessProformasSurfaceKeepsFiscalAndCashBoundaryTextual() throws {
        let source = try sourceText(
            at: "Nexo Business/features/proformas/presentation/BusinessProformasView.swift"
        )

        XCTAssertTrue(source.contains("no es factura"))
        XCTAssertTrue(source.contains("no cobra"))
        XCTAssertTrue(source.contains("no abre caja"))
        XCTAssertTrue(source.contains("no genera XML/RIDE"))
        XCTAssertTrue(source.contains("no llama al SRI"))
        XCTAssertTrue(source.contains("venta borrador"))
    }

    func testBusinessProformasApiDoesNotReferencePaymentCashInvoiceOrSriModules() throws {
        let source = try sourceText(
            at: "Nexo Business/features/proformas/data/BusinessProformasAPIRepository.swift"
        )

        XCTAssertTrue(source.contains("/api/v1/business/proformas"))
        XCTAssertTrue(source.contains("convert-to-sale"))
        XCTAssertFalse(source.contains("PaymentsAPIRepository"))
        XCTAssertFalse(source.contains("CashAPIRepository"))
        XCTAssertFalse(source.contains("BusinessDocumentsAPIRepository"))
        XCTAssertFalse(source.contains("electronic-documents"))
        XCTAssertFalse(source.contains("/invoice"))

        let forbiddenSideEffectMessage =
            "La conversión reportó efectos prohibidos: pago, caja, factura, XML, RIDE o SRI."
        XCTAssertTrue(source.contains("if response.hasForbiddenSideEffects"))
        XCTAssertTrue(source.contains(forbiddenSideEffectMessage))
        XCTAssertFalse(
            source
                .replacingOccurrences(of: forbiddenSideEffectMessage, with: "")
                .contains("SRI")
        )
    }

    private func sourceText(at repositoryRelativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appendingPathComponent(repositoryRelativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
