//
//  BusinessDocumentModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct BusinessDocument: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let saleId: String
    public let type: String
    public let status: String
    public let number: String?
    public let authorizationNumber: String?
    public let accessKey: String?
    public let customerEmail: String?
    public let pdfUrl: String?
    public let xmlUrl: String?
    public let createdAt: Date?
    public let authorizedAt: Date?
    public let rejectedAt: Date?

    public init(
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

public struct BusinessDocumentsResponse: Decodable, Equatable, Sendable {
    public let documents: [BusinessDocument]

    public init(documents: [BusinessDocument]) {
        self.documents = documents
    }
}

public struct BusinessDocumentResponse: Decodable, Equatable, Sendable {
    public let document: BusinessDocument
    public let sale: BusinessSale?
    public let idempotencyReplayed: Bool?

    public init(
        document: BusinessDocument,
        sale: BusinessSale? = nil,
        idempotencyReplayed: Bool? = nil
    ) {
        self.document = document
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }
}

public struct GenerateInternalTicketRequest: Encodable, Equatable, Sendable {
    public let note: String?

    public init(note: String? = nil) {
        self.note = note
    }
}

public struct RegisterPhysicalSaleNoteRequest: Encodable, Equatable, Sendable {
    public let physicalNumber: String
    public let note: String?

    public init(
        physicalNumber: String,
        note: String? = nil
    ) {
        self.physicalNumber = physicalNumber
        self.note = note
    }
}
