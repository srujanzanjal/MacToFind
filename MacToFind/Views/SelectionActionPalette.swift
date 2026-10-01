//
//  SelectionActionPalette.swift
//  MacToFind
//
//  Actions palette that appears after a valid rectangle selection.
//

import SwiftUI

struct SelectionActionPalette: View {
    let selectionRect: CGRect
    let screenSize: CGSize
    let isOCRReady: Bool
    let onAskGemini: () -> Void
    let onExtractText: () -> Void
    let onSearchGoogle: () -> Void
    let onTranslate: () -> Void
    let onCopyImage: () -> Void
    let onSaveImage: () -> Void
    
    @State private var isVisible = false
    @State private var hoveredAction: String?
    
    private let paletteHeight: CGFloat = 48
    private let paletteBottomPadding: CGFloat = 10
    
    private var palettePosition: CGPoint {
        let centerX = selectionRect.midX
        
        // Try to position below the selection
        let belowY = selectionRect.maxY + paletteBottomPadding + paletteHeight / 2
        
        // If there's not enough room below, position above
        if belowY + paletteHeight / 2 + 20 > screenSize.height {
            let aboveY = selectionRect.minY - paletteBottomPadding - paletteHeight / 2
            return CGPoint(x: centerX, y: max(paletteHeight / 2 + 10, aboveY))
        }
        
        return CGPoint(x: centerX, y: belowY)
    }
    
    var body: some View {
        HStack(spacing: 2) {
            PaletteActionButton(
                icon: "sparkle.magnifyingglass",
                label: "Ask Gemini",
                id: "gemini",
                hoveredAction: $hoveredAction,
                action: onAskGemini
            )
            
            paletteDivider
            
            PaletteActionButton(
                icon: "doc.text",
                label: "Extract Text",
                id: "extract",
                hoveredAction: $hoveredAction,
                isEnabled: isOCRReady,
                action: onExtractText
            )
            
            paletteDivider
            
            PaletteActionButton(
                icon: "globe",
                label: "Google",
                id: "google",
                hoveredAction: $hoveredAction,
                action: onSearchGoogle
            )
            
            paletteDivider
            
            PaletteActionButton(
                icon: "character.bubble",
                label: "Translate",
                id: "translate",
                hoveredAction: $hoveredAction,
                action: onTranslate
            )
            
            paletteDivider
            
            PaletteActionButton(
                icon: "doc.on.doc",
                label: "Copy",
                id: "copy",
                hoveredAction: $hoveredAction,
                action: onCopyImage
            )
            
            paletteDivider
            
            PaletteActionButton(
                icon: "square.and.arrow.down",
                label: "Save",
                id: "save",
                hoveredAction: $hoveredAction,
                action: onSaveImage
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                PaletteBlurBackground()
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.78))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        .position(palettePosition)
        .scaleEffect(isVisible ? 1.0 : 0.92)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isVisible = true
            }
        }
    }
    
    private var paletteDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 28)
    }
}

// MARK: - Palette Action Button
struct PaletteActionButton: View {
    let icon: String
    let label: String
    let id: String
    @Binding var hoveredAction: String?
    var isEnabled: Bool = true
    let action: () -> Void
    
    private var isHovered: Bool { hoveredAction == id }
    
    var body: some View {
        Button(action: {
            if isEnabled { action() }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isEnabled ? (isHovered ? .accentColor : .primary.opacity(0.8)) : .secondary.opacity(0.4))
                
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isEnabled ? (isHovered ? .accentColor : .secondary) : .secondary.opacity(0.4))
                    .lineLimit(1)
            }
            .frame(width: 64, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered && isEnabled ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredAction = hovering ? id : nil
            }
        }
    }
}

// MARK: - Palette Blur Background
struct PaletteBlurBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Copied Toast
struct CopiedToast: View {
    let message: String
    @Binding var isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    PaletteBlurBackground()
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                }
            }
        }
    }
}
