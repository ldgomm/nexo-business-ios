//
//  ContentView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct ContentView: View {
    let container: AppContainer

    var body: some View {
        RootView(container: container)
    }
}

#Preview("Login") {
    ContentView(container: .preview)
}
