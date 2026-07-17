//
//  BusinessProcurementAttachmentsViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 16/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessProcurementAttachmentsViewModelTests: XCTestCase {
    func testMutationPermissionsAreExactAndSupplierManagementStaysUnavailable() {
        let client = QueuedProcurementAttachmentAPIClient()
        let readOnly = makeViewModel(
            sourceType: .supplierDocument,
            permissions: [BusinessProcurementPermission.supplierDocumentsView],
            client: client
        )
        XCTAssertTrue(readOnly.canViewEvidence)
        XCTAssertFalse(readOnly.canUploadEvidence)
        XCTAssertFalse(readOnly.canDeleteEvidence)

        let uploader = makeViewModel(
            sourceType: .supplierDocument,
            permissions: [
                BusinessProcurementPermission.supplierDocumentsView,
                BusinessProcurementPermission.attachmentsUpload,
            ],
            client: client
        )
        XCTAssertTrue(uploader.canUploadEvidence)
        XCTAssertFalse(uploader.canDeleteEvidence)

        let deleter = makeViewModel(
            sourceType: .supplierDocument,
            permissions: [
                BusinessProcurementPermission.supplierDocumentsView,
                BusinessProcurementPermission.attachmentsDelete,
            ],
            client: client
        )
        XCTAssertFalse(deleter.canUploadEvidence)
        XCTAssertTrue(deleter.canDeleteEvidence)

        let supplier = makeViewModel(
            sourceType: .supplier,
            permissions: [
                BusinessProcurementPermission.suppliersView,
                BusinessProcurementPermission.suppliersSensitiveView,
                BusinessProcurementPermission.attachmentsUpload,
                BusinessProcurementPermission.attachmentsDelete,
            ],
            client: client
        )
        XCTAssertFalse(supplier.supportsAttachmentMutations)
        XCTAssertFalse(supplier.canUploadEvidence)
        XCTAssertFalse(supplier.canDeleteEvidence)
    }

    func testSourceTypesRequireExactViewAndSensitivePermissions() {
        let client = QueuedProcurementAttachmentAPIClient()

        XCTAssertEqual(
            makeViewModel(sourceType: .supplier, client: client).requiredViewPermissions,
            [
                BusinessProcurementPermission.suppliersView,
                BusinessProcurementPermission.suppliersSensitiveView,
            ]
        )
        XCTAssertEqual(
            makeViewModel(sourceType: .purchaseOrder, client: client).requiredViewPermissions,
            [
                BusinessProcurementPermission.purchaseOrdersView,
                BusinessProcurementPermission.purchaseOrdersCostView,
            ]
        )
        XCTAssertEqual(
            makeViewModel(sourceType: .purchaseReceipt, client: client).requiredViewPermissions,
            [BusinessProcurementPermission.purchaseReceiptsView]
        )
        XCTAssertEqual(
            makeViewModel(sourceType: .supplierDocument, client: client).requiredViewPermissions,
            [BusinessProcurementPermission.supplierDocumentsView]
        )
        XCTAssertEqual(
            makeViewModel(sourceType: .supplierPayment, client: client).requiredViewPermissions,
            [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsSensitiveView,
            ]
        )
    }

    func testDownloadRequiresActiveModuleAndAllSourcePermissionsBeforeNetwork() async {
        let client = QueuedProcurementAttachmentAPIClient(
            dataResponses: [Self.pdfResponse]
        )
        let inactive = makeViewModel(
            sourceType: .supplierDocument,
            activeModules: [],
            permissions: [BusinessProcurementPermission.supplierDocumentsView],
            client: client
        )
        let inactiveItem = try! XCTUnwrap(inactive.evidenceItems.first)

        await inactive.download(inactiveItem)

        XCTAssertEqual(
            inactive.errorMessage,
            "El módulo Compras no está activo para esta organización."
        )
        XCTAssertTrue(client.capturedDataRequests.isEmpty)

        let protectedPayment = makeViewModel(
            sourceType: .supplierPayment,
            permissions: [BusinessProcurementPermission.supplierPaymentsView],
            client: client
        )
        let protectedItem = try! XCTUnwrap(protectedPayment.evidenceItems.first)

        await protectedPayment.download(protectedItem)

        XCTAssertFalse(protectedPayment.canViewEvidence)
        XCTAssertEqual(
            protectedPayment.errorMessage,
            "No tienes permisos suficientes para consultar la evidencia de este recurso."
        )
        XCTAssertTrue(client.capturedDataRequests.isEmpty)
    }

    func testDownloadUsesKnownAttachmentRouteAndKeepsVerifiedLocalFile() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nexo-attachment-view-model-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let client = QueuedProcurementAttachmentAPIClient(
            dataResponses: [Self.pdfResponse]
        )
        let viewModel = makeViewModel(
            sourceType: .supplierDocument,
            attachmentIds: ["patt_1"],
            permissions: [BusinessProcurementPermission.supplierDocumentsView],
            client: client,
            downloadDirectory: tempDirectory
        )
        let item = try XCTUnwrap(viewModel.evidenceItems.first)

        await viewModel.download(item)

        XCTAssertEqual(client.capturedDataRequests.count, 1)
        let request = try XCTUnwrap(client.capturedDataRequests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, BusinessProcurementRoutes.attachment("patt_1"))
        XCTAssertEqual(request.headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertTrue(request.queryItems.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.lastFailedAttachmentId)
        XCTAssertEqual(viewModel.infoMessage, "Evidencia 1 está lista para compartir.")

        let file = try XCTUnwrap(viewModel.downloadedFile(for: item))
        XCTAssertEqual(file.fileName, "factura.pdf")
        XCTAssertEqual(file.contentType, "application/pdf")
        XCTAssertEqual(file.sizeBytes, Self.pdfResponse.data.count)
        XCTAssertEqual(try Data(contentsOf: file.localURL), Self.pdfResponse.data)
    }

    func testUnsafeAndDuplicateReferencesAreOmittedWithoutNetworkAccess() async throws {
        let client = QueuedProcurementAttachmentAPIClient(
            dataResponses: [Self.pdfResponse]
        )
        let viewModel = makeViewModel(
            sourceType: .supplierDocument,
            attachmentIds: [
                " patt_1 ",
                "patt_1",
                "../secret",
                "https://example.invalid/file",
                "",
                "safe-id_2",
            ],
            permissions: [BusinessProcurementPermission.supplierDocumentsView],
            client: client
        )

        XCTAssertEqual(viewModel.evidenceItems.map(\.position), [1, 2])
        XCTAssertEqual(viewModel.evidenceItems.map(\.displayName), ["Evidencia 1", "Evidencia 2"])
        XCTAssertEqual(viewModel.ignoredReferenceCount, 4)
        XCTAssertEqual(
            viewModel.integrityWarning,
            "Se omitieron 4 referencias de evidencia no válidas."
        )
        XCTAssertTrue(client.capturedDataRequests.isEmpty)
    }

    func testUnsupportedOrOversizedServerFileIsNotExposedForSharing() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nexo-attachment-invalid-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let unsupported = APIDataResponse(
            data: Data("<html>not evidence</html>".utf8),
            statusCode: 200,
            headers: [
                "Content-Type": "text/html",
                "Content-Disposition": "attachment; filename=\"evidence.html\"",
            ]
        )
        let client = QueuedProcurementAttachmentAPIClient(
            dataResponses: [unsupported]
        )
        let viewModel = makeViewModel(
            sourceType: .supplierDocument,
            permissions: [BusinessProcurementPermission.supplierDocumentsView],
            client: client,
            downloadDirectory: tempDirectory
        )
        let item = try XCTUnwrap(viewModel.evidenceItems.first)

        await viewModel.download(item)

        XCTAssertEqual(client.capturedDataRequests.count, 1)
        XCTAssertNil(viewModel.downloadedFile(for: item))
        XCTAssertEqual(
            viewModel.errorMessage,
            "El servidor no devolvió una evidencia PDF o imagen válida."
        )
        XCTAssertEqual(viewModel.lastFailedAttachmentId, "patt_1")
    }

    func testConcurrentDownloadAttemptsIssueOneBinaryRequest() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nexo-attachment-concurrency-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let client = QueuedProcurementAttachmentAPIClient(
            dataResponses: [Self.pdfResponse],
            delayNanoseconds: 20_000_000
        )
        let viewModel = makeViewModel(
            sourceType: .supplierDocument,
            permissions: [BusinessProcurementPermission.supplierDocumentsView],
            client: client,
            downloadDirectory: tempDirectory
        )
        let item = try XCTUnwrap(viewModel.evidenceItems.first)

        let firstDownload = Task { await viewModel.download(item) }
        while !viewModel.isDownloading(item) {
            await Task.yield()
        }
        await viewModel.download(item)
        await firstDownload.value

        XCTAssertEqual(client.capturedDataRequests.count, 1)
        XCTAssertNotNil(viewModel.downloadedFile(for: item))
        XCTAssertFalse(viewModel.isDownloading)
    }

    func testSignatureMismatchIsRejectedBeforeSourcePreflight() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "nexo-attachment-upload-validation-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let fakePDF = tempDirectory.appendingPathComponent("evidence.pdf")
        try Data("not a pdf".utf8).write(to: fakePDF)
        let client = QueuedProcurementAttachmentAPIClient()
        let viewModel = makeViewModel(
            sourceType: .supplierDocument,
            permissions: [
                BusinessProcurementPermission.supplierDocumentsView,
                BusinessProcurementPermission.attachmentsUpload,
            ],
            client: client
        )

        await viewModel.importAndUpload(from: fakePDF)

        XCTAssertNil(viewModel.pendingUpload)
        XCTAssertEqual(
            viewModel.errorMessage,
            "El archivo no es una evidencia válida o supera el límite de 10 MB."
        )
        XCTAssertTrue(client.capturedRequests.isEmpty)
    }

    func testFailedUploadPreflightRetainsTheSameCandidateAndIdempotencyKey() async {
        let client = QueuedProcurementAttachmentAPIClient()
        let viewModel = makeViewModel(
            sourceType: .supplierDocument,
            permissions: [
                BusinessProcurementPermission.supplierDocumentsView,
                BusinessProcurementPermission.attachmentsUpload,
            ],
            client: client
        )
        let key = IdempotencyKey(rawValue: "attachment-upload-fixed")
        viewModel.prepareUploadForTesting(
            fileName: "evidence.pdf",
            mediaType: .pdf,
            data: Data("%PDF-1.7 evidence".utf8),
            idempotencyKey: key
        )

        await viewModel.uploadPendingFile()

        XCTAssertEqual(viewModel.pendingUpload?.idempotencyKey, key)
        XCTAssertNil(viewModel.pendingUpload?.expectedSourceVersion)
        XCTAssertEqual(client.capturedRequests.count, 1)
        XCTAssertEqual(client.capturedRequests.first?.method, .get)
        XCTAssertEqual(
            client.capturedRequests.first?.path,
            BusinessProcurementRoutes.supplierDocument("source_1")
        )
    }

    func testUploadUsesAuthoritativeVersionStableKeyAndPostflightSourceState() async throws {
        let client = QueuedProcurementAttachmentAPIClient(
            responseSteps: [
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: [], version: 7).utf8)),
                .response(Data(Self.attachmentEnvelopeJSON.utf8)),
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: ["att_new"], version: 8).utf8)),
            ]
        )
        let viewModel = makeViewModel(
            sourceType: .purchaseReceipt,
            attachmentIds: [],
            permissions: [
                BusinessProcurementPermission.purchaseReceiptsView,
                BusinessProcurementPermission.attachmentsUpload,
            ],
            client: client
        )
        let key = IdempotencyKey(rawValue: "attachment-upload-fixed")
        viewModel.prepareUploadForTesting(
            fileName: "evidence.pdf",
            mediaType: .pdf,
            data: Data("%PDF-1.7 evidence".utf8),
            idempotencyKey: key
        )

        await viewModel.uploadPendingFile()

        XCTAssertEqual(client.capturedRequests.count, 3)
        XCTAssertEqual(client.capturedRequests[0].method, .get)
        XCTAssertEqual(client.capturedRequests[0].path, BusinessProcurementRoutes.purchaseReceipt("source_1"))
        XCTAssertEqual(client.capturedRequests[1].method, .post)
        XCTAssertEqual(client.capturedRequests[1].path, BusinessProcurementRoutes.attachments)
        XCTAssertEqual(client.capturedRequests[1].headers[BusinessHeaders.organizationId], "org_1")
        XCTAssertEqual(client.capturedRequests[1].headers[BusinessHeaders.idempotencyKey], key.rawValue)
        let multipart = try XCTUnwrap(client.capturedRequests[1].body)
        let multipartText = String(decoding: multipart, as: UTF8.self)
        XCTAssertTrue(multipartText.contains("name=\"sourceType\"\r\n\r\nPURCHASE_RECEIPT"))
        XCTAssertTrue(multipartText.contains("name=\"sourceId\"\r\n\r\nsource_1"))
        XCTAssertTrue(multipartText.contains("name=\"expectedSourceVersion\"\r\n\r\n7"))
        XCTAssertEqual(viewModel.evidenceItems.map(\.id), ["att_new"])
        XCTAssertEqual(viewModel.sourceVersion, 8)
        XCTAssertNil(viewModel.pendingUpload)
        XCTAssertFalse(viewModel.needsSourceRefresh)
        XCTAssertEqual(viewModel.infoMessage, "La evidencia se adjuntó y quedó ligada al recurso.")
    }

    func testUploadPostflightMustProveReturnedAttachmentMembership() async {
        let client = QueuedProcurementAttachmentAPIClient(
            responseSteps: [
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: [], version: 7).utf8)),
                .response(Data(Self.attachmentEnvelopeJSON.utf8)),
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: [], version: 8).utf8)),
            ]
        )
        let viewModel = makeViewModel(
            sourceType: .purchaseReceipt,
            attachmentIds: [],
            permissions: [
                BusinessProcurementPermission.purchaseReceiptsView,
                BusinessProcurementPermission.attachmentsUpload,
            ],
            client: client
        )
        viewModel.prepareUploadForTesting(
            fileName: "evidence.pdf",
            mediaType: .pdf,
            data: Data("%PDF-1.7 evidence".utf8)
        )

        await viewModel.uploadPendingFile()

        XCTAssertTrue(viewModel.needsSourceRefresh)
        XCTAssertNil(viewModel.sourceVersion)
        XCTAssertTrue(viewModel.evidenceItems.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(
            viewModel.infoMessage,
            "La operación terminó, pero debes actualizar el recurso antes de otra carga o eliminación."
        )
    }

    func testUploadConflictRefreshesAndDiscardsStaleAttempt() async {
        let conflict = APIError.server(
            statusCode: 409,
            code: "business_revision_conflict",
            message: "conflict",
            requestId: "req_conflict"
        )
        let client = QueuedProcurementAttachmentAPIClient(
            responseSteps: [
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: [], version: 7).utf8)),
                .failure(conflict),
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: ["att_other"], version: 8).utf8)),
            ]
        )
        let viewModel = makeViewModel(
            sourceType: .purchaseReceipt,
            attachmentIds: [],
            permissions: [
                BusinessProcurementPermission.purchaseReceiptsView,
                BusinessProcurementPermission.attachmentsUpload,
            ],
            client: client
        )
        viewModel.prepareUploadForTesting(
            fileName: "evidence.pdf",
            mediaType: .pdf,
            data: Data("%PDF-1.7 evidence".utf8)
        )

        await viewModel.uploadPendingFile()

        XCTAssertNil(viewModel.pendingUpload)
        XCTAssertEqual(viewModel.sourceVersion, 8)
        XCTAssertEqual(viewModel.evidenceItems.map(\.id), ["att_other"])
        XCTAssertFalse(viewModel.needsSourceRefresh)
        XCTAssertTrue(viewModel.errorMessage?.contains("Selecciona el archivo nuevamente") == true)
    }

    func testDeleteUsesPreflightVersionAndRequiresPostflightAbsence() async throws {
        let client = QueuedProcurementAttachmentAPIClient(
            responseSteps: [
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: ["att_old"], version: 9).utf8)),
                .response(Data("{}".utf8)),
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: [], version: 10).utf8)),
            ]
        )
        let viewModel = makeViewModel(
            sourceType: .purchaseReceipt,
            attachmentIds: ["att_old"],
            permissions: [
                BusinessProcurementPermission.purchaseReceiptsView,
                BusinessProcurementPermission.attachmentsDelete,
            ],
            client: client
        )
        let item = try XCTUnwrap(viewModel.evidenceItems.first)

        await viewModel.delete(item)

        XCTAssertEqual(client.capturedRequests.count, 3)
        XCTAssertEqual(client.capturedRequests[1].method, .delete)
        XCTAssertEqual(client.capturedRequests[1].path, BusinessProcurementRoutes.attachment("att_old"))
        XCTAssertEqual(
            client.capturedRequests[1].queryDictionary["expectedSourceVersion"],
            "9"
        )
        XCTAssertTrue(viewModel.evidenceItems.isEmpty)
        XCTAssertEqual(viewModel.sourceVersion, 10)
        XCTAssertFalse(viewModel.needsSourceRefresh)
        XCTAssertEqual(viewModel.infoMessage, "La evidencia se eliminó del recurso.")
    }

    func testDeletePostflightStillBoundLocksFurtherMutations() async throws {
        let client = QueuedProcurementAttachmentAPIClient(
            responseSteps: [
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: ["att_old"], version: 9).utf8)),
                .response(Data("{}".utf8)),
                .response(Data(Self.receiptEnvelopeJSON(attachmentIds: ["att_old"], version: 10).utf8)),
            ]
        )
        let viewModel = makeViewModel(
            sourceType: .purchaseReceipt,
            attachmentIds: ["att_old"],
            permissions: [
                BusinessProcurementPermission.purchaseReceiptsView,
                BusinessProcurementPermission.attachmentsDelete,
            ],
            client: client
        )
        let item = try XCTUnwrap(viewModel.evidenceItems.first)

        await viewModel.delete(item)

        XCTAssertTrue(viewModel.needsSourceRefresh)
        XCTAssertNil(viewModel.sourceVersion)
        XCTAssertEqual(viewModel.evidenceItems.map(\.id), ["att_old"])
        XCTAssertFalse(viewModel.canDeleteEvidence)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(
            viewModel.infoMessage,
            "La operación terminó, pero debes actualizar el recurso antes de otra carga o eliminación."
        )
    }

    func testAttachmentSurfaceKeepsEvidenceAndSecretBoundariesExplicit() throws {
        let viewSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessProcurementAttachmentsView.swift"
        )
        let viewModelSource = try sourceText(
            at: "Nexo Business/features/procurement/presentation/BusinessProcurementAttachmentsViewModel.swift"
        )

        XCTAssertTrue(viewSource.contains("No solicita un listado global"))
        XCTAssertTrue(viewSource.contains("no muestra identificadores internos"))
        XCTAssertTrue(viewSource.contains("no expone rutas ni metadatos de almacenamiento"))
        XCTAssertTrue(viewSource.contains("ShareLink(item: file.localURL)"))
        XCTAssertTrue(viewSource.contains("PDF, JPEG o PNG de hasta 10 MB"))
        XCTAssertTrue(viewModelSource.contains("requiredViewPermissions"))
        XCTAssertTrue(viewModelSource.contains("supplierPaymentsSensitiveView"))
        XCTAssertTrue(viewModelSource.contains("purchaseOrdersCostView"))
        XCTAssertTrue(viewModelSource.contains("downloadAttachment"))
        XCTAssertTrue(viewModelSource.contains("uploadAttachment"))
        XCTAssertTrue(viewModelSource.contains("deleteAttachment"))
        XCTAssertTrue(viewModelSource.contains("authoritativeSourceState"))
        XCTAssertTrue(viewModelSource.contains("expectedSourceVersion"))
        XCTAssertTrue(viewSource.contains(".fileImporter("))
        XCTAssertTrue(viewSource.contains(".confirmationDialog("))
        XCTAssertTrue(viewSource.contains("role: .destructive"))
        XCTAssertTrue(viewSource.contains("No se repetirá automáticamente"))
        XCTAssertTrue(
            viewModelSource.contains(
                "BusinessProcurementContractDecision.maximumAttachmentBytes"
            )
        )
        XCTAssertFalse(viewSource.contains("Text(item.id)"))
        XCTAssertFalse(viewSource.contains("responseHeaders"))
        XCTAssertFalse(viewSource.contains("checksumSha256"))
        XCTAssertFalse(viewSource.contains("storageReference"))
        XCTAssertFalse(viewModelSource.contains("BusinessProcurementRoutes.attachments"))
        XCTAssertFalse(viewModelSource.contains("sourceVersion +="))
        XCTAssertFalse(viewModelSource.contains("response.data.version +"))
    }

    private func makeViewModel(
        sourceType: BusinessProcurementAttachmentSourceType,
        attachmentIds: [String] = ["patt_1"],
        activeModules: Set<ModuleCode> = [.modulePurchases],
        permissions: Set<String>? = nil,
        client: QueuedProcurementAttachmentAPIClient,
        downloadDirectory: URL? = nil
    ) -> BusinessProcurementAttachmentsViewModel {
        BusinessProcurementAttachmentsViewModel(
            organizationId: "org_1",
            sourceType: sourceType,
            sourceId: "source_1",
            sourceVersion: 7,
            sourceDisplayName: "Documento de proveedor FAC-001",
            attachmentIds: attachmentIds,
            activeModules: activeModules,
            effectivePermissions: permissions ?? defaultPermissions(for: sourceType),
            repository: BusinessProcurementAPIRepository(
                apiClient: client,
                downloadDirectory: downloadDirectory
            )
        )
    }

    private func defaultPermissions(
        for sourceType: BusinessProcurementAttachmentSourceType
    ) -> Set<String> {
        switch sourceType {
        case .supplier:
            return [
                BusinessProcurementPermission.suppliersView,
                BusinessProcurementPermission.suppliersSensitiveView,
            ]
        case .purchaseOrder:
            return [
                BusinessProcurementPermission.purchaseOrdersView,
                BusinessProcurementPermission.purchaseOrdersCostView,
            ]
        case .purchaseReceipt:
            return [BusinessProcurementPermission.purchaseReceiptsView]
        case .supplierDocument:
            return [BusinessProcurementPermission.supplierDocumentsView]
        case .supplierPayment:
            return [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsSensitiveView,
            ]
        }
    }

    private func sourceText(at repositoryRelativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(repositoryRelativePath),
            encoding: .utf8
        )
    }

    private static var pdfResponse: APIDataResponse {
        APIDataResponse(
            data: Data("%PDF-1.7 evidence".utf8),
            statusCode: 200,
            headers: [
                "Content-Type": "application/pdf",
                "Content-Disposition": "attachment; filename=\"../factura.pdf\"",
                "X-Content-Type-Options": "nosniff",
            ]
        )
    }

    private static func receiptEnvelopeJSON(
        attachmentIds: [String],
        version: Int
    ) -> String {
        let attachmentJSON = attachmentIds.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {"data":{"id":"source_1","branchId":"br_1","supplierId":"sup_1","purchaseOrderId":null,
        "receiptNumber":"RC-001","status":"DRAFT","warehouseId":"wh_1","receivedAt":"2026-07-16T12:00:00Z",
        "lines":[],"inventoryMovementIds":[],"attachmentIds":[\(attachmentJSON)],"notes":null,
        "createdAt":"2026-07-16T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-16T12:00:00Z","updatedBy":"usr_1",
        "confirmedAt":null,"confirmedBy":null,"cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":\(version)},
        "meta":{"requestId":"req_receipt","idempotencyReplayed":false}}
        """
    }

    private static var attachmentEnvelopeJSON: String {
        """
        {"data":{"id":"att_new","sourceType":"PURCHASE_RECEIPT","sourceId":"source_1",
        "fileName":"evidence.pdf","mediaType":"application/pdf","sizeBytes":17,
        "checksumSha256":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        "uploadedAt":"2026-07-16T12:00:00Z","uploadedBy":"usr_1","version":99},
        "meta":{"requestId":"req_upload","idempotencyReplayed":false}}
        """
    }
}

private struct CapturedProcurementAttachmentRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?

    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }
}

private enum QueuedProcurementAttachmentResponse {
    case response(Data)
    case failure(APIError)
}

private final class QueuedProcurementAttachmentAPIClient: APIDataClient, @unchecked Sendable {
    private var dataResponses: [APIDataResponse]
    private var dataFailures: [APIError]
    private var responseSteps: [QueuedProcurementAttachmentResponse]
    private let delayNanoseconds: UInt64
    private(set) var capturedDataRequests: [CapturedProcurementAttachmentRequest] = []
    private(set) var capturedRequests: [CapturedProcurementAttachmentRequest] = []

    init(
        dataResponses: [APIDataResponse] = [],
        dataFailures: [APIError] = [],
        responseSteps: [QueuedProcurementAttachmentResponse] = [],
        delayNanoseconds: UInt64 = 0
    ) {
        self.dataResponses = dataResponses
        self.dataFailures = dataFailures
        self.responseSteps = responseSteps
        self.delayNanoseconds = delayNanoseconds
    }

    func send<Response: Decodable>(
        _ request: APIRequest<Response>
    ) async throws -> Response {
        capturedRequests.append(
            CapturedProcurementAttachmentRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers,
                body: request.body
            )
        )
        guard !responseSteps.isEmpty else {
            throw APIError.emptyResponse
        }
        switch responseSteps.removeFirst() {
        case .failure(let error):
            throw error
        case .response(let data):
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw APIError.decodingFailed(String(describing: error))
            }
        }
    }

    func sendData(
        _ request: APIRequest<EmptyResponse>
    ) async throws -> APIDataResponse {
        capturedDataRequests.append(
            CapturedProcurementAttachmentRequest(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                headers: request.headers,
                body: request.body
            )
        )
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if !dataFailures.isEmpty {
            throw dataFailures.removeFirst()
        }
        guard !dataResponses.isEmpty else {
            throw APIError.emptyResponse
        }
        return dataResponses.removeFirst()
    }
}
