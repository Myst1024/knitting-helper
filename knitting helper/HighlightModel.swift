//
//  HighlightModel.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import UIKit

/// Lightweight model for highlights (shared between Coordinator and overlay)
struct HighlightModel: Identifiable {
    let id: UUID
    // Canonical storage: page indices + normalized fractions within each page.
    var startPage: Int
    var startFraction: CGFloat
    var endPage: Int
    var endFraction: CGFloat
    var color: UIColor

    // Compute a canvas-aligned rect for this highlight using the provided canvas' pageFrames.
    func rect(in canvas: PDFCanvasView?) -> CGRect {
        guard let canvas = canvas, !canvas.pageFrames.isEmpty,
              let startFrame = canvas.pageFrames[startPage], let endFrame = canvas.pageFrames[endPage] else {
            // Fallback to proportional mapping within full canvas height.
            guard let height = canvas?.bounds.height, height > 0 else { return CGRect(x: 0, y: 0, width: canvas?.bounds.width ?? 0, height: PDFConstants.defaultHighlightHeight) }
            let y = startFraction * height
            let maxY = endFraction * height
            let h = max(PDFConstants.minHighlightHeight, maxY - y)
            return CGRect(x: 0, y: y, width: canvas?.bounds.width ?? 0, height: h)
        }
        let y = startFrame.minY + startFraction * startFrame.height
        let maxY = endFrame.minY + endFraction * endFrame.height
        let h = max(PDFConstants.minHighlightHeight, maxY - y)
        return CGRect(x: 0, y: y, width: canvas.bounds.width, height: h)
    }

    mutating func set(fromPageRange startPage: Int, startFraction: CGFloat, endPage: Int, endFraction: CGFloat) {
        self.startPage = startPage
        self.startFraction = startFraction
        self.endPage = endPage
        self.endFraction = endFraction
    }

    init(id: UUID = UUID(), startPage: Int = 0, startFraction: CGFloat = 0, endPage: Int = 0, endFraction: CGFloat = 0, color: UIColor = .purple) {
        self.id = id
        self.startPage = startPage
        self.startFraction = startFraction
        self.endPage = endPage
        self.endFraction = endFraction
        self.color = color
    }
}

