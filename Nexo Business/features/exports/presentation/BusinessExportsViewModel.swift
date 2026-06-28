//
//  BusinessExportsViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 23/6/26.
//

import Foundation
import Observation

@MainActor
@Observable
class BusinessExportsViewModel {
    private(set) var state: AsyncViewState<[BusinessExportDescriptor]> = .idle
    private(set) var exports: [BusinessExportDescriptor] = []
    private(set) var summary: BusinessOperationalSummaryResponse?
    private(set) var downloadedFile: BusinessExportDownloadedFile?
    private(set) var isLoading = false
    private(set) var isLoadingSummary = false
    private(set) var isGenerating = false

    var businessDate = Date()
    var selectedPreset: BusinessExportPeriodPreset = .thisMonth
    var selectedChart: BusinessExportChartKind = .salesByDay
    var customStartDate = Date()
    var customEndDate = Date()
    var errorMessage: String?
    var successMessage: String?

    let organizationId: String
    let branchId: String
    let effectivePermissions: Set<String>

    private let exportsRepository: BusinessExportsRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date

    init(
        organizationId: String,
        branchId: String,
        effectivePermissions: Set<String>,
        exportsRepository: BusinessExportsRepository,
        calendar: Calendar = BusinessExportsViewModel.makeBusinessCalendar(),
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.effectivePermissions = effectivePermissions
        self.exportsRepository = exportsRepository
        self.calendar = calendar
        self.nowProvider = nowProvider

        let now = nowProvider()
        self.businessDate = now
        self.customStartDate = now
        self.customEndDate = now
    }

    var canExport: Bool {
        hasPermission(Self.exportPermissions)
    }

    var selectedBusinessDateString: String {
        Self.businessDateFormatter.string(from: businessDate)
    }

    var periodBounds: (from: Date, to: Date) {
        let today = calendar.startOfDay(for: nowProvider())
        switch selectedPreset {
        case .today:
            return (today, today)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return (yesterday, yesterday)
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            return (start, today)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return (start, today)
        case .thisFortnight:
            let components = calendar.dateComponents([.year, .month, .day], from: today)
            let startDay = (components.day ?? 1) <= 15 ? 1 : 16
            let start = calendar.date(from: DateComponents(year: components.year, month: components.month, day: startDay)) ?? today
            return (start, today)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: today)?.start ?? today
            return (start, today)
        case .lastMonth:
            let currentMonth = calendar.dateInterval(of: .month, for: today)
            let start = currentMonth.flatMap { calendar.date(byAdding: .month, value: -1, to: $0.start) } ?? today
            let end = currentMonth.flatMap { calendar.date(byAdding: .day, value: -1, to: $0.start) } ?? today
            return (start, end)
        case .custom:
            return (calendar.startOfDay(for: customStartDate), calendar.startOfDay(for: customEndDate))
        }
    }

    var periodFromString: String {
        Self.businessDateFormatter.string(from: periodBounds.from)
    }

    var periodToString: String {
        Self.businessDateFormatter.string(from: periodBounds.to)
    }

    var periodLabel: String {
        selectedPreset.displayName
    }

    var periodDisplayText: String {
        if periodFromString == periodToString {
            return periodFromString
        }
        return "\(periodFromString) → \(periodToString)"
    }

    var validationMessage: String? {
        let today = calendar.startOfDay(for: nowProvider())
        let range = periodBounds
        if range.from > range.to {
            return "La fecha de inicio no puede ser mayor que la fecha de fin."
        }
        if range.from > today || range.to > today {
            return "No puedes generar informes de fechas futuras."
        }
        let days = calendar.dateComponents([.day], from: range.from, to: range.to).day ?? 0
        if days > 61 {
            return "El informe inteligente v1 permite máximo 62 días por exportación."
        }
        return nil
    }

    var canGenerateOperationalReport: Bool {
        canExport && validationMessage == nil && !isLoading && !isLoadingSummary && !isGenerating && (summary?.hasData ?? false)
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        guard canExport else {
            exports = []
            state = .failed("No tienes permiso para exportar la operación diaria.")
            errorMessage = "No tienes permiso para exportar la operación diaria."
            return
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        state = .loading

        defer { isLoading = false }

        do {
            let response = try await exportsRepository.catalog(organizationId: organizationId)
            exports = response.exports
            state = .loaded(response.exports)
            if response.exports.isEmpty {
                successMessage = "No hay exportaciones disponibles todavía."
            }
            await loadSummary()
        } catch let error as APIError {
            let message = humanMessage(for: error)
            errorMessage = message
            state = .failed(message)
        } catch {
            errorMessage = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }

    func loadSummary() async {
        guard canExport else { return }
        guard !organizationId.isEmpty, !branchId.isEmpty else {
            errorMessage = "Falta negocio o sucursal activa. Actualiza el contexto."
            return
        }
        if let validationMessage {
            summary = nil
            errorMessage = validationMessage
            return
        }
        guard !isLoadingSummary else { return }
        isLoadingSummary = true
        errorMessage = nil
        successMessage = nil
        downloadedFile = nil

        defer { isLoadingSummary = false }

        do {
            summary = try await exportsRepository.operationalSummary(
                organizationId: organizationId,
                branchId: branchId,
                from: periodFromString,
                to: periodToString,
                label: periodLabel
            )
            if summary?.hasData == false {
                successMessage = "No hay movimientos en este período. Cambia las fechas para generar un informe con datos."
            }
        } catch let error as APIError {
            errorMessage = humanMessage(for: error)
            summary = nil
        } catch {
            errorMessage = error.localizedDescription
            summary = nil
        }
    }

    func generateAndDownloadOperationalZip() async {
        guard canExport else {
            errorMessage = "No tienes permiso para generar o descargar exportaciones."
            return
        }

        guard !organizationId.isEmpty, !branchId.isEmpty else {
            errorMessage = "Falta negocio o sucursal activa. Actualiza el contexto."
            return
        }

        if let validationMessage {
            errorMessage = validationMessage
            return
        }

        guard summary?.hasData == true else {
            errorMessage = "No hay movimientos en este período. Cambia las fechas para generar un informe con datos."
            return
        }

        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        successMessage = nil
        downloadedFile = nil

        defer { isGenerating = false }

        do {
            let file = try await exportsRepository.downloadOperationalZip(
                organizationId: organizationId,
                branchId: branchId,
                from: periodFromString,
                to: periodToString,
                label: periodLabel
            )
            downloadedFile = file
            successMessage = "Informe listo: \(file.fileName)."
        } catch let error as APIError {
            errorMessage = humanMessage(for: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearGeneratedReport() {
        downloadedFile = nil
        successMessage = nil
    }

    func generateAndDownloadDailyZip() async {
        await generateAndDownloadOperationalZip()
    }

    func clearDownloadedFile() {
        downloadedFile = nil
    }

    func sizeText(for export: BusinessExportDescriptor) -> String? {
        guard let sizeBytes = export.sizeBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }

    func chartPoints(for kind: BusinessExportChartKind) -> [BusinessExportChartPoint] {
        guard let summary else { return [] }
        switch kind {
        case .salesByDay:
            return summary.charts.salesByDay.map {
                BusinessExportChartPoint(
                    id: $0.date,
                    title: $0.label,
                    subtitle: "\($0.saleCount) ventas",
                    value: $0.grandTotal.doubleValue,
                    valueText: $0.grandTotal.displayText
                )
            }
        case .topItems:
            return summary.charts.topItems.map {
                BusinessExportChartPoint(
                    id: $0.id,
                    title: $0.name,
                    subtitle: "Cantidad \($0.quantity.cleanQuantityText)",
                    value: $0.lineTotal.doubleValue,
                    valueText: $0.lineTotal.displayText
                )
            }
        case .paymentStatuses:
            return summary.charts.paymentStatuses.map {
                BusinessExportChartPoint(
                    id: $0.status,
                    title: Self.humanStatus($0.status),
                    subtitle: nil,
                    value: Double($0.count),
                    valueText: "\($0.count)"
                )
            }
        case .documentStatuses:
            return summary.charts.documentStatuses.map {
                BusinessExportChartPoint(
                    id: $0.status,
                    title: Self.humanStatus($0.status),
                    subtitle: nil,
                    value: Double($0.count),
                    valueText: "\($0.count)"
                )
            }
        }
    }

    private func humanMessage(for error: APIError) -> String {
        switch error.statusCode ?? 0 {
        case 400, 422:
            return error.userMessage
        case 401:
            return "Tu sesión caducó. Vuelve a iniciar sesión."
        case 403:
            return "No tienes permiso para exportar esta información."
        case 404:
            return "La exportación aún no está disponible."
        case 409:
            return "La exportación ya fue procesada. Actualiza e intenta de nuevo."
        case 500...599:
            return "El servidor no respondió correctamente. Intenta de nuevo."
        default:
            return error.userMessage
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }

    private static func humanStatus(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static let exportPermissions = [
        "business.exports.view",
        "business.exports.generate",
        "business.exports.download",
        "exports.view",
        "exports.generate",
        "exports.download",
        "reports.export",
        "reports.dashboard.view",
        "reports.sales.view",
        "reports.cash.view",
        "reports.documents.view"
    ]

    nonisolated private static func makeBusinessCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_EC")
        calendar.timeZone = TimeZone(identifier: "America/Guayaquil") ?? .current
        calendar.firstWeekday = 2 // lunes
        return calendar
    }

    private static let businessDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Guayaquil")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

class PreviewBusinessExportsRepository: BusinessExportsRepository, @unchecked Sendable {
    func downloadAccountantPackDraftZip(
        organizationId: String,
        branchId: String?,
        activityId: String?,
        year: Int,
        month: Int
    ) async throws -> BusinessExportDownloadedFile {
        let safeMonth = String(format: "%02d", month)
        let fileName = "nexo_paquete_contador_preview_\(year)_\(safeMonth).zip"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try Data("preview accountant pack \(year)-\(safeMonth)".utf8).write(to: url)

        return BusinessExportDownloadedFile(
            localURL: url,
            fileName: fileName,
            contentType: "application/zip",
            sizeBytes: 7
        )
    }
    
    func catalog(organizationId: String) async throws -> BusinessExportsCatalogResponse {
        BusinessExportsCatalogResponse(
            exports: [
                BusinessExportDescriptor(
                    id: "operational_intelligent_21d2_21f4",
                    kind: BusinessExportKind.operationalIntelligent.rawValue,
                    version: "21D.2-21F.4",
                    title: "Informe operativo inteligente",
                    description: "PDF ejecutivo, HTML con diagramas, resumen JSON y CSV por período.",
                    contentType: "application/zip",
                    fileName: "nexo_informe_operativo_preview.zip",
                    sizeBytes: 16384
                )
            ]
        )
    }

    func operationalSummary(
        organizationId: String,
        branchId: String?,
        from: String,
        to: String,
        label: String?
    ) async throws -> BusinessOperationalSummaryResponse {
        BusinessOperationalSummaryResponse.preview(from: from, to: to, label: label ?? "Este mes")
    }

    func downloadOperationalZip(
        organizationId: String,
        branchId: String?,
        from: String,
        to: String,
        label: String?
    ) async throws -> BusinessExportDownloadedFile {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nexo_informe_operativo_preview.zip")
        try Data("preview".utf8).write(to: url)
        return BusinessExportDownloadedFile(
            localURL: url,
            fileName: url.lastPathComponent,
            contentType: "application/zip",
            sizeBytes: 7
        )
    }

    func dailyMetadata(
        organizationId: String,
        branchId: String?,
        businessDate: String?
    ) async throws -> BusinessExportGenerateResponse {
        throw APIError.transport("Vista previa sin exportación diaria legacy.")
    }

    func generateDaily(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessExportGenerateRequest
    ) async throws -> BusinessExportGenerateResponse {
        throw APIError.transport("Vista previa sin exportación diaria legacy.")
    }

    func downloadDailyZip(
        organizationId: String,
        branchId: String?,
        businessDate: String?
    ) async throws -> BusinessExportDownloadedFile {
        try await downloadOperationalZip(
            organizationId: organizationId,
            branchId: branchId,
            from: businessDate ?? "2026-06-23",
            to: businessDate ?? "2026-06-23",
            label: "Hoy"
        )
    }
}

private extension BusinessOperationalSummaryResponse {
    static func preview(from: String, to: String, label: String) -> BusinessOperationalSummaryResponse {
        BusinessOperationalSummaryResponse(
            period: BusinessOperationalPeriod(
                from: from,
                to: to,
                label: label,
                timezone: "America/Guayaquil",
                isSingleDay: from == to,
                isPartialMonth: true,
                daysInPeriod: 23,
                daysWithData: 4
            ),
            hasData: true,
            totals: BusinessOperationalTotals(
                saleCount: 18,
                closedSaleCount: 16,
                canceledSaleCount: 1,
                itemCount: 42,
                grandTotal: BusinessExportMoney(amount: "486.50", currency: "USD"),
                paidTotal: BusinessExportMoney(amount: "420.00", currency: "USD"),
                receivableTotal: BusinessExportMoney(amount: "66.50", currency: "USD"),
                pendingReceivables: BusinessExportMoney(amount: "66.50", currency: "USD"),
                pendingReceivablesCount: 2,
                cashInTotal: BusinessExportMoney(amount: "260.00", currency: "USD"),
                cashOutTotal: BusinessExportMoney(amount: "15.00", currency: "USD"),
                netCashMovement: BusinessExportMoney(amount: "245.00", currency: "USD"),
                cashDifferenceTotal: BusinessExportMoney(amount: "0.00", currency: "USD"),
                documentCount: 14,
                authorizedDocumentCount: 13,
                pendingDocumentCount: 1,
                taxTotal: BusinessExportMoney(amount: "63.46", currency: "USD")
            ),
            comparisons: [
                BusinessOperationalComparison(
                    label: "vs período anterior equivalente",
                    from: "2026-05-01",
                    to: "2026-05-23",
                    currentGrandTotal: BusinessExportMoney(amount: "486.50", currency: "USD"),
                    previousGrandTotal: BusinessExportMoney(amount: "410.00", currency: "USD"),
                    grandTotalDelta: BusinessExportMoney(amount: "76.50", currency: "USD"),
                    grandTotalDeltaPercent: "18.66",
                    currentSaleCount: 18,
                    previousSaleCount: 15,
                    saleCountDelta: 3,
                    currentPaidTotal: BusinessExportMoney(amount: "420.00", currency: "USD"),
                    previousPaidTotal: BusinessExportMoney(amount: "380.00", currency: "USD"),
                    paidTotalDelta: BusinessExportMoney(amount: "40.00", currency: "USD")
                )
            ],
            charts: BusinessOperationalCharts(
                salesByDay: [
                    BusinessOperationalDailyPoint(date: "2026-06-01", label: "1/6", saleCount: 4, grandTotal: BusinessExportMoney(amount: "98.00", currency: "USD"), paidTotal: BusinessExportMoney(amount: "98.00", currency: "USD")),
                    BusinessOperationalDailyPoint(date: "2026-06-08", label: "8/6", saleCount: 5, grandTotal: BusinessExportMoney(amount: "124.50", currency: "USD"), paidTotal: BusinessExportMoney(amount: "90.00", currency: "USD")),
                    BusinessOperationalDailyPoint(date: "2026-06-15", label: "15/6", saleCount: 6, grandTotal: BusinessExportMoney(amount: "180.00", currency: "USD"), paidTotal: BusinessExportMoney(amount: "160.00", currency: "USD")),
                    BusinessOperationalDailyPoint(date: "2026-06-23", label: "23/6", saleCount: 3, grandTotal: BusinessExportMoney(amount: "84.00", currency: "USD"), paidTotal: BusinessExportMoney(amount: "72.00", currency: "USD"))
                ],
                topItems: [
                    BusinessOperationalTopItem(catalogItemId: "cuy", name: "Cuy entero", quantity: "6", netTotal: BusinessExportMoney(amount: "144.00", currency: "USD"), lineTotal: BusinessExportMoney(amount: "144.00", currency: "USD")),
                    BusinessOperationalTopItem(catalogItemId: "borrego", name: "Borrego asado", quantity: "10", netTotal: BusinessExportMoney(amount: "100.00", currency: "USD"), lineTotal: BusinessExportMoney(amount: "100.00", currency: "USD")),
                    BusinessOperationalTopItem(catalogItemId: "jugo", name: "Jarra de jugo", quantity: "8", netTotal: BusinessExportMoney(amount: "24.00", currency: "USD"), lineTotal: BusinessExportMoney(amount: "24.00", currency: "USD"))
                ],
                paymentStatuses: [
                    BusinessOperationalStatusCount(status: "paid", count: 16),
                    BusinessOperationalStatusCount(status: "partially_paid", count: 2)
                ],
                documentStatuses: [
                    BusinessOperationalStatusCount(status: "authorized", count: 13),
                    BusinessOperationalStatusCount(status: "pending", count: 1)
                ],
                cashMovementTypes: []
            ),
            alerts: [
                BusinessOperationalAlert(code: "documents_not_authorized", severity: "warning", message: "Hay documentos pendientes de revisar.", actionHint: "Revisar documentos antes de enviar al contador.")
            ],
            availableExports: ["pdf", "html", "json", "csv", "zip"],
            recommendedSummary: [
                "Ventas registradas: 18; total vendido: 486.50 USD.",
                "Documentos: 13/14 autorizados.",
                "Alertas operativas: 1. Revisar antes de enviar al contador."
            ]
        )
    }
}
