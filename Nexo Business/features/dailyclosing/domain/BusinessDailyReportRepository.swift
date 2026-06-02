//
//  BusinessDailyReportRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol BusinessDailyReportRepository: Sendable {
    func dailyReport(
        organizationId: String,
        branchId: String,
        businessDate: String
    ) async throws -> BusinessDailyReportResponse
}
