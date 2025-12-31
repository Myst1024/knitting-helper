//
//  PDFCanvasView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import UIKit
import PDFKit

/// Custom view that renders PDF pages using efficient multi-page rendering.
/// Pages are stacked vertically with full-width layout.
class PDFCanvasView: UIView {
    var document: PDFDocument? { didSet { setNeedsLayout(); setNeedsDisplay() } }
    var pageFrames: [Int: CGRect] = [:] // canvas coordinates
    private static let imageCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        // Limit to ~150 MB by default
        c.totalCostLimit = PDFConstants.imageCacheLimit
        return c
    }()

    static func clearCache() {
        imageCache.removeAllObjects()
    }
    private var contentHeightConstraint: NSLayoutConstraint?
    
    // Switch from CATiledLayer-based drawing to per-page UIImageView subviews.
    // Each page will have an image view that is rasterized asynchronously and cached.
    private var pageImageViews: [Int: UIImageView] = [:]

    override func didMoveToWindow() {
        super.didMoveToWindow()
        isOpaque = true
        backgroundColor = .clear
        contentMode = .redraw
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        computePageFramesAndLayoutViews()
    }

    private func computePageFramesAndLayoutViews() {
        pageFrames.removeAll()
        guard let doc = document else { return }
        let targetWidth = bounds.width > 0 ? bounds.width : 1
        var y: CGFloat = 0
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let media = page.bounds(for: .mediaBox)
            let scale = targetWidth / max(media.width, 1)
            let pageHeight = media.height * scale
            let frame = CGRect(x: 0, y: y, width: targetWidth, height: pageHeight)
            pageFrames[i] = frame

            // Ensure there is an imageView for this page
            if let imgView = pageImageViews[i] {
                imgView.frame = frame
            } else {
                let iv = UIImageView(frame: frame)
                iv.backgroundColor = .white
                // Rendered images are rasterized to exact view size; use scaleToFill so they map 1:1.
                iv.contentMode = .scaleToFill
                iv.clipsToBounds = true
                addSubview(iv)
                pageImageViews[i] = iv
                // Kick off rasterization
                rasterizePageIfNeeded(index: i, page: page, targetSize: frame.size, imageView: iv)
            }

            y += pageHeight
        }

        // Remove any image views for pages that no longer exist
        let validKeys = Set(0..<doc.pageCount)
        for (idx, iv) in pageImageViews {
            if !validKeys.contains(idx) {
                iv.removeFromSuperview()
                pageImageViews.removeValue(forKey: idx)
            }
        }

        // Update height constraint
        if let hc = contentHeightConstraint {
            hc.constant = y
        } else {
            let c = heightAnchor.constraint(equalToConstant: y)
            c.priority = .required
            c.isActive = true
            contentHeightConstraint = c
        }
    }

    private func rasterizePageIfNeeded(index: Int, page: PDFPage, targetSize: CGSize, imageView: UIImageView) {
        let docID = document?.documentURL?.absoluteString ?? "doc_anon"
        let keyString = "\(docID)_page_\(index)_w_\(Int(targetSize.width))_h_\(Int(targetSize.height))_s_\(Int(UIScreen.main.scale))"
        let key = NSString(string: keyString)
        if let cached = PDFCanvasView.imageCache.object(forKey: key) {
            imageView.image = cached
            return
        }

        // Render async at device scale so pixel dimensions match the imageView
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                let deviceScale = UIScreen.main.scale
                let format = UIGraphicsImageRendererFormat.default()
                format.scale = deviceScale
                let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
                let img = renderer.image { ctx in
                    let c = ctx.cgContext
                    UIColor.white.setFill()
                    c.fill(CGRect(origin: .zero, size: targetSize))
                    // Map PDF page to renderer coordinate space
                    let media = page.bounds(for: .mediaBox)
                    let sx = targetSize.width / max(media.width, 1)
                    let sy = targetSize.height / max(media.height, 1)
                    // Translate to top-left of renderer coordinate space and flip vertically
                    c.translateBy(x: 0, y: targetSize.height)
                    c.scaleBy(x: 1, y: -1)
                    // Apply scale to map PDF points -> renderer points
                    c.scaleBy(x: sx, y: sy)
                    page.draw(with: .mediaBox, to: c)
                }
                let cost = Int(targetSize.width * targetSize.height * deviceScale * deviceScale)
                PDFCanvasView.imageCache.setObject(img, forKey: key, cost: cost)
                DispatchQueue.main.async {
                    imageView.image = img
                }
                // Ensure we trigger a layout update if needed
                DispatchQueue.main.async {
                    self?.setNeedsLayout()
                }
            }
        }
    }
}

