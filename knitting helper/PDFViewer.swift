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
    @Binding var shouldAddNote: Bool
    @Binding var bookmarkName: String
    var onCreateBookmark: (String, Int, CGFloat, CGFloat) -> Void
    @Binding var highlights: [CodableHighlight]
    @Binding var notes: [CodableNote]
    @Binding var bookmarks: [CodableBookmark]
    let counterCount: Int
    @Binding var scrollOffsetY: Double
    @Binding var selectedBookmark: CodableBookmark?
    @Binding var bookmarkToRecolor: CodableBookmark?
    @Binding var shouldShowBookmarkColorPicker: Bool
    @Binding var bookmarkNameToCreate: String?

    var body: some View {
        PDFKitView(url: url, shouldAddHighlight: $shouldAddHighlight, shouldAddNote: $shouldAddNote, bookmarkName: $bookmarkName, onCreateBookmark: onCreateBookmark, highlights: $highlights, notes: $notes, bookmarks: $bookmarks, counterCount: counterCount, scrollOffsetY: $scrollOffsetY, selectedBookmark: $selectedBookmark, bookmarkToRecolor: $bookmarkToRecolor, shouldShowBookmarkColorPicker: $shouldShowBookmarkColorPicker, bookmarkNameToCreate: $bookmarkNameToCreate)
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var shouldAddHighlight: Bool
    @Binding var shouldAddNote: Bool
    @Binding var bookmarkName: String
    var onCreateBookmark: (String, Int, CGFloat, CGFloat) -> Void
    @Binding var highlights: [CodableHighlight]
    @Binding var notes: [CodableNote]
    @Binding var bookmarks: [CodableBookmark]
    let counterCount: Int
    @Binding var scrollOffsetY: Double
    @Binding var selectedBookmark: CodableBookmark?
    @Binding var bookmarkToRecolor: CodableBookmark?
    @Binding var shouldShowBookmarkColorPicker: Bool
    @Binding var bookmarkNameToCreate: String?

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
        
        // Overlay for notes (drawn in canvas coordinate space)
        let noteOverlay = NoteOverlayView()
        noteOverlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(noteOverlay)
        context.coordinator.noteOverlayView = noteOverlay
        noteOverlay.isUserInteractionEnabled = true
        contentView.bringSubviewToFront(noteOverlay)

        // Overlay for bookmarks (drawn in canvas coordinate space)
        let bookmarkOverlay = BookmarkOverlayView()
        bookmarkOverlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bookmarkOverlay)
        context.coordinator.bookmarkOverlayView = bookmarkOverlay
        bookmarkOverlay.isUserInteractionEnabled = true
        contentView.bringSubviewToFront(bookmarkOverlay)
        
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
            overlay.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
            
            // Pin note overlay to the canvas as well
            noteOverlay.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            noteOverlay.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            noteOverlay.topAnchor.constraint(equalTo: canvas.topAnchor),
            noteOverlay.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),

            // Pin bookmark overlay to the canvas as well
            bookmarkOverlay.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            bookmarkOverlay.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            bookmarkOverlay.topAnchor.constraint(equalTo: canvas.topAnchor),
            bookmarkOverlay.bottomAnchor.constraint(equalTo: canvas.bottomAnchor)
        ])
        
        // Gesture recognizers attached to scrollView (for tap/pan on highlights and notes)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(PDFViewCoordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false // Allow touches to pass through to note editors
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
            context.coordinator.loadNotes(notes)
            context.coordinator.layoutCanvas()
            context.coordinator.syncOverlay()
            context.coordinator.syncNoteOverlay()
            context.coordinator.syncBookmarkOverlay()

            // Set up bookmark creation callback
            context.coordinator.onCreateBookmark = { name, page, xFraction, yFraction in
                onCreateBookmark(name, page, xFraction, yFraction)
            }
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
        
        // Add note when requested
        if shouldAddNote {
            context.coordinator.addNoteAtCenter()
            DispatchQueue.main.async { shouldAddNote = false }
        }

        // Add bookmark at center when requested
        if let bookmarkName = bookmarkNameToCreate {
            context.coordinator.addBookmarkAtCenter(name: bookmarkName)
            DispatchQueue.main.async {
                bookmarkNameToCreate = nil
            }
        }

        // Show color picker for bookmark recoloring when requested
        if shouldShowBookmarkColorPicker, let bookmark = bookmarkToRecolor {
            context.coordinator.showColorPicker(for: bookmark)
            DispatchQueue.main.async {
                shouldShowBookmarkColorPicker = false
                bookmarkToRecolor = nil
            }
        }

        // Update notes when they change (compare by ID and count)
        // Only load notes from binding if coordinator doesn't have them (prevents overwriting notes added by coordinator)
        let coordinatorNotes = context.coordinator.getNotes()

        // If coordinator has more notes than binding, coordinator is the source of change - don't overwrite
        if coordinatorNotes.count > notes.count {
            // Coordinator just added notes, don't load from binding
            return
        }

        // If coordinator has fewer notes than binding, coordinator deleted notes - don't reload from binding
        if coordinatorNotes.count < notes.count {
            // Coordinator just deleted notes, sync overlay but don't reload from binding
            context.coordinator.syncNoteOverlay()
            return
        }

        // If binding has notes that coordinator doesn't have, load them (external changes)
        let coordinatorNoteIDs = Set(coordinatorNotes.map { $0.id })
        let bindingNoteIDs = Set(notes.map { $0.id })

        if !bindingNoteIDs.isSubset(of: coordinatorNoteIDs) {
            // Binding has new notes from external source, load them
            context.coordinator.loadNotes(notes)
            context.coordinator.syncNoteOverlay()
        } else if coordinatorNotes.count != notes.count {
            // Counts differ but no new IDs - might be a deletion, sync overlay
            context.coordinator.syncNoteOverlay()
        }

        // Update bookmark overlay when bookmarks change
        // Pass bookmarks directly to avoid binding issues
        context.coordinator.syncBookmarkOverlay(bookmarks)

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
            context.coordinator.loadNotes(notes)
            // Force a layout and redraw
            context.coordinator.layoutCanvas()
            context.coordinator.syncOverlay()
            context.coordinator.syncNoteOverlay()
            context.coordinator.syncBookmarkOverlay()
        }

        // Handle bookmark navigation
        if let bookmark = selectedBookmark {
            context.coordinator.navigateToBookmark(bookmark)
            // Reset the selected bookmark after navigation
            DispatchQueue.main.async {
                selectedBookmark = nil
            }
        }
    }
    
    func makeCoordinator() -> PDFViewCoordinator {
        PDFViewCoordinator(url: url, highlights: $highlights, notes: $notes, bookmarks: $bookmarks, bookmarkName: $bookmarkName, scrollOffsetY: $scrollOffsetY, selectedBookmark: $selectedBookmark, bookmarkToRecolor: $bookmarkToRecolor, shouldShowBookmarkColorPicker: $shouldShowBookmarkColorPicker)
    }
}
