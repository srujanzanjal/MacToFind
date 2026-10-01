//
//  InteractiveOCRTextView.swift
//  MacToFind
//
//  Interactive OCR text selection component supporting drag-selection over image OCR elements
//  and contextual Copy / Translate actions.
//

import SwiftUI
import AppKit

struct InteractiveOCRTextView: View {
    let elements: [OCRTextElement]
    @Binding var selectedElements: [OCRTextElement]
    let onCopy: (String) -> Void
    let onTranslate: (String) -> Void
    var onSelectionDismissed: (() -> Void)? = nil
    
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var isDragging: Bool = false
    @State private var hasCopied: Bool = false
    
    private var currentDragRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: max(abs(current.x - start.x), 1),
            height: max(abs(current.y - start.y), 1)
        )
    }
    
    private var selectedText: String {
        OCRResult.reconstructSelectedText(from: selectedElements)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Invisible interaction canvas that intercepts mouse events
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragStart == nil {
                                    dragStart = value.startLocation
                                    isDragging = true
                                    hasCopied = false
                                }
                                dragCurrent = value.location
                                
                                if let rect = currentDragRect {
                                    let intersecting = OCRCoordinateConverter.elementsIntersecting(
                                        selectionRect: rect,
                                        elements: elements,
                                        viewSize: geometry.size
                                    )
                                    selectedElements = intersecting
                                }
                            }
                            .onEnded { value in
                                isDragging = false
                                let dragDistance = hypot(value.translation.width, value.translation.height)
                                
                                // Single-click / tap fallback: select single word if clicked
                                if dragDistance < 4 {
                                    if let tappedElement = OCRCoordinateConverter.elementContaining(
                                        point: value.startLocation,
                                        elements: elements,
                                        viewSize: geometry.size
                                    ) {
                                        selectedElements = [tappedElement]
                                    } else {
                                        // Clicked outside any word: clear selection
                                        selectedElements.removeAll()
                                        onSelectionDismissed?()
                                    }
                                } else {
                                    // If drag ended with no elements, clear
                                    if selectedElements.isEmpty {
                                        onSelectionDismissed?()
                                    }
                                }
                                
                                dragStart = nil
                                dragCurrent = nil
                            }
                    )
                
                // Highlight layers for selected OCR elements
                ForEach(selectedElements) { element in
                    let rect = OCRCoordinateConverter.visionToView(
                        visionBox: element.boundingBox,
                        viewSize: geometry.size
                    )
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.28))
                        .frame(width: rect.width, height: rect.height)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.accentColor.opacity(0.65), lineWidth: 0.8)
                        )
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
                
                // Active drag selection marquee box
                if isDragging, let dragRect = currentDragRect {
                    Rectangle()
                        .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .background(Color.accentColor.opacity(0.06))
                        .frame(width: dragRect.width, height: dragRect.height)
                        .position(x: dragRect.midX, y: dragRect.midY)
                        .allowsHitTesting(false)
                }
                
                // Contextual Action Bar for selected text
                if !selectedElements.isEmpty && !isDragging {
                    if let selectionBounds = OCRCoordinateConverter.boundingRect(
                        for: selectedElements,
                        viewSize: geometry.size
                    ) {
                        ContextualTextActionBar(
                            hasCopied: hasCopied,
                            onCopy: {
                                onCopy(selectedText)
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    hasCopied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        hasCopied = false
                                    }
                                }
                            },
                            onTranslate: {
                                onTranslate(selectedText)
                            }
                        )
                        .position(contextualBarPosition(for: selectionBounds, viewSize: geometry.size))
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .allowsHitTesting(true)
                    }
                }
            }
        }
    }
    
    /// Positions the contextual bar directly above (or below if clamped) the selected text bounds.
    private func contextualBarPosition(for bounds: CGRect, viewSize: CGSize) -> CGPoint {
        let barWidth: CGFloat = 170
        let barHeight: CGFloat = 34
        let padding: CGFloat = 8
        
        let centerX = min(max(bounds.midX, barWidth / 2 + 4), viewSize.width - barWidth / 2 - 4)
        
        // Try to place above selection
        let aboveY = bounds.minY - padding - barHeight / 2
        if aboveY - barHeight / 2 >= 0 {
            return CGPoint(x: centerX, y: aboveY)
        }
        
        // If not enough room above, place below
        let belowY = bounds.maxY + padding + barHeight / 2
        return CGPoint(x: centerX, y: min(belowY, viewSize.height - barHeight / 2 - 4))
    }
}

// MARK: - Contextual Action Bar
struct ContextualTextActionBar: View {
    let hasCopied: Bool
    let onCopy: () -> Void
    let onTranslate: () -> Void
    
    @State private var hoveredButton: String?
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onCopy) {
                HStack(spacing: 4) {
                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                    Text(hasCopied ? "Copied" : "Copy")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(hasCopied ? .green : (hoveredButton == "copy" ? .accentColor : .primary))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hoveredButton == "copy" ? Color.accentColor.opacity(0.12) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hoveredButton = hovering ? "copy" : nil
            }
            
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 2)
            
            Button(action: onTranslate) {
                HStack(spacing: 4) {
                    Image(systemName: "character.bubble")
                        .font(.system(size: 11, weight: .medium))
                    Text("Translate")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(hoveredButton == "translate" ? .accentColor : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hoveredButton == "translate" ? Color.accentColor.opacity(0.12) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hoveredButton = hovering ? "translate" : nil
            }
        }
        .padding(3)
        .background(
            ZStack {
                PaletteBlurBackground()
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}
