//
//  CounterView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI

// MARK: - Constants

private enum Constants {
    static let cornerRadius: CGFloat = 8
    static let maxFieldWidth: CGFloat = 50
    static let shadowRadius: CGFloat = 2
    static let shadowOpacity: CGFloat = 0.08
    static let defaultMaxValue: Int = 10
}

enum CounterPosition {
    case single
    case first
    case middle
    case last
}

// MARK: - Counter Model

/// Represents a stitch or row counter with a name and numeric value
struct Counter: Identifiable {
    let id: UUID
    var name: String
    var value: Int
    var max: Int?
    var reps: Int
    
    init(id: UUID = UUID(), name: String = "Counter", value: Int = 0, max: Int? = nil, reps: Int = 0) {
        self.id = id
        self.name = name
        self.value = value
        self.max = max
        self.reps = reps
    }
}

// MARK: - Counter View

/// Individual counter component with increment/decrement buttons and delete option
struct CounterView: View {
    @Binding var counter: Counter
    let onDelete: () -> Void
    var position: CounterPosition = .single
    
    @State private var isEditingName = false
    @State private var isEditingMax = false
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isMaxFieldFocused: Bool
    
    private var isAtMax: Bool {
        if let max = counter.max {
            return counter.value >= max
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top row: name, max, and delete button
            HStack {
                if isEditingName {
                    TextField("Counter Name", text: $counter.name)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .font(.subheadline)
                        .onSubmit {
                            isEditingName = false
                        }
                } else {
                    Text(counter.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("AppText"))
                        .onTapGesture {
                            isEditingName = true
                            isNameFieldFocused = true
                        }
                }
                
                Spacer()
                
                MaxValueEditor(
                    max: $counter.max,
                    isEditing: $isEditingMax,
                    isFocused: $isMaxFieldFocused
                )
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            
            // Middle row: value and reps (if applicable)
            HStack(spacing: 10) {
                // Reset button
                Button(action: {
                    counter.value = 0
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.accentWarm.opacity(counter.value > 0 ? 0.15 : 0.05))
                            .frame(width: 28, height: 28)

                        Image(systemName: "gobackward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(counter.value > 0 ? LinearGradient.accentWarm : LinearGradient.disabled)
                    }
                }
                .buttonStyle(.plain)
                .opacity(counter.value > 0 ? 1 : 0.4)
                .disabled(counter.value == 0)

                // Decrement button
                Button(action: {
                    if counter.value > 0 {
                        counter.value -= 1
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(counter.value > 0 ? LinearGradient.accent : LinearGradient.disabled)
                            .frame(width: 32, height: 32)

                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(counter.value == 0)
                .alignmentGuide(VerticalAlignment.center) { d in d[VerticalAlignment.center] }
                
                Text("\(counter.value)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(isAtMax ? LinearGradient.accent : LinearGradient(
                        colors: [Color("AppText"), Color("AppText").opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                // Repeat button (when at max) or Increment button
                if isAtMax {
                    Button(action: {
                        // Reset counter and increment reps
                        var newCounter = counter
                        newCounter.value = 0
                        newCounter.reps += 1
                        counter = newCounter
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Repeat")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                LinearGradient.accent

                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .enhancedShadow(color: Color("AccentColor"), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        counter.value += 1
                    }) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.accent)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .alignmentGuide(VerticalAlignment.center) { d in d[VerticalAlignment.center] }
                }
                
                if counter.max != nil {
                    Divider()
                        .frame(height: 24)
                        .background(Color("AppSeparator"))

                    VStack(spacing: 2) {
                        Text("Reps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(counter.reps)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient.accentTertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient.accentTertiaryLight)
                    )

                    // Reset reps button (only if reps > 0)
                    if counter.reps > 0 {
                        Button(action: {
                            counter.reps = 0
                        }) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.accentTertiary.opacity(0.15))
                                    .frame(width: 24, height: 24)

                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(LinearGradient.accentTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            ZStack {
                // Base surface
                RoundedCornerShape(radius: Constants.cornerRadius, corners: cornersToRound())
                    .fill(Color("AppSurface"))
                
                // Subtle gradient overlay
                RoundedCornerShape(radius: Constants.cornerRadius, corners: cornersToRound())
                    .fill(LinearGradient.accentLight.opacity(0.4))
            }
            .shadow(
                color: position == .single ? Color("AppText").opacity(0.08) : .clear,
                radius: position == .single ? 10 : 0,
                x: 0,
                y: position == .single ? 4 : 0
            )
        )
        .overlay(
            RoundedCornerShape(radius: Constants.cornerRadius, corners: cornersToRound())
                .stroke(
                    LinearGradient(
                        colors: [
                            Color("AppSeparator"),
                            Color("AppSeparator").opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .onChange(of: isMaxFieldFocused) { _, isFocused in
            if !isFocused && isEditingMax {
                isEditingMax = false
            }
        }
        .onChange(of: isNameFieldFocused) { _, isFocused in
            if !isFocused && isEditingName {
                isEditingName = false
            }
        }
    }
    
    private func cornersToRound() -> UIRectCorner {
        switch position {
        case .single:
            return .allCorners
        case .first:
            return [.topLeft, .topRight]
        case .middle:
            return []
        case .last:
            return [.bottomLeft, .bottomRight]
        }
    }
}

// MARK: - Max Value Editor

struct MaxValueEditor: View {
    @Binding var max: Int?
    @Binding var isEditing: Bool
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        if isEditing {
            HStack(spacing: 0) {
                Text("max:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("Max", value: $max, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: Constants.maxFieldWidth)
                    .font(.caption)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .onSubmit {
                        isEditing = false
                    }
                Button("Done") {
                    max = max ?? Constants.defaultMaxValue
                    isEditing = false
                    isFocused = false
                }
                .font(.caption2)
                    .foregroundColor(Color("AccentColor"))
            }
        } else {
            if let maxValue = max {
                Text("max: \(maxValue)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(LinearGradient.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient.accentLight)
                    )
                    .onTapGesture {
                        isEditing = true
                        isFocused = true
                    }
            } else {
                Button {
                    max = Constants.defaultMaxValue
                    isEditing = true
                    isFocused = true
                } label: {
                    Text("+ max")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(LinearGradient.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(LinearGradient.accent, lineWidth: 1)
                        )
                }
            }
        }
    }
}

// MARK: - Custom Shape for Selective Corner Rounding

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Counters Overlay

/// Container view that displays all counters fixed at the top of the screen
struct CountersOverlay: View {
    @Binding var counters: [Counter]
    let onAddCounter: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Counter list
            if !counters.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(counters.enumerated()), id: \.element.id) { index, _ in
                        CounterView(
                            counter: $counters[index],
                            onDelete: {
                                counters.remove(at: index)
                            },
                            position: counterPosition(for: index, total: counters.count)
                        )
                        .padding(.horizontal, 12)
                    }
                }
            }
            
            // Floating add button
            HStack {
                Spacer()
                
                Button(action: onAddCounter) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.accentLight)
                            .frame(width: 36, height: 36)
                            .blur(radius: 4)

                        Circle()
                            .fill(LinearGradient.accent)
                            .frame(width: 32, height: 32)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .enhancedShadow(color: Color("AccentColor"), radius: 8, y: 4)
                .padding(.trailing, 16)
            }
            .padding(.top, counters.isEmpty ? 8 : 4)
            .padding(.bottom, 8)
        }
    }
    
    private func counterPosition(for index: Int, total: Int) -> CounterPosition {
        if total == 1 {
            return .single
        } else if index == 0 {
            return .first
        } else if index == total - 1 {
            return .last
        } else {
            return .middle
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CountersOverlay(
            counters: .constant([
                Counter(name: "Rows", value: 12, max: 20, reps: 2),
                Counter(name: "Stitches", value: 45, max: 50, reps: 0),
                Counter(name: "Repeats", value: 3)
            ]),
            onAddCounter: {}
        )
        
        Spacer()
    }
}
