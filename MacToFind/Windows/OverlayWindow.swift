//
//  OverlayWindow.swift
//  MacToFind
//
//  Created by MacBook on 06/09/2025.
//

import AppKit
import SwiftUI

class OverlayWindow: NSWindow {
    
    init() {
        super.init(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isMovableByWindowBackground = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.styleMask.insert(.fullSizeContentView)
        
        // Make window appear above everything except screen saver
        self.canBecomeVisibleWithoutLogin = true
        self.hidesOnDeactivate = false
        
        // Set initial frame to cover entire screen
        if let screen = NSScreen.main {
            self.setFrame(screen.frame, display: true)
        }
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    /// Optional escape handler for hierarchical state dismissal.
    /// Returns true if the escape was consumed by an inner state (e.g. text selection or palette).
    var onEscape: (() -> Bool)?
    
    func dismissOverlay() {
        if let handled = onEscape?(), handled {
            return
        }
        forceDismissOverlay()
    }
    
    func forceDismissOverlay() {
        self.hideOverlay()
        
        // Notify AppDelegate to clean up
        if let appDelegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate) {
            appDelegate.hideDrawingOverlay()
        }
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 {
            dismissOverlay()
            return
        }

        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Intercept ESC key at the key equivalent level to guarantee dismissal
        if event.keyCode == 53 { // ESC key
            dismissOverlay()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        dismissOverlay()
    }
    
    // Handle keyboard events
    override func keyDown(with event: NSEvent) {
        // Check for ESC key
        if event.keyCode == 53 { // 53 is the keycode for ESC
            dismissOverlay()
        } else {
            super.keyDown(with: event)
        }
    }
    
    func showOverlay(with view: some View, appState: AppState) {
        // Create hosting view
        let hostingView = NSHostingView(rootView: view.environmentObject(appState))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        self.contentView = hostingView
        
        // Ensure window covers full screen first
        if let screen = NSScreen.main {
            self.setFrame(screen.frame, display: true, animate: false)
        }
        
        // Activate app and make window key
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        
        // Ensure the hosting view can receive events
        if let contentView = self.contentView {
            contentView.window?.makeFirstResponder(contentView)
        }
    }
    
    func hideOverlay() {
        self.orderOut(nil)
        self.contentView = nil
    }
}