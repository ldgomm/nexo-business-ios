//
//  NexoBusinessApp.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

@main
struct NexoBusinessApp: App {
    private let config: BusinessRuntimeConfig
    private let container: BusinessAppContainer

    init() {
        let config = BusinessRuntimeConfig.current
        self.config = config
        self.container = BusinessAppContainer.live(config: config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
