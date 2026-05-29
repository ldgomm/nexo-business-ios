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
    case loadingOrganizations
    case needsOrganizationSelection([BusinessOrganizationAccess])
    case loadingContext
    case needsOperationalSelection(context: BusinessContextResponse, reason: String? = nil)
    case signedIn(BusinessContextResponse, BusinessOperationalSelection)
    case failed(String)
}
