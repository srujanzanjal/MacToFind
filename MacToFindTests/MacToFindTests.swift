//
//  MacToFindTests.swift
//  MacToFindTests
//
//  Created by MacBook on 06/09/2025.
//

import Testing
import AppKit
@testable import MacToFind

struct MacToFindTests {

    @Test func example() async throws {
        // Basic sanity check
        #expect(true)
    }

    @Test func testFloatingSearchStateSessionLifecycle() async throws {
        let state = FloatingSearchState()
        var archived = false
        state.onArchiveCurrentSession = {
            archived = true
        }

        // First search in session A
        state.appendSearchResult(query: "First query", image: nil, result: "First result")
        #expect(state.messages.count == 2)
        #expect(state.messages[0].content == "First query")
        #expect(state.messages[1].content == "First result")

        // New capture starts Session B: should archive Session A and start fresh
        state.startNewCaptureSession(query: "Second query", image: nil, result: "Second result")
        #expect(archived == true)
        #expect(state.messages.count == 2)
        #expect(state.messages[0].content == "Second query")
        #expect(state.messages[1].content == "Second result")
    }

    @Test func testMinimalChatMessageContextCardData() async throws {
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let message = MinimalChatMessage(
            content: "What is this?",
            images: [testImage],
            isUser: true
        )

        #expect(message.isUser == true)
        #expect(message.images?.count == 1)
        #expect(message.image != nil)
        #expect(message.content == "What is this?")
    }

    @Test func testOCRQualityOnBulletText() async throws {
        let sampleText = """
        I'm talking about:

        - Is the horizontal layout too wide?
        - Does it feel natural near the rectangle?
        - Does it obstruct the selected content?
        - Are the icons/labels easy to understand?
        - Does it feel like a native macOS feature?
        - Does it feel closer to the Circle-to-Search screenshot you showed?
        """

        let font = NSFont.systemFont(ofSize: 13)
        let attrString = NSAttributedString(string: sampleText, attributes: [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ])
        let textSize = attrString.size()
        let imageSize = NSSize(width: ceil(textSize.width) + 40, height: ceil(textSize.height) + 40)

        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        attrString.draw(at: NSPoint(x: 20, y: 20))
        image.unlockFocus()

        let ocr = OCRManager()
        let result = try await ocr.extractText(from: image)

        #expect(result.contains("I'm talking about:"))
        #expect(result.contains("- Is the horizontal layout too wide?"))
        #expect(result.contains("- Does it feel natural near the rectangle?"))
        #expect(result.contains("- Does it obstruct the selected content?"))
        #expect(result.contains("- Are the icons/labels easy to understand?"))
        #expect(result.contains("- Does it feel like a native macOS feature?"))
        #expect(result.contains("- Does it feel closer to the Circle-to-Search screenshot you showed?"))
        
        // Negative checks to confirm Portuguese language collisions and mangling are absent
        #expect(!result.contains("tallana"))
        #expect(!result.contains("costuck"))
        #expect(!result.contains("rectanglen"))
        #expect(!result.contains("Doninfeelice"))
    }

    @Test func testOCRQualityWithCodeAndURL() async throws {
        let codeSnippet = """
        Visit: https://developer.apple.com/vision?ref=100
        func verifyExtraction() -> Bool {
            return true
        }
        """

        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attrString = NSAttributedString(string: codeSnippet, attributes: [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ])
        let textSize = attrString.size()
        let imageSize = NSSize(width: ceil(textSize.width) + 30, height: ceil(textSize.height) + 30)

        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        attrString.draw(at: NSPoint(x: 15, y: 15))
        image.unlockFocus()

        let ocr = OCRManager()
        let result = try await ocr.extractText(from: image)

        #expect(result.contains("https://developer.apple.com/vision?ref=100"))
        #expect(result.contains("func verifyExtraction()"))
        #expect(result.contains("Bool"))
        #expect(result.contains("{"))
        #expect(result.contains("return true"))
        #expect(result.contains("}"))
    }

    // MARK: - Interactive Text Selection & Coordinate Tests

    @Test func testVisionToViewAndInverseConversion() {
        let viewSize = CGSize(width: 400, height: 300)
        
        // Vision: (0, 0.8) with height 0.2 means top edge is at 1.0 (top of image).
        // In SwiftUI, top of view is y=0.
        let topBox = CGRect(x: 0.1, y: 0.8, width: 0.5, height: 0.2)
        let viewRect = OCRCoordinateConverter.visionToView(visionBox: topBox, viewSize: viewSize)
        
        #expect(abs(viewRect.minX - 40.0) < 0.001)
        #expect(abs(viewRect.minY - 0.0) < 0.001) // at top
        #expect(abs(viewRect.width - 200.0) < 0.001)
        #expect(abs(viewRect.height - 60.0) < 0.001)
        
        // Inverse round-trip conversion
        let roundTripBox = OCRCoordinateConverter.viewToVision(viewRect: viewRect, viewSize: viewSize)
        #expect(abs(roundTripBox.origin.x - topBox.origin.x) < 0.001)
        #expect(abs(roundTripBox.origin.y - topBox.origin.y) < 0.001)
        #expect(abs(roundTripBox.width - topBox.width) < 0.001)
        #expect(abs(roundTripBox.height - topBox.height) < 0.001)
    }

    @Test func testOCRTextElementSortingAndReconstruction() {
        let line0Elem1 = OCRTextElement(text: "I'm", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.1, height: 0.1), confidence: 0.99, lineIndex: 0)
        let line0Elem2 = OCRTextElement(text: "talking", boundingBox: CGRect(x: 0.22, y: 0.8, width: 0.15, height: 0.1), confidence: 0.99, lineIndex: 0)
        let line0Elem3 = OCRTextElement(text: "about:", boundingBox: CGRect(x: 0.39, y: 0.8, width: 0.15, height: 0.1), confidence: 0.99, lineIndex: 0)
        
        let line1Elem1 = OCRTextElement(text: "-", boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.05, height: 0.1), confidence: 0.99, lineIndex: 1)
        let line1Elem2 = OCRTextElement(text: "Does", boundingBox: CGRect(x: 0.16, y: 0.6, width: 0.1, height: 0.1), confidence: 0.99, lineIndex: 1)
        let line1Elem3 = OCRTextElement(text: "it", boundingBox: CGRect(x: 0.27, y: 0.6, width: 0.05, height: 0.1), confidence: 0.99, lineIndex: 1)
        let line1Elem4 = OCRTextElement(text: "feel", boundingBox: CGRect(x: 0.33, y: 0.6, width: 0.1, height: 0.1), confidence: 0.99, lineIndex: 1)
        let line1Elem5 = OCRTextElement(text: "natural?", boundingBox: CGRect(x: 0.44, y: 0.6, width: 0.18, height: 0.1), confidence: 0.99, lineIndex: 1)
        
        // Test single line selection: only line 1
        let singleLineSelection = [line1Elem1, line1Elem2, line1Elem3, line1Elem4, line1Elem5]
        let singleLineText = OCRResult.reconstructSelectedText(from: singleLineSelection)
        #expect(singleLineText == "- Does it feel natural?")
        
        // Test multi-line selection: line 0 + line 1
        let multiLineSelection = [line0Elem1, line0Elem2, line0Elem3, line1Elem1, line1Elem2, line1Elem3, line1Elem4, line1Elem5]
        let multiLineText = OCRResult.reconstructSelectedText(from: multiLineSelection)
        #expect(multiLineText == "I'm talking about:\n- Does it feel natural?")
        
        // Punctuation check
        #expect(singleLineText.contains("natural?"))
        #expect(multiLineText.contains("about:"))
        #expect(multiLineText.contains("I'm"))
    }

    @Test func testSelectionMarqueeIntersection() {
        let viewSize = CGSize(width: 400, height: 200)
        
        // Word 1: in top region (Vision y=0.8..1.0 -> View y=0..40)
        let elem1 = OCRTextElement(text: "Header", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.3, height: 0.2), lineIndex: 0)
        // Word 2: in bottom region (Vision y=0.1..0.3 -> View y=140..180)
        let elem2 = OCRTextElement(text: "Footer", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2), lineIndex: 1)
        
        let allElements = [elem1, elem2]
        
        // Drag rect covering only top region (y: 0..50)
        let topDrag = CGRect(x: 20, y: 0, width: 200, height: 50)
        let selectedTop = OCRCoordinateConverter.elementsIntersecting(selectionRect: topDrag, elements: allElements, viewSize: viewSize)
        #expect(selectedTop.count == 1)
        #expect(selectedTop.first?.text == "Header")
        
        // Drag rect covering only bottom region (y: 130..190)
        let bottomDrag = CGRect(x: 20, y: 130, width: 200, height: 60)
        let selectedBottom = OCRCoordinateConverter.elementsIntersecting(selectionRect: bottomDrag, elements: allElements, viewSize: viewSize)
        #expect(selectedBottom.count == 1)
        #expect(selectedBottom.first?.text == "Footer")
        
        // Drag rect covering both
        let fullDrag = CGRect(x: 0, y: 0, width: 400, height: 200)
        let selectedBoth = OCRCoordinateConverter.elementsIntersecting(selectionRect: fullDrag, elements: allElements, viewSize: viewSize)
        #expect(selectedBoth.count == 2)
        #expect(selectedBoth[0].text == "Header")
        #expect(selectedBoth[1].text == "Footer")
    }

    @Test func testTranslateURLEncoding() {
        let testStrings = [
            "Does it feel natural near the rectangle?",
            "Line one\nLine two with spaces",
            "Special characters: & + = ? / # %",
            "Unicode text: café résumé 日本語",
        ]
        
        for text in testStrings {
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            #expect(encoded != nil)
            
            let urlString = "https://translate.google.com/?sl=auto&tl=en&text=\(encoded!)&op=translate"
            let url = URL(string: urlString)
            #expect(url != nil, "URL string must produce valid URL: \(urlString)")
            #expect(url?.scheme == "https")
            #expect(url?.host == "translate.google.com")
        }
    }
}

