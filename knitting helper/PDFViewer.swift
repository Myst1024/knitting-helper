//
//  PDFViewer.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI
import UIKit
import PDFKit

private enum Constants {
    static let defaultHighlightHeight: CGFloat = 120
    static let highlightOpacity: CGFloat = 0.35
    static let selectedHighlightOpacity: CGFloat = 0.6
    static let highlightStrokeWidth: CGFloat = 2.0
    static let handleWidth: CGFloat = 80
    static let handleHeight: CGFloat = 8
    static let handleCornerRadius: CGFloat = 4
    static let handleStrokeWidth: CGFloat = 1.0
    static let deleteButtonSize: CGFloat = 28
    static let deleteButtonInset: CGFloat = 8
    static let deleteButtonOffset: CGFloat = 12
    static let deleteIconOpacity: CGFloat = 0.9
    static let colorPickerButtonSize: CGFloat = 28
    static let colorPickerButtonSpacing: CGFloat = 8
    static let highlightTapHitSlop: CGFloat = 10
    static let minHighlightHeight: CGFloat = 30
    // Base hit slop applied uniformly; additional asymmetric extras below
    static let handleHitSlop: CGFloat = 10
    // Extra horizontal expansion applied to handle hit areas (left & right)
    static let handleHitExtraHorizontal: CGFloat = 10
    // Extra vertical expansion for top and bottom handles
    static let handleHitExtraTop: CGFloat = 20
    static let handleHitExtraBottom: CGFloat = 20
}

struct PDFViewer: View {
    let url: URL
    @Binding var shouldAddHighlight: Bool
    @Binding var highlights: [CodableHighlight]
    let counterCount: Int
    @Binding var scrollOffsetY: Double
    
    var body: some View {
        PDFKitView(url: url, shouldAddHighlight: $shouldAddHighlight, highlights: $highlights, counterCount: counterCount, scrollOffsetY: $scrollOffsetY)
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var shouldAddHighlight: Bool
    @Binding var highlights: [CodableHighlight]
    let counterCount: Int
    @Binding var scrollOffsetY: Double
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .systemBackground
        
        // Add top content inset for counters overlay - dynamic based on counter count
        let counterHeight: CGFloat = 60 // Approximate height per counter
        let topInset = (CGFloat(counterCount) * counterHeight)
        scrollView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        
        // Load document
        let document = PDFDocument(url: url)
        context.coordinator.document = document
        
        // Build canvas container (contentView) that will be zoomed
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        context.coordinator.contentView = contentView
        
        // Ensure contentView fills scroll content area and is at least as tall as the scroll view
        let minHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        minHeightConstraint.priority = .required
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor), // width follows scrollView; height computed after layout
            minHeightConstraint
        ])
        
        // Create tiled canvas view that draws all pages vertically stacked
        let canvas = PDFCanvasView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.document = document
        contentView.addSubview(canvas)
        context.coordinator.canvasView = canvas
        
        // Overlay for highlights (drawn in canvas coordinate space)
        let overlay = HighlightOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlay)
        context.coordinator.overlayView = overlay
        overlay.isUserInteractionEnabled = false
        contentView.bringSubviewToFront(overlay)
        
        // Allow the canvas to be centered vertically inside contentView when it's shorter than the scroll view
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvas.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor),
            canvas.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
            canvas.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Pin overlay to the canvas so its coordinate system matches canvas coordinates exactly
            overlay.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: canvas.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: canvas.bottomAnchor)
        ])
        
        // Gesture recognizers attached to scrollView (for tap/pan on highlights)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        scrollView.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(pan)
        
        // Store initial scroll offset to restore
        context.coordinator.initialScrollOffsetY = scrollOffsetY
        
        // Force initial layout to compute canvas size
        DispatchQueue.main.async {
            context.coordinator.loadHighlights(highlights)
            context.coordinator.layoutCanvas()
            context.coordinator.syncOverlay()
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update content inset when counter count changes
        let counterHeight: CGFloat = 60
        let topInset = CGFloat(counterCount) * counterHeight
        let oldInset = scrollView.contentInset.top
        scrollView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        
        // Restore scroll position once after layout and inset are applied
        if !context.coordinator.hasRestoredScrollPosition && context.coordinator.initialScrollOffsetY > 0 {
            // Only restore after content inset has stabilized
            if oldInset == topInset {
                DispatchQueue.main.async {
                    scrollView.setContentOffset(CGPoint(x: 0, y: context.coordinator.initialScrollOffsetY), animated: false)
                    context.coordinator.hasRestoredScrollPosition = true
                }
            }
        }
        
        // Add highlight when requested
        if shouldAddHighlight {
            context.coordinator.addHighlight()
            context.coordinator.syncOverlay()
            DispatchQueue.main.async { shouldAddHighlight = false }
        }

        // If the URL/document changed, replace the document and clear cached images
        if context.coordinator.document?.documentURL != url {
            let newDoc = PDFDocument(url: url)
            context.coordinator.document = newDoc
            context.coordinator.canvasView?.document = newDoc
            // Clear any cached raster images for previous document to avoid visual artifacts
            PDFCanvasView.clearCache()
            // Remove all highlight subviews (they belong to previous document coordinates)
            context.coordinator.overlayView?.subviews.forEach { $0.removeFromSuperview() }
            context.coordinator.overlayView?.highlights = []
            context.coordinator.overlayView?.selectedID = nil
            context.coordinator.loadHighlights(highlights)
            // Force a layout and redraw
            context.coordinator.layoutCanvas()
            context.coordinator.syncOverlay()
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(url: url, highlights: $highlights, scrollOffsetY: $scrollOffsetY) }
    
    // MARK: - Canvas and Overlay
    
    /// Custom view that renders PDF pages using CATiledLayer for efficient multi-page rendering.
    /// Pages are stacked vertically with full-width layout.
    class PDFCanvasView: UIView {
        var document: PDFDocument? { didSet { setNeedsLayout(); setNeedsDisplay() } }
        var pageFrames: [Int: CGRect] = [:] // canvas coordinates
        private static let imageCache: NSCache<NSString, UIImage> = {
            let c = NSCache<NSString, UIImage>()
            // Limit to ~150 MB by default
            c.totalCostLimit = 150 * 1024 * 1024
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
    
    
    /// Transparent overlay view that draws highlights, handles, and delete buttons on top of the PDF canvas.
    /// All drawing is done in canvas coordinate space.
    // Lightweight model for highlights (shared between Coordinator and overlay)
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
                guard let height = canvas?.bounds.height, height > 0 else { return CGRect(x: 0, y: 0, width: canvas?.bounds.width ?? 0, height: Constants.defaultHighlightHeight) }
                let y = startFraction * height
                let maxY = endFraction * height
                let h = max(Constants.minHighlightHeight, maxY - y)
                return CGRect(x: 0, y: y, width: canvas?.bounds.width ?? 0, height: h)
            }
            let y = startFrame.minY + startFraction * startFrame.height
            let maxY = endFrame.minY + endFraction * endFrame.height
            let h = max(Constants.minHighlightHeight, maxY - y)
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

    class HighlightOverlayView: UIView {
        // MARK: - Properties
        var highlights: [HighlightModel] = []
        var selectedID: UUID?
        private var highlightViews: [UUID: HighlightSubview] = [:]
        private var deleteButtonView: UIView?
        private var colorButtonView: UIView?
        
        // MARK: - Initialization
        override init(frame: CGRect) {
            super.init(frame: frame)
            configureView()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            configureView()
        }
        
        private func configureView() {
            isOpaque = false
            backgroundColor = .clear
            contentMode = .redraw
        }
        
        override func draw(_ rect: CGRect) {
            // Keep overlay fully transparent and rely on view-backed highlight subviews
            // and the view-backed buttons for interactive chrome. Clearing avoids
            // accumulation from previous non-view-backed drawing.
            guard let ctx = UIGraphicsGetCurrentContext() else { return }
            ctx.setBlendMode(.clear)
            ctx.fill(rect)
            ctx.setBlendMode(.normal)
        }
        
        // MARK: - Drawing Helpers
        private func drawEdgeHandle(at y: CGFloat, centerX: CGFloat, color: UIColor, in ctx: CGContext) {
            let handleRect = CGRect(
                x: centerX - Constants.handleWidth / 2,
                y: y - Constants.handleHeight / 2,
                width: Constants.handleWidth,
                height: Constants.handleHeight
            )
            
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 2,
                color: UIColor.black.withAlphaComponent(0.3).cgColor
            )
            
            let path = UIBezierPath(roundedRect: handleRect, cornerRadius: Constants.handleCornerRadius)
            UIColor.white.setFill()
            path.fill()
            color.setStroke()
            path.lineWidth = Constants.handleStrokeWidth
            path.stroke()
            ctx.restoreGState()
        }
        
        private func drawDeleteButton(for rect: CGRect, in ctx: CGContext) {
            let size = Constants.deleteButtonSize
            let buttonRect = CGRect(
                x: rect.minX + Constants.deleteButtonInset,
                y: rect.minY - size - Constants.deleteButtonOffset,
                width: size,
                height: size
            )
            
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: 4),
                blur: 8,
                color: UIColor.black.withAlphaComponent(0.4).cgColor
            )
            
            let path = UIBezierPath(ovalIn: buttonRect)
            UIColor.white.setFill()
            path.fill()
            ctx.restoreGState()
            
            // Draw trash icon
            let iconConfig = UIImage.SymbolConfiguration(pointSize: size / 2, weight: .medium)
            if let trashIcon = UIImage(systemName: "trash.fill", withConfiguration: iconConfig) {
                let iconSize = trashIcon.size
                let iconRect = CGRect(
                    x: buttonRect.midX - iconSize.width / 2,
                    y: buttonRect.midY - iconSize.height / 2,
                    width: iconSize.width,
                    height: iconSize.height
                )
                UIColor.systemRed.setFill()
                trashIcon.draw(in: iconRect, blendMode: .normal, alpha: Constants.deleteIconOpacity)
            }
        }
        
        private func drawColorPickerButton(for rect: CGRect, color: UIColor, in ctx: CGContext) {
            let size = Constants.colorPickerButtonSize
            let deleteButtonX = rect.minX + Constants.deleteButtonInset
            let buttonRect = CGRect(
                x: deleteButtonX + Constants.deleteButtonSize + Constants.colorPickerButtonSpacing,
                y: rect.minY - size - Constants.deleteButtonOffset,
                width: size,
                height: size
            )
            
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: 4),
                blur: 8,
                color: UIColor.black.withAlphaComponent(0.4).cgColor
            )
            
            // Draw background circle with highlight color
            let path = UIBezierPath(ovalIn: buttonRect)
            color.setFill()
            path.fill()
            ctx.restoreGState()
            
            // Draw white palette icon
            let iconConfig = UIImage.SymbolConfiguration(pointSize: size / 2, weight: .medium)
            if let paletteIcon = UIImage(systemName: "paintpalette.fill", withConfiguration: iconConfig) {
                let whiteIcon = paletteIcon.withTintColor(.white, renderingMode: .alwaysOriginal)
                let iconSize = whiteIcon.size
                let iconRect = CGRect(
                    x: buttonRect.midX - iconSize.width / 2,
                    y: buttonRect.midY - iconSize.height / 2,
                    width: iconSize.width,
                    height: iconSize.height
                )
                whiteIcon.draw(in: iconRect)
            }
        }

        // MARK: - View-backed highlights (faster incremental updates)
        /// Update visual subviews to match the provided model. This avoids full redraws.
        func update(highlights newHighlights: [HighlightModel], selectedID newSelected: UUID?, canvas: PDFCanvasView?) {
            // Convert arrays to dict for quick lookup
            var newMap: [UUID: HighlightModel] = [:]
            for h in newHighlights { newMap[h.id] = h }

            // Remove views for highlights that no longer exist
            for (id, view) in highlightViews {
                if newMap[id] == nil {
                    view.removeFromSuperview()
                    highlightViews.removeValue(forKey: id)
                }
            }

            // Add or update views for each highlight
            for h in newHighlights {
                let frame = h.rect(in: canvas) // overlay is pinned to canvas; use canvas for width/frames
                let frameAdjusted = CGRect(x: 0, y: frame.origin.y, width: bounds.width, height: frame.height)
                if let v = highlightViews[h.id] {
                    // Update frame and color if changed
                    if v.frame.origin.y != frameAdjusted.origin.y || v.frame.size.height != frameAdjusted.size.height || v.frame.size.width != frameAdjusted.size.width {
                        v.frame = frameAdjusted
                    }
                    v.updateColor(h.color)
                    v.setSelected(h.id == newSelected)
                } else {
                    // Create new highlight view
                    let v = HighlightSubview(frame: frameAdjusted)
                    v.setSelected(h.id == newSelected)
                    addSubview(v)
                    highlightViews[h.id] = v
                }
            }

            // Ensure selection state for any views not in newHighlights (safety)
            for (id, v) in highlightViews {
                v.setSelected(id == newSelected)
            }

            // Keep model in sync
            highlights = newHighlights
            selectedID = newSelected

            // Manage view-backed delete + color picker buttons for the selected highlight.
            // Buttons are non-interactive (isUserInteractionEnabled = false) so gesture
            // handling remains centralized in the Coordinator.
            if let sel = newSelected, let model = newMap[sel] {
                // Delete button
                let deleteSize = Constants.deleteButtonSize
                let modelRectRaw = model.rect(in: canvas)
                let modelRect = CGRect(x: 0, y: modelRectRaw.minY, width: bounds.width, height: modelRectRaw.height)
                let deleteFrame = CGRect(
                    x: modelRect.minX + Constants.deleteButtonInset,
                    y: modelRect.minY - deleteSize - Constants.deleteButtonOffset,
                    width: deleteSize,
                    height: deleteSize
                )
                if let db = deleteButtonView {
                    db.frame = deleteFrame
                } else {
                    let db = UIView(frame: deleteFrame)
                    db.backgroundColor = .white
                    db.layer.cornerRadius = deleteSize / 2
                    db.layer.shadowColor = UIColor.black.withAlphaComponent(0.4).cgColor
                    db.layer.shadowOffset = CGSize(width: 0, height: 4)
                    db.layer.shadowRadius = 8
                    db.layer.shadowOpacity = 1.0
                    db.isUserInteractionEnabled = false

                    // Trash icon
                    let iconConfig = UIImage.SymbolConfiguration(pointSize: deleteSize / 2, weight: .medium)
                    if let trash = UIImage(systemName: "trash.fill", withConfiguration: iconConfig)?.withTintColor(.systemRed, renderingMode: .alwaysOriginal) {
                        let iv = UIImageView(image: trash)
                        iv.translatesAutoresizingMaskIntoConstraints = false
                        iv.contentMode = .scaleAspectFit
                        db.addSubview(iv)
                        NSLayoutConstraint.activate([
                            iv.centerXAnchor.constraint(equalTo: db.centerXAnchor),
                            iv.centerYAnchor.constraint(equalTo: db.centerYAnchor),
                            iv.widthAnchor.constraint(lessThanOrEqualTo: db.widthAnchor, multiplier: 0.7),
                            iv.heightAnchor.constraint(lessThanOrEqualTo: db.heightAnchor, multiplier: 0.7),
                        ])
                    }

                    addSubview(db)
                    deleteButtonView = db
                }

                // Color picker button
                let colorSize = Constants.colorPickerButtonSize
                let deleteButtonX = modelRect.minX + Constants.deleteButtonInset
                let colorFrame = CGRect(
                    x: deleteButtonX + Constants.deleteButtonSize + Constants.colorPickerButtonSpacing,
                    y: modelRect.minY - colorSize - Constants.deleteButtonOffset,
                    width: colorSize,
                    height: colorSize
                )
                if let cb = colorButtonView {
                    cb.frame = colorFrame
                    cb.backgroundColor = model.color
                } else {
                    let cb = UIView(frame: colorFrame)
                    cb.backgroundColor = model.color
                    cb.layer.cornerRadius = colorSize / 2
                    cb.layer.shadowColor = UIColor.black.withAlphaComponent(0.4).cgColor
                    cb.layer.shadowOffset = CGSize(width: 0, height: 4)
                    cb.layer.shadowRadius = 8
                    cb.layer.shadowOpacity = 1.0
                    cb.isUserInteractionEnabled = false

                    let iconConfig = UIImage.SymbolConfiguration(pointSize: colorSize / 2, weight: .medium)
                    if let palette = UIImage(systemName: "paintpalette.fill", withConfiguration: iconConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                        let iv = UIImageView(image: palette)
                        iv.translatesAutoresizingMaskIntoConstraints = false
                        iv.contentMode = .scaleAspectFit
                        cb.addSubview(iv)
                        NSLayoutConstraint.activate([
                            iv.centerXAnchor.constraint(equalTo: cb.centerXAnchor),
                            iv.centerYAnchor.constraint(equalTo: cb.centerYAnchor),
                            iv.widthAnchor.constraint(lessThanOrEqualTo: cb.widthAnchor, multiplier: 0.7),
                            iv.heightAnchor.constraint(lessThanOrEqualTo: cb.heightAnchor, multiplier: 0.7),
                        ])
                    }

                    addSubview(cb)
                    colorButtonView = cb
                }

                // Ensure buttons are above highlight subviews
                if let db = deleteButtonView { bringSubviewToFront(db) }
                if let cb = colorButtonView { bringSubviewToFront(cb) }
            } else {
                // Remove any button chrome when nothing is selected
                deleteButtonView?.removeFromSuperview()
                deleteButtonView = nil
                colorButtonView?.removeFromSuperview()
                colorButtonView = nil
            }
        }
    }

    /// Lightweight view representing a single highlight. Updating its frame/color is GPU-accelerated.
    class HighlightSubview: UIView {
        private let fillView = UIView()
        private let topHandle = UIView()
        private let bottomHandle = UIView()
        private let topBorder = UIView()
        private let bottomBorder = UIView()
        private var currentColor: UIColor = .systemYellow
        override init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        private func commonInit() {
            fillView.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.35)
            fillView.isUserInteractionEnabled = false
            fillView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(fillView)

            NSLayoutConstraint.activate([
                fillView.leadingAnchor.constraint(equalTo: leadingAnchor),
                fillView.trailingAnchor.constraint(equalTo: trailingAnchor),
                fillView.topAnchor.constraint(equalTo: topAnchor),
                fillView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            // Add thin border views at the top and bottom edges so we can render
            // a colored border without using the view's layer border (which can
            // obscure subviews). Borders are underneath the handle views so
            // handles appear above them.
            topBorder.translatesAutoresizingMaskIntoConstraints = false
            topBorder.backgroundColor = .clear
            addSubview(topBorder)
            bottomBorder.translatesAutoresizingMaskIntoConstraints = false
            bottomBorder.backgroundColor = .clear
            addSubview(bottomBorder)
            NSLayoutConstraint.activate([
                topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
                topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
                topBorder.topAnchor.constraint(equalTo: topAnchor),
                topBorder.heightAnchor.constraint(equalToConstant: Constants.highlightStrokeWidth),

                bottomBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
                bottomBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
                bottomBorder.bottomAnchor.constraint(equalTo: bottomAnchor),
                bottomBorder.heightAnchor.constraint(equalToConstant: Constants.highlightStrokeWidth),
            ])

            // Handles are white filled with a subtle colored stroke when selected.
            topHandle.backgroundColor = .white
            bottomHandle.backgroundColor = .white
            topHandle.layer.cornerRadius = Constants.handleCornerRadius
            bottomHandle.layer.cornerRadius = Constants.handleCornerRadius
            topHandle.translatesAutoresizingMaskIntoConstraints = false
            bottomHandle.translatesAutoresizingMaskIntoConstraints = false
            // Add handles after borders so they render above the border views
            addSubview(topHandle)
            addSubview(bottomHandle)

            NSLayoutConstraint.activate([
                topHandle.widthAnchor.constraint(equalToConstant: Constants.handleWidth),
                topHandle.heightAnchor.constraint(equalToConstant: Constants.handleHeight),
                topHandle.centerXAnchor.constraint(equalTo: centerXAnchor),
                topHandle.topAnchor.constraint(equalTo: topAnchor, constant: -Constants.handleHeight / 2),

                bottomHandle.widthAnchor.constraint(equalToConstant: Constants.handleWidth),
                bottomHandle.heightAnchor.constraint(equalToConstant: Constants.handleHeight),
                bottomHandle.centerXAnchor.constraint(equalTo: centerXAnchor),
                bottomHandle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: Constants.handleHeight / 2),
            ])
        }

        func updateColor(_ color: UIColor) {
            currentColor = color
            fillView.backgroundColor = color.withAlphaComponent(Constants.highlightOpacity)
            // If currently selected, update the visible borders and handle strokes
            if !topBorder.isHidden {
                topBorder.backgroundColor = color
                bottomBorder.backgroundColor = color
                topHandle.layer.borderColor = color.cgColor
                bottomHandle.layer.borderColor = color.cgColor
                topHandle.layer.borderWidth = Constants.handleStrokeWidth
                bottomHandle.layer.borderWidth = Constants.handleStrokeWidth
            }
        }

        func setSelected(_ selected: Bool) {
            topHandle.isHidden = !selected
            bottomHandle.isHidden = !selected
            // Use the border subviews instead of the layer border so handles
            // remain visually on top. Update their color and visibility.
            topBorder.isHidden = !selected
            bottomBorder.isHidden = !selected
            if selected {
                topBorder.backgroundColor = currentColor
                bottomBorder.backgroundColor = currentColor
                topHandle.layer.borderColor = currentColor.cgColor
                bottomHandle.layer.borderColor = currentColor.cgColor
                topHandle.layer.borderWidth = Constants.handleStrokeWidth
                bottomHandle.layer.borderWidth = Constants.handleStrokeWidth
            } else {
                topHandle.layer.borderWidth = 0.0
                bottomHandle.layer.borderWidth = 0.0
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
        var url: URL
        var highlightsBinding: Binding<[CodableHighlight]>
        var scrollOffsetYBinding: Binding<Double>

        var contentView: UIView?
        var canvasView: PDFCanvasView?
        var overlayView: HighlightOverlayView?

        // Document reference for cache invalidation and change detection
        var document: PDFDocument?
        var hasRestoredScrollPosition: Bool = false

        var initialScrollOffsetY: Double = 0

        // Models
        // (High-level HighlightModel is declared at file scope)

        // State
        var highlights: [HighlightModel] = []
        var selectedHighlightID: UUID?
        var showingColorPicker = false

        // Gesture state
        private var isDragging = false
        private var isResizing = false
        private var resizingEdge: ResizeEdge?
        private var dragStartPointInCanvas: CGPoint?
        private var dragStartRect: CGRect?
        private var resizeAnchorY: CGFloat?
        private var shouldBlockScrolling = false

        enum ResizeEdge { case top, bottom }

        init(url: URL, highlights: Binding<[CodableHighlight]>, scrollOffsetY: Binding<Double>) {
            self.url = url
            self.highlightsBinding = highlights
            self.scrollOffsetYBinding = scrollOffsetY
            super.init()
        }

        // Canvas Management
        func layoutCanvas() {
            canvasView?.setNeedsLayout()
            canvasView?.layoutIfNeeded()
            syncOverlay()
        }

        func syncOverlay() {
            guard let overlay = overlayView else { return }
            overlay.update(highlights: highlights, selectedID: selectedHighlightID, canvas: canvasView)
        }

        // Highlight Persistence
        func loadHighlights(_ codableHighlights: [CodableHighlight]) {
            // Convert stored page+fraction positions into canvas rects
            var models: [HighlightModel] = []
            for codable in codableHighlights {
                // Create canonical model from stored page+fractions
                let model = HighlightModel(id: codable.id, startPage: codable.startPage, startFraction: codable.startFraction, endPage: codable.endPage, endFraction: codable.endFraction, color: UIColor(hex: codable.colorHex) ?? .purple)
                models.append(model)
            }
            highlights = models
            syncOverlay()
        }

        func getHighlights() -> [CodableHighlight] {
            // Already stored as page+fractions in the canonical model
            return highlights.map { h in
                CodableHighlight(id: h.id, startPage: h.startPage, startFraction: h.startFraction, endPage: h.endPage, endFraction: h.endFraction, colorHex: h.color.toHex())
            }
        }

        // MARK: - Coordinate conversion helpers
        private func canvasRectToPageRange(_ rect: CGRect) -> (Int, CGFloat, Int, CGFloat) {
            guard let canvas = canvasView, !canvas.pageFrames.isEmpty else {
                // Fallback: treat entire canvas as page 0
                let height = max(1, canvasView?.bounds.height ?? 1)
                let startFrac = max(0, min(1, rect.minY / height))
                let endFrac = max(0, min(1, rect.maxY / height))
                return (0, startFrac, 0, endFrac)
            }

            // Find start page
            var startPage = 0
            var startFrac: CGFloat = 0
            var endPage = 0
            var endFrac: CGFloat = 0

            // Iterate pages to find intersections
            for (pageIndex, frame) in canvas.pageFrames.sorted(by: { $0.key < $1.key }) {
                let pageRect = frame
                if rect.minY >= pageRect.minY && rect.minY <= pageRect.maxY {
                    startPage = pageIndex
                    startFrac = (rect.minY - pageRect.minY) / max(1, pageRect.height)
                }
                if rect.maxY >= pageRect.minY && rect.maxY <= pageRect.maxY {
                    endPage = pageIndex
                    endFrac = (rect.maxY - pageRect.minY) / max(1, pageRect.height)
                }
            }

            // Clamp
            startFrac = max(0, min(1, startFrac))
            endFrac = max(0, min(1, endFrac))
            return (startPage, startFrac, endPage, endFrac)
        }

        private func pageRangeToCanvasRect(startPage: Int, startFraction: CGFloat, endPage: Int, endFraction: CGFloat) -> CGRect? {
            guard let canvas = canvasView, !canvas.pageFrames.isEmpty else {
                // Fallback: approximate using canvas height
                guard let height = canvasView?.bounds.height, height > 0 else { return nil }
                let y = startFraction * height
                let h = max(Constants.minHighlightHeight, (endFraction * height) - (startFraction * height))
                return CGRect(x: 0, y: y, width: canvasView?.bounds.width ?? 0, height: h)
            }

            guard let startFrame = canvas.pageFrames[startPage], let endFrame = canvas.pageFrames[endPage] else { return nil }
            let y = startFrame.minY + startFraction * startFrame.height
            let maxY = endFrame.minY + endFraction * endFrame.height
            let height = max(Constants.minHighlightHeight, maxY - y)
            return CGRect(x: 0, y: y, width: canvas.bounds.width, height: height)
        }

        private func syncHighlightsToBinding() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.highlightsBinding.wrappedValue = self.getHighlights()
            }
        }

        // Highlight Management
        func addHighlight() {
            guard let canvas = canvasView else { return }
            if canvas.pageFrames.isEmpty { layoutCanvas() }
            guard let scroll = canvas.superview?.superview as? UIScrollView else { return }
            let visibleCenterInScroll = CGPoint(x: scroll.bounds.midX, y: scroll.bounds.midY)
            let centerInCanvas = canvas.convert(visibleCenterInScroll, from: scroll)
            // Determine page/fraction for a centered default-size highlight
            let defaultRect = CGRect(x: 0, y: centerInCanvas.y - Constants.defaultHighlightHeight / 2, width: canvas.bounds.width, height: Constants.defaultHighlightHeight)
            let (sPage, sFrac, ePage, eFrac) = canvasRectToPageRange(defaultRect)
            let h = HighlightModel(id: UUID(), startPage: sPage, startFraction: sFrac, endPage: ePage, endFraction: eFrac, color: .purple)
            // Ensure canonical rect exists
            if pageRangeToCanvasRect(startPage: sPage, startFraction: sFrac, endPage: ePage, endFraction: eFrac) != nil {
                // No-op; the rect will be computed by overlay when rendering
            }
            highlights.append(h)
            syncOverlay()
            syncHighlightsToBinding()
        }

        // Gesture Handlers
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let canvas = canvasView, let overlay = overlayView else { return }
            let location = gesture.location(in: canvas)
            if let selectedID = selectedHighlightID,
               let selectedHighlight = highlights.first(where: { $0.id == selectedID }) {
                let selRect = selectedHighlight.rect(in: canvas)
                if isDeleteButtonTapped(at: location, for: selRect) {
                    highlights.removeAll { $0.id == selectedID }
                    selectedHighlightID = nil
                    overlay.update(highlights: highlights, selectedID: nil, canvas: canvasView)
                    syncHighlightsToBinding()
                    return
                }
                if isColorPickerButtonTapped(at: location, for: selRect) {
                    showColorPicker(for: selectedHighlight)
                    return
                }
            }
            var foundHighlight = false
            for h in highlights {
                let hitArea = h.rect(in: canvas).insetBy(dx: -Constants.highlightTapHitSlop, dy: -Constants.highlightTapHitSlop)
                if hitArea.contains(location) {
                    selectedHighlightID = h.id
                    overlay.selectedID = selectedHighlightID
                    foundHighlight = true
                    break
                }
            }
            if !foundHighlight { selectedHighlightID = nil }
            overlay.update(highlights: highlights, selectedID: selectedHighlightID, canvas: canvasView)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let canvas = canvasView, let overlay = overlayView else { return }
            let location = gesture.location(in: canvas)
            switch gesture.state {
            case .began:
                shouldBlockScrolling = true
                var foundHandle = false
                for h in highlights {
                    let rect = h.rect(in: canvas)
                    if let edge = detectEdgeHandle(at: location, for: rect) {
                        selectedHighlightID = h.id
                        overlay.selectedID = selectedHighlightID
                        isResizing = true
                        resizingEdge = edge
                        dragStartPointInCanvas = location
                        dragStartRect = rect
                        resizeAnchorY = (edge == .top) ? rect.maxY : rect.minY
                        foundHandle = true
                        break
                    }
                }
                if !foundHandle {
                    for h in highlights {
                        let rect = h.rect(in: canvas)
                        let hitArea = rect.insetBy(dx: -Constants.highlightTapHitSlop, dy: -Constants.highlightTapHitSlop)
                        if hitArea.contains(location) {
                            selectedHighlightID = h.id
                            overlay.selectedID = selectedHighlightID
                            isDragging = true
                            dragStartPointInCanvas = location
                            dragStartRect = rect
                            foundHandle = true
                            break
                        }
                    }
                    if !foundHandle { shouldBlockScrolling = false }
                }
                if isDragging || isResizing { if let scroll = canvas.superview?.superview as? UIScrollView { scroll.isScrollEnabled = false } }
                overlay.update(highlights: highlights, selectedID: selectedHighlightID, canvas: canvasView)
            case .changed:
                guard let startPoint = dragStartPointInCanvas, let startRect = dragStartRect, let selectedID = selectedHighlightID else { return }
                guard isDragging || isResizing else { return }
                guard let hIndex = highlights.firstIndex(where: { $0.id == selectedID }) else { return }
                guard let canvas = canvasView else { return }
                let dy = location.y - startPoint.y
                if isDragging {
                    let newY = startRect.origin.y + dy
                    // Compute new rect in canvas coordinates and convert to page fractions
                    let newRect = CGRect(x: 0, y: max(0, min(newY, max(0, canvas.bounds.height - (startRect.height)))), width: canvas.bounds.width, height: startRect.height)
                    let (sPage, sFrac, ePage, eFrac) = canvasRectToPageRange(newRect)
                    highlights[hIndex].set(fromPageRange: sPage, startFraction: sFrac, endPage: ePage, endFraction: eFrac)
                } else if isResizing, let anchorY = resizeAnchorY {
                    let minY = min(anchorY, location.y)
                    let maxY = max(anchorY, location.y)
                    let newRect = CGRect(x: 0, y: minY, width: canvas.bounds.width, height: max(Constants.minHighlightHeight, maxY - minY))
                    let (sPage, sFrac, ePage, eFrac) = canvasRectToPageRange(newRect)
                    highlights[hIndex].set(fromPageRange: sPage, startFraction: sFrac, endPage: ePage, endFraction: eFrac)
                } else { return }
                overlay.update(highlights: highlights, selectedID: selectedHighlightID, canvas: canvasView)
            case .ended, .cancelled, .failed:
                // Nothing extra needed here; highlights already canonicalized during interactions.

                syncHighlightsToBinding()
                isDragging = false; isResizing = false; resizingEdge = nil; dragStartPointInCanvas = nil; dragStartRect = nil; resizeAnchorY = nil; shouldBlockScrolling = false
                if let scroll = canvas.superview?.superview as? UIScrollView { scroll.isScrollEnabled = true }
            default: break
            }
        }

        // Helpers
        private func detectEdgeHandle(at point: CGPoint, for rect: CGRect) -> ResizeEdge? {
            let centerX = rect.midX
            // Create base handle rects centered horizontally
            let topHandle = CGRect(x: centerX - Constants.handleWidth / 2, y: rect.minY - Constants.handleHeight / 2, width: Constants.handleWidth, height: Constants.handleHeight)
            let bottomHandle = CGRect(x: centerX - Constants.handleWidth / 2, y: rect.maxY - Constants.handleHeight / 2, width: Constants.handleWidth, height: Constants.handleHeight)

            // Expand horizontally by handleHitSlop + extra horizontal, and vertically by base slop plus asymmetric extras
            let topHitArea = topHandle.insetBy(dx: -(Constants.handleHitSlop + Constants.handleHitExtraHorizontal), dy: -(Constants.handleHitSlop + Constants.handleHitExtraTop))
            if topHitArea.contains(point) { return .top }

            let bottomHitArea = bottomHandle.insetBy(dx: -(Constants.handleHitSlop + Constants.handleHitExtraHorizontal), dy: -(Constants.handleHitSlop + Constants.handleHitExtraBottom))
            if bottomHitArea.contains(point) { return .bottom }
            return nil
        }

        private func isDeleteButtonTapped(at point: CGPoint, for rect: CGRect) -> Bool {
            let deleteButton = CGRect(x: rect.minX + Constants.deleteButtonInset, y: rect.minY - Constants.deleteButtonSize - Constants.deleteButtonOffset, width: Constants.deleteButtonSize, height: Constants.deleteButtonSize)
            return deleteButton.contains(point)
        }

        private func isColorPickerButtonTapped(at point: CGPoint, for rect: CGRect) -> Bool {
            let deleteButtonX = rect.minX + Constants.deleteButtonInset
            let colorPickerButton = CGRect(x: deleteButtonX + Constants.deleteButtonSize + Constants.colorPickerButtonSpacing, y: rect.minY - Constants.colorPickerButtonSize - Constants.deleteButtonOffset, width: Constants.colorPickerButtonSize, height: Constants.colorPickerButtonSize)
            return colorPickerButton.contains(point)
        }

        private func showColorPicker(for highlight: HighlightModel) {
            guard let canvas = canvasView else { return }
            let pickerView = ColorPickerView(selectedColor: highlight.color) { [weak self] color in self?.updateHighlightColor(highlight.id, to: color) }
            let rect = highlight.rect(in: canvas)
            let deleteButtonX = rect.minX + Constants.deleteButtonInset
            let buttonX = deleteButtonX + Constants.deleteButtonSize + Constants.colorPickerButtonSpacing
            let buttonY = rect.minY - Constants.colorPickerButtonSize - Constants.deleteButtonOffset
            let buttonCenter = canvas.convert(CGPoint(x: buttonX + Constants.colorPickerButtonSize / 2, y: buttonY + Constants.colorPickerButtonSize / 2), to: nil)
            pickerView.show(from: buttonCenter, in: canvas)
        }

        private func updateHighlightColor(_ highlightID: UUID, to color: UIColor) {
            guard let index = highlights.firstIndex(where: { $0.id == highlightID }) else { return }
            highlights[index].color = color
            syncOverlay()
            syncHighlightsToBinding()
        }

        // UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { return contentView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { syncOverlay() }
        func scrollViewDidScroll(_ scrollView: UIScrollView) { syncOverlay(); scrollOffsetYBinding.wrappedValue = Double(scrollView.contentOffset.y) }

        // UIGestureRecognizerDelegate
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { return !shouldBlockScrolling }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer, let canvas = canvasView {
                let loc = gestureRecognizer.location(in: canvas)
                return highlights.contains { h in
                    let rect = h.rect(in: canvas)
                    let hitArea = rect.insetBy(dx: -Constants.highlightTapHitSlop, dy: -Constants.highlightTapHitSlop)
                    return detectEdgeHandle(at: loc, for: rect) != nil || hitArea.contains(loc)
                }
            }
            return true
        }
    }
}

// MARK: - Color Picker View

class ColorPickerView: UIView {
    private let colors: [UIColor] = [.purple, .systemBlue, .systemGreen, .systemRed, .systemYellow]
    private let selectedColor: UIColor
    private let onColorSelected: (UIColor) -> Void
    private var backdropView: UIView?
    
    init(selectedColor: UIColor, onColorSelected: @escaping (UIColor) -> Void) {
        self.selectedColor = selectedColor
        self.onColorSelected = onColorSelected
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 16
        layer.shadowOpacity = 0.3
        
        // Create horizontal stack of color buttons
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        for color in colors {
            let button = createColorButton(color: color)
            stackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    private func createColorButton(color: UIColor) -> UIView {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = color
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.white.cgColor
        
        // Add shadow for depth
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        
        // If this is the currently selected color, add a checkmark
        if color.toHex() == selectedColor.toHex() {
            let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
            checkmark.tintColor = .white
            checkmark.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(checkmark)
            
            NSLayoutConstraint.activate([
                checkmark.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                checkmark.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
        }
        
        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return button
    }
    
    @objc private func colorButtonTapped(_ sender: UIButton) {
        guard let color = sender.backgroundColor else { return }
        onColorSelected(color)
        dismiss()
    }
    
    func show(from point: CGPoint, in view: UIView) {
        guard let window = view.window else { return }
        
        // Create backdrop
        let backdrop = UIView(frame: window.bounds)
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        backdrop.alpha = 0
        self.backdropView = backdrop
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backdropTapped))
        backdrop.addGestureRecognizer(tapGesture)
        
        window.addSubview(backdrop)
        
        // Add color picker view
        self.translatesAutoresizingMaskIntoConstraints = false
        self.alpha = 0
        self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        window.addSubview(self)
        
        // Calculate picker size (force layout to get size)
        let tempSize = self.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let pickerWidth = tempSize.width
        let pickerHeight = tempSize.height
        let margin: CGFloat = 16
        
        // Calculate optimal position
        var centerX = point.x
        var bottomY = point.y - 8
        
        // Check horizontal bounds
        let minX = pickerWidth / 2 + margin
        let maxX = window.bounds.width - pickerWidth / 2 - margin
        centerX = max(minX, min(maxX, centerX))
        
        // Check vertical bounds - prefer above, but show below if needed
        let minY = pickerHeight + margin
        if bottomY < minY {
            // Not enough space above, show below instead
            bottomY = point.y + 32 + pickerHeight
        }
        
        // Ensure doesn't go off bottom
        let maxY = window.bounds.height - margin
        bottomY = min(maxY, bottomY)
        
        // Position with constraints
        NSLayoutConstraint.activate([
            self.centerXAnchor.constraint(equalTo: window.leadingAnchor, constant: centerX),
            self.bottomAnchor.constraint(equalTo: window.topAnchor, constant: bottomY)
        ])
        
        // Animate in
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            backdrop.alpha = 1
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    @objc private func backdropTapped() {
        dismiss()
    }
    
    private func dismiss() {
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseIn) {
            self.backdropView?.alpha = 0
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            self.backdropView?.removeFromSuperview()
            self.removeFromSuperview()
        }
    }
}

// MARK: - UIColor Hex Conversion

extension UIColor {
    /// Initialize UIColor from hex string
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    /// Convert UIColor to hex string
    func toHex() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255)
        return String(format: "#%06X", rgb)
    }
}

