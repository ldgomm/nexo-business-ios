//
//  BusinessDocumentModelsDecodingTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessDocumentModelsDecodingTests: XCTestCase {
    func testDecodesBusinessDocumentsResponse() throws {
        let json = #"""
        {
          "documents": [
            {
              "id": "doc_1",
              "saleId": "sale_1",
              "type": "internal_ticket",
              "status": "generated",
              "number": "T-001",
              "createdAt": "2026-05-29T12:00:00Z"
            },
            {
              "id": "doc_2",
              "saleId": "sale_1",
              "type": "physical_sale_note",
              "status": "registered",
              "number": "001-001-000000123",
              "customerEmail": "cliente@nexo.test",
              "createdAt": "2026-05-29T12:05:00Z"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessDocumentsResponse.self, from: json)

        XCTAssertEqual(response.documents.count, 2)
        XCTAssertEqual(response.documents[0].id, "doc_1")
        XCTAssertEqual(response.documents[1].customerEmail, "cliente@nexo.test")
    }

    func testDecodesBusinessDocumentResponseWithSaleMissing() throws {
        let json = #"""
        {
          "document": {
            "id": "doc_1",
            "saleId": "sale_1",
            "type": "internal_ticket",
            "status": "generated",
            "number": "T-001"
          },
          "idempotencyReplayed": true
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessDocumentResponse.self, from: json)

        XCTAssertEqual(response.document.id, "doc_1")
        XCTAssertEqual(response.idempotencyReplayed, true)
        XCTAssertNil(response.sale)
    }

    func testDecodesBusinessElectronicDocumentIssueResponse() throws {
        let json = #"""
        {
          "document": {
            "id": "edoc_1",
            "documentId": "edoc_1",
            "organizationId": "org_1",
            "branchId": "br_1",
            "emissionPointId": "ep_1",
            "saleId": "sale_1",
            "documentType": "electronic_invoice",
            "type": "electronic_invoice",
            "displayNumber": "001-001-000000123",
            "number": "001-001-000000123",
            "accessKey": "1234567890123456789012345678901234567890123456789",
            "claveAcceso": "1234567890123456789012345678901234567890123456789",
            "authorizationNumber": "1234567890",
            "numeroAutorizacion": "1234567890",
            "status": "AUTHORIZED",
            "sriStatus": "AUTHORIZED",
            "environment": "test",
            "issuedAt": "2026-06-11T14:00:00Z",
            "authorizedAt": "2026-06-11T14:00:30Z",
            "rideGeneratedAt": "2026-06-11T14:00:40Z",
            "deliveredAt": null,
            "customerEmail": "cliente@nexo.test",
            "pdfUrl": null,
            "xmlUrl": null,
            "hasRide": true,
            "hasXml": true,
            "hasErrors": false,
            "lastSriReceptionStatus": "RECIBIDA",
            "lastSriAuthorizationStatus": "AUTORIZADO",
            "lastErrorMessage": null,
            "createdAt": "2026-06-11T14:00:00Z",
            "updatedAt": "2026-06-11T14:00:40Z"
          },
          "authorized": true,
          "stoppedBeforeSri": false,
          "receptionStatus": "RECIBIDA",
          "authorizationStatus": "AUTORIZADO",
          "replayed": false
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessElectronicDocumentIssueResponse.self, from: json)

        XCTAssertEqual(response.document.id, "edoc_1")
        XCTAssertEqual(response.document.type, "electronic_invoice")
        XCTAssertEqual(response.document.number, "001-001-000000123")
        XCTAssertEqual(response.document.accessKey, "1234567890123456789012345678901234567890123456789")
        XCTAssertEqual(response.document.authorizationNumber, "1234567890")
        XCTAssertEqual(response.document.status, "AUTHORIZED")
        XCTAssertEqual(response.document.customerEmail, "cliente@nexo.test")
        XCTAssertEqual(response.authorized, true)
        XCTAssertEqual(response.stoppedBeforeSri, false)
        XCTAssertEqual(response.receptionStatus, "RECIBIDA")
        XCTAssertEqual(response.authorizationStatus, "AUTORIZADO")
        XCTAssertEqual(response.idempotencyReplayed, false)
    }

    func testDecodesElectronicDocumentVaultListTimelineAndArtifact() throws {
        let listJSON = #"""
        {
          "documents": [
            {
              "id": "edoc_1",
              "documentId": "edoc_1",
              "organizationId": "org_1",
              "saleId": "sale_1",
              "documentType": "electronic_invoice",
              "displayNumber": "001-001-000000123",
              "accessKey": "1234567890123456789012345678901234567890123456789",
              "status": "AUTHORIZED",
              "sriStatus": "AUTORIZADO",
              "environment": "test",
              "issueDate": "2026-06-11T14:00:00Z",
              "hasRide": true,
              "hasXml": true,
              "customerName": "Cliente Demo",
              "total": "12.50"
            }
          ],
          "total": 1,
          "hasMore": false
        }
        """#.data(using: .utf8)!

        let list = try JSONDecoder.nexoDefault.decode(BusinessElectronicDocumentsResponse.self, from: listJSON)
        XCTAssertEqual(list.documents.count, 1)
        XCTAssertEqual(list.documents[0].documentId, "edoc_1")
        XCTAssertEqual(list.documents[0].displayNumber, "001-001-000000123")
        XCTAssertEqual(list.documents[0].hasRide, true)
        XCTAssertEqual(list.documents[0].hasXml, true)

        let timelineJSON = #"""
        {
          "documentId": "edoc_1",
          "events": [
            { "id": "evt_1", "action": "AUTHORIZED", "message": "Autorizado", "actorUserId": "usr_1", "occurredAt": "2026-06-11T14:00:30Z" }
          ]
        }
        """#.data(using: .utf8)!

        let timeline = try JSONDecoder.nexoDefault.decode(BusinessElectronicDocumentTimelineResponse.self, from: timelineJSON)
        XCTAssertEqual(timeline.events.first?.type, "AUTHORIZED")
        XCTAssertEqual(timeline.events.first?.actor, "usr_1")

        let artifactJSON = #"""
        {
          "artifact": {
            "kind": "authorized_xml",
            "fileName": "001-001-000000123-authorized.xml",
            "contentType": "application/xml",
            "sizeBytes": 128,
            "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
          },
          "xml": {
            "kind": "authorized_xml",
            "fileName": "001-001-000000123-authorized.xml",
            "contentType": "application/xml",
            "sizeBytes": 128,
            "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
          }
        }
        """#.data(using: .utf8)!

        let artifact = try JSONDecoder.nexoDefault.decode(BusinessDocumentArtifactEnvelopeResponse.self, from: artifactJSON)
        XCTAssertEqual(artifact.xml?.kind, .authorizedXml)
        XCTAssertEqual(artifact.xml?.kind.publicRawValue, "authorizedXml")
        XCTAssertEqual(artifact.xml?.kind.displayName, "XML autorizado")
        XCTAssertEqual(artifact.artifact?.fileName, "001-001-000000123-authorized.xml")
    }
    
    func testBusinessDocumentArtifactKindDecodesPublicLegacyAndUnknownValues() throws {
        let publicJSON = #"""
        {
          "kind": "authorizedXml",
          "fileName": "001-001-000000123-authorized.xml",
          "contentType": "application/xml"
        }
        """#.data(using: .utf8)!

        let legacyJSON = #"""
        {
          "kind": "authorized_xml",
          "fileName": "001-001-000000123-authorized.xml",
          "contentType": "application/xml"
        }
        """#.data(using: .utf8)!

        let unknownJSON = #"""
        {
          "kind": "creditNoteAuthorizedXml",
          "fileName": "001-001-000000123-credit-note.xml",
          "contentType": "application/xml"
        }
        """#.data(using: .utf8)!

        let publicArtifact = try JSONDecoder.nexoDefault.decode(BusinessDocumentArtifact.self, from: publicJSON)
        let legacyArtifact = try JSONDecoder.nexoDefault.decode(BusinessDocumentArtifact.self, from: legacyJSON)
        let unknownArtifact = try JSONDecoder.nexoDefault.decode(BusinessDocumentArtifact.self, from: unknownJSON)

        XCTAssertEqual(publicArtifact.kind, .authorizedXml)
        XCTAssertEqual(legacyArtifact.kind, .authorizedXml)
        XCTAssertEqual(publicArtifact.kind.displayName, "XML autorizado")
        XCTAssertEqual(legacyArtifact.kind.displayName, "XML autorizado")
        XCTAssertEqual(unknownArtifact.kind.displayName, "Archivo")

        if case .unknown(let rawValue) = unknownArtifact.kind {
            XCTAssertEqual(rawValue, "creditNoteAuthorizedXml")
        } else {
            XCTFail("Expected unknown artifact kind")
        }
    }

    func testBusinessDocumentTextSanitizerHidesInternalStorageAndSecrets() {
        XCTAssertNil(BusinessDocumentTextSanitizer.sanitizedMessage("Archivo en electronic-invoicing/org/doc/ride_pdf/file.pdf"))
        XCTAssertNil(BusinessDocumentTextSanitizer.sanitizedMessage("objectKey=org/doc/authorized_xml.xml"))
        XCTAssertNil(BusinessDocumentTextSanitizer.sanitizedMessage("password de firma inválido"))
        XCTAssertNil(BusinessDocumentTextSanitizer.sanitizedMessage("/var/lib/nexo/signature.p12"))
        XCTAssertNil(BusinessDocumentTextSanitizer.sanitizedMessage("token abc123"))
        XCTAssertEqual(BusinessDocumentTextSanitizer.sanitizedMessage("RIDE generado correctamente."), "RIDE generado correctamente.")
    }

    func testBusinessDocumentTimelineUsesHumanTitleAndSanitizesUnsafeMessage() throws {
        let json = #"""
        {
          "documentId": "edoc_1",
          "events": [
            {
              "id": "evt_1",
              "type": "SRI_RECEPTION_TRANSPORT_FAILED",
              "title": "technical backend title",
              "message": "falló /var/lib/nexo/electronic-invoicing/doc/sri_request.xml",
              "actor": "usr_1",
              "createdAt": "2026-06-11T14:00:30Z",
              "severity": "error"
            },
            {
              "id": "evt_2",
              "type": "FUTURE_EVENT_TYPE",
              "title": "signed_xml exposed",
              "message": "Evento visible",
              "actor": "usr_2",
              "createdAt": "2026-06-11T14:01:30Z",
              "severity": "info"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessElectronicDocumentTimelineResponse.self, from: json)

        XCTAssertEqual(response.events[0].title, "No se pudo conectar con recepción SRI.")
        XCTAssertNil(response.events[0].message)

        XCTAssertEqual(response.events[1].title, "Evento registrado.")
        XCTAssertEqual(response.events[1].message, "Evento visible")
    }
}
