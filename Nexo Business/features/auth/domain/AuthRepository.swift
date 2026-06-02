//
//  AuthRepository.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol AuthRepository: Sendable {
    func login(email: String, password: String) async throws -> LoginResponse
    func logout() async throws
}
