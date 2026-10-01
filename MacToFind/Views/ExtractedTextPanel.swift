//
//  ExtractedTextPanel.swift
//  MacToFind
//
//  Inspection panel for reviewing and copying OCR-extracted text.
//

import SwiftUI
import AppKit

struct ExtractedTextPanel: View {
    let text: String
    let selectionRect: CGRect
    let screenSize: CGSize
    let onClose: () -> Void
    var onCopied: (() -> Void)? = nil
    
    @State private var hasCopied = false
    @State private var isVisible = false
    
    private let panelWidth: CGFloat = 380
    private let panelHeight: CGFloat = 260
    private let panelMargin: CGFloat = 12
    
    private var panelPosition: CGPoint {
        let centerX = min(max(selectionRect.midX, panelWidth / 2 + panelMargin), screenSize.width - panelWidth / 2 - panelMargin)
        
        // Try to position below the selection
        let belowY = selectionRect.maxY + panelMargin + panelHeight / 2
        
        // If not enough room below, position above
        if belowY + panelHeight / 2 + 20 > screenSize.height {
            let aboveY = selectionRect.minY - panelMargin - panelHeight / 2
            return CGPoint(x: centerX, y: max(panelHeight / 2 + panelMargin, aboveY))
        }
        
        return CGPoint(x: centerX, y: belowY)
    }
    
    private var lineCount: Int {
        text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    
                    Text("Extracted Text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .opacity(0.4)
            
            // Text Content (Selectable & Scrollable)
            ScrollView(.vertical, showsIndicators: true) {
                Text(text)
                    .font(.system(size: 12.5, weight: .regular, design: .default))
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(maxHeight: panelHeight - 90)
            .background(Color.primary.opacity(0.02))
            
            Divider()
                .opacity(0.4)
            
            // Footer
            HStack {
                Text("\(lineCount) line\(lineCount == 1 ? "" : "s") · \(text.count) chars")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    HStack(spacing: 5) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                        Text(hasCopied ? "Copied" : "Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(hasCopied ? .green : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(hasCopied ? Color.green.opacity(0.15) : Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: panelWidth)
        .background(
            ZStack {
                PaletteBlurBackground()
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.88))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.20), radius: 16, x: 0, y: 8)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        .position(panelPosition)
        .scaleEffect(isVisible ? 1.0 : 0.94)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.15)) {
            hasCopied = true
        }
        
        onCopied?()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.15)) {
                hasCopied = false
            }
        }
    }
}
