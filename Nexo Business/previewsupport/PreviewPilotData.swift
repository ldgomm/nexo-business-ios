//
//  PreviewPilotData.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum PreviewPilotData {
    static var completedPilotChecklist: [PilotChecklistItem] {
        PilotChecklistFactory.defaultItems().map { item in
            var copy = item
            copy.isDone = item.isRequired
            copy.updatedAt = Date()
            return copy
        }
    }
}
