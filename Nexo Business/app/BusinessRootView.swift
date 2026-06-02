//
//  BusinessRootView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct BusinessRootView: View {
    private let container: BusinessAppContainer

    @State private var sessionViewModel: BusinessSessionViewModel
    @State private var loginViewModel: LoginViewModel

    init(container: BusinessAppContainer) {
        self.container = container

        let sessionViewModel = BusinessSessionViewModel(
            tokenStore: container.tokenStore,
            selectionStore: container.selectionStore,
            organizationAccessRepository: container.organizationAccessRepository,
            contextRepository: container.contextRepository
        )

        _sessionViewModel = State(initialValue: sessionViewModel)
        _loginViewModel = State(
            initialValue: LoginViewModel(
                authRepository: container.authRepository,
                onLoginSucceeded: {
                    await sessionViewModel.loadOrganizationsAfterLogin()
                }
            )
        )
    }

    var body: some View {
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
        case .bootstrapping, .loadingOrganizations, .loadingContext:
            BusinessSessionLoadingView()

        case let .signedOut(message):
            signedOutContent(message: message)

        case let .needsOrganizationSelection(organizations):
            BusinessOrganizationSelectionView(
                organizations: organizations,
                selectAction: { organization in
                    Task { await sessionViewModel.selectOrganization(organization) }
                },
                logoutAction: {
                    Task { await sessionViewModel.logout() }
                }
            )

        case let .needsOperationalSelection(context, reason):
            BusinessOperationalSelectionView(
                context: context,
                reason: reason,
                continueAction: { branchId, activityId in
                    Task {
                        await sessionViewModel.selectOperationalContext(
                            branchId: branchId,
                            activityId: activityId
                        )
                    }
                },
                changeOrganizationAction: {
                    Task { await sessionViewModel.changeOrganization() }
                },
                logoutAction: {
                    Task { await sessionViewModel.logout() }
                }
            )

        case let .signedIn(context, selection):
            BusinessHomeView(
                context: context,
                operationalSelection: selection,
                container: container,
                onRefresh: {
                    Task { await sessionViewModel.refreshContext() }
                },
                onChangeOrganization: {
                    Task { await sessionViewModel.changeOrganization() }
                },
                onChangeOperation: {
                    Task { await sessionViewModel.changeOperationalContext() }
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
    BusinessRootView(container: .preview)
}
