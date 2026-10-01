//
//  FloatingSearchWindow.swift
//  MacToFind
//
//  Created by MacBook on 06/09/2025.
//

import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers

// MARK: - Floating Search Window
class FloatingSearchWindow: NSPanel {
    private var hostingView: NSHostingView<AnyView>?
    private var appState: AppState?
    private let defaultWindowHeight: CGFloat = 540
    private let defaultWindowWidth: CGFloat = 620
    private var searchFieldFocusHandler: (() -> Void)?
    private var clearChatHandler: (() -> Void)?
    private let searchState = FloatingSearchState()
    
    // SwiftData ModelContainer
    private lazy var modelContainer: ModelContainer = {
        let schema = Schema([
            ChatSession.self,
            SearchHistory.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init(appState: AppState? = nil) {
        self.appState = appState
        
        // Initialize as a floating, resizable panel with native translucency
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: defaultWindowWidth, height: defaultWindowHeight),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        
        setupPanel()
        setupContent()
        positionWindow()
        setupCloseObserver()
    }
    
    private func setupPanel() {
        // Transparent backing for SwiftUI glassmorphism
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        
        // Floating behavior above normal app windows
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        // Don't hide when app is inactive
        hidesOnDeactivate = false
        
        // Movable by clicking and dragging anywhere on the window background
        isMovable = true
        isMovableByWindowBackground = true
        
        // Minimum size constraint
        minSize = NSSize(width: 500, height: 400)
        
        // Round corners on content view
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 18
        contentView?.layer?.masksToBounds = false
    }
    
    private func setupCloseObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloseFloatingSearchWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.makeFirstResponder(nil)
            self?.close()
        }
    }
    
    private func setupContent() {
        updateContent()
    }
    
    private func updateContent() {
        hostingView?.removeFromSuperview()
        
        var content = FloatingSearchInterface(
            appState: appState ?? AppState(),
            searchState: searchState
        )
        content.onWindowVisible = { [weak self] in
            self?.focusSearchField()
        }
        clearChatHandler = {
            NotificationCenter.default.post(name: NSNotification.Name("ClearChat"), object: nil)
        }
        
        hostingView = NSHostingView(rootView: AnyView(
            content
                .modelContainer(modelContainer)
        ))
        hostingView?.frame = contentView?.bounds ?? .zero
        hostingView?.autoresizingMask = [.width, .height]
        
        if let hostingView = hostingView {
            contentView?.addSubview(hostingView)
        }
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let xPos = (screenFrame.width - defaultWindowWidth) / 2 + screenFrame.origin.x
        let yPos = screenFrame.maxY - defaultWindowHeight - 80 // 80px from top
        
        // Ensure within bounds
        let safeX = max(screenFrame.minX, min(xPos, screenFrame.maxX - defaultWindowWidth))
        let safeY = max(screenFrame.minY, min(yPos, screenFrame.maxY - defaultWindowHeight))
        
        setFrame(NSRect(x: safeX, y: safeY, width: defaultWindowWidth, height: defaultWindowHeight), display: true)
    }
    
    // Handle keyboard shortcuts
    override func keyDown(with event: NSEvent) {
        let hasCommand = event.modifierFlags.contains(.command)
        let hasShift = event.modifierFlags.contains(.shift)
        
        if event.keyCode == 53 { // ESC key
            handleEscape()
        } else if hasCommand && event.charactersIgnoringModifiers == "k" { // Command+K
            clearChatHandler?()
        } else if hasCommand && hasShift && event.charactersIgnoringModifiers == "n" { // Command+Shift+N  
            clearChatHandler?()
        } else if hasCommand && !hasShift && event.charactersIgnoringModifiers == "h" { // Command+H
            NotificationCenter.default.post(name: NSNotification.Name("ShowHistory"), object: nil)
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let hasCommand = event.modifierFlags.contains(.command)
        let hasShift = event.modifierFlags.contains(.shift)
        
        if hasCommand && hasShift && event.charactersIgnoringModifiers == "s" {
            if let appDelegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate) {
                appDelegate.openPreferences()
            }
            return true
        } else if hasCommand && event.charactersIgnoringModifiers == "k" {
            clearChatHandler?()
            return true
        } else if hasCommand && hasShift && event.charactersIgnoringModifiers == "n" {
            clearChatHandler?()
            return true
        } else if hasCommand && !hasShift && event.charactersIgnoringModifiers == "h" {
            NotificationCenter.default.post(name: NSNotification.Name("ShowHistory"), object: nil)
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    override func cancelOperation(_ sender: Any?) {
        handleEscape()
    }
    
    private func handleEscape() {
        NotificationCenter.default.post(name: NSNotification.Name("FloatingSearchEscape"), object: nil)
    }
    
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    func focusSearchField() {
        if !self.isKeyWindow {
            self.makeKeyAndOrderFront(nil)
        }
        searchFieldFocusHandler?()
    }
    
    // Display search result received from drawing overlay
    func displaySearchResult(query: String, image: NSImage?, result: String) {
        // Start a fresh conversational context for new screen captures
        searchState.startNewCaptureSession(query: query, image: image, result: result)
        
        if !self.isVisible {
            self.makeKeyAndOrderFront(nil)
        } else if !self.isKeyWindow {
            self.makeKey()
        }
        self.focusSearchField()
    }
}

// MARK: - Floating Search State
class FloatingSearchState: ObservableObject {
    @Published var messages: [MinimalChatMessage] = []
    var onArchiveCurrentSession: (() -> Void)?
    var onSaveSession: (() -> Void)?
    
    func startNewCaptureSession(query: String, image: NSImage?, result: String) {
        // If there's an ongoing chat, archive it to history first
        if !messages.isEmpty {
            onArchiveCurrentSession?()
            messages.removeAll()
        }
        
        appendSearchResult(query: query, image: image, result: result)
        onSaveSession?()
    }
    
    func appendSearchResult(query: String, image: NSImage?, result: String) {
        let userMessage = MinimalChatMessage(
            content: query,
            images: image != nil ? [image!] : nil,
            isUser: true
        )
        let assistantMessage = MinimalChatMessage(
            content: result,
            images: nil,
            isUser: false
        )
        messages.append(userMessage)
        messages.append(assistantMessage)
    }
}

// MARK: - Floating Search Interface
struct FloatingSearchInterface: View {
    let appState: AppState
    @ObservedObject var searchState: FloatingSearchState
    var onWindowVisible: (() -> Void)? = nil
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var geminiService = GeminiService()
    @StateObject private var historyManager = ChatHistoryManager()
    @State private var searchText = ""
    @State private var attachedImages: [NSImage] = []
    @State private var isLoading = false
    @FocusState private var isSearchFocused: Bool
    @State private var showHistory = false
    @State private var selectedSession: ChatSession?
    @State private var previewImage: NSImage?
    
    private let clearChatNotification = NotificationCenter.default.publisher(for: NSNotification.Name("ClearChat"))
    private let showHistoryNotification = NotificationCenter.default.publisher(for: NSNotification.Name("ShowHistory"))
    private let escapeNotification = NotificationCenter.default.publisher(for: NSNotification.Name("FloatingSearchEscape"))
    
    var body: some View {
        ZStack {
            // Main Content Layout
            VStack(spacing: 0) {
                // 1. Top Fixed Header
                headerView
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
                
                Divider()
                    .opacity(0.25)
                
                // 2. Middle Body: History sidebar + Conversation area
                HStack(spacing: 0) {
                    if showHistory {
                        HistorySidebarView(
                            selectedSession: $selectedSession,
                            currentMessages: $searchState.messages,
                            historyManager: historyManager,
                            onNewChat: handleClearChat
                        )
                        .frame(width: 260)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(1)
                        
                        Divider()
                            .opacity(0.3)
                    }
                    
                    VStack(spacing: 0) {
                        if searchState.messages.isEmpty {
                            EmptyStateView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            MinimalChatContainer(
                                messages: $searchState.messages,
                                onImageClick: { image in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        previewImage = image
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        // Compact assistant loading indicator
                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.65)
                                Text("Gemini is thinking...")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                            )
                            .padding(.bottom, 8)
                            .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                    .opacity(0.25)
                
                // 3. Bottom Fixed Input Bar
                BottomInputBar(
                    searchText: $searchText,
                    attachedImages: $attachedImages,
                    isLoading: isLoading,
                    onSearch: performSearch,
                    onClear: {
                        searchText = ""
                        attachedImages = []
                    },
                    isSearchFocused: $isSearchFocused
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            }
            .background(
                ZStack {
                    GlassmorphismBackground()
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.65))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            
            // 4. Modal Image Preview Overlay
            if let imageToPreview = previewImage {
                ImagePreviewModal(
                    image: imageToPreview,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            previewImage = nil
                        }
                    }
                )
                .zIndex(10)
            }
        }
        .onAppear {
            historyManager.setModelContext(modelContext)
            
            // Wire up conversation lifecycle callbacks
            searchState.onArchiveCurrentSession = { [weak historyManager] in
                if let hm = historyManager, !searchState.messages.isEmpty {
                    hm.saveToCurrentSession(messages: searchState.messages)
                    hm.clearCurrentSession()
                }
            }
            searchState.onSaveSession = { [weak historyManager] in
                historyManager?.saveToCurrentSession(messages: searchState.messages)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
                onWindowVisible?()
            }
        }
        .onChange(of: searchState.messages.count) { _ in
            if !searchState.messages.isEmpty {
                historyManager.saveToCurrentSession(messages: searchState.messages)
            }
        }
        .onReceive(clearChatNotification) { _ in
            handleClearChat()
        }
        .onReceive(showHistoryNotification) { _ in
            toggleHistory()
        }
        .onReceive(escapeNotification) { _ in
            handleHierarchicalEscape()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            // LEFT: App Brand
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("MacToFind")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.9))
            }
            
            // CENTER / LEFT: New Search Button
            Button(action: handleClearChat) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("New Search")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.75))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Start a new search (⌘⇧N)")
            
            Spacer()
            
            // RIGHT: History, Settings, Close
            HStack(spacing: 6) {
                Button(action: toggleHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                        .foregroundColor(showHistory ? .accentColor : .secondary)
                        .frame(width: 26, height: 26)
                        .background(showHistory ? Color.accentColor.opacity(0.12) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Chat History (⌘H)")
                
                Button(action: openSettings) {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Settings (⌘⇧S)")
                
                Button(action: closeWindow) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Actions
    private func handleHierarchicalEscape() {
        if previewImage != nil {
            withAnimation(.easeOut(duration: 0.15)) {
                previewImage = nil
            }
        } else if showHistory {
            toggleHistory()
        } else {
            closeWindow()
        }
    }
    
    private func closeWindow() {
        NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingSearchWindow"), object: nil)
    }
    
    private func toggleHistory() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showHistory.toggle()
        }
    }
    
    private func openSettings() {
        if let appDelegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate) {
            appDelegate.openPreferences()
        } else {
            let settings = SettingsWindow()
            settings.showSettings(animated: true)
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedImages.isEmpty else { return }
        
        let queryText = searchText
        let imagesToSend = attachedImages
        
        Task {
            await searchWithGemini(text: queryText, images: imagesToSend)
        }
    }
    
    private func searchWithGemini(text: String, images: [NSImage]) async {
        isLoading = true
        
        await MainActor.run {
            let messageText = text.isEmpty && !images.isEmpty ? 
                (images.count == 1 ? "What's in this image?" : "What's in these images?") : text
            
            searchState.messages.append(MinimalChatMessage(
                content: messageText,
                images: images.isEmpty ? nil : images,
                isUser: true
            ))
            
            searchText = ""
            attachedImages = []
        }
        
        do {
            let messageHistory = searchState.messages.dropLast().map { message in
                (content: message.content, images: message.images ?? [], isUser: message.isUser)
            }
            
            let result = try await geminiService.searchWithHistory(
                Array(messageHistory).map { (content: $0.content, image: $0.images.first, isUser: $0.isUser) },
                newText: text.isEmpty && !images.isEmpty ? 
                    (images.count == 1 ? "What's in this image?" : "What's in these images?") : text,
                newImage: images.first
            )
            
            await MainActor.run {
                searchState.messages.append(MinimalChatMessage(
                    content: result,
                    images: nil,
                    isUser: false
                ))
                
                isLoading = false
                historyManager.saveToCurrentSession(messages: searchState.messages)
                isSearchFocused = true
            }
        } catch {
            await MainActor.run {
                searchState.messages.append(MinimalChatMessage(
                    content: "⚠️ **Search Error:** \(error.localizedDescription)\n\nPlease check your internet connection and Gemini API key in Settings.",
                    image: nil,
                    isUser: false
                ))
                isLoading = false
                isSearchFocused = true
            }
        }
    }
    
    private func handleClearChat() {
        if !searchState.messages.isEmpty {
            historyManager.saveToCurrentSession(messages: searchState.messages)
        }
        clearChat()
    }
    
    private func clearChat() {
        withAnimation(.easeOut(duration: 0.2)) {
            searchState.messages = []
            searchText = ""
            attachedImages = []
            selectedSession = nil
            previewImage = nil
            historyManager.clearCurrentSession()
        }
        isSearchFocused = true
    }
}

// MARK: - Bottom Input Bar
struct BottomInputBar: View {
    @Binding var searchText: String
    @Binding var attachedImages: [NSImage]
    let isLoading: Bool
    let onSearch: () -> Void
    let onClear: () -> Void
    @FocusState.Binding var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            // Attached images preview
            if !attachedImages.isEmpty {
                ImagePreviewBar(images: $attachedImages)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
            }
            
            HStack(spacing: 10) {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Text input
                PasteableTextField(
                    text: $searchText,
                    images: $attachedImages,
                    isFocused: $isSearchFocused,
                    onSubmit: onSearch,
                    onFocus: {}
                )
                
                // Clear button
                if !searchText.isEmpty || !attachedImages.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Clear input")
                }
                
                // Send button
                Button(action: onSearch) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(canSend ? .accentColor : Color.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("Send follow-up question (Return)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    private var canSend: Bool {
        (!searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedImages.isEmpty) && !isLoading
    }
}

// MARK: - Enlarged Image Preview Modal
struct ImagePreviewModal: View {
    let image: NSImage
    let onClose: () -> Void
    @State private var isCopied = false
    
    var body: some View {
        ZStack {
            // Dark translucent background with tap to close
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            // Content Card
            VStack(spacing: 12) {
                // Top bar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text("Captured Selection")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Copy button
                    Button(action: copyImage) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(isCopied ? "Copied" : "Copy Image")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Save button
                    Button(action: saveImage) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 11))
                            Text("Save Image...")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close preview (Esc)")
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
                // Full aspect-fit image
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
            .padding(32)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
    
    private func copyImage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCopied = false
            }
        }
    }
    
    private func saveImage() {
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

// MARK: - Glassmorphism Background
struct GlassmorphismBackground: NSViewRepresentable {
    @Environment(\.colorScheme) var colorScheme
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = colorScheme == .dark ? .underWindowBackground : .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 18
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("What can I help you find?")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))
            
            Text("Select an area with Cmd+Shift+Space, or type a query below.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}