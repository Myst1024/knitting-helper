//
//  BookmarkOverlayView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/31/25.
//

import UIKit

/// Transparent overlay view that displays bookmark icons on top of the PDF canvas.
/// All positioning is done in canvas coordinate space.
class BookmarkOverlayView: UIView {
    // MARK: - Properties
    var bookmarks: [BookmarkModel] = []
    private var bookmarkIconViews: [UUID: BookmarkIconView] = [:]

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
        // Keep overlay fully transparent and rely on view-backed bookmark icons
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setBlendMode(.clear)
        ctx.fill(rect)
        ctx.setBlendMode(.normal)
    }

    // MARK: - View-backed bookmarks (faster incremental updates)
    /// Update visual subviews to match the provided model. This avoids full redraws.
    func update(bookmarks newBookmarks: [BookmarkModel], canvas: PDFCanvasView?) {
        // Convert arrays to dict for quick lookup
        var newMap: [UUID: BookmarkModel] = [:]
        for b in newBookmarks { newMap[b.id] = b }

        // Remove views for bookmarks that no longer exist
        for (id, view) in bookmarkIconViews {
            if newMap[id] == nil {
                view.removeFromSuperview()
                bookmarkIconViews.removeValue(forKey: id)
            }
        }

        // Add or update views for each bookmark
        for bookmark in newBookmarks {
            let point = bookmark.point(in: canvas)
            let iconSize = PDFConstants.bookmarkIconSize
            let frame = CGRect(
                x: point.x - iconSize / 2,
                y: point.y - iconSize / 2,
                width: iconSize,
                height: iconSize
            )

            if let view = bookmarkIconViews[bookmark.id] {
                // Update frame if changed
                if view.frame.origin != frame.origin {
                    view.frame = frame
                }
                view.setColor(bookmark.color)
            } else {
                // Create new bookmark icon view
                let view = BookmarkIconView(frame: frame, color: bookmark.color)
                addSubview(view)
                bookmarkIconViews[bookmark.id] = view
            }
        }

        // Keep model in sync
        bookmarks = newBookmarks
    }
}

/// Lightweight view representing a single bookmark icon. The icon is tappable.
/// Dragging is handled by the PDFViewCoordinator.
class BookmarkIconView: UIView {
    private let iconImageView = UIImageView()
    private var bookmarkColor: UIColor = .systemOrange

    init(frame: CGRect, color: UIColor = .systemOrange) {
        self.bookmarkColor = color
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
        let whiteCircleSize = PDFConstants.bookmarkIconSize * 0.85 // Make circle 85% of icon size
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

        // Create bookmark icon with SF Symbol - bookmark.fill
        let iconConfig = UIImage.SymbolConfiguration(pointSize: PDFConstants.bookmarkIconSize * 0.65, weight: .medium)
        let bookmarkIcon = UIImage(systemName: "bookmark.fill", withConfiguration: iconConfig)?.withTintColor(bookmarkColor, renderingMode: .alwaysOriginal)

        iconImageView.image = bookmarkIcon
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


    func setColor(_ color: UIColor) {
        bookmarkColor = color
        // Update icon with new color
        let iconConfig = UIImage.SymbolConfiguration(pointSize: PDFConstants.bookmarkIconSize * 0.65, weight: .medium)
        let bookmarkIcon = UIImage(systemName: "bookmark.fill", withConfiguration: iconConfig)?.withTintColor(bookmarkColor, renderingMode: .alwaysOriginal)
        iconImageView.image = bookmarkIcon
    }
}
