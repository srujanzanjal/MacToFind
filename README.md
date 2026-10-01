<div align="center">

# 🔍 MacToFind

### *Circle to Search & Visual Intelligence for macOS — Powered by Google Gemini*

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma%20%7C%20Sequoia)-black?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Gemini](https://img.shields.io/badge/Google%20Gemini-2.5%20Flash-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-000000?style=for-the-badge&logo=apple)](https://apple.com)
[![CI](https://github.com/srujanzanjal/MacToFind/actions/workflows/ci.yml/badge.svg)](https://github.com/srujanzanjal/MacToFind/actions/workflows/ci.yml)

<br/>

**Select anything on your Mac screen to instantly search, extract text, translate, or chat with multimodal AI.**

[Explore Features](#-features) • [Quick Start](#-quick-start) • [Keyboard Shortcuts](#-keyboard-shortcuts) • [Architecture](#-architecture) • [Privacy](#-privacy--security)

</div>

---

## 💡 What is MacToFind?

**MacToFind** brings the seamless, fluid visual search experience of Android's *Circle to Search* and *Google Lens* directly to the macOS desktop. 

Engineered natively in **SwiftUI** and **AppKit**, MacToFind acts as a lightweight, unobtrusive background agent. With a single keystroke (`⌘⇧Space`), the entire screen is frozen with a glassmorphic lens, letting you drag-select any image, document, chart, or code snippet. From there, a floating **Actions Palette** lets you query Google Gemini, inspect and interact with on-device OCR text, launch instant Google image searches, translate foreign languages, or copy content with zero friction.

---

## ✨ Features

### 🎯 1. Instant Screen Selection (`⌘⇧Space`)
- **Global Hotkey Trigger**: Works universally across all macOS workspaces, full-screen apps, and external displays.
- **Fluid Screen Freeze**: Instant capture via Apple's ultra-low-latency `ScreenCaptureKit`.
- **Drag-to-Select**: Clean, anti-aliased marquee selection with live dimension cues.

### 🪄 2. Contextual Actions Palette
Immediately upon releasing your selection, an intelligent 6-action glassmorphic palette appears dynamically anchored to your bounding box:
- 🤖 **Ask Gemini**: Multi-turn multimodal analysis using **Gemini 2.5 Flash** with cached local OCR context.
- 📋 **Extract Text**: Opens an on-screen text inspector with line/word count, line-break formatting, and instant clipboard export.
- 🌐 **Search Google**: Prepares the selection image on your clipboard and opens Google Images in your default browser.
- 🌍 **Translate**: Seamless one-tap translation through Google Translate.
- 🖼️ **Copy Image**: Copies the cropped pixel-perfect image directly to your pasteboard.
- 💾 **Save Image**: Exports your crop to PNG or JPEG via native macOS save sheet.

### 📝 3. Interactive OCR & Bounding-Box Selection (Google Lens Style)
- **100% Local Vision OCR**: Powered directly by Apple's on-device `VNRecognizeTextRequest` (Revision 3) with neural engine acceleration.
- **Selectable Word Highlights**: Recognized text elements become individually interactive. Drag across any sentence or phrase within your crop to highlight it.
- **In-Place Actions**: Floating mini-bar lets you **Copy** or **Translate** specifically highlighted words on the fly.
- **Hierarchical Escape**: Pressing `ESC` cleanly steps backward (clears word highlight $\rightarrow$ clears action palette $\rightarrow$ dismisses overlay).

### 💬 4. Multimodal Floating AI Companion
- **Persistent Floating Search Window**: Floats above other windows with native macOS liquid glassmorphism.
- **Conversational Memory**: Ask continuous follow-up questions about your screen capture without losing conversational state.
- **Drag & Drop & Paste (`⌘V`)**: Drop images directly into the chat bar or paste clipboard bitmaps at any time.
- **Session History**: Local history with timestamps and quick-recall query cards.

### 🕵️ 5. Stealth Background Utility Mode
- **Zero Dock Clutter**: Configured as a macOS Agent (`LSUIElement = true`) — does not occupy Dock space or clutter `⌘Tab`.
- **Silent Startup**: Launches in the background with zero intrusive windows.
- **Launch at Login**: Integrates with Apple's modern `SMAppService.mainApp` Background Task Management; visible and configurable in **System Settings > General > Login Items & Extensions**.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action | Scope |
|:---|:---|:---|
| <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>Space</kbd> | **Trigger Screen Capture & Selection** | Global |
| <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>O</kbd> | **Open / Focus Floating AI Chat** | Global |
| <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>S</kbd> | **Open MacToFind Preferences** | Global |
| <kbd>ESC</kbd> | **Step Backward / Cancel Selection** | Overlay / Palette |
| <kbd>⌘</kbd> <kbd>V</kbd> | **Paste Image into Chat** | In Chat Bar |
| <kbd>Return</kbd> | **Submit Prompt to Gemini** | In Chat Bar |

---

## 🚀 Quick Start

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Apple Silicon (M1/M2/M3/M4) or Intel processor
- A free [Google Gemini API Key](https://aistudio.google.com/app/apikey)

### Installation

#### Option 1: Pre-Built Release
1. Download `MacToFind.dmg` or `MacToFind.zip` from [Releases](https://github.com/srujanzanjal/MacToFind/releases).
2. Move `MacToFind.app` into your `/Applications` directory.
3. Launch **MacToFind**.
4. Grant the macOS **Screen Recording** permission when prompted:
   > *System Settings $\rightarrow$ Privacy & Security $\rightarrow$ Screen Recording $\rightarrow$ Enable **MacToFind***.
5. Enter your Gemini API key in the Setup Wizard.

#### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/srujanzanjal/MacToFind.git
cd MacToFind

# Build Release and install to /Applications
make install

# Or build and run locally
make run
```

---

## 🏗 Architecture

```
MacToFind/
├── 🎯 Core & Lifecycle
│   ├── MacToFindApp.swift           # Application entry point (@main)
│   ├── AppDelegate.swift            # Window lifecycle, menu bar & global hotkeys
│   ├── MacToFind.entitlements       # Apple sandbox & TCC entitlements
│   └── Models/
│       ├── AppState.swift           # Global observable application state
│       ├── ChatSession.swift        # SwiftData persistent chat models
│       └── DrawingPath.swift        # Selection vectors & geometry
│
├── 🪟 Windows
│   ├── OverlayWindow.swift          # Fullscreen transparent capture canvas
│   ├── FloatingSearchWindow.swift   # Glassmorphic floating AI search bar
│   ├── SettingsWindow.swift         # Native settings panel
│   └── SetupWindow.swift            # First-run onboarding wizard
│
├── 🎨 Views & UI Components
│   ├── SelectionActionPalette.swift # 6-button post-selection pill
│   ├── InteractiveOCRTextView.swift # Bounding-box text selector overlay
│   ├── ExtractedTextPanel.swift     # Rich OCR inspection drawer
│   ├── DrawingOverlayView.swift     # Core selection coordinator
│   └── MinimalChatBubble.swift      # Markdown-rendered AI responses
│
├── 🔧 Managers
│   ├── OCRManager.swift             # VNRecognizeTextRequest pipeline
│   ├── HotkeyManager.swift          # Carbon Event global hotkey bridge
│   ├── LaunchAtLoginManager.swift   # SMAppService.mainApp registration
│   ├── ScreenCaptureManager.swift   # SCShareableContent capture engine
│   └── ChatHistoryManager.swift     # History storage & session archiving
│
└── 🌐 Services
    ├── GeminiService.swift          # Gemini 2.5 Flash multimodal client
    └── APIKeyValidator.swift        # Live Google AI Studio key validation
```

### Key Technical Decisions
- **Carbon Hotkeys**: Uses Carbon Event Handlers for global hotkeys (`⌘⇧Space`), eliminating the need for intrusive macOS Accessibility permissions.
- **ScreenCaptureKit**: Leverages hardware-accelerated capture without generating disk temporary clutter until explicitly requested.
- **Vision Revision 3**: Implements native macOS OCR with accurate bounding-box normalization, language correction, and high-DPI scaling.
- **Actors & Modern Concurrency**: `@MainActor` isolation throughout UI coordinators ensures zero race conditions or UI thread hitches.

---

## 🔒 Privacy & Security

MacToFind was designed under a strict **Zero-Telemetry, Local-First** philosophy:

| Data Type | Processed Locally | Transmitted to Cloud | Destination |
|:---|:---:|:---:|:---|
| **Screen Pixels** | ✅ Yes | ⚠️ Only when you use Ask Gemini | Google Gemini API (HTTPS) |
| **OCR Text Extraction** | ✅ Yes | ❌ Never | Apple Neural Engine (On-Device) |
| **Search Queries** | ✅ Yes | ⚠️ User-Initiated Only | Google Gemini API (HTTPS) |
| **Gemini API Key** | ✅ Yes | Only to Google, as the request header | macOS Keychain |
| **Telemetry / Tracking** | ❌ None | ❌ None | Zero analytics or trackers |

---

## 🧪 Testing

MacToFind includes a full test suite covering OCR text reconstruction, bounding-box coordinate transformations, URL encoding, Markdown parsing, and state lifecycle:

```bash
# Run test suite via Xcode CLI
xcodebuild -project MacToFind.xcodeproj \
           -scheme MacToFind \
           -destination 'platform=macOS' \
           test CODE_SIGNING_ALLOWED=NO
```

---

## 🤝 Contributing

Contributions, issues, and feature suggestions are warmly welcomed!
1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/MyFeature`).
3. Commit your changes (`git commit -m "Add MyFeature"`).
4. Push to the branch (`git push origin feature/MyFeature`).
5. Open a Pull Request.

---

<div align="center">

Made with ❤️ for macOS power users by Srujan Zanjal.

</div>
