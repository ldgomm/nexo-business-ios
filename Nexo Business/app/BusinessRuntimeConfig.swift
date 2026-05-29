//
//  BusinessRuntimeConfig.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct BusinessRuntimeConfig: Equatable, Sendable {
    let environment: AppEnvironment
    let organizationId: String
    let deviceId: String

    static var current: BusinessRuntimeConfig {
        let bundle = Bundle.main

        let baseURLString = bundle.object(forInfoDictionaryKey: "NEXO_API_BASE_URL") as? String
        let organizationId = bundle.object(forInfoDictionaryKey: "NEXO_ORGANIZATION_ID") as? String
        let deviceId = bundle.object(forInfoDictionaryKey: "NEXO_DEVICE_ID") as? String

        let environment = baseURLString
            .flatMap(URL.init(string:))
            .map { AppEnvironment(name: "configured", baseURL: $0) }
            ?? .staging

        return BusinessRuntimeConfig(
            environment: environment,
            organizationId: organizationId?.isEmpty == false ? organizationId! : "org_altos",
            deviceId: deviceId?.isEmpty == false ? deviceId! : "ios-business-15a"
        )
    }

    static let staging = BusinessRuntimeConfig(
        environment: .staging,
        organizationId: "org_altos",
        deviceId: "ios-business-15a"
    )
}
