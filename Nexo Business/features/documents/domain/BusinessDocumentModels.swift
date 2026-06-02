//
//  BusinessDocumentModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct BusinessDocument: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let saleId: String
    let type: String
    let status: String
    let number: String?
    let authorizationNumber: String?
    let accessKey: String?
    let customerEmail: String?
    let pdfUrl: String?
    let xmlUrl: String?
    let createdAt: Date?
    let authorizedAt: Date?
    let rejectedAt: Date?

    init(
        id: String,
        saleId: String,
        type: String,
        status: String,
        number: String? = nil,
        authorizationNumber: String? = nil,
        accessKey: String? = nil,
        customerEmail: String? = nil,
        pdfUrl: String? = nil,
        xmlUrl: String? = nil,
        createdAt: Date? = nil,
        authorizedAt: Date? = nil,
        rejectedAt: Date? = nil
    ) {
        self.id = id
        self.saleId = saleId
        self.type = type
        self.status = status
        self.number = number
        self.authorizationNumber = authorizationNumber
        self.accessKey = accessKey
        self.customerEmail = customerEmail
        self.pdfUrl = pdfUrl
        self.xmlUrl = xmlUrl
        self.createdAt = createdAt
        self.authorizedAt = authorizedAt
        self.rejectedAt = rejectedAt
    }
}

struct BusinessDocumentsResponse: Decodable, Equatable, Sendable {
    let documents: [BusinessDocument]

    init(documents: [BusinessDocument]) {
        self.documents = documents
    }
}

struct BusinessDocumentResponse: Decodable, Equatable, Sendable {
    let document: BusinessDocument
    let sale: BusinessSale?
    let idempotencyReplayed: Bool?

    init(
        document: BusinessDocument,
        sale: BusinessSale? = nil,
        idempotencyReplayed: Bool? = nil
    ) {
        self.document = document
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }
}

struct GenerateInternalTicketRequest: Encodable, Equatable, Sendable {
    let note: String?

    init(note: String? = nil) {
        self.note = note
    }
}

struct RegisterPhysicalSaleNoteRequest: Encodable, Equatable, Sendable {
    let physicalNumber: String
    let note: String?

    init(
        physicalNumber: String,
        note: String? = nil
    ) {
        self.physicalNumber = physicalNumber
        self.note = note
    }
}
