//
//  PDFViewCoordinator.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI
import UIKit
import PDFKit
import Combine

class PDFViewCoordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    var url: URL
    var highlightsBinding: Binding<[CodableHighlight]>
    var notesBinding: Binding<[CodableNote]>
    var bookmarksBinding: Binding<[CodableBookmark]>
    var bookmarkNameBinding: Binding<String>
    var scrollOffsetYBinding: Binding<Double>
    var selectedBookmarkBinding: Binding<CodableBookmark?>
    var bookmarkToRecolorBinding: Binding<CodableBookmark?>
    var shouldShowBookmarkColorPickerBinding: Binding<Bool>

    var contentView: UIView?
    var canvasView: PDFCanvasView?
    var overlayView: HighlightOverlayView?
    var noteOverlayView: NoteOverlayView?
    var bookmarkOverlayView: BookmarkOverlayView?

    // Document reference for cache invalidation and change detection
    var document: PDFDocument?
    var hasRestoredScrollPosition: Bool = false

    var initialScrollOffsetY: Double = 0

    // State
    var highlights: [HighlightModel] = []
    var selectedHighlightID: UUID?
    var showingColorPicker = false
    
    // Note state
    var notes: [NoteModel] = []
    var openNoteIDs: Set<UUID> = []
    var noteEditorViews: [UUID: UIView] = [:]
    var noteEditorHostingControllers: [UUID: UIHostingController<NoteEditorView>] = [:]
    var noteEditorSizes: [UUID: CGSize] = [:]

    // Bookmark state
    var onCreateBookmark: ((String, Int, CGFloat, CGFloat) -> Void)?
    var onDeleteNote: ((UUID) -> Void)?

    // Bookmarks are now read directly from the binding - project is the source of truth
    var bookmarks: [BookmarkModel] {
        return bookmarksBinding.wrappedValue.map { codable in
            BookmarkModel(
                id: codable.id,
                page: codable.page,
                xFraction: codable.xFraction,
                yFraction: codable.yFraction,
                name: codable.name,
                color: UIColor(hex: codable.colorHex) ?? .systemOrange
            )
        }
    }

    // Gesture state
    private var isDragging = false
    private var isResizing = false
    private var isDraggingNote = false
    private var isDraggingBookmark = false
    private var isResizingNoteEditor = false
    private var resizingEdge: ResizeEdge?
    private var dragStartPointInCanvas: CGPoint?
    private var dragStartRect: CGRect?
    private var noteDragStartPoint: CGPoint?
    private var noteDragStartModel: NoteModel?
    private var bookmarkDragStartPoint: CGPoint?
    private var bookmarkDragStartModel: BookmarkModel?
    private var noteEditorResizeStartPoint: CGPoint?
    private var noteEditorResizeStartSize: CGSize?
    private var noteEditorResizeStartOrigin: CGPoint?
    private var noteEditorResizeNoteID: UUID?
    
    // MARK: - Note Helper Methods
    
    /// Finds the index of a note by ID, or nil if not found
    private func noteIndex(for noteID: UUID) -> Int? {
        return notes.firstIndex(where: { $0.id == noteID })
    }
    
    /// Gets a note by ID, or nil if not found
    private func note(for noteID: UUID) -> NoteModel? {
        return notes.first(where: { $0.id == noteID })
    }
    
    /// Gets the persisted size for a note editor, or returns default size
    private func getNoteEditorSize(for noteID: UUID) -> CGSize {
        if let savedSize = noteEditorSizes[noteID] {
            return savedSize
        }
        if let note = note(for: noteID), note.width > 0 && note.height > 0 {
            let size = CGSize(width: note.width, height: note.height)
            noteEditorSizes[noteID] = size
            return size
        }
        return CGSize(
            width: PDFConstants.noteEditorDefaultWidth,
            height: PDFConstants.noteEditorDefaultHeight
        )
    }
    
    /// Saves the size for a note editor
    private func setNoteEditorSize(_ size: CGSize, for noteID: UUID) {
        noteEditorSizes[noteID] = size
        if let index = noteIndex(for: noteID) {
            notes[index].width = size.width
            notes[index].height = size.height
        }
    }
    
    /// Validates that canvas and contentView have valid bounds
    private func validateBounds() -> Bool {
        guard let canvas = canvasView, let contentView = contentView else { return false }
        return canvas.bounds.width > 0 && canvas.bounds.height > 0 &&
               contentView.bounds.width > 0 && contentView.bounds.height > 0
    }
    
    /// Calculates the position for a note editor based on the note's icon position
    private func calculateNoteEditorPosition(for note: NoteModel) -> CGPoint? {
        guard let canvas = canvasView, let contentView = contentView else { return nil }
        guard validateBounds() else { return nil }
        
        let notePoint = note.point(in: canvas)
        guard notePoint.x.isFinite && notePoint.y.isFinite else { return nil }
        
        let notePointInContentView = canvas.convert(notePoint, to: contentView)
        guard notePointInContentView.x.isFinite && notePointInContentView.y.isFinite else { return nil }
        
        let editorSize = getNoteEditorSize(for: note.id)
        let iconLeftEdge = notePointInContentView.x - PDFConstants.noteIconSize / 2
        let preferredX = iconLeftEdge - 1 // 1pt gap, left-aligned
        let x = max(8, min(preferredX, contentView.bounds.width - editorSize.width - 8))
        let y = min(notePointInContentView.y + PDFConstants.noteIconSize / 2 + 1,
                   max(8, contentView.bounds.height - editorSize.height - 8))
        
        guard x.isFinite && y.isFinite && x >= 0 && y >= 0 else { return nil }
        return CGPoint(x: x, y: y)
    }
    
    /// Calculates the resize handle rect for a note editor view
    private func resizeHandleRect(for editorView: UIView, expanded: Bool = false) -> CGRect {
        let size = expanded ? PDFConstants.noteEditorResizeHandleSize + 20 : PDFConstants.noteEditorResizeHandleSize
        return CGRect(
            x: editorView.frame.maxX - PDFConstants.noteEditorResizeHandleSize - 4,
            y: editorView.frame.maxY - PDFConstants.noteEditorResizeHandleSize - 4,
            width: size,
            height: size
        )
    }
    
    /// Calculates the hit area for a note icon at a given point
    private func noteIconHitArea(at point: CGPoint) -> CGRect {
        return CGRect(
            x: point.x - PDFConstants.noteIconSize / 2 - PDFConstants.noteIconTapHitSlop,
            y: point.y - PDFConstants.noteIconSize / 2 - PDFConstants.noteIconTapHitSlop,
            width: PDFConstants.noteIconSize + PDFConstants.noteIconTapHitSlop * 2,
            height: PDFConstants.noteIconSize + PDFConstants.noteIconTapHitSlop * 2
        )
    }

    /// Calculates the hit area for a bookmark icon at a given point
    private func bookmarkIconHitArea(at point: CGPoint) -> CGRect {
        return CGRect(
            x: point.x - PDFConstants.bookmarkIconSize / 2 - PDFConstants.noteIconTapHitSlop,
            y: point.y - PDFConstants.bookmarkIconSize / 2 - PDFConstants.noteIconTapHitSlop,
            width: PDFConstants.bookmarkIconSize + PDFConstants.noteIconTapHitSlop * 2,
            height: PDFConstants.bookmarkIconSize + PDFConstants.noteIconTapHitSlop * 2
        )
    }
    
    /// Creates a NoteEditorView with bindings configured for a specific note
    private func createNoteEditorView(for noteID: UUID) -> NoteEditorView {
        let defaultSize = getNoteEditorSize(for: noteID)
        let noteColor = note(for: noteID)?.color ?? .systemBlue
        return NoteEditorView(
            text: Binding(
                get: { [weak self] in
                    self?.note(for: noteID)?.text ?? ""
                },
                set: { [weak self] newText in
                    self?.updateNoteText(noteID, text: newText)
                }
            ),
            size: Binding(
                get: { [weak self] in
                    self?.noteEditorSizes[noteID] ?? defaultSize
                },
                set: { [weak self] newSize in
                    guard let self = self else { return }
                    self.noteEditorSizes[noteID] = newSize
                    self.updateNoteEditorFrame(for: noteID)
                    self.setNoteEditorSize(newSize, for: noteID)
                    self.syncNotesToBinding()
                }
            ),
            noteID: noteID,
            noteColor: Color(noteColor),
            onDelete: { [weak self] in
                self?.deleteNote(noteID)
            },
            onColorPicker: { [weak self] in
                guard let self = self, let note = self.note(for: noteID) else { return }
                self.showColorPicker(for: note)
            }
        )
    }
    private var resizeAnchorY: CGFloat?
    private var shouldBlockScrolling = false

    enum ResizeEdge { case top, bottom }

    init(url: URL, highlights: Binding<[CodableHighlight]>, notes: Binding<[CodableNote]>, bookmarks: Binding<[CodableBookmark]>, bookmarkName: Binding<String>, scrollOffsetY: Binding<Double>, selectedBookmark: Binding<CodableBookmark?>, bookmarkToRecolor: Binding<CodableBookmark?>, shouldShowBookmarkColorPicker: Binding<Bool>) {
        self.url = url
        self.highlightsBinding = highlights
        self.notesBinding = notes
        self.bookmarksBinding = bookmarks
        self.bookmarkNameBinding = bookmarkName
        self.scrollOffsetYBinding = scrollOffsetY
        self.selectedBookmarkBinding = selectedBookmark
        self.bookmarkToRecolorBinding = bookmarkToRecolor
        self.shouldShowBookmarkColorPickerBinding = shouldShowBookmarkColorPicker
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
            self.syncNoteOverlay()
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
    
    func syncNoteOverlay() {
        guard let noteOverlay = noteOverlayView else { return }
        noteOverlay.update(notes: notes, openNoteIDs: openNoteIDs, canvas: canvasView)
    }

    func syncBookmarkOverlay(_ bookmarks: [CodableBookmark]? = nil) {
        guard let bookmarkOverlay = bookmarkOverlayView else { return }
        let bookmarksToUse = bookmarks ?? self.bookmarks.map { model in
            CodableBookmark(
                id: model.id,
                page: model.page,
                xFraction: model.xFraction,
                yFraction: model.yFraction,
                name: model.name,
                colorHex: model.color.toHex()
            )
        }
        let models = bookmarksToUse.map { codable in
            BookmarkModel(
                id: codable.id,
                page: codable.page,
                xFraction: codable.xFraction,
                yFraction: codable.yFraction,
                name: codable.name,
                color: UIColor(hex: codable.colorHex) ?? .systemOrange
            )
        }
        bookmarkOverlay.update(bookmarks: models, canvas: canvasView)
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
    
    // Note Persistence
    func loadNotes(_ codableNotes: [CodableNote]) {
        // Close all existing note editors first to prevent duplicates
        // Do this without syncing to binding to avoid triggering reloads
        let existingOpenNoteIDs = Array(openNoteIDs)
        for noteID in existingOpenNoteIDs {
            openNoteIDs.remove(noteID)
            if let editorView = noteEditorViews[noteID] {
                editorView.removeFromSuperview()
                noteEditorViews.removeValue(forKey: noteID)
            }
            noteEditorHostingControllers.removeValue(forKey: noteID)
        }
        
        var models: [NoteModel] = []
        var notesToOpen: [UUID] = []

        // Get existing note IDs to clean up removed notes
        let existingNoteIDs = Set(noteEditorSizes.keys)
        let newNoteIDs = Set(codableNotes.map { $0.id })

        // Remove sizes for notes that no longer exist
        for removedID in existingNoteIDs.subtracting(newNoteIDs) {
            noteEditorSizes.removeValue(forKey: removedID)
        }

        for codable in codableNotes {
            let model = NoteModel(
                id: codable.id,
                page: codable.page,
                xFraction: codable.xFraction,
                yFraction: codable.yFraction,
                text: codable.text,
                isOpen: codable.isOpen,
                width: codable.width,
                height: codable.height,
                color: UIColor(hex: codable.colorHex) ?? .systemBlue
            )
            models.append(model)

            // Restore size if it was saved
            if codable.width > 0 && codable.height > 0 {
                noteEditorSizes[codable.id] = CGSize(width: codable.width, height: codable.height)
            } else {
                // Clear any stale size entry
                noteEditorSizes.removeValue(forKey: codable.id)
            }

            // Track notes that should be opened
            if codable.isOpen {
                notesToOpen.append(codable.id)
            }
        }
        notes = models
        
        // Restore open state
        openNoteIDs = Set(notesToOpen)
        
        syncNoteOverlay()
        
        // Open note editors for notes that were previously open
        // Delay to ensure canvas is laid out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            for noteID in notesToOpen {
                // Only open if still in openNoteIDs and note still exists
                if self.openNoteIDs.contains(noteID) && self.notes.contains(where: { $0.id == noteID }) {
                    self.openNoteEditor(for: noteID)
                }
            }
        }
    }
    
    func getNotes() -> [CodableNote] {
        return notes.map { n in
            let size = getNoteEditorSize(for: n.id)
            let isCurrentlyOpen = openNoteIDs.contains(n.id)

            return CodableNote(
                id: n.id,
                page: n.page,
                xFraction: n.xFraction,
                yFraction: n.yFraction,
                text: n.text,
                isOpen: isCurrentlyOpen,
                width: size.width,
                height: size.height,
                colorHex: n.color.toHex()
            )
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
    
    // MARK: - Note coordinate conversion helpers
    private func canvasPointToPageFraction(_ point: CGPoint) -> (Int, CGFloat, CGFloat) {
        guard let canvas = canvasView, !canvas.pageFrames.isEmpty else {
            // Fallback: treat entire canvas as page 0
            let height = max(1, canvasView?.bounds.height ?? 1)
            let width = max(1, canvasView?.bounds.width ?? 1)
            let xFrac = max(0, min(1, point.x / width))
            let yFrac = max(0, min(1, point.y / height))
            return (0, xFrac, yFrac)
        }
        
        // Find which page contains this point
        for (pageIndex, frame) in canvas.pageFrames.sorted(by: { $0.key < $1.key }) {
            if frame.contains(point) {
                let xFrac = (point.x - frame.minX) / max(1, frame.width)
                let yFrac = (point.y - frame.minY) / max(1, frame.height)
                return (pageIndex, max(0, min(1, xFrac)), max(0, min(1, yFrac)))
            }
        }
        
        // If point is outside all pages, find closest page
        var closestPage = 0
        var minDistance: CGFloat = .greatestFiniteMagnitude
        for (pageIndex, frame) in canvas.pageFrames {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let distance = sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2))
            if distance < minDistance {
                minDistance = distance
                closestPage = pageIndex
            }
        }
        
        if let frame = canvas.pageFrames[closestPage] {
            let xFrac = (point.x - frame.minX) / max(1, frame.width)
            let yFrac = (point.y - frame.minY) / max(1, frame.height)
            return (closestPage, max(0, min(1, xFrac)), max(0, min(1, yFrac)))
        }
        
        return (0, 0.5, 0.5)
    }


    private func syncNotesToBinding() {
        self.notesBinding.wrappedValue = self.getNotes()
    }


    private func syncHighlightsToBinding() {
        self.highlightsBinding.wrappedValue = self.getHighlights()
    }

    func getBookmarks() -> [CodableBookmark] {
        // Bookmarks are stored directly in the binding as the source of truth
        return bookmarksBinding.wrappedValue
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
        
        // Check if tap is inside any note editor view - if so, let SwiftUI handle it
        if let contentView = contentView {
            let locationInContentView = canvas.convert(location, to: contentView)
            for (_, editorView) in noteEditorViews {
                if editorView.frame.contains(locationInContentView) {
                    // Tap is inside a note editor - let SwiftUI handle it
                    return
                }
            }
        }
        
        // Check for note editor resize handle tap (in contentView coordinates)
        if let contentView = contentView {
            let locationInContentView = canvas.convert(location, to: contentView)
            for (_, editorView) in noteEditorViews {
                if resizeHandleRect(for: editorView).contains(locationInContentView) {
                    // Don't toggle, just return (resize will be handled by pan gesture)
                    return
                }
            }
        }
        
        // Check for note tap
        if noteOverlayView != nil {
            for note in notes {
                let notePoint = note.point(in: canvas)
                if noteIconHitArea(at: notePoint).contains(location) {
                    toggleNoteEditor(for: note.id)
                    return
                }
            }
        }
        
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
            
            // Check for note editor resize handle first (in contentView coordinates)
            if let contentView = contentView {
                let locationInContentView = canvas.convert(location, to: contentView)
                for (noteID, editorView) in noteEditorViews {
                    if resizeHandleRect(for: editorView, expanded: true).contains(locationInContentView) {
                        isResizingNoteEditor = true
                        noteEditorResizeStartPoint = locationInContentView
                        noteEditorResizeStartSize = editorView.frame.size
                        noteEditorResizeStartOrigin = editorView.frame.origin
                        noteEditorResizeNoteID = noteID
                        foundHandle = true
                        // Disable scrolling to prevent interference
                        if let scroll = canvas.superview?.superview as? UIScrollView {
                            scroll.isScrollEnabled = false
                        }
                        break
                    }
                }
            }
            
            // Check for note drag
            if !foundHandle, noteOverlayView != nil {
                for note in notes {
                    let notePoint = note.point(in: canvas)
                    if noteIconHitArea(at: notePoint).contains(location) {
                        isDraggingNote = true
                        noteDragStartPoint = location
                        noteDragStartModel = note
                        foundHandle = true
                        if let scroll = canvas.superview?.superview as? UIScrollView { scroll.isScrollEnabled = false }
                        break
                    }
                }
            }

            // Check for bookmark drag
            if !foundHandle, bookmarkOverlayView != nil {
                for bookmark in bookmarks {
                    let bookmarkPoint = bookmark.point(in: canvas)
                    if bookmarkIconHitArea(at: bookmarkPoint).contains(location) {
                        isDraggingBookmark = true
                        bookmarkDragStartPoint = location
                        bookmarkDragStartModel = bookmark
                        foundHandle = true
                        if let scroll = canvas.superview?.superview as? UIScrollView { scroll.isScrollEnabled = false }
                        break
                    }
                }
            }
            
            if !foundHandle {
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
            }
            if isDragging || isResizing { if let scroll = canvas.superview?.superview as? UIScrollView { scroll.isScrollEnabled = false } }
            overlay.update(highlights: highlights, selectedID: selectedHighlightID, canvas: canvasView)
        case .changed:
            if isResizingNoteEditor {
                guard let startPoint = noteEditorResizeStartPoint,
                      let startSize = noteEditorResizeStartSize,
                      let noteID = noteEditorResizeNoteID,
                      let editorView = noteEditorViews[noteID],
                      let contentView = contentView else { return }
                
                let locationInContentView = canvas.convert(location, to: contentView)
                let dx = locationInContentView.x - startPoint.x
                let dy = locationInContentView.y - startPoint.y
                
                let newWidth = max(PDFConstants.noteEditorMinWidth, min(PDFConstants.noteEditorMaxWidth, startSize.width + dx))
                let newHeight = max(PDFConstants.noteEditorMinHeight, min(PDFConstants.noteEditorMaxHeight, startSize.height + dy))
                
                let newSize = CGSize(width: newWidth, height: newHeight)
                
                // Keep the top-left corner fixed using the stored origin
                let fixedOrigin = noteEditorResizeStartOrigin ?? editorView.frame.origin
                
                // Update the stored size
                setNoteEditorSize(newSize, for: noteID)
                
                // Update the frame
                editorView.frame = CGRect(origin: fixedOrigin, size: newSize)
                
                // Force SwiftUI to update by recreating the root view with the new size binding
                if let hostingController = noteEditorHostingControllers[noteID] {
                    hostingController.rootView = createNoteEditorView(for: noteID)
                }
            } else if isDraggingNote {
                guard let startPoint = noteDragStartPoint, let startModel = noteDragStartModel else { return }
                guard let noteIndex = notes.firstIndex(where: { $0.id == startModel.id }) else { return }
                guard let canvas = canvasView else { return }
                
                // Ensure canvas is laid out
                if canvas.pageFrames.isEmpty {
                    layoutCanvas()
                }
                
                let dx = location.x - startPoint.x
                let dy = location.y - startPoint.y
                let currentPoint = startModel.point(in: canvas)
                let newPoint = CGPoint(
                    x: max(0, min(canvas.bounds.width, currentPoint.x + dx)),
                    y: max(0, min(canvas.bounds.height, currentPoint.y + dy))
                )
                let (page, xFrac, yFrac) = canvasPointToPageFraction(newPoint)
                notes[noteIndex].set(fromPage: page, xFraction: xFrac, yFraction: yFrac)
                syncNoteOverlay()
                // Update editor position if open - defer to ensure layout is complete
                let draggedNoteID = notes[noteIndex].id
                if openNoteIDs.contains(draggedNoteID) {
                    DispatchQueue.main.async { [weak self] in
                        self?.updateNoteEditorPosition(for: draggedNoteID)
                    }
                }
            } else if isDraggingBookmark {
                guard let startPoint = bookmarkDragStartPoint, let startModel = bookmarkDragStartModel else { return }
                guard let canvas = canvasView else { return }

                // Ensure canvas is laid out
                if canvas.pageFrames.isEmpty {
                    layoutCanvas()
                }

                let dx = location.x - startPoint.x
                let dy = location.y - startPoint.y
                let currentPoint = startModel.point(in: canvas)
                let newPoint = CGPoint(
                    x: max(0, min(canvas.bounds.width, currentPoint.x + dx)),
                    y: max(0, min(canvas.bounds.height, currentPoint.y + dy))
                )
                let (page, xFrac, yFrac) = canvasPointToPageFraction(newPoint)
                updateBookmarkPosition(bookmarkID: startModel.id, to: newPoint)
                syncBookmarkOverlay()
            } else {
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
            }
        case .ended, .cancelled, .failed:
            // Nothing extra needed here; highlights already canonicalized during interactions.
            if isResizingNoteEditor {
                // Save the final size to the note model when resize ends
                if let noteID = noteEditorResizeNoteID,
                   let finalSize = noteEditorSizes[noteID],
                   let index = notes.firstIndex(where: { $0.id == noteID }) {
                    notes[index].width = finalSize.width
                    notes[index].height = finalSize.height
                    syncNotesToBinding()
                }
                
                isResizingNoteEditor = false
                noteEditorResizeStartPoint = nil
                noteEditorResizeStartSize = nil
                noteEditorResizeStartOrigin = nil
                noteEditorResizeNoteID = nil
                // Re-enable scrolling
                if let scroll = canvas.superview?.superview as? UIScrollView {
                    scroll.isScrollEnabled = true
                }
            } else if isDraggingNote {
                syncNotesToBinding()
                isDraggingNote = false
                noteDragStartPoint = nil
                noteDragStartModel = nil
            } else if isDraggingBookmark {
                // Bookmark position is already updated via updateBookmarkPosition
                isDraggingBookmark = false
                bookmarkDragStartPoint = nil
                bookmarkDragStartModel = nil
            } else {
                syncHighlightsToBinding()
            }
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
    func scrollViewDidZoom(_ scrollView: UIScrollView) { 
        syncOverlay()
        syncNoteOverlay()
        // Update editor positions - defer to ensure layout is complete after zoom
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for noteID in self.openNoteIDs {
                self.updateNoteEditorPosition(for: noteID)
            }
        }
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncOverlay()
        syncNoteOverlay()
        scrollOffsetYBinding.wrappedValue = Double(scrollView.contentOffset.y)

        // Update editor positions - defer to avoid layout issues during scrolling
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for noteID in self.openNoteIDs {
                self.updateNoteEditorPosition(for: noteID)
            }
        }
    }

    // UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { return !shouldBlockScrolling }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't handle taps that are inside note editor views - let SwiftUI handle them
        if gestureRecognizer is UITapGestureRecognizer, let contentView = contentView {
            let location = touch.location(in: contentView)
            for (_, editorView) in noteEditorViews {
                if editorView.frame.contains(location) {
                    return false // Let the note editor handle the touch
                }
            }
        }
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer, let canvas = canvasView {
            let loc = gestureRecognizer.location(in: canvas)
            
            // Check for note editor resize handle first (before checking note drag)
            if let contentView = contentView {
                let locationInContentView = canvas.convert(loc, to: contentView)
                for (_, editorView) in noteEditorViews {
                    if resizeHandleRect(for: editorView, expanded: true).contains(locationInContentView) {
                        // Block scrolling when resizing
                        if let scroll = canvas.superview?.superview as? UIScrollView {
                            scroll.isScrollEnabled = false
                        }
                        return true
                    }
                }
            }
            
            // Check for note drag
            if notes.contains(where: { note in
                let notePoint = note.point(in: canvas)
                return noteIconHitArea(at: notePoint).contains(loc)
            }) {
                return true
            }

            // Check for bookmark drag
            if bookmarks.contains(where: { bookmark in
                let bookmarkPoint = bookmark.point(in: canvas)
                return bookmarkIconHitArea(at: bookmarkPoint).contains(loc)
            }) {
                return true
            }

            // Check for highlight drag/resize
            return highlights.contains { h in
                let rect = h.rect(in: canvas)
                let hitArea = rect.insetBy(dx: -PDFConstants.highlightTapHitSlop, dy: -PDFConstants.highlightTapHitSlop)
                return detectEdgeHandle(at: loc, for: rect) != nil || hitArea.contains(loc)
            }
        }
        return true
    }
    
    // MARK: - Note Management
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let canvas = canvasView else { return }
        let location = gesture.location(in: canvas)
        addNote(at: location)
    }
    
    func addNote(at location: CGPoint) {
        guard let canvas = canvasView else { return }
        if canvas.pageFrames.isEmpty { layoutCanvas() }
        
        let (page, xFrac, yFrac) = canvasPointToPageFraction(location)
        let note = NoteModel(id: UUID(), page: page, xFraction: xFrac, yFraction: yFrac, text: "", color: .systemBlue)
        notes.append(note)
        syncNoteOverlay()
        syncNotesToBinding()
        // Open the editor for the new note
        toggleNoteEditor(for: note.id)
    }
    
    func toggleNoteEditor(for noteID: UUID) {
        if openNoteIDs.contains(noteID) {
            closeNoteEditor(for: noteID)
        } else {
            openNoteEditor(for: noteID)
        }
    }
    
    func openNoteEditor(for noteID: UUID) {
        guard let note = note(for: noteID),
              let canvas = canvasView,
              let contentView = contentView else { return }
        
        // If editor is already open, don't create a duplicate
        if noteEditorViews[noteID] != nil {
            return
        }
        
        // Ensure canvas is laid out before positioning
        if canvas.pageFrames.isEmpty {
            layoutCanvas()
        }
        
        openNoteIDs.insert(noteID)
        
        // Update the note model's isOpen state
        if let index = noteIndex(for: noteID) {
            notes[index].isOpen = true
            syncNotesToBinding()
        }
        
        syncNoteOverlay()
        
        // Calculate position BEFORE creating the view to avoid flickering
        guard let position = calculateNoteEditorPosition(for: note) else {
            // If bounds aren't ready, defer opening
            DispatchQueue.main.async { [weak self] in
                self?.openNoteEditor(for: noteID)
            }
            return
        }
        
        let editorSize = getNoteEditorSize(for: noteID)
        
        // Create SwiftUI hosting controller for the note editor
        let hostingController = UIHostingController(rootView: createNoteEditorView(for: noteID))
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = true
        
        // Hide the view completely until positioned
        hostingController.view.isHidden = true
        
        // Set frame BEFORE adding to view hierarchy to prevent flickering
        hostingController.view.frame = CGRect(origin: position, size: editorSize)
        
        // Now add to view hierarchy
        contentView.addSubview(hostingController.view)
        
        // Store references
        noteEditorViews[noteID] = hostingController.view
        noteEditorHostingControllers[noteID] = hostingController
        
        // Show the view after it's been added and positioned
        DispatchQueue.main.async { [weak hostingController, weak self] in
            guard let view = hostingController?.view,
                  let self = self else { return }
            // Double-check the frame is correct
            if view.frame.origin.x < 10 && view.frame.origin.y < 10 {
                // Position was lost, recalculate
                self.updateNoteEditorPosition(for: noteID)
            }
            // Show the view
            view.isHidden = false
        }
    }
    
    func updateNoteEditorFrame(for noteID: UUID) {
        guard let editorView = noteEditorViews[noteID] else { return }
        let size = getNoteEditorSize(for: noteID)
        editorView.frame.size = size
    }
    
    func closeNoteEditor(for noteID: UUID) {
        openNoteIDs.remove(noteID)
        syncNoteOverlay()
        
        // Save the current size to the note model before closing
        if let size = noteEditorSizes[noteID] {
            setNoteEditorSize(size, for: noteID)
        }
        if let index = noteIndex(for: noteID) {
            notes[index].isOpen = false
            syncNotesToBinding()
        }
        
        if let editorView = noteEditorViews[noteID] {
            editorView.removeFromSuperview()
            noteEditorViews.removeValue(forKey: noteID)
        }
        noteEditorHostingControllers.removeValue(forKey: noteID)
        // Keep the size in noteEditorSizes so it's remembered if reopened
    }
    
    func updateNoteEditorPosition(for noteID: UUID) {
        guard let note = note(for: noteID),
              let editorView = noteEditorViews[noteID],
              let canvas = canvasView else { return }
        
        // Ensure canvas is laid out and has valid bounds
        if canvas.pageFrames.isEmpty {
            layoutCanvas()
        }
        
        // Validate that we have valid bounds
        guard validateBounds() else {
            // If bounds aren't valid yet, try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateNoteEditorPosition(for: noteID)
            }
            return
        }
        
        // Calculate new position
        guard let position = calculateNoteEditorPosition(for: note) else {
            return
        }
        
        // Update frame directly
        editorView.frame.origin = position
    }
    
    func updateNoteText(_ noteID: UUID, text: String) {
        guard let index = noteIndex(for: noteID) else { return }
        notes[index].text = text
        syncNotesToBinding()
    }
    
    func deleteNote(_ noteID: UUID) {
        // Just show the confirmation alert - don't delete yet
        onDeleteNote?(noteID)
    }

    func confirmDeleteNote(_ noteID: UUID) {
        // User confirmed deletion - now clean up UI state
        closeNoteEditor(for: noteID)
        notes.removeAll { $0.id == noteID }
        noteEditorSizes.removeValue(forKey: noteID)
        openNoteIDs.remove(noteID)
        syncNoteOverlay()
        syncNotesToBinding()
    }
    
    private func showColorPicker(for note: NoteModel) {
        guard let canvas = canvasView,
              let editorView = noteEditorViews[note.id] else { return }
        
        let pickerView = ColorPickerView(selectedColor: note.color) { [weak self] color in
            self?.updateNoteColor(note.id, to: color)
        }
        
        // Position the color picker near the color picker button (bottom left of note editor)
        let buttonSize = PDFConstants.noteEditorResizeHandleSize - 4
        let buttonX = editorView.frame.minX - 4 + buttonSize / 2
        let buttonY = editorView.frame.maxY - 4 - buttonSize / 2
        let buttonCenter = canvas.convert(CGPoint(x: buttonX, y: buttonY), to: nil)
        
        pickerView.show(from: buttonCenter, in: canvas)
    }
    
    private func updateNoteColor(_ noteID: UUID, to color: UIColor) {
        guard let index = noteIndex(for: noteID) else { return }
        notes[index].color = color
        syncNoteOverlay()
        syncNotesToBinding()

        // Update the editor view to reflect the new color
        if let hostingController = noteEditorHostingControllers[noteID] {
            hostingController.rootView = createNoteEditorView(for: noteID)
        }
    }

    func showColorPicker(for bookmark: CodableBookmark) {
        guard let canvas = canvasView else { return }

        let pickerView = ColorPickerView(selectedColor: UIColor(hex: bookmark.colorHex) ?? .systemOrange) { [weak self] color in
            self?.updateBookmarkColor(bookmark.id, to: color)
        }

        // Show color picker from center of screen
        guard let window = canvas.window else { return }
        let screenBounds = window.bounds
        let centerPoint = CGPoint(x: screenBounds.midX, y: screenBounds.midY)

        pickerView.show(from: centerPoint, in: canvas)
    }

    private func updateBookmarkColor(_ bookmarkID: UUID, to color: UIColor) {
        // Update the bookmark color in the binding
        var updatedBookmarks = bookmarksBinding.wrappedValue
        if let index = updatedBookmarks.firstIndex(where: { $0.id == bookmarkID }) {
            updatedBookmarks[index].colorHex = color.toHex()
            bookmarksBinding.wrappedValue = updatedBookmarks
        }
        syncBookmarkOverlay()
    }
    
    func addNoteAtCenter() {
        guard let canvas = canvasView else { return }
        if canvas.pageFrames.isEmpty { layoutCanvas() }
        guard let scroll = canvas.superview?.superview as? UIScrollView else { return }

        // Use the exact same approach as addHighlight - it works correctly
        let visibleCenterInScroll = CGPoint(x: scroll.bounds.midX, y: scroll.bounds.midY)
        let centerInCanvas = canvas.convert(visibleCenterInScroll, from: scroll)

        addNote(at: centerInCanvas)
    }

    func addBookmarkAtCenter(name: String) {
        guard let canvas = canvasView else { return }
        if canvas.pageFrames.isEmpty { layoutCanvas() }
        guard let scroll = canvas.superview?.superview as? UIScrollView else { return }

        // Use the exact same approach as addHighlight and addNoteAtCenter
        let visibleCenterInScroll = CGPoint(x: scroll.bounds.midX, y: scroll.bounds.midY)
        let centerInCanvas = canvas.convert(visibleCenterInScroll, from: scroll)

        let (page, xFrac, yFrac) = canvasPointToPageFraction(centerInCanvas)

        // Create bookmark using the callback
        onCreateBookmark?(name, page, xFrac, yFrac)
    }


    func updateBookmarkPosition(bookmarkID: UUID, to canvasPoint: CGPoint) {
        // Update the bookmark position in the binding
        var updatedBookmarks = bookmarksBinding.wrappedValue
        if let index = updatedBookmarks.firstIndex(where: { $0.id == bookmarkID }) {
            let (page, xFrac, yFrac) = canvasPointToPageFraction(canvasPoint)
            updatedBookmarks[index].page = page
            updatedBookmarks[index].xFraction = xFrac
            updatedBookmarks[index].yFraction = yFrac
            bookmarksBinding.wrappedValue = updatedBookmarks
        }
        // Don't sync overlay here - let SwiftUI handle it naturally
    }

    func navigateToBookmark(_ bookmark: CodableBookmark) {
        guard let scrollView = contentView?.superview as? UIScrollView,
              let canvas = canvasView else { return }

        // Convert bookmark to canvas point
        let bookmarkModel = BookmarkModel(
            id: bookmark.id,
            page: bookmark.page,
            xFraction: bookmark.xFraction,
            yFraction: bookmark.yFraction,
            name: bookmark.name,
            color: UIColor(hex: bookmark.colorHex) ?? .systemOrange
        )
        let canvasPoint = bookmarkModel.point(in: canvas)

        // Calculate the scroll position to place bookmark in top 10% of the visible screen area
        // Account for content inset (counters overlay) that reduces the visible height
        let scrollViewBounds = scrollView.bounds
        let visibleHeight = scrollViewBounds.height - scrollView.contentInset.top
        let centerX = canvasPoint.x - scrollViewBounds.width / 2
        let bookmarkVisibleY = scrollView.contentInset.top + visibleHeight * 0.1
        let topPositionY = canvasPoint.y - bookmarkVisibleY

        // Ensure we don't scroll outside bounds
        let clampedX = max(0, min(centerX, canvas.bounds.width - scrollViewBounds.width))
        let clampedY = max(0, min(topPositionY, canvas.bounds.height - scrollViewBounds.height))

        // Scroll to the bookmark position
        scrollView.setContentOffset(CGPoint(x: clampedX, y: clampedY), animated: true)
    }
}

