//
//  AppEnvironment.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct AppEnvironment: Equatable, Sendable {
    let name: String
    let baseURL: URL

    init(name: String, baseURL: URL) {
        self.name = name
        self.baseURL = baseURL
    }

    static let staging = AppEnvironment(
        name: "staging",
        baseURL: URL(string: "https://api-staging.premierdarkcoffee.com")!
    )

    static let local = AppEnvironment(
        name: "local",
        baseURL: URL(string: "http://localhost:8080")!
    )
}
