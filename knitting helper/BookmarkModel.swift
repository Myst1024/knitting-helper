//
//  BookmarkModel.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/31/25.
//

import UIKit
import SwiftUI

/// Lightweight model for bookmarks (shared between Coordinator and overlay)
struct BookmarkModel: Identifiable {
    let id: UUID
    // Canonical storage: page index + normalized fractions within the page.
    var page: Int
    var xFraction: CGFloat // 0..1 relative to page width
    var yFraction: CGFloat // 0..1 relative to page height
    var name: String
    var color: UIColor // Color of the bookmark icon

    // Compute a canvas-aligned point for this bookmark using the provided canvas' pageFrames.
    func point(in canvas: PDFCanvasView?) -> CGPoint {
        guard let canvas = canvas, !canvas.pageFrames.isEmpty,
              let pageFrame = canvas.pageFrames[page] else {
            // Fallback to proportional mapping within full canvas height.
            guard let height = canvas?.bounds.height, height > 0,
                  let width = canvas?.bounds.width, width > 0 else {
                return CGPoint(x: 0, y: 0)
            }
            let x = xFraction * width
            let y = yFraction * height
            return CGPoint(x: x, y: y)
        }
        let x = pageFrame.minX + xFraction * pageFrame.width
        let y = pageFrame.minY + yFraction * pageFrame.height
        return CGPoint(x: x, y: y)
    }

    mutating func set(fromPage page: Int, xFraction: CGFloat, yFraction: CGFloat) {
        self.page = page
        self.xFraction = xFraction
        self.yFraction = yFraction
    }

    init(id: UUID = UUID(), page: Int = 0, xFraction: CGFloat = 0.5, yFraction: CGFloat = 0.5, name: String = "", color: UIColor = .systemOrange) {
        self.id = id
        self.page = page
        self.xFraction = xFraction
        self.yFraction = yFraction
        self.name = name
        self.color = color
    }
}

/// Object that handles bookmark creation callbacks
class BookmarkCreator {
    var createBookmark: ((String) -> Void)?

    func createBookmarkWithName(_ name: String) {
        createBookmark?(name)
    }
}
