//
//  BusinessHeaders.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessHeaders {
    public static let organizationId = "X-Organization-Id"
    public static let branchId = "X-Branch-Id"
    public static let activityId = "X-Activity-Id"
    public static let requestId = "X-Request-Id"
    public static let correlationId = "X-Correlation-Id"
    public static let deviceId = "X-Device-Id"
    public static let appName = "X-App-Name"
    public static let appVersion = "X-App-Version"
    public static let appBuild = "X-App-Build"
    public static let platform = "X-Platform"
    public static let idempotencyKey = "Idempotency-Key"
    public static let catalogRevision = "X-Catalog-Revision"
    public static let taxConfigurationRevision = "X-Tax-Configuration-Revision"
}
