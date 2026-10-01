//
//  OCRCoordinateConverter.swift
//  MacToFind
//
//  Coordinate conversion layer between normalized Vision space ([0, 1], bottom-left origin)
//  and SwiftUI view space (points, top-left origin).
//

import CoreGraphics
import Foundation

struct OCRCoordinateConverter {
    
    /// Converts a normalized Vision bounding box to SwiftUI view coordinates.
    ///
    /// Vision coordinates have origin (0, 0) at the bottom-left of the image and range from 0.0 to 1.0.
    /// SwiftUI coordinates have origin (0, 0) at the top-left of the view.
    ///
    /// - Parameters:
    ///   - visionBox: The normalized bounding box from Vision (`[0, 1]`).
    ///   - viewSize: The size of the SwiftUI view displaying the content.
    /// - Returns: The bounding box in SwiftUI view coordinates.
    static func visionToView(visionBox: CGRect, viewSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        
        let width = visionBox.width * viewSize.width
        let height = visionBox.height * viewSize.height
        let x = visionBox.origin.x * viewSize.width
        // In Vision, visionBox.origin.y is the bottom edge of the box.
        // In SwiftUI, y=0 is at the top, so the top edge is (1.0 - visionBox.maxY) * height.
        let y = (1.0 - visionBox.maxY) * viewSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Converts a rectangle in SwiftUI view coordinates back to normalized Vision coordinates.
    ///
    /// - Parameters:
    ///   - viewRect: The rectangle in SwiftUI view coordinates.
    ///   - viewSize: The size of the SwiftUI view.
    /// - Returns: The normalized bounding box in Vision coordinates (`[0, 1]`, bottom-left origin).
    static func viewToVision(viewRect: CGRect, viewSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        
        let normWidth = viewRect.width / viewSize.width
        let normHeight = viewRect.height / viewSize.height
        let normX = viewRect.minX / viewSize.width
        // In SwiftUI, viewRect.maxY is the bottom edge of the box.
        // In Vision, y=0 is at the bottom, so normY = 1.0 - (viewRect.maxY / viewSize.height).
        let normY = 1.0 - (viewRect.maxY / viewSize.height)
        
        return CGRect(x: normX, y: normY, width: normWidth, height: normHeight)
    }
    
    /// Finds all OCR text elements whose view-space bounding box intersects the given selection rectangle.
    /// Preserves the reading order of the input elements.
    ///
    /// - Parameters:
    ///   - selectionRect: The drag selection rectangle in SwiftUI view coordinates.
    ///   - elements: The list of OCRTextElements in reading order.
    ///   - viewSize: The size of the view displaying the elements.
    /// - Returns: The subset of elements intersecting the selection, in reading order.
    static func elementsIntersecting(
        selectionRect: CGRect,
        elements: [OCRTextElement],
        viewSize: CGSize
    ) -> [OCRTextElement] {
        guard viewSize.width > 0, viewSize.height > 0, !selectionRect.isEmpty else { return [] }
        
        let normalizedSelection = selectionRect.standardized
        
        return elements.filter { element in
            let elementViewRect = visionToView(visionBox: element.boundingBox, viewSize: viewSize)
            return normalizedSelection.intersects(elementViewRect)
        }
    }
    
    /// Finds the single OCR text element containing the given point, if any.
    ///
    /// - Parameters:
    ///   - point: The point in SwiftUI view coordinates.
    ///   - elements: The list of OCRTextElements.
    ///   - viewSize: The size of the view.
    ///   - tolerance: Extra padding around the element box to make clicking easier.
    /// - Returns: The matching element, if found.
    static func elementContaining(
        point: CGPoint,
        elements: [OCRTextElement],
        viewSize: CGSize,
        tolerance: CGFloat = 3.0
    ) -> OCRTextElement? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        
        for element in elements {
            let elementViewRect = visionToView(visionBox: element.boundingBox, viewSize: viewSize)
            let expandedRect = elementViewRect.insetBy(dx: -tolerance, dy: -tolerance)
            if expandedRect.contains(point) {
                return element
            }
        }
        return nil
    }
    
    /// Computes the union bounding box enclosing the provided elements in SwiftUI view coordinates.
    ///
    /// - Parameters:
    ///   - elements: The elements to enclose.
    ///   - viewSize: The size of the view.
    /// - Returns: The enclosing CGRect, or nil if elements is empty.
    static func boundingRect(for elements: [OCRTextElement], viewSize: CGSize) -> CGRect? {
        guard !elements.isEmpty, viewSize.width > 0, viewSize.height > 0 else { return nil }
        
        var unionRect: CGRect?
        for element in elements {
            let rect = visionToView(visionBox: element.boundingBox, viewSize: viewSize)
            if let current = unionRect {
                unionRect = current.union(rect)
            } else {
                unionRect = rect
            }
        }
        return unionRect
    }
}
