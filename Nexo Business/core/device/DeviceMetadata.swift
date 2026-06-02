//
//  DeviceMetadata.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct DeviceMetadata: Equatable, Sendable {
    let requestId: String
    let correlationId: String
    let deviceId: String
    let appName: String
    let appVersion: String
    let appBuild: String
    let platform: String

    init(
        requestId: String = UUID().uuidString,
        correlationId: String = UUID().uuidString,
        deviceId: String,
        appName: String,
        appVersion: String,
        appBuild: String,
        platform: String
    ) {
        self.requestId = requestId
        self.correlationId = correlationId
        self.deviceId = deviceId
        self.appName = appName
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.platform = platform
    }
}

protocol DeviceMetadataProviding: Sendable {
    func deviceMetadata() -> DeviceMetadata
}

struct StaticDeviceMetadataProvider: DeviceMetadataProviding {
    private let base: DeviceMetadata

    init(base: DeviceMetadata) {
        self.base = base
    }

    func deviceMetadata() -> DeviceMetadata {
        DeviceMetadata(
            requestId: UUID().uuidString,
            correlationId: base.correlationId,
            deviceId: base.deviceId,
            appName: base.appName,
            appVersion: base.appVersion,
            appBuild: base.appBuild,
            platform: base.platform
        )
    }

    static func stagingDefault(
        deviceId: String = "ios-business-15a"
    ) -> StaticDeviceMetadataProvider {
        StaticDeviceMetadataProvider(
            base: DeviceMetadata(
                deviceId: deviceId,
                appName: "nexo-business-ios",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "15.0.0",
                appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "15A",
                platform: "ios"
            )
        )
    }
}
