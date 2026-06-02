//
//  BusinessContextRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol BusinessContextRepository: Sendable {
    func getContext(organizationId: String) async throws -> BusinessContextResponse
}
