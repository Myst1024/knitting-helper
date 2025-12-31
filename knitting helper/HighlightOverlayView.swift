//
//  HighlightOverlayView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import UIKit

/// Transparent overlay view that draws highlights, handles, and delete buttons on top of the PDF canvas.
/// All drawing is done in canvas coordinate space.
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
            let deleteSize = PDFConstants.deleteButtonSize
            let modelRectRaw = model.rect(in: canvas)
            let modelRect = CGRect(x: 0, y: modelRectRaw.minY, width: bounds.width, height: modelRectRaw.height)
            let deleteFrame = CGRect(
                x: modelRect.minX + PDFConstants.deleteButtonInset,
                y: modelRect.minY - deleteSize - PDFConstants.deleteButtonOffset,
                width: deleteSize,
                height: deleteSize
            )
            if let db = deleteButtonView {
                db.frame = deleteFrame
            } else {
                let db = UIView(frame: deleteFrame)
                db.backgroundColor = UIColor(named: "AppSurface") ?? .white
                db.layer.cornerRadius = deleteSize / 2
                db.layer.shadowColor = (UIColor(named: "AppText") ?? UIColor.black).withAlphaComponent(0.4).cgColor
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
            let colorSize = PDFConstants.colorPickerButtonSize
            let deleteButtonX = modelRect.minX + PDFConstants.deleteButtonInset
            let colorFrame = CGRect(
                x: deleteButtonX + PDFConstants.deleteButtonSize + PDFConstants.colorPickerButtonSpacing,
                y: modelRect.minY - colorSize - PDFConstants.deleteButtonOffset,
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
                cb.layer.shadowColor = (UIColor(named: "AppText") ?? UIColor.black).withAlphaComponent(0.4).cgColor
                cb.layer.shadowOffset = CGSize(width: 0, height: 4)
                cb.layer.shadowRadius = 8
                cb.layer.shadowOpacity = 1.0
                cb.isUserInteractionEnabled = false

                let iconConfig = UIImage.SymbolConfiguration(pointSize: colorSize / 2, weight: .medium)
                if let palette = UIImage(systemName: "paintpalette.fill", withConfiguration: iconConfig)?.withTintColor(UIColor(named: "AppSurface") ?? .white, renderingMode: .alwaysOriginal) {
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
        fillView.backgroundColor = UIColor.systemYellow.withAlphaComponent(PDFConstants.highlightOpacity)
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
            topBorder.heightAnchor.constraint(equalToConstant: PDFConstants.highlightStrokeWidth),

            bottomBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: PDFConstants.highlightStrokeWidth),
        ])

        // Handles are white filled with a subtle colored stroke when selected.
        topHandle.backgroundColor = UIColor(named: "AppSurface") ?? .white
        bottomHandle.backgroundColor = UIColor(named: "AppSurface") ?? .white
        topHandle.layer.cornerRadius = PDFConstants.handleCornerRadius
        bottomHandle.layer.cornerRadius = PDFConstants.handleCornerRadius
        topHandle.translatesAutoresizingMaskIntoConstraints = false
        bottomHandle.translatesAutoresizingMaskIntoConstraints = false
        // Add handles after borders so they render above the border views
        addSubview(topHandle)
        addSubview(bottomHandle)

        NSLayoutConstraint.activate([
            topHandle.widthAnchor.constraint(equalToConstant: PDFConstants.handleWidth),
            topHandle.heightAnchor.constraint(equalToConstant: PDFConstants.handleHeight),
            topHandle.centerXAnchor.constraint(equalTo: centerXAnchor),
            topHandle.topAnchor.constraint(equalTo: topAnchor, constant: -PDFConstants.handleHeight / 2),

            bottomHandle.widthAnchor.constraint(equalToConstant: PDFConstants.handleWidth),
            bottomHandle.heightAnchor.constraint(equalToConstant: PDFConstants.handleHeight),
            bottomHandle.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottomHandle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: PDFConstants.handleHeight / 2),
        ])
    }

    func updateColor(_ color: UIColor) {
        currentColor = color
        fillView.backgroundColor = color.withAlphaComponent(PDFConstants.highlightOpacity)
        // If currently selected, update the visible borders and handle strokes
        if !topBorder.isHidden {
            topBorder.backgroundColor = color
            bottomBorder.backgroundColor = color
            topHandle.layer.borderColor = color.cgColor
            bottomHandle.layer.borderColor = color.cgColor
            topHandle.layer.borderWidth = PDFConstants.handleStrokeWidth
            bottomHandle.layer.borderWidth = PDFConstants.handleStrokeWidth
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
            topHandle.layer.borderWidth = PDFConstants.handleStrokeWidth
            bottomHandle.layer.borderWidth = PDFConstants.handleStrokeWidth
        } else {
            topHandle.layer.borderWidth = 0.0
            bottomHandle.layer.borderWidth = 0.0
        }
    }
}

