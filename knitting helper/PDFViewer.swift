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
        scrollView.minimumZoomScale = PDFConstants.minimumZoomScale
        scrollView.maximumZoomScale = PDFConstants.maximumZoomScale
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = UIColor(named: "AppBackground") ?? .systemBackground
        
        // Add top content inset for counters overlay - dynamic based on counter count
        let topInset = CGFloat(counterCount) * PDFConstants.counterHeight
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
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(PDFViewCoordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        scrollView.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(PDFViewCoordinator.handlePan(_:)))
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
        let topInset = CGFloat(counterCount) * PDFConstants.counterHeight
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
            guard let newDoc = PDFDocument(url: url) else {
                // Document failed to load - keep existing document
                return
            }
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
    
    func makeCoordinator() -> PDFViewCoordinator {
        PDFViewCoordinator(url: url, highlights: $highlights, scrollOffsetY: $scrollOffsetY)
    }
}
