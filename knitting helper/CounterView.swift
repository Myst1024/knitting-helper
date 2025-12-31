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
    static let counterPadding: CGFloat = 8
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
                // Decrement button
                Button(action: {
                    if counter.value > 0 {
                        counter.value -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(
                            counter.value > 0 ?
                            LinearGradient(
                                    colors: [Color("AccentColor"), Color("AccentColor").opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(counter.value == 0)
                .alignmentGuide(VerticalAlignment.center) { d in d[VerticalAlignment.center] }
                
                    Text("\(counter.value)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isAtMax ? Color("AccentColor") : Color("AppText"))
                
                // Repeat button (when at max) or Increment button
                if isAtMax {
                    Button(action: {
                        counter.value = 0
                        counter.reps += 1
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text("Repeat")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                            .foregroundColor(Color("AppSurface"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color("AccentColor"), Color("AccentColor").opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color("AppText").opacity(0.2), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        counter.value += 1
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color("AccentColor"), Color("AccentColor").opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .alignmentGuide(VerticalAlignment.center) { d in d[VerticalAlignment.center] }
                }
                
                if counter.max != nil {
                    Divider()
                        .frame(height: 24)
                    
                    VStack(spacing: 0) {
                        Text("Reps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(counter.reps)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Reset button
                Button(action: {
                    counter.value = 0
                }) {
                    Image(systemName: "gobackward")
                        .font(.body)
                        .foregroundColor(Color("AccentColor").opacity(0.9))
                }
                .buttonStyle(.plain)
                .opacity(counter.value > 0 ? 1 : 0.3)
                .disabled(counter.value == 0)
            }
        }
        .padding(Constants.counterPadding)
        .background(
            RoundedCornerShape(radius: Constants.cornerRadius, corners: cornersToRound())
                .fill(Color("AppSurface"))
                .shadow(color: position == .single ? Color("AppText").opacity(0.06) : .clear, radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedCornerShape(radius: Constants.cornerRadius, corners: cornersToRound())
                .stroke(Color("AppSeparator"), lineWidth: 0.5)
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
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                        .background(Color("AccentColor").opacity(0.08))
                    .cornerRadius(6)
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
                        .foregroundColor(Color("AccentColor"))
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
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(Color("AccentColor"))
                        .padding(6)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(Color("AppSurface"))
                                    .frame(width: 28, height: 28)
                                Circle()
                                    .stroke(Color("AccentColor"), lineWidth: 1)
                                    .frame(width: 28, height: 28)
                            }
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
            .padding(.top, counters.isEmpty ? 12 : 8)
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
