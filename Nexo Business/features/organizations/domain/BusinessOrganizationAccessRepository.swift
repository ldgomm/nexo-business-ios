//
//  BusinessOrganizationAccessRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol BusinessOrganizationAccessRepository: Sendable {
    func listOrganizations() async throws -> BusinessOrganizationAccessResponse
}
