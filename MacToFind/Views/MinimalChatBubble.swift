//
//  MinimalChatBubble.swift
//  MacToFind
//
//  Created by MacBook on 06/09/2025.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MinimalChatMessage: Identifiable {
    let id: UUID
    let content: String
    let image: NSImage?  // Keep for backward compatibility
    let images: [NSImage]?  // Field for multiple images
    let isUser: Bool
    let timestamp: Date
    
    // Full initializer with all parameters
    init(id: UUID = UUID(), content: String, images: [NSImage]? = nil, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.image = images?.first
        self.images = images
        self.isUser = isUser
        self.timestamp = timestamp
    }
    
    // Convenience initializer for single image
    init(content: String, image: NSImage?, isUser: Bool) {
        self.init(id: UUID(), content: content, images: image != nil ? [image!] : nil, isUser: isUser, timestamp: Date())
    }
    
    // Convenience initializer for multiple images
    init(content: String, images: [NSImage]?, isUser: Bool) {
        self.init(id: UUID(), content: content, images: images, isUser: isUser, timestamp: Date())
    }
}

struct MinimalChatBubble: View {
    let message: MinimalChatMessage
    var onImageClick: ((NSImage) -> Void)? = nil
    
    @State private var isHovered = false
    @State private var showActions = false
    @State private var isCopied = false
    @State private var isImageCopied = false
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
            if message.isUser {
                userContent
            } else {
                assistantContent
            }
        }
        .padding(.horizontal, message.isUser ? 32 : 16)
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
                showActions = hovering
            }
        }
    }
    
    // MARK: - User Message / Context Card
    @ViewBuilder
    private var userContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // If message has captured images, render as a clean Context Card
            if let images = message.images, let firstImage = images.first {
                VStack(alignment: .leading, spacing: 8) {
                    // Header label
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text("Selected Region")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Action buttons for the image
                        HStack(spacing: 8) {
                            Button(action: { copyImage(firstImage) }) {
                                HStack(spacing: 3) {
                                    Image(systemName: isImageCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10))
                                    Text(isImageCopied ? "Copied" : "Copy")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Copy image to clipboard")
                            
                            Button(action: { saveImage(firstImage) }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 10))
                                    Text("Save")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Save image to disk...")
                        }
                    }
                    
                    // Thumbnail container
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: firstImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 420, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onImageClick?(firstImage)
                            }
                        
                        // Click to enlarge badge
                        Button(action: { onImageClick?(firstImage) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Enlarge")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                            .foregroundColor(.primary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .help("View larger preview (Esc to close)")
                    }
                }
            }
            
            // Text query
            if !message.content.isEmpty {
                Text(message.content)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            
            // Subtle timestamp
            if showActions {
                HStack {
                    Spacer()
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .transition(.opacity)
            }
        }
        .padding(14)
        .frame(maxWidth: 460, alignment: .leading)
        .background(Color.accentColor.opacity(0.12))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - Assistant Message
    @ViewBuilder
    private var assistantContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Gemini response header
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)
                Text("Gemini")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if showActions {
                    HStack(spacing: 8) {
                        Text(formatTime(message.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Button(action: copyMessage) {
                            HStack(spacing: 3) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10))
                                Text(isCopied ? "Copied" : "Copy")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Copy response text")
                    }
                    .transition(.opacity)
                }
            }
            
            // Markdown formatted content
            if !message.content.isEmpty {
                MarkdownTextView(content: message.content)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Helpers
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func copyMessage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCopied = false
            }
        }
    }
    
    private func copyImage(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        withAnimation(.easeInOut(duration: 0.2)) {
            isImageCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isImageCopied = false
            }
        }
    }
    
    private func saveImage(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Captured Image"
        savePanel.nameFieldStringValue = "MacToFind-capture.png"
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            guard let tiffData = image.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData) else { return }
            
            let isJpeg = url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
            let fileType: NSBitmapImageRep.FileType = isJpeg ? .jpeg : .png
            if let data = bitmapImage.representation(using: fileType, properties: [:]) {
                try? data.write(to: url)
            }
        }
    }
}

// MARK: - Minimal Chat Container
struct MinimalChatContainer: View {
    @Binding var messages: [MinimalChatMessage]
    var onImageClick: ((NSImage) -> Void)? = nil
    @Namespace private var bottomID
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: true) {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        MinimalChatBubble(message: message, onImageClick: onImageClick)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom)
                                        .combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }
}
