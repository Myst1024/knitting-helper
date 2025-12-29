//
//  CounterView.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 12/27/25.
//

import SwiftUI

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
        VStack(spacing: 6) {
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
                        .foregroundColor(.primary)
                        .onTapGesture {
                            isEditingName = true
                            isNameFieldFocused = true
                        }
                }
                
                Spacer()
                
                // Max value (tappable to edit)
                if isEditingMax {
                    HStack(spacing: 4) {
                        Text("max:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("Max", value: $counter.max, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .font(.caption)
                            .keyboardType(.numberPad)
                            .focused($isMaxFieldFocused)
                            .onSubmit {
                                isEditingMax = false
                            }
                        Button("Done") {
                            counter.max = counter.max ?? 10
                            isEditingMax = false
                            isMaxFieldFocused = false
                        }
                        .font(.caption2)
                        .foregroundColor(.purple)
                    }
                } else {
                    if let max = counter.max {
                        Text("max: \(max)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(6)
                            .onTapGesture {
                                isEditingMax = true
                                isMaxFieldFocused = true
                            }
                    } else {
                        Button {
                            counter.max = 10
                            isEditingMax = true
                            isMaxFieldFocused = true
                        } label: {
                            Text("+ max")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            
            // Middle row: value and reps (if applicable)
            HStack(spacing: 12) {
                // Decrement button
                Button(action: {
                    if counter.value > 0 {
                        counter.value -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(counter.value > 0 ? .purple : .gray.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(counter.value == 0)
                
                VStack(spacing: 0) {
                    Text("Count")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(counter.value)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(isAtMax ? .purple : .primary)
                }
                
                // Repeat button (when at max) or Increment button
                if isAtMax {
                    Button(action: {
                        counter.value = 0
                        counter.reps += 1
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text("Repeat")
                                .fontWeight(.semibold)
                        }
                        .font(.callout)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        counter.value += 1
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }
                
                if counter.max != nil {
                    Divider()
                        .frame(height: 30)
                    
                    VStack(spacing: 0) {
                        Text("Reps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(counter.reps)")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Reset button
                Button(action: {
                    counter.value = 0
                }) {
                    Image(systemName: "gobackward")
                        .font(.body)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .opacity(counter.value > 0 ? 1 : 0.3)
                .disabled(counter.value == 0)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
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
}

// MARK: - Counters Overlay

/// Container view that displays all counters fixed at the top of the screen
struct CountersOverlay: View {
    @Binding var counters: [Counter]
    let onAddCounter: () -> Void
    
    var body: some View {
        if !counters.isEmpty || true { // Always show to allow adding counters
            VStack(spacing: 8) {
                // Header with add button
                HStack {
                    Text("Counters")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: onAddCounter) {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                // Counter list (full width)
                if !counters.isEmpty {
                    ForEach($counters) { $counter in
                        CounterView(counter: $counter) {
                            if let index = counters.firstIndex(where: { $0.id == counter.id }) {
                                counters.remove(at: index)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 8)
                }
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
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
