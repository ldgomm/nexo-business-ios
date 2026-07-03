//
//  NexoBusinessApp.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

@main
struct NexoBusinessApp: App {
    private let config: RuntimeConfig
    private let container: AppContainer

    init() {
        let config = RuntimeConfig.current
        self.config = config
        self.container = AppContainer.live(config: config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
