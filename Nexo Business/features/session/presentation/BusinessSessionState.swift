//
//  BusinessSessionState.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessSessionState: Equatable {
    case bootstrapping
    case signedOut(message: String? = nil)
    case loadingContext
    case signedIn(BusinessContextResponse)
    case failed(String)
}
