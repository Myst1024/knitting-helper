//
//  PDFViewer.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI
import UIKit
import PDFKit

struct PDFViewer: View {
    let url: URL
    @Binding var shouldAddHighlight: Bool
    
    var body: some View {
        PDFKitView(url: url, shouldAddHighlight: $shouldAddHighlight)
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var shouldAddHighlight: Bool
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .systemBackground
        
        // Load document
        let document = PDFDocument(url: url)
        context.coordinator.document = document
        
        // Build canvas container (contentView) that will be zoomed
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        context.coordinator.contentView = contentView
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor) // width follows scrollView; height computed after layout
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
        
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        // Gesture recognizers attached to scrollView (for tap/pan on highlights)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        scrollView.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(pan)
        
        // Force initial layout to compute canvas size
        DispatchQueue.main.async {
            context.coordinator.layoutCanvas()
            context.coordinator.syncOverlay()
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Add highlight when requested
        if shouldAddHighlight {
            context.coordinator.addHighlight()
            context.coordinator.syncOverlay()
            DispatchQueue.main.async { shouldAddHighlight = false }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    
    // MARK: - Canvas and Overlay
    
    /// Custom view that renders PDF pages using CATiledLayer for efficient multi-page rendering.
    /// Pages are stacked vertically with full-width layout.
    class PDFCanvasView: UIView {
        var document: PDFDocument? { didSet { setNeedsLayout(); setNeedsDisplay() } }
        var pageFrames: [Int: CGRect] = [:] // canvas coordinates
        
        override class var layerClass: AnyClass { CATiledLayer.self }
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let tiled = layer as? CATiledLayer {
                tiled.levelsOfDetail = 4
                tiled.levelsOfDetailBias = 4
                tiled.tileSize = CGSize(width: 512, height: 512)
            }
            isOpaque = true
            backgroundColor = .clear
            contentMode = .redraw
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            computePageFrames()
            setNeedsDisplay()
        }
        
        private func computePageFrames() {
            pageFrames.removeAll()
            guard let doc = document else { return }
            // Compute width equal to self.bounds.width; scale each page to that width and stack vertically
            let targetWidth = bounds.width > 0 ? bounds.width : 1
            var y: CGFloat = 0
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let media = page.bounds(for: .mediaBox)
                let scale = targetWidth / max(media.width, 1)
                let pageHeight = media.height * scale
                let frame = CGRect(x: 0, y: y, width: targetWidth, height: pageHeight)
                pageFrames[i] = frame
                y += pageHeight
            }
            // Update intrinsic/content size via constraints if inside a container
            if let heightConstraint = constraints.first(where: { $0.firstAttribute == .height }) {
                heightConstraint.constant = y
            } else {
                let c = heightAnchor.constraint(equalToConstant: y)
                c.priority = .required
                c.isActive = true
            }
        }
        
        override func draw(_ rect: CGRect) {
            guard let ctx = UIGraphicsGetCurrentContext(), let doc = document else { return }
            
            // Clear tile background (keep canvas transparent; pages draw their own white background)
            ctx.setFillColor(UIColor.clear.cgColor)
            ctx.fill(rect)
            
            for (index, frame) in pageFrames {
                if rect.intersects(frame), let page = doc.page(at: index) {
                    ctx.saveGState()
                    // Fill page background
                    UIColor.white.setFill()
                    UIBezierPath(rect: frame).fill()
                    // Compute transform from PDF page space to frame
                    let media = page.bounds(for: .mediaBox)
                    let sx = frame.width / media.width
                    let sy = frame.height / media.height
                    ctx.translateBy(x: frame.minX, y: frame.minY)
                    ctx.scaleBy(x: sx, y: sy)
                    // PDF page draw uses Quartz coordinates (origin bottom-left), flip vertically
                    ctx.translateBy(x: 0, y: media.height)
                    ctx.scaleBy(x: 1, y: -1)
                    page.draw(with: .mediaBox, to: ctx)
                    ctx.restoreGState()
                }
            }
        }
    }
    
    
    /// Transparent overlay view that draws highlights, handles, and delete buttons on top of the PDF canvas.
    /// All drawing is done in canvas coordinate space.
    class HighlightOverlayView: UIView {
        // MARK: - Properties
        var highlights: [Coordinator.Highlight] = []
        var selectedID: UUID?
        
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
            guard let ctx = UIGraphicsGetCurrentContext() else { return }
            
            // Clear overlay to avoid trails
            ctx.setBlendMode(.clear)
            ctx.fill(rect)
            ctx.setBlendMode(.normal)
            
            ctx.saveGState()
            for h in highlights {
                let viewRect = h.rectInCanvas
                let path = UIBezierPath(rect: viewRect)
                h.color.withAlphaComponent(Coordinator.Constants.highlightOpacity).setFill()
                path.fill()
                
                // If selected, draw a subtle border with drop shadow and edge handles
                if h.id == selectedID {
                    ctx.saveGState()
                    ctx.setShadow(
                        offset: CGSize(width: 1, height: 4),
                        blur: 4,
                        color: UIColor.black.withAlphaComponent(0.2).cgColor
                    )
                    let strokePath = UIBezierPath(rect: viewRect.insetBy(dx: -0.5, dy: -0.5))
                    h.color.withAlphaComponent(Coordinator.Constants.selectedHighlightOpacity).setStroke()
                    strokePath.lineWidth = Coordinator.Constants.highlightStrokeWidth
                    strokePath.stroke()
                    ctx.restoreGState()
                    
                    // Draw top and bottom edge handles
                    drawEdgeHandle(at: viewRect.minY, centerX: viewRect.midX, color: h.color, in: ctx)
                    drawEdgeHandle(at: viewRect.maxY, centerX: viewRect.midX, color: h.color, in: ctx)
                    
                    // Draw delete button on the left side, slightly above the highlight
                    drawDeleteButton(for: viewRect, in: ctx)
                }
            }
            ctx.restoreGState()
        }
        
        // MARK: - Drawing Helpers
        private func drawEdgeHandle(at y: CGFloat, centerX: CGFloat, color: UIColor, in ctx: CGContext) {
            let handleRect = CGRect(
                x: centerX - Coordinator.Constants.handleWidth / 2,
                y: y - Coordinator.Constants.handleHeight / 2,
                width: Coordinator.Constants.handleWidth,
                height: Coordinator.Constants.handleHeight
            )
            
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 2,
                color: UIColor.black.withAlphaComponent(0.3).cgColor
            )
            
            let path = UIBezierPath(roundedRect: handleRect, cornerRadius: Coordinator.Constants.handleCornerRadius)
            UIColor.white.setFill()
            path.fill()
            color.setStroke()
            path.lineWidth = Coordinator.Constants.handleStrokeWidth
            path.stroke()
            ctx.restoreGState()
        }
        
        private func drawDeleteButton(for rect: CGRect, in ctx: CGContext) {
            let size = Coordinator.Constants.deleteButtonSize
            let buttonRect = CGRect(
                x: rect.minX + Coordinator.Constants.deleteButtonInset,
                y: rect.minY - size - Coordinator.Constants.deleteButtonOffset,
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
                trashIcon.draw(in: iconRect, blendMode: .normal, alpha: Coordinator.Constants.deleteIconOpacity)
            }
        }
    }
    
    // MARK: - Coordinator
    
    /// Coordinator that manages PDF viewing state, highlights, and gesture interactions.
    /// All highlight geometry is stored in canvas coordinate space for simplicity.
    class Coordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
        // MARK: - Constants
        enum Constants {
            static let highlightOpacity: CGFloat = 0.3
            static let selectedHighlightOpacity: CGFloat = 0.5
            static let highlightStrokeWidth: CGFloat = 1.5
            static let highlightTapHitSlop: CGFloat = 14
            
            static let handleWidth: CGFloat = 60
            static let handleHeight: CGFloat = 8
            static let handleHitSlop: CGFloat = 20
            static let handleCornerRadius: CGFloat = 4
            static let handleStrokeWidth: CGFloat = 2
            
            static let deleteButtonSize: CGFloat = 24
            static let deleteButtonOffset: CGFloat = 8
            static let deleteButtonInset: CGFloat = 10
            static let deleteIconOpacity: CGFloat = 0.8
            
            static let defaultHighlightHeight: CGFloat = 30
            static let minHighlightHeight: CGFloat = 10
        }
        
        // MARK: - Properties
        let url: URL
        weak var contentView: UIView?
        weak var canvasView: PDFCanvasView?
        weak var overlayView: HighlightOverlayView?
        var document: PDFDocument?
        
        // MARK: - Models
        
        /// Represents a highlight rectangle in canvas coordinate space.
        /// Full-width highlighting with vertical-only resizing.
        struct Highlight: Identifiable {
            let id: UUID
            var rectInCanvas: CGRect
            var color: UIColor
        }
        
        // MARK: - State
        var highlights: [Highlight] = []
        var selectedHighlightID: UUID?
        
        // Gesture state
        private var isDragging = false
        private var isResizing = false
        private var resizingEdge: ResizeEdge?
        private var dragStartPointInCanvas: CGPoint?
        private var dragStartRect: CGRect?
        private var resizeAnchorY: CGFloat?
        private var shouldBlockScrolling = false
        
        enum ResizeEdge {
            case top, bottom
        }
        
        init(url: URL) {
            self.url = url
        }
        
        // MARK: - Canvas Management
        func layoutCanvas() {
            canvasView?.setNeedsLayout()
            canvasView?.layoutIfNeeded()
            syncOverlay()
        }
        
        func syncOverlay() {
            guard let overlay = overlayView, let canvas = canvasView else { return }
            overlay.frame = canvas.frame
            overlay.highlights = highlights
            overlay.selectedID = selectedHighlightID
            overlay.setNeedsDisplay()
        }
        
        // MARK: - Highlight Management
        func addHighlight() {
            guard let canvas = canvasView else { return }
            // Ensure canvas has computed page frames
            if canvas.pageFrames.isEmpty {
                layoutCanvas()
            }
            // Use current visible area to place highlight
            guard let scroll = canvas.superview?.superview as? UIScrollView else { return }
            let visible = CGRect(origin: scroll.contentOffset, size: scroll.bounds.size)
            
            // Create full-width highlight in center of visible area
            let y = visible.midY - Constants.defaultHighlightHeight / 2
            let rectInCanvas = CGRect(x: 0, y: y, width: canvas.bounds.width, height: Constants.defaultHighlightHeight)
            let h = Highlight(id: UUID(), rectInCanvas: rectInCanvas, color: .purple)
            highlights.append(h)
            syncOverlay()
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let canvas = canvasView, let overlay = overlayView else { return }
            let location = gesture.location(in: canvas)
            
            // Priority 1: Check delete button tap
            if let selectedID = selectedHighlightID,
               let selectedHighlight = highlights.first(where: { $0.id == selectedID }),
               isDeleteButtonTapped(at: location, for: selectedHighlight.rectInCanvas) {
                highlights.removeAll { $0.id == selectedID }
                selectedHighlightID = nil
                overlay.selectedID = nil
                overlay.highlights = highlights
                overlay.setNeedsDisplay()
                return
            }
            
            // Priority 2: Check highlight tap (with extended hit area)
            var foundHighlight = false
            for h in highlights {
                let hitArea = h.rectInCanvas.insetBy(dx: -Constants.highlightTapHitSlop, dy: -Constants.highlightTapHitSlop)
                if hitArea.contains(location) {
                    selectedHighlightID = h.id
                    overlay.selectedID = selectedHighlightID
                    foundHighlight = true
                    break
                }
            }
            
            // Deselect if tapped outside
            if !foundHighlight {
                selectedHighlightID = nil
                overlay.selectedID = nil
            }
            overlay.setNeedsDisplay()
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let canvas = canvasView, let overlay = overlayView else { return }
            let location = gesture.location(in: canvas)
            
            switch gesture.state {
            case .began:
                shouldBlockScrolling = true
                
                // PRIORITY 1: Check if starting on a top/bottom edge handle of any highlight
                var foundHandle = false
                for h in highlights {
                    if let edge = detectEdgeHandle(at: location, for: h.rectInCanvas) {
                        selectedHighlightID = h.id
                        overlay.selectedID = selectedHighlightID
                        isResizing = true
                        resizingEdge = edge
                        dragStartPointInCanvas = location
                        dragStartRect = h.rectInCanvas
                        // Set the anchor Y as the opposite edge
                        resizeAnchorY = (edge == .top) ? h.rectInCanvas.maxY : h.rectInCanvas.minY
                        foundHandle = true
                        break
                    }
                }
                
                // PRIORITY 2: If not on a handle, check if on highlight body
                if !foundHandle {
                    for h in highlights {
                        let hitArea = h.rectInCanvas.insetBy(dx: -Constants.highlightTapHitSlop, dy: -Constants.highlightTapHitSlop)
                        if hitArea.contains(location) {
                            selectedHighlightID = h.id
                            overlay.selectedID = selectedHighlightID
                            isDragging = true
                            dragStartPointInCanvas = location
                            dragStartRect = h.rectInCanvas
                            foundHandle = true
                            break
                        }
                    }
                    
                    if !foundHandle {
                        shouldBlockScrolling = false
                    }
                }
                
                // Disable scroll while dragging or resizing
                if isDragging || isResizing {
                    if let scroll = canvas.superview?.superview as? UIScrollView { scroll.isScrollEnabled = false }
                }
                
                overlay.setNeedsDisplay()
            case .changed:
                guard let startPoint = dragStartPointInCanvas, let startRect = dragStartRect, let selectedID = selectedHighlightID else { return }
                guard isDragging || isResizing else { return }
                guard let hIndex = highlights.firstIndex(where: { $0.id == selectedID }) else { return }
                guard let canvas = canvasView else { return }
                
                let dy = location.y - startPoint.y
                var newRect: CGRect
                
                if isDragging {
                    // Move the entire highlight vertically only
                    newRect = CGRect(x: 0, y: startRect.minY + dy, width: canvas.bounds.width, height: startRect.height)
                } else if isResizing, let anchorY = resizeAnchorY {
                    // Resize from top or bottom edge
                    let minY = min(anchorY, location.y)
                    let maxY = max(anchorY, location.y)
                    
                    newRect = CGRect(x: 0, y: minY, width: canvas.bounds.width, height: maxY - minY)
                    
                    // Ensure minimum height
                    if newRect.height < Constants.minHighlightHeight {
                        return
                    }
                } else {
                    return
                }
                
                highlights[hIndex].rectInCanvas = newRect
                overlay.highlights = highlights
                overlay.setNeedsDisplay()
            case .ended, .cancelled, .failed:
                isDragging = false
                isResizing = false
                resizingEdge = nil
                dragStartPointInCanvas = nil
                dragStartRect = nil
                resizeAnchorY = nil
                shouldBlockScrolling = false
                if let scroll = canvas.superview?.superview as? UIScrollView { scroll.isScrollEnabled = true }
            default: break
            }
        }
        
        // MARK: - Helper Methods
        private func detectEdgeHandle(at point: CGPoint, for rect: CGRect) -> ResizeEdge? {
            let centerX = rect.midX
            
            // Top handle bounds with hitslop
            let topHandle = CGRect(
                x: centerX - Constants.handleWidth / 2,
                y: rect.minY - Constants.handleHeight / 2,
                width: Constants.handleWidth,
                height: Constants.handleHeight
            )
            let topHitArea = topHandle.insetBy(dx: -Constants.handleHitSlop, dy: -Constants.handleHitSlop)
            if topHitArea.contains(point) {
                return .top
            }
            
            // Bottom handle bounds with hitslop
            let bottomHandle = CGRect(
                x: centerX - Constants.handleWidth / 2,
                y: rect.maxY - Constants.handleHeight / 2,
                width: Constants.handleWidth,
                height: Constants.handleHeight
            )
            let bottomHitArea = bottomHandle.insetBy(dx: -Constants.handleHitSlop, dy: -Constants.handleHitSlop)
            if bottomHitArea.contains(point) {
                return .bottom
            }
            
            return nil
        }
        
        private func isDeleteButtonTapped(at point: CGPoint, for rect: CGRect) -> Bool {
            let deleteButton = CGRect(
                x: rect.minX + Constants.deleteButtonInset,
                y: rect.minY - Constants.deleteButtonSize - Constants.deleteButtonOffset,
                width: Constants.deleteButtonSize,
                height: Constants.deleteButtonSize
            )
            return deleteButton.contains(point)
        }
        
        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return contentView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) { syncOverlay() }
        func scrollViewDidScroll(_ scrollView: UIScrollView) { syncOverlay() }
        
        // MARK: - UIGestureRecognizerDelegate
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Block scrollView gestures when interacting with highlights/handles
            return !shouldBlockScrolling
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Let pan begin only if it starts on a highlight or edge handle; taps can always begin
            if gestureRecognizer is UIPanGestureRecognizer, let canvas = canvasView {
                let loc = gestureRecognizer.location(in: canvas)
                
                // Check if on any highlight or edge handle (in canvas coordinates)
                return highlights.contains { h in
                    let hitArea = h.rectInCanvas.insetBy(dx: -Constants.highlightTapHitSlop, dy: -Constants.highlightTapHitSlop)
                    return detectEdgeHandle(at: loc, for: h.rectInCanvas) != nil || hitArea.contains(loc)
                }
            }
            return true
        }
    }
}

