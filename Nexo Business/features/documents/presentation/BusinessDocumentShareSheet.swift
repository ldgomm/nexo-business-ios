//
//  BusinessDocumentShareSheet.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI
import UIKit

struct BusinessDocumentShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var activities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: activities)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
