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
    let documentId: String
    let organizationId: String?
    let branchId: String?
    let emissionPointId: String?
    let environment: String?
    let sriStatus: String?
    let issuedAt: Date?
    let updatedAt: Date?
    let rideGeneratedAt: Date?
    let deliveredAt: Date?
    let hasRide: Bool
    let hasXml: Bool
    let hasErrors: Bool
    let lastSriReceptionStatus: String?
    let lastSriAuthorizationStatus: String?
    let lastErrorMessage: String?
    let customerName: String?
    let customerIdentification: String?
    let total: String?
    let currency: String

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
        rejectedAt: Date? = nil,
        documentId: String? = nil,
        organizationId: String? = nil,
        branchId: String? = nil,
        emissionPointId: String? = nil,
        environment: String? = nil,
        sriStatus: String? = nil,
        issuedAt: Date? = nil,
        updatedAt: Date? = nil,
        rideGeneratedAt: Date? = nil,
        deliveredAt: Date? = nil,
        hasRide: Bool? = nil,
        hasXml: Bool? = nil,
        hasErrors: Bool = false,
        lastSriReceptionStatus: String? = nil,
        lastSriAuthorizationStatus: String? = nil,
        lastErrorMessage: String? = nil,
        customerName: String? = nil,
        customerIdentification: String? = nil,
        total: String? = nil,
        currency: String = "USD"
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
        self.documentId = documentId ?? id
        self.organizationId = organizationId
        self.branchId = branchId
        self.emissionPointId = emissionPointId
        self.environment = environment
        self.sriStatus = sriStatus ?? status
        self.issuedAt = issuedAt ?? createdAt
        self.updatedAt = updatedAt
        self.rideGeneratedAt = rideGeneratedAt
        self.deliveredAt = deliveredAt
        self.hasRide = hasRide ?? (pdfUrl?.isEmpty == false)
        self.hasXml = hasXml ?? (xmlUrl?.isEmpty == false)
        self.hasErrors = hasErrors
        self.lastSriReceptionStatus = lastSriReceptionStatus
        self.lastSriAuthorizationStatus = lastSriAuthorizationStatus
        self.lastErrorMessage = lastErrorMessage
        self.customerName = customerName
        self.customerIdentification = customerIdentification
        self.total = total
        self.currency = currency
    }

    private enum CodingKeys: String, CodingKey {
        case id, documentId, organizationId, branchId, emissionPointId, saleId
        case type, documentType, status, sriStatus, number, displayNumber, documentNumber
        case authorizationNumber, numeroAutorizacion, accessKey, claveAcceso
        case customerName, customer, customerIdentification, customerEmail
        case total, grandTotal, currency, environment, pdfUrl, xmlUrl
        case createdAt, issueDate, issuedAt, updatedAt, authorizedAt, rejectedAt, rideGeneratedAt, deliveredAt, emailSentAt
        case hasRide, hasXml, hasErrors, lastSriReceptionStatus, lastSriAuthorizationStatus, lastErrorMessage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeFirstString(for: [.id, .documentId])
        documentId = try c.decodeFirstStringIfPresent(for: [.documentId, .id]) ?? id
        organizationId = try c.decodeFirstStringIfPresent(for: [.organizationId])
        branchId = try c.decodeFirstStringIfPresent(for: [.branchId])
        emissionPointId = try c.decodeFirstStringIfPresent(for: [.emissionPointId])
        saleId = try c.decodeFirstStringIfPresent(for: [.saleId]) ?? ""
        type = try c.decodeFirstStringIfPresent(for: [.type, .documentType]) ?? "electronic_invoice"
        status = try c.decodeFirstStringIfPresent(for: [.status, .sriStatus]) ?? "unknown"
        sriStatus = try c.decodeFirstStringIfPresent(for: [.sriStatus, .lastSriAuthorizationStatus, .lastSriReceptionStatus, .status])
        number = try c.decodeFirstStringIfPresent(for: [.number, .displayNumber, .documentNumber])
        authorizationNumber = try c.decodeFirstStringIfPresent(for: [.authorizationNumber, .numeroAutorizacion])
        accessKey = try c.decodeFirstStringIfPresent(for: [.accessKey, .claveAcceso])
        customerName = try c.decodeFirstStringIfPresent(for: [.customerName, .customer])
        customerIdentification = try c.decodeFirstStringIfPresent(for: [.customerIdentification])
        customerEmail = try c.decodeFirstStringIfPresent(for: [.customerEmail])
        total = try c.decodeFirstStringIfPresent(for: [.total, .grandTotal])
        currency = try c.decodeFirstStringIfPresent(for: [.currency]) ?? "USD"
        pdfUrl = try c.decodeFirstStringIfPresent(for: [.pdfUrl])
        xmlUrl = try c.decodeFirstStringIfPresent(for: [.xmlUrl])
        createdAt = try c.decodeFirstDateIfPresent(for: [.createdAt, .issuedAt, .issueDate])
        issuedAt = try c.decodeFirstDateIfPresent(for: [.issuedAt, .issueDate, .createdAt])
        updatedAt = try c.decodeFirstDateIfPresent(for: [.updatedAt])
        authorizedAt = try c.decodeFirstDateIfPresent(for: [.authorizedAt])
        rejectedAt = try c.decodeFirstDateIfPresent(for: [.rejectedAt])
        rideGeneratedAt = try c.decodeFirstDateIfPresent(for: [.rideGeneratedAt])
        deliveredAt = try c.decodeFirstDateIfPresent(for: [.deliveredAt, .emailSentAt])
        environment = try c.decodeFirstStringIfPresent(for: [.environment])
        hasRide = try c.decodeIfPresent(Bool.self, forKey: .hasRide) ?? (pdfUrl?.isEmpty == false)
        hasXml = try c.decodeIfPresent(Bool.self, forKey: .hasXml) ?? (xmlUrl?.isEmpty == false)
        hasErrors = try c.decodeIfPresent(Bool.self, forKey: .hasErrors) ?? false
        lastSriReceptionStatus = try c.decodeFirstStringIfPresent(for: [.lastSriReceptionStatus])
        lastSriAuthorizationStatus = try c.decodeFirstStringIfPresent(for: [.lastSriAuthorizationStatus])
        lastErrorMessage = try c.decodeFirstStringIfPresent(for: [.lastErrorMessage])
    }

    var displayNumber: String {
        number?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? id
    }

    var effectiveStatus: String {
        sriStatus?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? status
    }
}

extension BusinessDocument {
    var isElectronicInvoiceForBusinessUI: Bool {
        let normalizedType = Self.normalized(type)
        return normalizedType.contains("electronic_invoice") ||
        normalizedType.contains("factura") ||
        normalizedType.contains("invoice")
    }

    var businessDisplayNumber: String {
        if let number = number?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty {
            return number
        }

        if isElectronicInvoiceForBusinessUI {
            return "Factura electrónica"
        }

        return "Comprobante"
    }

    var shortAuthorizationDisplay: String? {
        guard let value = authorizationNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if value.count <= 18 { return value }
        return "…" + String(value.suffix(12))
    }

    var businessIdentityKeys: [String] {
        var keys: [String] = []
        let candidates: [(String, String?)] = [
            ("documentId", documentId),
            ("id", id),
            ("accessKey", accessKey),
            ("authorization", authorizationNumber)
        ]

        for (prefix, value) in candidates {
            if let normalized = Self.normalizedIdentifier(value), !normalized.isEmpty {
                keys.append("\(prefix):\(normalized)")
            }
        }

        return keys
    }

    var businessSortDate: Date? {
        authorizedAt ?? deliveredAt ?? issuedAt ?? createdAt ?? updatedAt ?? rejectedAt
    }

    static func bestElectronicInvoice(in documents: [BusinessDocument]) -> BusinessDocument? {
        documents
            .filter(\.isElectronicInvoiceForBusinessUI)
            .sorted(by: businessSort)
            .first
    }

    static func mergeUniquePreferBest(_ documents: [BusinessDocument]) -> [BusinessDocument] {
        var result: [BusinessDocument] = []

        for document in documents {
            if let index = result.firstIndex(where: { isSameBusinessDocument($0, document) }) {
                let current = result[index]
                result[index] = businessSort(document, current) ? document : current
            } else {
                result.append(document)
            }
        }

        return result.sorted(by: businessSort)
    }

    static func isSameBusinessDocument(_ lhs: BusinessDocument, _ rhs: BusinessDocument) -> Bool {
        let lhsKeys = Set(lhs.businessIdentityKeys)
        let rhsKeys = Set(rhs.businessIdentityKeys)
        return !lhsKeys.isDisjoint(with: rhsKeys)
    }

    static func businessSort(_ lhs: BusinessDocument, _ rhs: BusinessDocument) -> Bool {
        let leftPriority = businessStatusPriority(lhs.effectiveStatus)
        let rightPriority = businessStatusPriority(rhs.effectiveStatus)

        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }

        switch (lhs.businessSortDate, rhs.businessSortDate) {
        case let (left?, right?):
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.businessDisplayNumber.localizedCaseInsensitiveCompare(rhs.businessDisplayNumber) == .orderedAscending
        }
    }

    private static func businessStatusPriority(_ status: String) -> Int {
        switch normalized(status) {
        case "authorized", "autorizado", "delivered", "sent_email", "email_sent":
            return 0
        case "received", "received_by_sri", "received_by_tax_authority", "recibida", "sent", "submitted", "submitted_to_sri", "submitted_to_reception", "signed", "validated":
            return 1
        case "generated", "access_key_generated", "registered", "draft":
            return 2
        case "rejected", "rechazado", "not_authorized", "notauthorized", "no_autorizada", "returned", "returned_by_sri", "devuelta", "signature_failed", "xsd_invalid", "reception_transport_failed", "error", "failed", "delivery_failed", "email_failed":
            return 3
        case "not_required", "no_required", "none", "without_document", "sin_documento", "":
            return 5
        default:
            return 4
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
    }

    private static func normalizedIdentifier(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct BusinessDocumentListEnvelope: Decodable, Equatable, Sendable {
    let documents: [BusinessDocument]
    let total: Int?
    let hasMore: Bool?

    private enum CodingKeys: String, CodingKey { case documents, items, results, data, total, count, hasMore }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        documents = (try? c.decodeIfPresent([BusinessDocument].self, forKey: .documents))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .items))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .results))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .data))
            ?? []
        total = (try? c.decodeIfPresent(Int.self, forKey: .total))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .count))
        hasMore = try? c.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
}

struct BusinessDocumentsResponse: Decodable, Equatable, Sendable {
    let documents: [BusinessDocument]

    init(documents: [BusinessDocument]) {
        self.documents = documents
    }

    private enum CodingKeys: String, CodingKey { case documents, items, results, data, payload, result }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let nestedData = (try? c.decodeIfPresent(BusinessDocumentListEnvelope.self, forKey: .data)) ?? nil
        let nestedPayload = (try? c.decodeIfPresent(BusinessDocumentListEnvelope.self, forKey: .payload)) ?? nil
        let nestedResult = (try? c.decodeIfPresent(BusinessDocumentListEnvelope.self, forKey: .result)) ?? nil

        documents = (try? c.decodeIfPresent([BusinessDocument].self, forKey: .documents))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .items))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .results))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .data))
            ?? nestedData?.documents
            ?? nestedPayload?.documents
            ?? nestedResult?.documents
            ?? []
    }
}

struct BusinessElectronicDocumentFilters: Equatable, Sendable {
    let saleId: String?
    let status: String?
    let environment: String?
    let from: String?
    let to: String?
    let limit: Int

    init(
        saleId: String? = nil,
        status: String? = nil,
        environment: String? = nil,
        from: String? = nil,
        to: String? = nil,
        limit: Int = 100
    ) {
        self.saleId = saleId?.trimmedNilIfBlank
        self.status = status?.trimmedNilIfBlank
        self.environment = environment?.trimmedNilIfBlank
        self.from = from?.trimmedNilIfBlank
        self.to = to?.trimmedNilIfBlank
        self.limit = max(1, min(limit, 250))
    }

    var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let saleId { items.append(URLQueryItem(name: "saleId", value: saleId)) }
        if let status { items.append(URLQueryItem(name: "status", value: status)) }
        if let environment { items.append(URLQueryItem(name: "environment", value: environment)) }
        if let from { items.append(URLQueryItem(name: "from", value: from)) }
        if let to { items.append(URLQueryItem(name: "to", value: to)) }
        return items
    }
}

struct BusinessElectronicDocumentsResponse: Decodable, Equatable, Sendable {
    let documents: [BusinessDocument]
    let total: Int
    let hasMore: Bool

    init(documents: [BusinessDocument], total: Int? = nil, hasMore: Bool = false) {
        self.documents = documents
        self.total = total ?? documents.count
        self.hasMore = hasMore
    }

    private enum CodingKeys: String, CodingKey { case documents, items, results, data, payload, result, total, count, hasMore }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let nestedData = (try? c.decodeIfPresent(BusinessDocumentListEnvelope.self, forKey: .data)) ?? nil
        let nestedPayload = (try? c.decodeIfPresent(BusinessDocumentListEnvelope.self, forKey: .payload)) ?? nil
        let nestedResult = (try? c.decodeIfPresent(BusinessDocumentListEnvelope.self, forKey: .result)) ?? nil

        documents = (try? c.decodeIfPresent([BusinessDocument].self, forKey: .documents))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .items))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .results))
            ?? (try? c.decodeIfPresent([BusinessDocument].self, forKey: .data))
            ?? nestedData?.documents
            ?? nestedPayload?.documents
            ?? nestedResult?.documents
            ?? []

        total = (try? c.decodeIfPresent(Int.self, forKey: .total))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .count))
            ?? nestedData?.total
            ?? nestedPayload?.total
            ?? nestedResult?.total
            ?? documents.count

        hasMore = (try? c.decodeIfPresent(Bool.self, forKey: .hasMore))
            ?? nestedData?.hasMore
            ?? nestedPayload?.hasMore
            ?? nestedResult?.hasMore
            ?? false
    }
}

struct BusinessDocumentResponse: Decodable, Equatable, Sendable {
    let document: BusinessDocument
    let sale: BusinessSale?
    let idempotencyReplayed: Bool?

    init(document: BusinessDocument, sale: BusinessSale? = nil, idempotencyReplayed: Bool? = nil) {
        self.document = document
        self.sale = sale
        self.idempotencyReplayed = idempotencyReplayed
    }
}


enum BusinessElectronicDocumentAction: Equatable, Hashable, Codable, Sendable {
    case viewDetail
    case viewTimeline
    case downloadRide
    case downloadXml
    case retryReception
    case retryAuthorization
    case resendEmail
    case regenerateRide
    case unknown(String)

    init(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "view_detail", "viewdetail": self = .viewDetail
        case "view_timeline", "viewtimeline": self = .viewTimeline
        case "download_ride", "downloadride": self = .downloadRide
        case "download_xml", "downloadxml": self = .downloadXml
        case "retry_reception", "retryreception": self = .retryReception
        case "retry_authorization", "retryauthorization": self = .retryAuthorization
        case "resend_email", "resendemail": self = .resendEmail
        case "regenerate_ride", "regenerateride": self = .regenerateRide
        case let value where value.isEmpty: self = .unknown("unknown")
        case let value: self = .unknown(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: (try? container.decode(String.self)) ?? "unknown")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(publicRawValue)
    }

    var publicRawValue: String {
        switch self {
        case .viewDetail: return "view_detail"
        case .viewTimeline: return "view_timeline"
        case .downloadRide: return "download_ride"
        case .downloadXml: return "download_xml"
        case .retryReception: return "retry_reception"
        case .retryAuthorization: return "retry_authorization"
        case .resendEmail: return "resend_email"
        case .regenerateRide: return "regenerate_ride"
        case .unknown(let rawValue): return rawValue
        }
    }

    var displayName: String {
        switch self {
        case .viewDetail: return "Ver detalle"
        case .viewTimeline: return "Ver timeline"
        case .downloadRide: return "Ver RIDE"
        case .downloadXml: return "Ver XML"
        case .retryReception: return "Reintentar recepción"
        case .retryAuthorization: return "Reintentar autorización"
        case .resendEmail: return "Reenviar email"
        case .regenerateRide: return "Regenerar RIDE"
        case .unknown: return "Acción no disponible"
        }
    }
}

struct BusinessElectronicDocumentRetrySummary: Decodable, Equatable, Sendable {
    let canRetryReception: Bool
    let canRetryAuthorization: Bool
    let canResendEmail: Bool
    let canRegenerateRide: Bool
    let receptionRetryCount: Int
    let authorizationRetryCount: Int
    let emailAttempts: Int
    let rideRegenerationCount: Int
    let nextRetryAt: Date?
    let lastRetryAt: Date?
    let message: String?

    init(
        canRetryReception: Bool = false,
        canRetryAuthorization: Bool = false,
        canResendEmail: Bool = false,
        canRegenerateRide: Bool = false,
        receptionRetryCount: Int = 0,
        authorizationRetryCount: Int = 0,
        emailAttempts: Int = 0,
        rideRegenerationCount: Int = 0,
        nextRetryAt: Date? = nil,
        lastRetryAt: Date? = nil,
        message: String? = nil
    ) {
        self.canRetryReception = canRetryReception
        self.canRetryAuthorization = canRetryAuthorization
        self.canResendEmail = canResendEmail
        self.canRegenerateRide = canRegenerateRide
        self.receptionRetryCount = receptionRetryCount
        self.authorizationRetryCount = authorizationRetryCount
        self.emailAttempts = emailAttempts
        self.rideRegenerationCount = rideRegenerationCount
        self.nextRetryAt = nextRetryAt
        self.lastRetryAt = lastRetryAt
        self.message = BusinessDocumentTextSanitizer.sanitizedMessage(message)
    }

    private enum CodingKeys: String, CodingKey {
        case canRetryReception, canRetryAuthorization, canResendEmail, canRegenerateRide
        case receptionRetryCount, authorizationRetryCount, emailAttempts, rideRegenerationCount
        case nextRetryAt, lastRetryAt, message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            canRetryReception: try c.decodeIfPresent(Bool.self, forKey: .canRetryReception) ?? false,
            canRetryAuthorization: try c.decodeIfPresent(Bool.self, forKey: .canRetryAuthorization) ?? false,
            canResendEmail: try c.decodeIfPresent(Bool.self, forKey: .canResendEmail) ?? false,
            canRegenerateRide: try c.decodeIfPresent(Bool.self, forKey: .canRegenerateRide) ?? false,
            receptionRetryCount: try c.decodeIfPresent(Int.self, forKey: .receptionRetryCount) ?? 0,
            authorizationRetryCount: try c.decodeIfPresent(Int.self, forKey: .authorizationRetryCount) ?? 0,
            emailAttempts: try c.decodeIfPresent(Int.self, forKey: .emailAttempts) ?? 0,
            rideRegenerationCount: try c.decodeIfPresent(Int.self, forKey: .rideRegenerationCount) ?? 0,
            nextRetryAt: try c.decodeFirstDateIfPresent(for: [.nextRetryAt]),
            lastRetryAt: try c.decodeFirstDateIfPresent(for: [.lastRetryAt]),
            message: try c.decodeFirstStringIfPresent(for: [.message])
        )
    }
}

struct BusinessElectronicDocumentDetailEnvelopeResponse: Decodable, Equatable, Sendable {
    let document: BusinessElectronicDocumentDetail
}

struct BusinessElectronicDocumentDetail: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let documentId: String
    let summary: BusinessDocument
    let organizationId: String
    let saleId: String?
    let documentType: String
    let displayNumber: String
    let accessKey: String
    let authorizationNumber: String?
    let customerName: String?
    let customerIdentification: String?
    let customerEmail: String?
    let total: String?
    let currency: String
    let status: String
    let sriStatus: String
    let environment: String
    let issueDate: Date?
    let authorizedAt: Date?
    let updatedAt: Date?
    let sri: BusinessElectronicDocumentSriState
    let artifacts: BusinessElectronicDocumentArtifacts
    let email: BusinessElectronicDocumentEmailState
    let timeline: [BusinessElectronicDocumentTimelineEvent]
    let errors: [BusinessSriDocumentError]
    let warnings: [String]
    let availableActions: [BusinessElectronicDocumentAction]
    let retrySummary: BusinessElectronicDocumentRetrySummary

    func allows(_ action: BusinessElectronicDocumentAction) -> Bool {
        availableActions.contains(action)
    }

    private enum CodingKeys: String, CodingKey {
        case id, documentId, summary, organizationId, saleId, documentType, type, displayNumber, number, documentNumber
        case accessKey, claveAcceso, authorizationNumber, numeroAutorizacion
        case customerName, customerIdentification, customerEmail, total, grandTotal, currency
        case status, sriStatus, environment, issueDate, issuedAt, authorizedAt, updatedAt
        case sri, artifacts, email, timeline, errors, warnings, availableActions, retrySummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeFirstString(for: [.id, .documentId])
        documentId = try c.decodeFirstStringIfPresent(for: [.documentId, .id]) ?? id
        if let decodedSummary = try c.decodeIfPresent(BusinessDocument.self, forKey: .summary) {
            summary = decodedSummary
        } else {
            let decodedSaleId = try c.decodeFirstStringIfPresent(for: [.saleId]) ?? ""
            let decodedType = try c.decodeFirstStringIfPresent(for: [.documentType, .type]) ?? "electronic_invoice"
            let decodedStatus = try c.decodeFirstStringIfPresent(for: [.status, .sriStatus]) ?? "unknown"
            let decodedNumber = try c.decodeFirstStringIfPresent(for: [.displayNumber, .number, .documentNumber])
            let decodedAuthorizationNumber = try c.decodeFirstStringIfPresent(for: [.authorizationNumber, .numeroAutorizacion])
            let decodedAccessKey = try c.decodeFirstStringIfPresent(for: [.accessKey, .claveAcceso])
            let decodedCustomerEmail = try c.decodeFirstStringIfPresent(for: [.customerEmail])
            let decodedIssueDate = try c.decodeFirstDateIfPresent(for: [.issueDate, .issuedAt])
            let decodedAuthorizedAt = try c.decodeFirstDateIfPresent(for: [.authorizedAt])
            let decodedOrganizationId = try c.decodeFirstStringIfPresent(for: [.organizationId])
            let decodedEnvironment = try c.decodeFirstStringIfPresent(for: [.environment])
            let decodedSriStatus = try c.decodeFirstStringIfPresent(for: [.sriStatus])
            let decodedUpdatedAt = try c.decodeFirstDateIfPresent(for: [.updatedAt])

            summary = BusinessDocument(
                id: id,
                saleId: decodedSaleId,
                type: decodedType,
                status: decodedStatus,
                number: decodedNumber,
                authorizationNumber: decodedAuthorizationNumber,
                accessKey: decodedAccessKey,
                customerEmail: decodedCustomerEmail,
                createdAt: decodedIssueDate,
                authorizedAt: decodedAuthorizedAt,
                organizationId: decodedOrganizationId,
                environment: decodedEnvironment,
                sriStatus: decodedSriStatus,
                updatedAt: decodedUpdatedAt
            )
        }
        organizationId = try c.decodeFirstStringIfPresent(for: [.organizationId]) ?? summary.organizationId ?? ""
        saleId = try c.decodeFirstStringIfPresent(for: [.saleId]) ?? summary.saleId.nilIfBlank
        documentType = try c.decodeFirstStringIfPresent(for: [.documentType, .type]) ?? summary.type
        displayNumber = try c.decodeFirstStringIfPresent(for: [.displayNumber, .number, .documentNumber]) ?? summary.displayNumber
        accessKey = try c.decodeFirstStringIfPresent(for: [.accessKey, .claveAcceso]) ?? summary.accessKey ?? ""
        authorizationNumber = try c.decodeFirstStringIfPresent(for: [.authorizationNumber, .numeroAutorizacion]) ?? summary.authorizationNumber
        customerName = try c.decodeFirstStringIfPresent(for: [.customerName]) ?? summary.customerName
        customerIdentification = try c.decodeFirstStringIfPresent(for: [.customerIdentification]) ?? summary.customerIdentification
        customerEmail = try c.decodeFirstStringIfPresent(for: [.customerEmail]) ?? summary.customerEmail
        total = try c.decodeFirstStringIfPresent(for: [.total, .grandTotal]) ?? summary.total
        currency = try c.decodeFirstStringIfPresent(for: [.currency]) ?? summary.currency
        status = try c.decodeFirstStringIfPresent(for: [.status]) ?? summary.status
        sriStatus = try c.decodeFirstStringIfPresent(for: [.sriStatus]) ?? summary.sriStatus ?? status
        environment = try c.decodeFirstStringIfPresent(for: [.environment]) ?? summary.environment ?? "test"
        issueDate = try c.decodeFirstDateIfPresent(for: [.issueDate, .issuedAt]) ?? summary.issuedAt ?? summary.createdAt
        authorizedAt = try c.decodeFirstDateIfPresent(for: [.authorizedAt]) ?? summary.authorizedAt
        updatedAt = try c.decodeFirstDateIfPresent(for: [.updatedAt]) ?? summary.updatedAt
        sri = try c.decodeIfPresent(BusinessElectronicDocumentSriState.self, forKey: .sri) ?? BusinessElectronicDocumentSriState(
            environment: environment,
            receptionStatus: summary.lastSriReceptionStatus,
            authorizationStatus: summary.lastSriAuthorizationStatus ?? sriStatus,
            authorizationNumber: authorizationNumber,
            accessKey: accessKey,
            authorizedAt: authorizedAt,
            lastCheckedAt: updatedAt
        )
        artifacts = try c.decodeIfPresent(BusinessElectronicDocumentArtifacts.self, forKey: .artifacts) ?? BusinessElectronicDocumentArtifacts(
            ride: summary.hasRide ? BusinessDocumentArtifact(kind: "ride", fileName: "\(displayNumber).pdf", contentType: "application/pdf") : nil,
            signedXml: nil,
            authorizedXml: summary.hasXml ? BusinessDocumentArtifact(kind: "authorizedXml", fileName: "\(displayNumber)-authorized.xml", contentType: "application/xml") : nil,
            xml: summary.hasXml ? BusinessDocumentArtifact(kind: "authorizedXml", fileName: "\(displayNumber)-authorized.xml", contentType: "application/xml") : nil
        )
        email = try c.decodeIfPresent(BusinessElectronicDocumentEmailState.self, forKey: .email) ?? BusinessElectronicDocumentEmailState(
            recipient: summary.customerEmail,
            status: summary.deliveredAt == nil ? nil : "sent",
            sentAt: summary.deliveredAt,
            lastError: nil,
            attempts: nil
        )
        timeline = try c.decodeIfPresent([BusinessElectronicDocumentTimelineEvent].self, forKey: .timeline) ?? []
        errors = try c.decodeIfPresent([BusinessSriDocumentError].self, forKey: .errors) ?? []
        warnings = try c.decodeIfPresent([String].self, forKey: .warnings) ?? []
        availableActions = (try c.decodeIfPresent([BusinessElectronicDocumentAction].self, forKey: .availableActions) ?? []).uniqueByPublicRawValue
        retrySummary = try c.decodeIfPresent(BusinessElectronicDocumentRetrySummary.self, forKey: .retrySummary) ?? BusinessElectronicDocumentRetrySummary()
    }
}

struct BusinessElectronicDocumentSriState: Decodable, Equatable, Sendable {
    let environment: String?
    let receptionStatus: String?
    let authorizationStatus: String?
    let authorizationNumber: String?
    let accessKey: String?
    let receivedAt: Date?
    let authorizedAt: Date?
    let lastCheckedAt: Date?
    let retryCount: Int?
    let nextRetryAt: Date?

    init(
        environment: String? = nil,
        receptionStatus: String? = nil,
        authorizationStatus: String? = nil,
        authorizationNumber: String? = nil,
        accessKey: String? = nil,
        receivedAt: Date? = nil,
        authorizedAt: Date? = nil,
        lastCheckedAt: Date? = nil,
        retryCount: Int? = nil,
        nextRetryAt: Date? = nil
    ) {
        self.environment = environment
        self.receptionStatus = receptionStatus
        self.authorizationStatus = authorizationStatus
        self.authorizationNumber = authorizationNumber
        self.accessKey = accessKey
        self.receivedAt = receivedAt
        self.authorizedAt = authorizedAt
        self.lastCheckedAt = lastCheckedAt
        self.retryCount = retryCount
        self.nextRetryAt = nextRetryAt
    }
}

enum BusinessDocumentArtifactKind: Equatable, Hashable, Codable, Sendable {
    case ride
    case ridePdf
    case signedXml
    case authorizedXml
    case generatedXml
    case sriRequest
    case sriResponse
    case xml
    case unknown(String)

    init(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "ride":
            self = .ride
        case "ridePdf", "ride_pdf":
            self = .ridePdf
        case "signedXml", "signed_xml":
            self = .signedXml
        case "authorizedXml", "authorized_xml":
            self = .authorizedXml
        case "generatedXml", "generated_xml":
            self = .generatedXml
        case "sriRequest", "sri_request":
            self = .sriRequest
        case "sriResponse", "sri_response":
            self = .sriResponse
        case "xml":
            self = .xml
        case let value where value.isEmpty:
            self = .unknown("artifact")
        case let value:
            self = .unknown(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(publicRawValue)
    }

    var publicRawValue: String {
        switch self {
        case .ride:
            return "ride"
        case .ridePdf:
            return "ridePdf"
        case .signedXml:
            return "signedXml"
        case .authorizedXml:
            return "authorizedXml"
        case .generatedXml:
            return "generatedXml"
        case .sriRequest:
            return "sriRequest"
        case .sriResponse:
            return "sriResponse"
        case .xml:
            return "xml"
        case .unknown(let rawValue):
            return rawValue
        }
    }

    var displayName: String {
        switch self {
        case .ride, .ridePdf:
            return "RIDE PDF"
        case .signedXml:
            return "XML firmado"
        case .authorizedXml, .xml:
            return "XML autorizado"
        case .generatedXml:
            return "XML generado"
        case .sriRequest:
            return "Solicitud SRI"
        case .sriResponse:
            return "Respuesta SRI"
        case .unknown:
            return "Archivo"
        }
    }

    var isRide: Bool {
        switch self {
        case .ride, .ridePdf:
            return true
        default:
            return false
        }
    }

    var isXml: Bool {
        switch self {
        case .signedXml, .authorizedXml, .generatedXml, .xml:
            return true
        default:
            return false
        }
    }
}

enum BusinessDocumentTextSanitizer {
    static func sanitizedMessage(_ message: String?) -> String? {
        guard let message else { return nil }

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let humanized = APIErrorHumanizer.humanizedBusinessMessage(trimmed) {
            return humanized
        }

        let lowercased = trimmed.lowercased()

        let forbiddenFragments = [
            "domain_rule_violation",
            "sitem_",
            "sale item",
            "sritaxcode",
            "sri_tax_code",
            "tax profile",
            "electronic-invoicing/",
            "ride_pdf/",
            "signed_xml",
            "authorized_xml",
            "generated_xml",
            "sri_request",
            "sri_response",
            "bucket",
            "objectkey",
            "storagekey",
            "/var/",
            "/tmp/",
            ".p12",
            ".pfx",
            "secret",
            "password",
            "privatekey",
            "token"
        ]

        guard forbiddenFragments.allSatisfy({ !lowercased.contains($0) }) else {
            return nil
        }

        return trimmed
    }

    static func sanitizedFileName(_ fileName: String?, fallback: String = "Archivo") -> String {
        sanitizedMessage(fileName) ?? fallback
    }
}

struct BusinessElectronicDocumentArtifacts: Decodable, Equatable, Sendable {
    let ride: BusinessDocumentArtifact?
    let signedXml: BusinessDocumentArtifact?
    let authorizedXml: BusinessDocumentArtifact?
    let xml: BusinessDocumentArtifact?
}

struct BusinessDocumentArtifact: Decodable, Equatable, Identifiable, Sendable {
    let id: String?
    let artifactId: String?
    let kind: BusinessDocumentArtifactKind
    let fileName: String
    let contentType: String
    let sizeBytes: Int64?
    let downloadUrl: String?
    let expiresAt: Date?
    let sha256: String?

    init(
        id: String? = nil,
        artifactId: String? = nil,
        kind: String,
        fileName: String,
        contentType: String,
        sizeBytes: Int64? = nil,
        downloadUrl: String? = nil,
        expiresAt: Date? = nil,
        sha256: String? = nil
    ) {
        self.init(
            id: id,
            artifactId: artifactId,
            kind: BusinessDocumentArtifactKind(rawValue: kind),
            fileName: fileName,
            contentType: contentType,
            sizeBytes: sizeBytes,
            downloadUrl: downloadUrl,
            expiresAt: expiresAt,
            sha256: sha256
        )
    }

    init(
        id: String? = nil,
        artifactId: String? = nil,
        kind: BusinessDocumentArtifactKind,
        fileName: String,
        contentType: String,
        sizeBytes: Int64? = nil,
        downloadUrl: String? = nil,
        expiresAt: Date? = nil,
        sha256: String? = nil
    ) {
        self.id = id ?? artifactId ?? sha256 ?? "\(kind.publicRawValue)-\(fileName)"
        self.artifactId = artifactId ?? id
        self.kind = kind
        self.fileName = fileName
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.downloadUrl = downloadUrl
        self.expiresAt = expiresAt
        self.sha256 = sha256
    }

    var displayName: String {
        kind.displayName
    }

    var safeFileName: String {
        BusinessDocumentTextSanitizer.sanitizedFileName(fileName, fallback: kind.displayName)
    }

    private enum CodingKeys: String, CodingKey {
        case id, artifactId, kind, artifactType, fileName, filename, contentType, sizeBytes, downloadUrl, downloadURL, url, expiresAt, sha256
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try c.decodeFirstStringIfPresent(for: [.id, .artifactId, .sha256])
        let decodedKind = BusinessDocumentArtifactKind(
            rawValue: try c.decodeFirstStringIfPresent(for: [.kind, .artifactType]) ?? "artifact"
        )
        let decodedFileName = try c.decodeFirstStringIfPresent(for: [.fileName, .filename]) ?? "documento"
        let decodedSha256 = try c.decodeFirstStringIfPresent(for: [.sha256])

        kind = decodedKind
        fileName = decodedFileName
        contentType = try c.decodeFirstStringIfPresent(for: [.contentType]) ?? "application/octet-stream"
        sizeBytes = try c.decodeIfPresent(Int64.self, forKey: .sizeBytes)
        downloadUrl = try c.decodeFirstStringIfPresent(for: [.downloadUrl, .downloadURL, .url])
        expiresAt = try c.decodeFirstDateIfPresent(for: [.expiresAt])
        sha256 = decodedSha256
        artifactId = try c.decodeFirstStringIfPresent(for: [.artifactId]) ?? decodedId
        id = decodedId ?? decodedSha256 ?? "\(decodedKind.publicRawValue)-\(decodedFileName)"
    }
}

struct BusinessElectronicDocumentEmailState: Decodable, Equatable, Sendable {
    let recipient: String?
    let status: String?
    let sentAt: Date?
    let lastError: String?
    let attempts: Int?

    init(recipient: String? = nil, status: String? = nil, sentAt: Date? = nil, lastError: String? = nil, attempts: Int? = nil) {
        self.recipient = recipient
        self.status = status
        self.sentAt = sentAt
        self.lastError = lastError
        self.attempts = attempts
    }
}

struct BusinessSriDocumentError: Decodable, Equatable, Identifiable, Sendable {
    let id: String?
    let code: String?
    let type: String?
    let rawMessage: String?
    let message: String?
    let userMessage: String?
    let technicalMessage: String?
    let field: String?
    let occurredAt: Date?
    let retryable: Bool?
    let severity: String?
}

extension BusinessSriDocumentError {
    var safeDisplayMessage: String {
        BusinessDocumentTextSanitizer.sanitizedMessage(userMessage)
            ?? BusinessDocumentTextSanitizer.sanitizedMessage(message)
            ?? BusinessDocumentTextSanitizer.sanitizedMessage(rawMessage)
            ?? "Error SRI"
    }

    var safeCode: String? {
        BusinessDocumentTextSanitizer.sanitizedMessage(code)
    }
}

struct BusinessElectronicDocumentTimelineResponse: Decodable, Equatable, Sendable {
    let documentId: String
    let events: [BusinessElectronicDocumentTimelineEvent]
}

struct BusinessElectronicDocumentTimelineEvent: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let type: String
    let title: String
    let message: String?
    let actor: String?
    let createdAt: Date?
    let severity: String?

    private enum CodingKeys: String, CodingKey {
        case id, type, action, title, message, actor, actorUserId, createdAt, occurredAt, severity, status
    }

    init(
        id: String,
        type: String,
        title: String? = nil,
        message: String? = nil,
        actor: String? = nil,
        createdAt: Date? = nil,
        severity: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = Self.title(from: type)
        self.message = BusinessDocumentTextSanitizer.sanitizedMessage(message)
        self.actor = BusinessDocumentTextSanitizer.sanitizedMessage(actor)
        self.createdAt = createdAt
        self.severity = BusinessDocumentTextSanitizer.sanitizedMessage(severity)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decodeFirstStringIfPresent(for: [.type, .action]) ?? "event"
        id = try c.decodeFirstStringIfPresent(for: [.id]) ?? UUID().uuidString
        title = Self.title(from: type)
        message = BusinessDocumentTextSanitizer.sanitizedMessage(
            try c.decodeFirstStringIfPresent(for: [.message])
        )
        actor = BusinessDocumentTextSanitizer.sanitizedMessage(
            try c.decodeFirstStringIfPresent(for: [.actor, .actorUserId])
        )
        createdAt = try c.decodeFirstDateIfPresent(for: [.createdAt, .occurredAt])
        severity = BusinessDocumentTextSanitizer.sanitizedMessage(
            try c.decodeFirstStringIfPresent(for: [.severity, .status])
        )
    }

    private static func title(from raw: String) -> String {
        switch raw.uppercased() {
        case "SRI_ACCESS_KEY_GENERATED":
            return "Clave de acceso generada."
        case "ELECTRONIC_XML_GENERATED":
            return "XML generado."
        case "ELECTRONIC_XML_XSD_VALIDATED":
            return "XML validado."
        case "ELECTRONIC_XML_XSD_INVALID":
            return "XML inválido."
        case "ELECTRONIC_XML_SIGNED":
            return "XML firmado."
        case "ELECTRONIC_XML_SIGNATURE_FAILED":
            return "No se pudo firmar el XML."
        case "SRI_RECEPTION_SUBMITTED":
            return "Enviado al SRI."
        case "SRI_RECEPTION_RECEIVED":
            return "Recibido por el SRI."
        case "SRI_RECEPTION_RETURNED":
            return "Devuelto por el SRI."
        case "SRI_RECEPTION_TRANSPORT_FAILED":
            return "No se pudo conectar con recepción SRI."
        case "SRI_AUTHORIZATION_QUERIED":
            return "Autorización consultada."
        case "SRI_AUTHORIZED", "AUTHORIZED", "AUTORIZADO":
            return "Autorizado por el SRI."
        case "SRI_NOT_AUTHORIZED":
            return "No autorizado por el SRI."
        case "SRI_AUTHORIZATION_PROCESSING":
            return "Autorización en proceso."
        case "SRI_AUTHORIZATION_TRANSPORT_FAILED":
            return "No se pudo consultar autorización SRI."
        case "ELECTRONIC_RIDE_GENERATED":
            return "RIDE generado correctamente."
        case "ELECTRONIC_RIDE_REUSED":
            return "RIDE reutilizado correctamente."
        case "ELECTRONIC_INVOICE_EMAIL_SENT":
            return "Correo enviado correctamente."
        case "ELECTRONIC_INVOICE_EMAIL_FAILED":
            return "No se pudo enviar el correo."
        default:
            return "Evento registrado."
        }
    }
}

struct BusinessDocumentEmailResendRequest: Encodable, Equatable, Sendable {
    let recipientOverride: String?
    let reason: String
    let allowResend: Bool

    init(recipientOverride: String? = nil, reason: String, allowResend: Bool = true) {
        self.recipientOverride = recipientOverride?.trimmedNilIfBlank
        self.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        self.allowResend = allowResend
    }
}

struct BusinessDocumentEmailResendResponse: Decodable, Equatable, Sendable {
    let documentId: String
    let accepted: Bool
    let recipient: String?
    let message: String
    let requestedAt: Date?
}

struct BusinessDocumentArtifactEnvelopeResponse: Decodable, Equatable, Sendable {
    let artifact: BusinessDocumentArtifact?
    let ride: BusinessDocumentArtifact?
    let xml: BusinessDocumentArtifact?
}

struct GenerateInternalTicketRequest: Encodable, Equatable, Sendable {
    let note: String?
    init(note: String? = nil) { self.note = note }
}

struct RegisterPhysicalSaleNoteRequest: Encodable, Equatable, Sendable {
    let physicalNumber: String
    let note: String?
    init(physicalNumber: String, note: String? = nil) {
        self.physicalNumber = physicalNumber
        self.note = note
    }
}

struct IssueBusinessElectronicDocumentRequest: Encodable, Equatable, Sendable {
    let signatureId: String?
    let queryAuthorizationImmediately: Bool
    let numericCode: String?
    let documentId: String?
    let issuedAt: String?
    let issuedDate: String?

    init(signatureId: String? = nil, queryAuthorizationImmediately: Bool = true, numericCode: String? = nil, documentId: String? = nil, issuedAt: String? = nil, issuedDate: String? = nil) {
        self.signatureId = signatureId?.trimmedNilIfBlank
        self.queryAuthorizationImmediately = queryAuthorizationImmediately
        self.numericCode = numericCode?.trimmedNilIfBlank
        self.documentId = documentId?.trimmedNilIfBlank
        self.issuedAt = issuedAt?.trimmedNilIfBlank
        self.issuedDate = issuedDate?.trimmedNilIfBlank
    }
}

struct RetryBusinessElectronicInvoiceReceptionRequest: Encodable, Equatable, Sendable {
    let queryAuthorizationImmediately: Bool
    let reason: String?
    init(queryAuthorizationImmediately: Bool = true, reason: String? = nil) {
        self.queryAuthorizationImmediately = queryAuthorizationImmediately
        self.reason = reason?.trimmedNilIfBlank
    }
}

struct RetryBusinessElectronicInvoiceAuthorizationRequest: Encodable, Equatable, Sendable {
    let reason: String?
    init(reason: String? = nil) {
        self.reason = reason?.trimmedNilIfBlank
    }
}

struct RegenerateBusinessElectronicDocumentRideRequest: Encodable, Equatable, Sendable {
    let reason: String?
    let forceRegenerateRide: Bool
    init(reason: String? = nil, forceRegenerateRide: Bool = true) {
        self.reason = reason?.trimmedNilIfBlank
        self.forceRegenerateRide = forceRegenerateRide
    }
}

struct BusinessElectronicDocumentActionResponse: Decodable, Equatable, Sendable {
    let documentId: String
    let accepted: Bool
    let status: String?
    let message: String
    let requestedAt: Date?
    let replayed: Bool

    private enum CodingKeys: String, CodingKey {
        case documentId, id, accepted, status, message, requestedAt, replayed, idempotencyReplayed
    }

    init(documentId: String, accepted: Bool = true, status: String? = nil, message: String, requestedAt: Date? = nil, replayed: Bool = false) {
        self.documentId = documentId
        self.accepted = accepted
        self.status = status
        self.message = message
        self.requestedAt = requestedAt
        self.replayed = replayed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        documentId = try c.decodeFirstStringIfPresent(for: [.documentId, .id]) ?? ""
        accepted = try c.decodeIfPresent(Bool.self, forKey: .accepted) ?? true
        status = try c.decodeFirstStringIfPresent(for: [.status])
        message = BusinessDocumentTextSanitizer.sanitizedMessage(try c.decodeFirstStringIfPresent(for: [.message])) ?? "Acción solicitada correctamente."
        requestedAt = try c.decodeFirstDateIfPresent(for: [.requestedAt])
        let replayedValue = try c.decodeIfPresent(Bool.self, forKey: .replayed)
        let idempotencyReplayedValue = try c.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
        replayed = replayedValue ?? idempotencyReplayedValue ?? false
    }

    var idempotencyReplayed: Bool { replayed }
}

struct BusinessElectronicDocumentIssueResponse: Decodable, Equatable, Sendable {
    let document: BusinessDocument
    let authorized: Bool
    let stoppedBeforeSri: Bool
    let receptionStatus: String?
    let authorizationStatus: String?
    let replayed: Bool

    init(document: BusinessDocument, authorized: Bool, stoppedBeforeSri: Bool, receptionStatus: String? = nil, authorizationStatus: String? = nil, replayed: Bool = false) {
        self.document = document
        self.authorized = authorized
        self.stoppedBeforeSri = stoppedBeforeSri
        self.receptionStatus = receptionStatus
        self.authorizationStatus = authorizationStatus
        self.replayed = replayed
    }

    var idempotencyReplayed: Bool { replayed }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [Key]) throws -> String {
        for key in keys {
            if let value = try decodeFirstStringIfPresent(for: [key]) {
                return value
            }
        }
        throw DecodingError.keyNotFound(keys.first!, DecodingError.Context(codingPath: codingPath, debugDescription: "Missing required string value."))
    }

    func decodeFirstStringIfPresent(for keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
            if let intValue = try decodeIfPresent(Int.self, forKey: key) { return String(intValue) }
            if let int64Value = try decodeIfPresent(Int64.self, forKey: key) { return String(int64Value) }
            if let doubleValue = try decodeIfPresent(Double.self, forKey: key) { return String(doubleValue) }
        }
        return nil
    }

    func decodeFirstDateIfPresent(for keys: [Key]) throws -> Date? {
        for key in keys {
            if let value = try decodeIfPresent(Date.self, forKey: key) {
                return value
            }
        }
        return nil
    }
}

private extension Array where Element == BusinessElectronicDocumentAction {
    var uniqueByPublicRawValue: [BusinessElectronicDocumentAction] {
        var seen = Set<String>()
        return filter { action in
            let key = action.publicRawValue
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

private extension String {
    var trimmedNilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
