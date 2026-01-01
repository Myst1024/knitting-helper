//
//  NoteOverlayView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/28/25.
//

import UIKit

/// Transparent overlay view that displays note icons on top of the PDF canvas.
/// All positioning is done in canvas coordinate space.
class NoteOverlayView: UIView {
    // MARK: - Properties
    var notes: [NoteModel] = []
    var openNoteIDs: Set<UUID> = []
    private var noteIconViews: [UUID: NoteIconView] = [:]
    
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
        isUserInteractionEnabled = true
    }
    
    override func draw(_ rect: CGRect) {
        // Keep overlay fully transparent and rely on view-backed note icons
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setBlendMode(.clear)
        ctx.fill(rect)
        ctx.setBlendMode(.normal)
    }
    
    // MARK: - View-backed notes (faster incremental updates)
    /// Update visual subviews to match the provided model. This avoids full redraws.
    func update(notes newNotes: [NoteModel], openNoteIDs newOpenNoteIDs: Set<UUID>, canvas: PDFCanvasView?) {
        // Convert arrays to dict for quick lookup
        var newMap: [UUID: NoteModel] = [:]
        for n in newNotes { newMap[n.id] = n }

        // Remove views for notes that no longer exist
        for (id, view) in noteIconViews {
            if newMap[id] == nil {
                view.removeFromSuperview()
                noteIconViews.removeValue(forKey: id)
            }
        }

        // Add or update views for each note
        for note in newNotes {
            let point = note.point(in: canvas)
            let iconSize = PDFConstants.noteIconSize
            let frame = CGRect(
                x: point.x - iconSize / 2,
                y: point.y - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            
            if let view = noteIconViews[note.id] {
                // Update frame if changed
                if view.frame.origin != frame.origin {
                    view.frame = frame
                }
                view.setOpen(newOpenNoteIDs.contains(note.id))
                view.setColor(note.color)
            } else {
                // Create new note icon view
                let view = NoteIconView(frame: frame, color: note.color)
                view.setOpen(newOpenNoteIDs.contains(note.id))
                addSubview(view)
                noteIconViews[note.id] = view
            }
        }

        // Keep model in sync
        notes = newNotes
        openNoteIDs = newOpenNoteIDs
    }
}

/// Lightweight view representing a single note icon. The icon is movable and tappable.
class NoteIconView: UIView {
    private let iconImageView = UIImageView()
    private var isOpen = false
    private var noteColor: UIColor = .systemBlue
    
    init(frame: CGRect, color: UIColor = .systemBlue) {
        self.noteColor = color
        super.init(frame: frame)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = true // Ensure the icon view can receive touches
        
        // White circular background (always white regardless of theme) - smaller than the view
        let whiteCircleSize = PDFConstants.noteIconSize * 0.85 // Make circle 85% of icon size
        let whiteCircle = UIView()
        whiteCircle.backgroundColor = .white
        whiteCircle.layer.cornerRadius = whiteCircleSize / 2
        whiteCircle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(whiteCircle)
        
        NSLayoutConstraint.activate([
            whiteCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            whiteCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            whiteCircle.widthAnchor.constraint(equalToConstant: whiteCircleSize),
            whiteCircle.heightAnchor.constraint(equalToConstant: whiteCircleSize),
        ])
        
        // Create note icon with SF Symbol - pencil in circle (filled version for closed state)
        // Make icon bigger to fill the circle better
        let iconConfig = UIImage.SymbolConfiguration(pointSize: PDFConstants.noteIconSize * 0.65, weight: .medium)
        let noteIcon = UIImage(systemName: "pencil.circle", withConfiguration: iconConfig)?.withTintColor(noteColor, renderingMode: .alwaysOriginal)
        
        iconImageView.image = noteIcon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.65),
            iconImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.65),
        ])
        
        // Add shadow to the main view
        layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 1.0
    }
    
    func setOpen(_ open: Bool) {
        isOpen = open
        // Use filled version when open, outline when closed
        let iconConfig = UIImage.SymbolConfiguration(pointSize: PDFConstants.noteIconSize * 0.65, weight: .medium)
        if open {
            // Filled/solid version when open
            let filledIcon = UIImage(systemName: "pencil.circle.fill", withConfiguration: iconConfig)?.withTintColor(noteColor, renderingMode: .alwaysOriginal)
            iconImageView.image = filledIcon
            transform = CGAffineTransform(scaleX: 1.1, y: 1.1) // Slight scale for emphasis
        } else {
            // Outline version when closed
            let outlineIcon = UIImage(systemName: "pencil.circle", withConfiguration: iconConfig)?.withTintColor(noteColor, renderingMode: .alwaysOriginal)
            iconImageView.image = outlineIcon
            transform = .identity
        }
    }
    
    func setColor(_ color: UIColor) {
        noteColor = color
        // Update icon with new color
        let iconConfig = UIImage.SymbolConfiguration(pointSize: PDFConstants.noteIconSize * 0.65, weight: .medium)
        if isOpen {
            let filledIcon = UIImage(systemName: "pencil.circle.fill", withConfiguration: iconConfig)?.withTintColor(noteColor, renderingMode: .alwaysOriginal)
            iconImageView.image = filledIcon
        } else {
            let outlineIcon = UIImage(systemName: "pencil.circle", withConfiguration: iconConfig)?.withTintColor(noteColor, renderingMode: .alwaysOriginal)
            iconImageView.image = outlineIcon
        }
    }
}

