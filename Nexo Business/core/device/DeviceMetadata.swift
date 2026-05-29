//
//  DeviceMetadata.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct DeviceMetadata: Equatable, Sendable {
    public let requestId: String
    public let correlationId: String
    public let deviceId: String
    public let appName: String
    public let appVersion: String
    public let appBuild: String
    public let platform: String

    public init(
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

public protocol DeviceMetadataProviding: Sendable {
    func deviceMetadata() -> DeviceMetadata
}

public struct StaticDeviceMetadataProvider: DeviceMetadataProviding {
    private let base: DeviceMetadata

    public init(base: DeviceMetadata) {
        self.base = base
    }

    public func deviceMetadata() -> DeviceMetadata {
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

    public static func stagingDefault(
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
