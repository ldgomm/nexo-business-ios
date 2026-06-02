//
//  PreviewOrganizationAccessRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

extension PreviewData {
    static let organizations = [
        BusinessOrganizationAccess(
            id: businessContext.organization.id,
            commercialName: businessContext.organization.commercialName,
            legalName: businessContext.organization.legalName,
            taxId: businessContext.organization.taxId,
            countryCode: businessContext.organization.countryCode,
            roleName: "Operador",
            status: "active"
        ),
        BusinessOrganizationAccess(
            id: "org_demo_store",
            commercialName: "Tienda Demo",
            legalName: "Tienda Demo S.A.S.",
            taxId: "0999999999001",
            countryCode: "EC",
            roleName: "Encargado",
            status: "active"
        )
    ]
}

final class PreviewBusinessOrganizationAccessRepository: BusinessOrganizationAccessRepository, @unchecked Sendable {
    init() {}

    func listOrganizations() async throws -> BusinessOrganizationAccessResponse {
        BusinessOrganizationAccessResponse(organizations: PreviewData.organizations)
    }
}
