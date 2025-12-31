//
//  PDFViewCoordinator.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI
import UIKit
import PDFKit

class PDFViewCoordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleOrientationChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    @objc func handleOrientationChange() {
        // Ensure layout and overlay sync run on main thread after rotation/layout settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            self.layoutCanvas()
            self.syncOverlay()
        }
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
            let h = max(PDFConstants.minHighlightHeight, (endFraction * height) - (startFraction * height))
            return CGRect(x: 0, y: y, width: canvasView?.bounds.width ?? 0, height: h)
        }

        guard let startFrame = canvas.pageFrames[startPage], let endFrame = canvas.pageFrames[endPage] else { return nil }
        let y = startFrame.minY + startFraction * startFrame.height
        let maxY = endFrame.minY + endFraction * endFrame.height
        let height = max(PDFConstants.minHighlightHeight, maxY - y)
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
        let defaultRect = CGRect(x: 0, y: centerInCanvas.y - PDFConstants.defaultHighlightHeight / 2, width: canvas.bounds.width, height: PDFConstants.defaultHighlightHeight)
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
            let hitArea = h.rect(in: canvas).insetBy(dx: -PDFConstants.highlightTapHitSlop, dy: -PDFConstants.highlightTapHitSlop)
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
                    let hitArea = rect.insetBy(dx: -PDFConstants.highlightTapHitSlop, dy: -PDFConstants.highlightTapHitSlop)
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
                let newRect = CGRect(x: 0, y: minY, width: canvas.bounds.width, height: max(PDFConstants.minHighlightHeight, maxY - minY))
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
        let topHandle = CGRect(x: centerX - PDFConstants.handleWidth / 2, y: rect.minY - PDFConstants.handleHeight / 2, width: PDFConstants.handleWidth, height: PDFConstants.handleHeight)
        let bottomHandle = CGRect(x: centerX - PDFConstants.handleWidth / 2, y: rect.maxY - PDFConstants.handleHeight / 2, width: PDFConstants.handleWidth, height: PDFConstants.handleHeight)

        // Expand horizontally by handleHitSlop + extra horizontal, and vertically by base slop plus asymmetric extras
        let topHitArea = topHandle.insetBy(dx: -(PDFConstants.handleHitSlop + PDFConstants.handleHitExtraHorizontal), dy: -(PDFConstants.handleHitSlop + PDFConstants.handleHitExtraTop))
        if topHitArea.contains(point) { return .top }

        let bottomHitArea = bottomHandle.insetBy(dx: -(PDFConstants.handleHitSlop + PDFConstants.handleHitExtraHorizontal), dy: -(PDFConstants.handleHitSlop + PDFConstants.handleHitExtraBottom))
        if bottomHitArea.contains(point) { return .bottom }
        return nil
    }

    private func isDeleteButtonTapped(at point: CGPoint, for rect: CGRect) -> Bool {
        let deleteButton = CGRect(x: rect.minX + PDFConstants.deleteButtonInset, y: rect.minY - PDFConstants.deleteButtonSize - PDFConstants.deleteButtonOffset, width: PDFConstants.deleteButtonSize, height: PDFConstants.deleteButtonSize)
        return deleteButton.contains(point)
    }

    private func isColorPickerButtonTapped(at point: CGPoint, for rect: CGRect) -> Bool {
        let deleteButtonX = rect.minX + PDFConstants.deleteButtonInset
        let colorPickerButton = CGRect(x: deleteButtonX + PDFConstants.deleteButtonSize + PDFConstants.colorPickerButtonSpacing, y: rect.minY - PDFConstants.colorPickerButtonSize - PDFConstants.deleteButtonOffset, width: PDFConstants.colorPickerButtonSize, height: PDFConstants.colorPickerButtonSize)
        return colorPickerButton.contains(point)
    }

    private func showColorPicker(for highlight: HighlightModel) {
        guard let canvas = canvasView else { return }
        let pickerView = ColorPickerView(selectedColor: highlight.color) { [weak self] color in self?.updateHighlightColor(highlight.id, to: color) }
        let rect = highlight.rect(in: canvas)
        let deleteButtonX = rect.minX + PDFConstants.deleteButtonInset
        let buttonX = deleteButtonX + PDFConstants.deleteButtonSize + PDFConstants.colorPickerButtonSpacing
        let buttonY = rect.minY - PDFConstants.colorPickerButtonSize - PDFConstants.deleteButtonOffset
        let buttonCenter = canvas.convert(CGPoint(x: buttonX + PDFConstants.colorPickerButtonSize / 2, y: buttonY + PDFConstants.colorPickerButtonSize / 2), to: nil)
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
                let hitArea = rect.insetBy(dx: -PDFConstants.highlightTapHitSlop, dy: -PDFConstants.highlightTapHitSlop)
                return detectEdgeHandle(at: loc, for: rect) != nil || hitArea.contains(loc)
            }
        }
        return true
    }
}

