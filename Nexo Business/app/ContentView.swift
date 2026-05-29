//
//  ContentView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct ContentView: View {
    let container: BusinessAppContainer

    var body: some View {
        BusinessRootView(container: container)
    }
}

#Preview("Login") {
    ContentView(container: .preview)
}
