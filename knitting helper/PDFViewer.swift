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
    
    class HighlightOverlayView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            backgroundColor = .clear
            contentMode = .redraw
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            isOpaque = false
            backgroundColor = .clear
            contentMode = .redraw
        }
        
        var highlights: [Coordinator.Highlight] = []
        var selectedID: UUID?
        
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
                // Constant fill alpha
                (h.color.withAlphaComponent(0.3)).setFill()
                path.fill()
                // If selected, draw a subtle border with drop shadow and edge handles
                if h.id == selectedID {
                    ctx.saveGState()
                    // Add subtle drop shadow
                    ctx.setShadow(offset: CGSize(width: 1, height: 4), blur: 4, color: UIColor.black.withAlphaComponent(0.2).cgColor)
                    let strokePath = UIBezierPath(rect: viewRect.insetBy(dx: -0.5, dy: -0.5))
                    (h.color.withAlphaComponent(0.5)).setStroke()
                    strokePath.lineWidth = 1.5
                    strokePath.stroke()
                    ctx.restoreGState()
                    
                    // Draw top and bottom edge handles
                    let handleWidth: CGFloat = 60
                    let handleHeight: CGFloat = 8
                    let centerX = viewRect.midX
                    
                    // Top handle
                    let topHandle = CGRect(x: centerX - handleWidth/2, y: viewRect.minY - handleHeight/2, width: handleWidth, height: handleHeight)
                    ctx.saveGState()
                    ctx.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                    let topPath = UIBezierPath(roundedRect: topHandle, cornerRadius: 4)
                    UIColor.white.setFill()
                    topPath.fill()
                    h.color.setStroke()
                    topPath.lineWidth = 2
                    topPath.stroke()
                    ctx.restoreGState()
                    
                    // Bottom handle
                    let bottomHandle = CGRect(x: centerX - handleWidth/2, y: viewRect.maxY - handleHeight/2, width: handleWidth, height: handleHeight)
                    ctx.saveGState()
                    ctx.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                    let bottomPath = UIBezierPath(roundedRect: bottomHandle, cornerRadius: 4)
                    UIColor.white.setFill()
                    bottomPath.fill()
                    h.color.setStroke()
                    bottomPath.lineWidth = 2
                    bottomPath.stroke()
                    ctx.restoreGState()
                }
            }
            ctx.restoreGState()
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
        let url: URL
        weak var contentView: UIView?
        weak var canvasView: PDFCanvasView?
        weak var overlayView: HighlightOverlayView?
        var document: PDFDocument?
        
        // Explicit highlight model
        struct Highlight: Identifiable {
            let id: UUID
            var rectInCanvas: CGRect // in canvas coordinates
            var color: UIColor
        }
        
        var highlights: [Highlight] = []
        var selectedHighlightID: UUID?
        var isDragging = false
        var isResizing = false
        var resizingEdge: ResizeEdge?
        var dragStartPointInCanvas: CGPoint?
        var dragStartRect: CGRect?
        var resizeAnchorY: CGFloat? // The fixed edge Y position during resize
        var shouldBlockScrolling = false // Set to true when gesture starts on highlight/handle
        
        enum ResizeEdge {
            case top, bottom
        }
        
        init(url: URL) { self.url = url }
        
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
            let highlightHeight: CGFloat = 30
            let y = visible.midY - highlightHeight / 2
            let rectInCanvas = CGRect(x: 0, y: y, width: canvas.bounds.width, height: highlightHeight)
            let h = Highlight(id: UUID(), rectInCanvas: rectInCanvas, color: .purple)
            highlights.append(h)
            syncOverlay()
        }
        
        // MARK: Gestures
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let canvas = canvasView, let overlay = overlayView else { return }
            let location = gesture.location(in: canvas)
            
            // Check if tap is on any highlight (in canvas coordinates)
            var foundHighlight = false
            for h in highlights {
                if h.rectInCanvas.insetBy(dx: -14, dy: -14).contains(location) {
                    selectedHighlightID = h.id
                    overlay.selectedID = selectedHighlightID
                    foundHighlight = true
                    break
                }
            }
            
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
                        if h.rectInCanvas.insetBy(dx: -14, dy: -14).contains(location) {
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
                    if newRect.height < 10 {
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
        
        func detectEdgeHandle(at point: CGPoint, for rect: CGRect, handleSize: CGFloat = 30) -> ResizeEdge? {
            // Check if near top edge
            if abs(point.y - rect.minY) < handleSize && point.x >= rect.minX && point.x <= rect.maxX {
                return .top
            }
            // Check if near bottom edge
            if abs(point.y - rect.maxY) < handleSize && point.x >= rect.minX && point.x <= rect.maxX {
                return .bottom
            }
            return nil
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
                    detectEdgeHandle(at: loc, for: h.rectInCanvas) != nil ||
                    h.rectInCanvas.insetBy(dx: -14, dy: -14).contains(loc)
                }
            }
            return true
        }
    }
}

