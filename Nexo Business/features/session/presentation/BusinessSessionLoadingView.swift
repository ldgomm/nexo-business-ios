//
//  BusinessSessionLoadingView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct BusinessSessionLoadingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 4) {
                Text("Preparando Nexo Business")
                    .font(.headline)

                Text("Cargando sesión, permisos y contexto operativo…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }
}

#Preview {
    BusinessSessionLoadingView()
}
