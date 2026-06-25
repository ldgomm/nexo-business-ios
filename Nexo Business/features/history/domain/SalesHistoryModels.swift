//
//  SalesHistoryModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum SalesHistoryStatusFilter: String, CaseIterable, Identifiable, Sendable, Hashable {
    case all
    case pending
    case confirmed
    case inProgress = "in_progress"
    case ready
    case delivered
    case closed
    case canceled

    var id: String { rawValue }

    var queryValue: String? {
        switch self {
        case .all:
            return nil
        default:
            return rawValue
        }
    }

    var displayName: String {
        switch self {
        case .all:
            return "Todas"
        case .pending:
            return "Pendientes"
        case .confirmed:
            return "Confirmadas"
        case .inProgress:
            return "En proceso"
        case .ready:
            return "Listas"
        case .delivered:
            return "Entregadas"
        case .closed:
            return "Cerradas"
        case .canceled:
            return "Canceladas"
        }
    }
}

struct SalesHistorySearchRequest: Equatable, Sendable {
    let branchId: String
    let query: String?
    let status: SalesHistoryStatusFilter
    let statusValues: [String]?
    let date: Date?
    let limit: Int

    init(
        branchId: String,
        query: String? = nil,
        status: SalesHistoryStatusFilter = .all,
        statusValues: [String]? = nil,
        date: Date? = nil,
        limit: Int = 50
    ) {
        self.branchId = branchId
        self.query = query
        self.status = status
        self.statusValues = statusValues
        self.date = date
        self.limit = limit
    }
}

struct BusinessSalesHistoryResponse: Decodable, Equatable, Sendable {
    let sales: [BusinessSale]
    let total: Int?
    let hasMore: Bool?

    init(
        sales: [BusinessSale],
        total: Int? = nil,
        hasMore: Bool? = nil
    ) {
        self.sales = sales
        self.total = total
        self.hasMore = hasMore
    }

    private enum CodingKeys: String, CodingKey {
        case sales
        case items
        case results
        case data
        case total
        case hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sales = try container.decodeIfPresent([BusinessSale].self, forKey: .sales)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .results)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .data)
            ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
}
