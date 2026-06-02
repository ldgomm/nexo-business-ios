//
//  LoginView.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct LoginView: View {
    @Bindable private var viewModel: LoginViewModel

    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nexo Business")
                    .font(.largeTitle.bold())

                Text("Opera ventas, caja y comprobantes desde el móvil.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Correo", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()

            SecureField("Contraseña", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.login() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Ingresar")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.email.isEmpty ||
                viewModel.password.isEmpty ||
                viewModel.isLoading
            )

            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    LoginView(
        viewModel: LoginViewModel(
            authRepository: PreviewAuthRepository()
        )
    )
}
