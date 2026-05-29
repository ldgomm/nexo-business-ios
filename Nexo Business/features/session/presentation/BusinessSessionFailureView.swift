//
//  BusinessSessionFailureView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct BusinessSessionFailureView: View {
    private let message: String
    private let retryAction: () -> Void
    private let logoutAction: () -> Void

    public init(
        message: String,
        retryAction: @escaping () -> Void,
        logoutAction: @escaping () -> Void
    ) {
        self.message = message
        self.retryAction = retryAction
        self.logoutAction = logoutAction
    }

    public var body: some View {
        ContentUnavailableView {
            Label("No se pudo cargar el negocio", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            VStack(spacing: 10) {
                Button("Reintentar") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)

                Button("Cerrar sesión", role: .destructive) {
                    logoutAction()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    BusinessSessionFailureView(
        message: "No se pudo conectar. Revisa internet e inténtalo nuevamente.",
        retryAction: {},
        logoutAction: {}
    )
}
