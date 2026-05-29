//
//  ContentView.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct ContentView: View {
    let container: BusinessAppContainer
    let organizationId: String

    var body: some View {
        BusinessRootView(
            container: container,
            organizationId: organizationId
        )
    }
}

#Preview("Login") {
    ContentView(
        container: .preview,
        organizationId: PreviewData.businessContext.organization.id
    )
}
