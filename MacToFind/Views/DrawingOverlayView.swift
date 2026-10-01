//
//  DrawingOverlayView.swift
//  MacToFind
//
//  Created by MacBook on 06/09/2025.
//

import SwiftUI
import Vision
import UniformTypeIdentifiers

struct DrawingOverlayView: View {
    @EnvironmentObject var appState: AppState
    @State private var backgroundImage: NSImage?
    @State private var paths: [DrawingPath] = []
    @State private var currentPath = DrawingPath()
    @State private var isDrawing = false
    @State private var detectedShape: DetectedShape = .unknown
    @State private var showShapeHint = false
    @State private var selectedRegion: CGRect?
    @State private var isProcessing = false
    @State private var loadingStageText = "Analyzing selection..."
    @State private var showActionPalette = false
    @State private var cachedCroppedImage: NSImage?
    @State private var cachedOCRText: String?
    @State private var cachedOCRResult: OCRResult?
    @State private var selectedTextElements: [OCRTextElement] = []
    @State private var isOCRRunning = false
    @State private var showExtractedTextPanel = false
    @State private var showToast = false
    @State private var toastMessage = "Copied!"
    
    private var hasValidSelection: Bool {
        if let region = selectedRegion {
            return region.width >= 10 && region.height >= 10
        }
        return !paths.isEmpty
    }
    
    let screenCapture = ScreenCaptureManagerV2.shared
    let ocrManager = OCRManager()
    let geminiService = GeminiService()
    let elementDetector = ElementDetector()
    
    @State private var detectedElements: [ElementDetector.DetectedElement] = []
    @State private var highlightedElement: ElementDetector.DetectedElement?
    
    // Screenshot passed from AppDelegate
    let screenshot: NSImage?
    
    init(screenshot: NSImage? = nil) {
        self.screenshot = screenshot
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background screenshot - display at 1:1 scale (no scaling)
                if let image = backgroundImage {
                    Image(nsImage: image)
                        // Don't use .resizable() or .scaledToFit() - keep original size
                        .frame(width: image.size.width, height: image.size.height)
                        // Remove opacity to show apps without transparency
                } else {
                    Color.black.opacity(0.3)
                }
                
                // Drawing canvas
                Canvas { context, size in
                    // Draw completed paths
                    for path in paths {
                        context.stroke(
                            path.path,
                            with: .color(path.strokeColor),
                            lineWidth: path.lineWidth
                        )
                    }
                    
                    // Draw current path
                    if isDrawing {
                        context.stroke(
                            currentPath.path,
                            with: .color(currentPath.strokeColor),
                            lineWidth: currentPath.lineWidth
                        )
                    }
                    
                    // Highlight selected region with better visibility
                    if let region = selectedRegion {
                        // Draw a solid background first
                        context.fill(
                            Path(roundedRect: region, cornerRadius: 8),
                            with: .color(.green.opacity(0.15))
                        )
                        
                        // Draw animated dashed border
                        context.stroke(
                            Path(roundedRect: region, cornerRadius: 8),
                            with: .color(.green),
                            style: StrokeStyle(lineWidth: 3, dash: [8, 4], dashPhase: 0)
                        )
                        
                        // Draw corner handles for better visibility
                        let handleSize: CGFloat = 8
                        let handleColor = Color.green
                        
                        // Top-left corner
                        context.fill(
                            Path(ellipseIn: CGRect(x: region.minX - handleSize/2, y: region.minY - handleSize/2, width: handleSize, height: handleSize)),
                            with: .color(handleColor)
                        )
                        
                        // Top-right corner
                        context.fill(
                            Path(ellipseIn: CGRect(x: region.maxX - handleSize/2, y: region.minY - handleSize/2, width: handleSize, height: handleSize)),
                            with: .color(handleColor)
                        )
                        
                        // Bottom-left corner
                        context.fill(
                            Path(ellipseIn: CGRect(x: region.minX - handleSize/2, y: region.maxY - handleSize/2, width: handleSize, height: handleSize)),
                            with: .color(handleColor)
                        )
                        
                        // Bottom-right corner
                        context.fill(
                            Path(ellipseIn: CGRect(x: region.maxX - handleSize/2, y: region.maxY - handleSize/2, width: handleSize, height: handleSize)),
                            with: .color(handleColor)
                        )
                    }
                    
                    // Highlight detected element on hover
                    if let element = highlightedElement {
                        context.stroke(
                            Path(roundedRect: element.boundingBox, cornerRadius: 4),
                            with: .color(.blue),
                            style: StrokeStyle(lineWidth: 2, dash: [3, 3])
                        )
                    }
                }
                
                // UI Controls
                VStack {
                    // Top toolbar
                    HStack {
                        // Drawing tools
                        HStack(spacing: 12) {
                            Button(action: clearDrawing) {
                                Label("Clear", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: undoLastPath) {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(.bordered)
                            .disabled(paths.isEmpty)
                            
                            if showShapeHint {
                                Text("Detected: \(detectedShape.description)")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                        .cornerRadius(12)
                        
                        Spacer()
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button(action: cancelDrawing) {
                                Label("Cancel", systemImage: "xmark")
                            }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.escape, modifiers: [])
                        }
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                        .cornerRadius(12)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 8) {
                        Text("Draw to select • Click to select element")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 16) {
                            Label("Circle areas", systemImage: "scribble")
                            Label("ESC to cancel", systemImage: "escape")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    .cornerRadius(12)
                    .padding(.bottom, 30)
                }
                
                // Interactive OCR Text Selection layer directly over the selected rectangle
                if let region = selectedRegion, let ocrResult = cachedOCRResult, !ocrResult.elements.isEmpty, !isProcessing {
                    InteractiveOCRTextView(
                        elements: ocrResult.elements,
                        selectedElements: $selectedTextElements,
                        onCopy: { selectedString in
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(selectedString, forType: .string)
                            toastMessage = "Selected text copied!"
                            withAnimation { showToast = true }
                        },
                        onTranslate: { selectedString in
                            handleTranslateSelectedText(selectedString)
                        },
                        onSelectionDismissed: {
                            selectedTextElements.removeAll()
                        }
                    )
                    .frame(width: region.width, height: region.height)
                    .position(x: region.midX, y: region.midY)
                    .allowsHitTesting(true)
                }
                
                // Extracted Text inspection panel
                if showExtractedTextPanel, let text = cachedOCRText, let region = selectedRegion, !isProcessing {
                    ExtractedTextPanel(
                        text: text,
                        selectionRect: region,
                        screenSize: geometry.size,
                        onClose: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                showExtractedTextPanel = false
                                showActionPalette = true
                            }
                        },
                        onCopied: {
                            toastMessage = "Text copied to clipboard!"
                            withAnimation { showToast = true }
                        }
                    )
                    .allowsHitTesting(true)
                } else if showActionPalette, let region = selectedRegion, !isProcessing {
                    // Actions palette (appears after valid selection)
                    SelectionActionPalette(
                        selectionRect: region,
                        screenSize: geometry.size,
                        isOCRReady: cachedOCRText != nil,
                        onAskGemini: handleAskGemini,
                        onExtractText: handleExtractText,
                        onSearchGoogle: handleSearchGoogle,
                        onTranslate: handleTranslate,
                        onCopyImage: handleCopyImage,
                        onSaveImage: handleSaveImage
                    )
                    .allowsHitTesting(true)
                }
                
                // Loading overlay
                if isProcessing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text(loadingStageText)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(28)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                }
                
                // Toast feedback
                CopiedToast(message: toastMessage, isVisible: $showToast)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 80)
            }
            .onAppear {
                // Use the screenshot passed from AppDelegate
                if let screenshot = screenshot {
                    backgroundImage = screenshot
                    
                    // No need to calculate display properties - using 1:1 display
                    print("Screenshot loaded at 1:1 scale: \(screenshot.size)")
                    
                    // Detect elements in background
                    Task {
                        if let elements = try? await elementDetector.detectElements(in: screenshot) {
                            await MainActor.run {
                                self.detectedElements = elements
                            }
                        }
                    }
                } else {
                    // Fallback: capture if no screenshot was passed
                    captureScreen()
                }
                
                // Register hierarchical escape handler with OverlayWindow
                if let overlayWindow = NSApp.windows.first(where: { $0 is OverlayWindow }) as? OverlayWindow {
                    overlayWindow.onEscape = { [self] in
                        return self.handleEscape()
                    }
                }
            }
            .onDisappear {
                if let overlayWindow = NSApp.windows.first(where: { $0 is OverlayWindow }) as? OverlayWindow {
                    overlayWindow.onEscape = nil
                }
            }
            .gesture(drawingGesture)
            .onTapGesture { location in
                handleTap(at: location)
            }
            .onExitCommand {
                if !handleEscape() {
                    cancelDrawing()
                }
            }
        }
    }
    
    var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // If a region already exists, and the user touches inside it with OCR elements, let InteractiveOCRTextView handle it
                if let region = selectedRegion, region.contains(value.startLocation), cachedOCRResult != nil {
                    return
                }
                
                if !isDrawing {
                    isDrawing = true
                    currentPath = DrawingPath()
                    selectedTextElements.removeAll()
                }
                currentPath.addPoint(value.location)
                
                // Check for shape detection
                if currentPath.points.count > 10 {
                    let shape = currentPath.detectShape()
                    if shape != .unknown && shape != .line {
                        detectedShape = shape
                        showShapeHint = true
                    }
                }
            }
            .onEnded { value in
                currentPath.complete()
                
                // Process the completed path
                if currentPath.points.count > 3 {
                    paths.append(currentPath)
                    
                    // Auto-detect selection region
                    if let bbox = currentPath.boundingBox() {
                        if bbox.width >= 10 && bbox.height >= 10 {
                            selectedRegion = bbox
                            print("Selected region set from drawing: \(bbox)")
                            print("Region size: \(bbox.width) x \(bbox.height)")
                            
                            // Show visual feedback
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showShapeHint = true
                            }
                            
                            // Prepare selection: crop image and start OCR
                            prepareSelectionForPalette(region: bbox)
                        } else {
                            print("Selection too small (\(bbox.width) x \(bbox.height)), discarded")
                        }
                    } else {
                        print("WARNING: Could not create bounding box from path")
                    }
                } else {
                    print("Path too short: only \(currentPath.points.count) points")
                }
                
                currentPath = DrawingPath()
                isDrawing = false
                
                // Hide shape hint after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showShapeHint = false
                }
            }
    }
    
    private func captureScreen() {
        // This is now only a fallback - should not normally be called
        print("Warning: captureScreen fallback called - screenshot should have been passed from AppDelegate")
        
        Task {
            // Try CGDisplay method first as it's less likely to trigger permissions
            if let fallbackImage = screenCapture.captureWithCGDisplay() {
                let elements = try? await elementDetector.detectElements(in: fallbackImage)
                
                await MainActor.run {
                    self.backgroundImage = fallbackImage
                    self.detectedElements = elements ?? []
                }
            } else {
                // Last resort: try direct capture
                do {
                    if let screenshot = try await screenCapture.captureScreenDirect() {
                        let elements = try? await elementDetector.detectElements(in: screenshot)
                        
                        await MainActor.run {
                            self.backgroundImage = screenshot
                            self.detectedElements = elements ?? []
                        }
                    }
                } catch {
                    print("All capture methods failed: \(error)")
                    // Show a semi-transparent background as last resort
                    await MainActor.run {
                        self.backgroundImage = nil
                    }
                }
            }
        }
    }
    
    private func handleTap(at location: CGPoint) {
        // Smart element detection at tap location
        Task {
            await detectElementAt(location)
        }
    }
    
    private func detectElementAt(_ point: CGPoint) async {
        guard let image = backgroundImage else { return }
        
        // Find element at tap location
        if let element = elementDetector.findElementAt(point: point, in: detectedElements) {
            await MainActor.run {
                selectedRegion = element.boundingBox
                highlightedElement = element
                
                // Prepare selection: crop image and start OCR
                prepareSelectionForPalette(region: element.boundingBox)
                
                // Animate the selection
                withAnimation(.easeInOut(duration: 0.3)) {
                    showShapeHint = true
                }
                
                // Hide hint after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showShapeHint = false
                    }
                }
            }
        } else {
            // Create a small region around the tap point if no element found
            let regionSize: CGFloat = 100
            let region = CGRect(
                x: point.x - regionSize/2,
                y: point.y - regionSize/2,
                width: regionSize,
                height: regionSize
            )
            
            await MainActor.run {
                selectedRegion = region
                highlightedElement = nil
                
                // Prepare selection: crop image and start OCR
                prepareSelectionForPalette(region: region)
            }
        }
    }
    
    private func performSearch() {
        print("=== performSearch called ===")
        
        // If no region selected but paths exist, use bounding box of all paths
        var regionToSearch = selectedRegion
        if regionToSearch == nil && !paths.isEmpty {
            print("No selected region, calculating from paths...")
            // Calculate bounding box from all paths
            var minX = CGFloat.infinity
            var minY = CGFloat.infinity
            var maxX = -CGFloat.infinity
            var maxY = -CGFloat.infinity
            
            for path in paths {
                if let bbox = path.boundingBox() {
                    minX = min(minX, bbox.minX)
                    minY = min(minY, bbox.minY)
                    maxX = max(maxX, bbox.maxX)
                    maxY = max(maxY, bbox.maxY)
                }
            }
            
            if minX != .infinity {
                regionToSearch = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                print("Calculated region from paths: \(regionToSearch!)")
            }
        }
        
        guard var region = regionToSearch,
              let image = backgroundImage else { 
            print("ERROR: No region (\(regionToSearch == nil)) or image (\(backgroundImage == nil)) selected")
            // Show error to user
            let alert = NSAlert()
            alert.messageText = "No Selection"
            alert.informativeText = "Please draw or select an area to search"
            alert.alertStyle = .warning
            alert.runModal()
            return 
        }
        
        // No conversion needed - using 1:1 display
        print("Region selected (1:1 coordinates): \(region)")
        print("Background image size: \(image.size)")
        
        isProcessing = true
        loadingStageText = "Cropping selection..."
        
        Task {
            do {
                print("Cropping image to converted region...")
                // Crop image to selected region (now in image coordinates)
                let croppedImage = cropImage(image, to: region)
                print("Cropped image size: \(croppedImage.size)")
                
                // Save the cropped image immediately
                await MainActor.run {
                    appState.lastCapturedImage = croppedImage
                    loadingStageText = "Extracting text with OCR..."
                    print("Saved cropped image to app state")
                }
                
                // Try to extract text with OCR (but don't fail if it doesn't work)
                var extractedText = ""
                do {
                    print("Attempting OCR extraction...")
                    extractedText = try await ocrManager.extractText(from: croppedImage)
                    print("OCR extracted text: \(extractedText.prefix(100))...")
                } catch {
                    print("OCR failed (non-fatal): \(error)")
                    // Continue without OCR text
                }
                
                await MainActor.run {
                    loadingStageText = "Analyzing with Gemini 2.5 Flash..."
                }
                
                // Search with Gemini
                let searchQuery = extractedText.isEmpty ? 
                    "What is shown in this image selection? Please describe what you see." : 
                    "Context from image: \(extractedText)\n\nPlease provide relevant information about this."
                
                print("Sending to Gemini with query: \(searchQuery.prefix(100))...")
                let result = try await geminiService.searchWithImage(
                    croppedImage,
                    text: searchQuery
                )
                print("Gemini response received: \(result.prefix(100))...")
                
                await MainActor.run {
                    loadingStageText = "Opening search assistant..."
                    print("Updating UI with results...")
                    // Update state with results
                    appState.lastExtractedText = extractedText
                    appState.searchResults = result
                    appState.isLoading = false
                    appState.showMainWindow = true
                    
                    // Clear overlay state
                    appState.showSearchOverlay = false
                    isProcessing = false
                    
                    print("Hiding overlay and presenting search result in floating search window...")
                    print("[SEARCH] Gemini result received, presenting result")
                    if let appDelegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate) {
                        print("[SEARCH] AppDelegate.shared found")
                        print("[SEARCH] FloatingSearchWindow exists: \(appDelegate.floatingSearchWindow != nil)")
                        appDelegate.hideDrawingOverlay()
                        
                        // Ensure floating search window is shown and pass result
                        appDelegate.showMainWindow()
                        appDelegate.floatingSearchWindow?.displaySearchResult(
                            query: searchQuery,
                            image: croppedImage,
                            result: result
                        )
                        print("[SEARCH] displaySearchResult called")
                    }
                    print("=== performSearch completed successfully ===")
                }
            } catch {
                print("ERROR in performSearch: \(error)")
                print("Error details: \(error.localizedDescription)")
                
                await MainActor.run {
                    // Show error but still allow user to dismiss overlay
                    appState.errorMessage = "Search failed: \(error.localizedDescription)"
                    isProcessing = false
                    
                    // Show alert with option to retry or cancel
                    let alert = NSAlert()
                    alert.messageText = "Search Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Retry")
                    alert.addButton(withTitle: "Cancel")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        // Retry the search
                        print("User chose to retry search")
                        performSearch()
                    } else {
                        // Cancel and close overlay
                        print("User chose to cancel after error")
                        cancelDrawing()
                    }
                }
            }
        }
    }
    
    private func cropImage(_ image: NSImage, to rect: CGRect) -> NSImage {
        print("cropImage called with rect: \(rect)")
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("ERROR: Could not get CGImage from NSImage")
            return image
        }
        
        print("Original CGImage size: \(cgImage.width) x \(cgImage.height)")
        print("NSImage size: \(image.size)")
        
        // Calculate scale factor
        let scale = CGFloat(cgImage.width) / image.size.width
        print("Scale factor: \(scale)")
        
        // For CGImage cropping, we need to use the CGImage coordinate system
        // CGImage has origin at top-left, same as SwiftUI
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,  // Don't invert Y coordinate
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        print("Scaled rect for cropping: \(scaledRect)")
        
        // Ensure the rect is within bounds
        let clampedRect = CGRect(
            x: max(0, min(scaledRect.origin.x, CGFloat(cgImage.width) - 1)),
            y: max(0, min(scaledRect.origin.y, CGFloat(cgImage.height) - 1)),
            width: min(scaledRect.width, CGFloat(cgImage.width) - scaledRect.origin.x),
            height: min(scaledRect.height, CGFloat(cgImage.height) - scaledRect.origin.y)
        )
        
        print("Clamped rect: \(clampedRect)")
        
        guard clampedRect.width > 0 && clampedRect.height > 0 else {
            print("ERROR: Invalid rect dimensions after clamping")
            return image
        }
        
        guard let croppedCGImage = cgImage.cropping(to: clampedRect) else {
            print("ERROR: CGImage cropping failed")
            return image
        }
        
        print("Cropped CGImage size: \(croppedCGImage.width) x \(croppedCGImage.height)")
        
        // Create NSImage from cropped CGImage
        // Use the actual size of the cropped image, not the original rect size
        let actualSize = NSSize(width: CGFloat(croppedCGImage.width) / scale, 
                                height: CGFloat(croppedCGImage.height) / scale)
        let resultImage = NSImage(cgImage: croppedCGImage, size: actualSize)
        
        print("Result NSImage size: \(resultImage.size)")
        
        return resultImage
    }
    
    private func clearDrawing() {
        paths.removeAll()
        currentPath = DrawingPath()
        selectedRegion = nil
        detectedShape = .unknown
        showActionPalette = false
        showExtractedTextPanel = false
        cachedCroppedImage = nil
        cachedOCRText = nil
        cachedOCRResult = nil
        selectedTextElements.removeAll()
        isOCRRunning = false
    }
    
    private func undoLastPath() {
        if !paths.isEmpty {
            paths.removeLast()
            
            // Update selected region
            if let lastPath = paths.last,
               let bbox = lastPath.boundingBox() {
                selectedRegion = bbox
            } else {
                selectedRegion = nil
            }
        }
    }
    
    private func cancelDrawing() {
        // Clear drawing state
        paths.removeAll()
        currentPath = DrawingPath()
        selectedRegion = nil
        isProcessing = false
        showActionPalette = false
        showExtractedTextPanel = false
        cachedCroppedImage = nil
        cachedOCRText = nil
        cachedOCRResult = nil
        selectedTextElements.removeAll()
        isOCRRunning = false
        
        // Hide overlay window first
        if let appDelegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate) {
            appDelegate.hideDrawingOverlay()
        }
        
        // Only reset overlay-related state
        appState.showSearchOverlay = false
        appState.isCapturing = false
        
        // Don't reset other state - keep main window and any previous results
    }
    
    // MARK: - Palette Preparation
    
    private func prepareSelectionForPalette(region: CGRect) {
        guard let image = backgroundImage else { return }
        
        // Crop the image for the selection
        let cropped = cropImage(image, to: region)
        cachedCroppedImage = cropped
        cachedOCRText = nil
        isOCRRunning = true
        showExtractedTextPanel = false
        
        // Show the palette
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showActionPalette = true
        }
        
        // Start OCR in background (non-blocking)
        Task {
            do {
                let result = try await ocrManager.recognizeText(from: cropped)
                await MainActor.run {
                    cachedOCRResult = result
                    cachedOCRText = result.fullText.isEmpty ? nil : result.fullText
                    isOCRRunning = false
                    print("[Palette] OCR cached: \(result.fullText.prefix(80))... (\(result.elements.count) elements)")
                }
            } catch {
                await MainActor.run {
                    cachedOCRResult = nil
                    cachedOCRText = nil
                    isOCRRunning = false
                    print("[Palette] OCR failed (non-fatal): \(error)")
                }
            }
        }
    }
    
    // MARK: - Palette Action Handlers
    
    private func handleAskGemini() {
        guard let croppedImage = cachedCroppedImage else { return }
        
        let extractedText = cachedOCRText ?? ""
        showActionPalette = false
        isProcessing = true
        loadingStageText = "Analyzing with Gemini 2.5 Flash..."
        
        Task {
            do {
                await MainActor.run {
                    appState.lastCapturedImage = croppedImage
                }
                
                // Build query from cached OCR text
                let searchQuery = extractedText.isEmpty ?
                    "What is shown in this image selection? Please describe what you see." :
                    "Context from image: \(extractedText)\n\nPlease provide relevant information about this."
                
                print("[AskGemini] Sending to Gemini with query: \(searchQuery.prefix(100))...")
                let result = try await geminiService.searchWithImage(
                    croppedImage,
                    text: searchQuery
                )
                print("[AskGemini] Gemini response received: \(result.prefix(100))...")
                
                await MainActor.run {
                    loadingStageText = "Opening search assistant..."
                    appState.lastExtractedText = extractedText
                    appState.searchResults = result
                    appState.isLoading = false
                    appState.showMainWindow = true
                    appState.showSearchOverlay = false
                    isProcessing = false
                    
                    if let appDelegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate) {
                        appDelegate.hideDrawingOverlay()
                        appDelegate.showMainWindow()
                        appDelegate.floatingSearchWindow?.displaySearchResult(
                            query: searchQuery,
                            image: croppedImage,
                            result: result
                        )
                    }
                }
            } catch {
                print("[AskGemini] Error: \(error)")
                await MainActor.run {
                    isProcessing = false
                    
                    let alert = NSAlert()
                    alert.messageText = "Search Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    private func handleExtractText() {
        guard let text = cachedOCRText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            toastMessage = isOCRRunning ? "Extracting text..." : "No text detected"
            withAnimation { showToast = true }
            return
        }
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            showActionPalette = false
            showExtractedTextPanel = true
        }
    }
    
    private func handleSearchGoogle() {
        guard let croppedImage = cachedCroppedImage else {
            toastMessage = "No image available"
            withAnimation { showToast = true }
            return
        }
        
        // Write cropped image to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("MacToFind-selection.png")
        if let tiffData = croppedImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        }
        
        // Copy cropped image to clipboard both as native image and file URL
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([croppedImage, fileURL as NSURL])
        
        if let url = URL(string: "https://images.google.com") {
            NSWorkspace.shared.open(url)
            
            toastMessage = "Opened Google Images (drag or upload your image)"
            withAnimation { showToast = true }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                cancelDrawing()
            }
        }
    }
    
    private func handleTranslateSelectedText(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.google.com/?sl=auto&tl=en&text=\(encodedText)&op=translate") else {
            toastMessage = "Failed to create translation URL"
            withAnimation { showToast = true }
            return
        }
        
        NSWorkspace.shared.open(url)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cancelDrawing()
        }
    }
    
    private func handleEscape() -> Bool {
        if !selectedTextElements.isEmpty {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedTextElements.removeAll()
            }
            return true
        }
        if showExtractedTextPanel {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                showExtractedTextPanel = false
                showActionPalette = true
            }
            return true
        }
        if showActionPalette || selectedRegion != nil {
            clearDrawing()
            return true
        }
        return false
    }
    
    private func handleTranslate() {
        guard let text = cachedOCRText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            toastMessage = isOCRRunning ? "Extracting text..." : "No text detected to translate"
            withAnimation { showToast = true }
            return
        }
        
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.google.com/?sl=auto&tl=en&text=\(encodedText)&op=translate") else {
            toastMessage = "Failed to create translation URL"
            withAnimation { showToast = true }
            return
        }
        
        NSWorkspace.shared.open(url)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cancelDrawing()
        }
    }
    
    private func handleCopyImage() {
        guard let image = cachedCroppedImage else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        toastMessage = "Image copied to clipboard!"
        withAnimation { showToast = true }
    }
    
    private func handleSaveImage() {
        guard let image = cachedCroppedImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Selection"
        savePanel.nameFieldStringValue = "MacToFind-selection.png"
        
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

#Preview {
    DrawingOverlayView()
        .environmentObject(AppState())
}