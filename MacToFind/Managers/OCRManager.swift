//
//  OCRManager.swift
//  MacToFind
//
//  Created by MacBook on 06/09/2025.
//

import Foundation
import Vision
import AppKit

/// A recognized text token/word with its bounding box in normalized Vision coordinates.
struct OCRTextElement: Identifiable, Equatable {
    let id: UUID
    let text: String
    /// Normalized coordinates [0, 1] relative to the cropped image where (0,0) is bottom-left (Vision standard).
    let boundingBox: CGRect
    let confidence: Float
    let lineIndex: Int
    
    init(id: UUID = UUID(), text: String, boundingBox: CGRect, confidence: Float = 1.0, lineIndex: Int = 0) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.lineIndex = lineIndex
    }
}

/// The complete OCR result containing reconstructed text and positional elements.
struct OCRResult: Equatable {
    let fullText: String
    let elements: [OCRTextElement]
    
    init(fullText: String = "", elements: [OCRTextElement] = []) {
        self.fullText = fullText
        self.elements = elements
    }
    
    /// Reconstructs a clean string from a subset of selected elements, preserving line breaks when lineIndex changes and spaces within lines.
    static func reconstructSelectedText(from elements: [OCRTextElement]) -> String {
        guard !elements.isEmpty else { return "" }
        var result = ""
        for (index, elem) in elements.enumerated() {
            if index > 0 {
                let prev = elements[index - 1]
                if elem.lineIndex != prev.lineIndex {
                    result += "\n"
                } else {
                    result += " "
                }
            }
            result += elem.text
        }
        return result
    }
}

class OCRManager {
    
    /// Performs text recognition and returns both full text and structured positional elements.
    func recognizeText(from image: NSImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }
        
        let processedCGImage = Self.preprocessForOCR(cgImage: cgImage)
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let result = Self.buildOCRResult(from: observations)
                guard !result.fullText.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                continuation.resume(returning: result)
            }
            
            request.recognitionLevel = .accurate
            if #available(macOS 13.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
                request.automaticallyDetectsLanguage = true
            }
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.0
            
            let handler = VNImageRequestHandler(cgImage: processedCGImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    /// Legacy/String-only API that forwards to recognizeText and returns the full reconstructed text.
    func extractText(from image: NSImage) async throws -> String {
        let result = try await recognizeText(from: image)
        return result.fullText
    }
    
    // MARK: - OCR Preprocessing
    
    /// Preprocesses small crops to ensure high-fidelity recognition on small fonts without modifying the original image.
    static func preprocessForOCR(cgImage: CGImage) -> CGImage {
        guard cgImage.width < 600 || cgImage.height < 300 else {
            return cgImage
        }
        
        let scale = 2
        let width = cgImage.width * scale
        let height = cgImage.height * scale
        
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return cgImage
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? cgImage
    }
    
    // MARK: - Line Reconstruction & Structural Assembly
    
    /// Builds an OCRResult containing both reading-order fullText and word-level OCRTextElements.
    static func buildOCRResult(from observations: [VNRecognizedTextObservation]) -> OCRResult {
        guard !observations.isEmpty else { return OCRResult() }
        
        // Vision coordinates: (0,0) is bottom-left, y=1.0 is top.
        // Sort descending by maxY (top of text block to bottom).
        let sorted = observations.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
        
        struct LineCluster {
            var topY: CGFloat
            var bottomY: CGFloat
            var observations: [VNRecognizedTextObservation]
            var height: CGFloat { topY - bottomY }
            var midY: CGFloat { (topY + bottomY) / 2 }
        }
        
        var lines: [LineCluster] = []
        
        for obs in sorted {
            let bbox = obs.boundingBox
            let obsTop = bbox.maxY
            let obsBottom = bbox.minY
            let obsMid = bbox.midY
            let obsHeight = bbox.height
            
            var placed = false
            for i in 0..<lines.count {
                let line = lines[i]
                let verticalOverlap = min(line.topY, obsTop) - max(line.bottomY, obsBottom)
                let minHeight = min(line.height, obsHeight)
                
                // Observations belong to the same line if their vertical overlap or vertical center distance is within tolerance
                if verticalOverlap > minHeight * 0.4 || abs(line.midY - obsMid) < minHeight * 0.5 {
                    lines[i].observations.append(obs)
                    lines[i].topY = max(line.topY, obsTop)
                    lines[i].bottomY = min(line.bottomY, obsBottom)
                    placed = true
                    break
                }
            }
            
            if !placed {
                lines.append(LineCluster(topY: obsTop, bottomY: obsBottom, observations: [obs]))
            }
        }
        
        // Sort lines top to bottom (descending midY in Vision coordinates)
        lines.sort { $0.midY > $1.midY }
        
        // Calculate median line height to distinguish regular line wraps from paragraph breaks
        let lineHeights = lines.map { $0.height }.sorted()
        let medianHeight = lineHeights.isEmpty ? 0.02 : lineHeights[lineHeights.count / 2]
        
        var resultParts: [String] = []
        var allElements: [OCRTextElement] = []
        
        for (lineIdx, line) in lines.enumerated() {
            // Sort observations in this line left to right (ascending minX)
            let lineObs = line.observations.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            var lineTokens: [String] = []
            
            for obs in lineObs {
                guard let candidate = obs.topCandidates(1).first else { continue }
                let obsText = candidate.string.trimmingCharacters(in: .whitespaces)
                guard !obsText.isEmpty else { continue }
                lineTokens.append(obsText)
                
                // Extract word-level bounding boxes
                let words = candidate.string.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                var searchStart = candidate.string.startIndex
                for word in words {
                    guard let range = candidate.string.range(of: word, range: searchStart..<candidate.string.endIndex) else { continue }
                    let wordBox = (try? candidate.boundingBox(for: range))?.boundingBox ?? obs.boundingBox
                    allElements.append(OCRTextElement(
                        text: word,
                        boundingBox: wordBox,
                        confidence: candidate.confidence,
                        lineIndex: lineIdx
                    ))
                    searchStart = range.upperBound
                }
            }
            
            let lineText = lineTokens.joined(separator: " ")
            guard !lineText.isEmpty else { continue }
            
            if lineIdx > 0 {
                let prevLine = lines[lineIdx - 1]
                let verticalGap = prevLine.bottomY - line.topY
                // If gap is noticeably larger than line height, preserve paragraph break
                if verticalGap > medianHeight * 1.35 {
                    resultParts.append("\n\n" + lineText)
                } else {
                    resultParts.append("\n" + lineText)
                }
            } else {
                resultParts.append(lineText)
            }
        }
        
        return OCRResult(fullText: resultParts.joined(), elements: allElements)
    }
    
    /// Groups and orders Vision text observations to faithfully preserve reading order, line breaks, paragraph gaps, and inline spacing.
    static func reconstructText(from observations: [VNRecognizedTextObservation]) -> String {
        return buildOCRResult(from: observations).fullText
    }
    
    func detectTextRegions(in image: NSImage) async throws -> [CGRect] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let boundingBoxes = observations.map { observation in
                    observation.boundingBox
                }
                
                continuation.resume(returning: boundingBoxes)
            }
            
            request.reportCharacterBoxes = false
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.processingFailed(error.localizedDescription))
            }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case recognitionFailed(String)
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        case .recognitionFailed(let message):
            return "Text recognition failed: \(message)"
        case .processingFailed(let message):
            return "Image processing failed: \(message)"
        }
    }
}