//
//  NoteModel.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import UIKit

/// Lightweight model for notes (shared between Coordinator and overlay)
struct NoteModel: Identifiable {
    let id: UUID
    // Canonical storage: page index + normalized fractions within the page.
    var page: Int
    var xFraction: CGFloat // 0..1 relative to page width
    var yFraction: CGFloat // 0..1 relative to page height
    var text: String
    var isOpen: Bool // Whether the note editor is currently open
    var width: CGFloat // Note editor width
    var height: CGFloat // Note editor height
    var color: UIColor // Color of the note icon

    // Compute a canvas-aligned point for this note using the provided canvas' pageFrames.
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

    init(id: UUID = UUID(), page: Int = 0, xFraction: CGFloat = 0.5, yFraction: CGFloat = 0.5, text: String = "", isOpen: Bool = false, width: CGFloat = 0, height: CGFloat = 0, color: UIColor = .systemBlue) {
        self.id = id
        self.page = page
        self.xFraction = xFraction
        self.yFraction = yFraction
        self.text = text
        self.isOpen = isOpen
        self.width = width
        self.height = height
        self.color = color
    }
}

