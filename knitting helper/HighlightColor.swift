//
//  HighlightColor.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import UIKit

/// Enum for highlight colors with type-safe access
enum HighlightColor: String, CaseIterable {
    case purple
    case blue
    case green
    case red
    case yellow
    
    var uiColor: UIColor {
        switch self {
        case .purple:
            return .purple
        case .blue:
            return .systemBlue
        case .green:
            return .systemGreen
        case .red:
            return .systemRed
        case .yellow:
            return .systemYellow
        }
    }
}

