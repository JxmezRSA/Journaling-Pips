//
//  Item.swift
//  Journaling Pips
//
//  Created by James Scharnick on 2026/06/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
