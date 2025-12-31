//
//  ColorPickerView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import UIKit

class ColorPickerView: UIView {
    private let colors: [UIColor] = HighlightColor.allCases.map { $0.uiColor }
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
        backgroundColor = UIColor(named: "AppSurface") ?? .white
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
        button.layer.borderColor = (UIColor(named: "AppSurface") ?? UIColor.white).cgColor
        
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

