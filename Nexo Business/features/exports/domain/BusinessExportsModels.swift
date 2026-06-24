//
//  BusinessExportsModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 23/6/26.
//

import Foundation

enum BusinessExportKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case dailyOperational = "daily_operational"
    case operationalIntelligent = "operational_intelligent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dailyOperational:
            return "Exportación operativa diaria"
        case .operationalIntelligent:
            return "Informe operativo inteligente"
        }
    }
}

enum BusinessExportPeriodPreset: String, CaseIterable, Identifiable, Sendable {
    case today
    case yesterday
    case thisWeek
    case last7Days
    case thisFortnight
    case thisMonth
    case lastMonth
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Hoy"
        case .yesterday: return "Ayer"
        case .thisWeek: return "Esta semana"
        case .last7Days: return "Últimos 7 días"
        case .thisFortnight: return "Esta quincena"
        case .thisMonth: return "Este mes"
        case .lastMonth: return "Mes anterior"
        case .custom: return "Personalizado"
        }
    }
}

enum BusinessExportChartKind: String, CaseIterable, Identifiable, Sendable {
    case salesByDay
    case topItems
    case paymentStatuses
    case documentStatuses

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .salesByDay: return "Ventas"
        case .topItems: return "Productos"
        case .paymentStatuses: return "Pagos"
        case .documentStatuses: return "Documentos"
        }
    }
}

struct BusinessExportDescriptor: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: String
    let version: String?
    let title: String
    let description: String?
    let contentType: String?
    let fileName: String?
    let generatedAt: Date?
    let sizeBytes: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case exportId
        case kind
        case type
        case version
        case exportVersion
        case title
        case name
        case description
        case contentType
        case fileName
        case generatedAt
        case sizeBytes
    }

    init(
        id: String,
        kind: String,
        version: String? = nil,
        title: String,
        description: String? = nil,
        contentType: String? = nil,
        fileName: String? = nil,
        generatedAt: Date? = nil,
        sizeBytes: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.version = version
        self.title = title
        self.description = description
        self.contentType = contentType
        self.fileName = fileName
        self.generatedAt = generatedAt
        self.sizeBytes = sizeBytes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? BusinessExportKind.dailyOperational.rawValue
        version = try container.decodeIfPresent(String.self, forKey: .version)
            ?? container.decodeIfPresent(String.self, forKey: .exportVersion)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .exportId)
            ?? [kind, version].compactMap { $0 }.joined(separator: ":")
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? (BusinessExportKind(rawValue: kind)?.displayName ?? BusinessExportKind.dailyOperational.displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
        sizeBytes = try container.decodeIfPresent(Int.self, forKey: .sizeBytes)
    }
}

struct BusinessExportsCatalogResponse: Decodable, Equatable, Sendable {
    let exports: [BusinessExportDescriptor]

    private enum CodingKeys: String, CodingKey {
        case exports
        case items
        case availableExports
        case data
    }

    init(exports: [BusinessExportDescriptor]) {
        self.exports = exports
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exports = try container.decodeIfPresent([BusinessExportDescriptor].self, forKey: .exports)
            ?? container.decodeIfPresent([BusinessExportDescriptor].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessExportDescriptor].self, forKey: .availableExports)
            ?? container.decodeIfPresent([BusinessExportDescriptor].self, forKey: .data)
            ?? []
    }
}

struct BusinessExportGenerateRequest: Encodable, Equatable, Sendable {
    let kind: String
    let businessDate: String?
    let branchId: String?

    init(
        kind: String = BusinessExportKind.dailyOperational.rawValue,
        businessDate: String? = nil,
        branchId: String? = nil
    ) {
        self.kind = kind
        self.businessDate = businessDate
        self.branchId = branchId
    }
}

struct BusinessExportGenerateResponse: Decodable, Equatable, Sendable {
    let export: BusinessExportDescriptor

    private enum CodingKeys: String, CodingKey {
        case export
        case descriptor
        case data
    }

    init(export: BusinessExportDescriptor) {
        self.export = export
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let export = try? container.decode(BusinessExportDescriptor.self, forKey: .export) {
                self.export = export
                return
            }
            if let export = try? container.decode(BusinessExportDescriptor.self, forKey: .descriptor) {
                self.export = export
                return
            }
            if let export = try? container.decode(BusinessExportDescriptor.self, forKey: .data) {
                self.export = export
                return
            }
        }

        self.export = try BusinessExportDescriptor(from: decoder)
    }
}

struct BusinessExportDownloadedFile: Identifiable, Equatable, Sendable {
    let id: String
    let localURL: URL
    let fileName: String
    let contentType: String
    let sizeBytes: Int
    let sha256: String?

    init(localURL: URL, fileName: String, contentType: String, sizeBytes: Int, sha256: String? = nil) {
        self.localURL = localURL
        self.fileName = fileName
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.id = localURL.absoluteString
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}

struct BusinessOperationalSummaryResponse: Decodable, Equatable, Sendable {
    let period: BusinessOperationalPeriod
    let hasData: Bool
    let totals: BusinessOperationalTotals
    let comparisons: [BusinessOperationalComparison]
    let charts: BusinessOperationalCharts
    let alerts: [BusinessOperationalAlert]
    let availableExports: [String]
    let recommendedSummary: [String]
}

struct BusinessOperationalPeriod: Decodable, Equatable, Sendable {
    let from: String
    let to: String
    let label: String
    let timezone: String
    let isSingleDay: Bool
    let isPartialMonth: Bool
    let daysInPeriod: Int
    let daysWithData: Int
}

struct BusinessOperationalTotals: Decodable, Equatable, Sendable {
    let saleCount: Int
    let closedSaleCount: Int
    let canceledSaleCount: Int
    let itemCount: Int
    let grandTotal: BusinessExportMoney
    let paidTotal: BusinessExportMoney
    let receivableTotal: BusinessExportMoney
    let pendingReceivables: BusinessExportMoney
    let pendingReceivablesCount: Int
    let cashInTotal: BusinessExportMoney
    let cashOutTotal: BusinessExportMoney
    let netCashMovement: BusinessExportMoney
    let cashDifferenceTotal: BusinessExportMoney
    let documentCount: Int
    let authorizedDocumentCount: Int
    let pendingDocumentCount: Int
    let taxTotal: BusinessExportMoney
}

struct BusinessExportMoney: Decodable, Equatable, Sendable {
    let amount: String
    let currency: String

    var doubleValue: Double {
        Double(amount) ?? 0
    }

    var displayText: String {
        let value = doubleValue
        return value.formatted(.currency(code: currency))
    }
}

struct BusinessOperationalComparison: Decodable, Equatable, Sendable {
    let label: String
    let from: String
    let to: String
    let currentGrandTotal: BusinessExportMoney
    let previousGrandTotal: BusinessExportMoney
    let grandTotalDelta: BusinessExportMoney
    let grandTotalDeltaPercent: String?
    let currentSaleCount: Int
    let previousSaleCount: Int
    let saleCountDelta: Int
    let currentPaidTotal: BusinessExportMoney
    let previousPaidTotal: BusinessExportMoney
    let paidTotalDelta: BusinessExportMoney

    var deltaDisplayText: String {
        let prefix = grandTotalDelta.doubleValue >= 0 ? "+" : ""
        if let percent = grandTotalDeltaPercent {
            return "\(prefix)\(grandTotalDelta.displayText) · \(prefix)\(percent)%"
        }
        return "\(prefix)\(grandTotalDelta.displayText)"
    }
}

struct BusinessOperationalCharts: Decodable, Equatable, Sendable {
    let salesByDay: [BusinessOperationalDailyPoint]
    let topItems: [BusinessOperationalTopItem]
    let paymentStatuses: [BusinessOperationalStatusCount]
    let documentStatuses: [BusinessOperationalStatusCount]
    let cashMovementTypes: [BusinessOperationalStatusCount]
}

struct BusinessOperationalDailyPoint: Decodable, Equatable, Identifiable, Sendable {
    let date: String
    let label: String
    let saleCount: Int
    let grandTotal: BusinessExportMoney
    let paidTotal: BusinessExportMoney

    var id: String { date }
}

struct BusinessOperationalTopItem: Decodable, Equatable, Identifiable, Sendable {
    let catalogItemId: String?
    let name: String
    let quantity: String
    let netTotal: BusinessExportMoney
    let lineTotal: BusinessExportMoney

    var id: String { catalogItemId ?? name }
}

struct BusinessOperationalStatusCount: Decodable, Equatable, Identifiable, Sendable {
    let status: String
    let count: Int

    var id: String { status }
}

struct BusinessOperationalAlert: Decodable, Equatable, Identifiable, Sendable {
    let code: String
    let severity: String
    let message: String
    let actionHint: String?

    var id: String { code + message }
}

struct BusinessExportChartPoint: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let value: Double
    let valueText: String
}
