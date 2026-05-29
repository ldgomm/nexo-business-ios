//
//  BusinessRootView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct BusinessRootView: View {
    private let container: BusinessAppContainer
    private let organizationId: String

    @State private var sessionViewModel: BusinessSessionViewModel
    @State private var loginViewModel: LoginViewModel

    public init(
        container: BusinessAppContainer,
        organizationId: String
    ) {
        self.container = container
        self.organizationId = organizationId

        let sessionViewModel = BusinessSessionViewModel(
            organizationId: organizationId,
            tokenStore: container.tokenStore,
            contextRepository: container.contextRepository
        )

        _sessionViewModel = State(initialValue: sessionViewModel)
        _loginViewModel = State(
            initialValue: LoginViewModel(
                authRepository: container.authRepository,
                onLoginSucceeded: {
                    await sessionViewModel.loadContextAfterLogin()
                }
            )
        )
    }

    public var body: some View {
        Group {
            content
        }
        .task {
            await sessionViewModel.bootstrapIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch sessionViewModel.state {
        case .bootstrapping, .loadingContext:
            BusinessSessionLoadingView()

        case let .signedOut(message):
            signedOutContent(message: message)

        case let .signedIn(context):
            BusinessHomeView(
                context: context,
                container: container,
                onRefresh: {
                    Task { await sessionViewModel.refreshContext() }
                },
                onLogout: {
                    Task { await sessionViewModel.logout() }
                }
            )

        case let .failed(message):
            BusinessSessionFailureView(
                message: message,
                retryAction: {
                    Task { await sessionViewModel.retryBootstrapOrRefresh() }
                },
                logoutAction: {
                    Task { await sessionViewModel.logout() }
                }
            )
        }
    }

    private func signedOutContent(message: String?) -> some View {
        VStack(spacing: 0) {
            if let message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
            }

            LoginView(viewModel: loginViewModel)
        }
    }
}

#Preview("Signed out") {
    BusinessRootView(
        container: .preview,
        organizationId: PreviewData.businessContext.organization.id
    )
}
