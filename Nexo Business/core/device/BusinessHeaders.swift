//
//  BusinessHeaders.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessHeaders {
    static let organizationId = "X-Organization-Id"
    static let branchId = "X-Branch-Id"
    static let activityId = "X-Activity-Id"
    static let requestId = "X-Request-Id"
    static let correlationId = "X-Correlation-Id"
    static let deviceId = "X-Device-Id"
    static let appName = "X-App-Name"
    static let appVersion = "X-App-Version"
    static let appBuild = "X-App-Build"
    static let platform = "X-Platform"
    static let idempotencyKey = "Idempotency-Key"
    static let catalogRevision = "X-Catalog-Revision"
    static let taxConfigurationRevision = "X-Tax-Configuration-Revision"
}
