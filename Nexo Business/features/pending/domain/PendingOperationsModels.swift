//
//  PendingOperationsModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct PendingSalesResponse: Decodable, Equatable, Sendable {
    let sales: [BusinessSale]
    let total: Int?

    init(
        sales: [BusinessSale],
        total: Int? = nil
    ) {
        self.sales = sales
        self.total = total
    }

    private enum CodingKeys: String, CodingKey {
        case sales
        case items
        case results
        case data
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sales = try container.decodeIfPresent([BusinessSale].self, forKey: .sales)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .results)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .data)
            ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }
}

struct PendingReceivablesResponse: Decodable, Equatable, Sendable {
    let receivables: [ReceivableRecord]
    let total: Int?

    init(
        receivables: [ReceivableRecord],
        total: Int? = nil
    ) {
        self.receivables = receivables
        self.total = total
    }

    private enum CodingKeys: String, CodingKey {
        case receivables
        case items
        case results
        case data
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        receivables = try container.decodeIfPresent([ReceivableRecord].self, forKey: .receivables)
            ?? container.decodeIfPresent([ReceivableRecord].self, forKey: .items)
            ?? container.decodeIfPresent([ReceivableRecord].self, forKey: .results)
            ?? container.decodeIfPresent([ReceivableRecord].self, forKey: .data)
            ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }
}

struct PendingDocumentsResponse: Decodable, Equatable, Sendable {
    let documents: [BusinessDocument]
    let total: Int?

    init(
        documents: [BusinessDocument],
        total: Int? = nil
    ) {
        self.documents = documents
        self.total = total
    }

    private enum CodingKeys: String, CodingKey {
        case documents
        case items
        case results
        case data
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        documents = try container.decodeIfPresent([BusinessDocument].self, forKey: .documents)
            ?? container.decodeIfPresent([BusinessDocument].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessDocument].self, forKey: .results)
            ?? container.decodeIfPresent([BusinessDocument].self, forKey: .data)
            ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }
}
