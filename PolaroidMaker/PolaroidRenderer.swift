//
//  PolaroidRenderer.swift
//  PolaroidMaker
//
//  Created by Vlad Ungureanu on 08/09/2025.
//

import Foundation
import AppKit
import CoreGraphics
import CoreText
import UniformTypeIdentifiers
import Photos

struct PolaroidRenderer {
    // FreePrints Retro specifications
    static let exportWidth: CGFloat = 1800
    static let outerMargin: CGFloat = 72
    static let bottomBand: CGFloat = 340
    static let cardCorner: CGFloat = 28
    static let photoCorner: CGFloat = 16
    static let shadowRadius: CGFloat = 18
    static let shadowOffset = CGPoint(x: 0, y: -2)
    static let shadowOpacity: CGFloat = 0.18
    static let lineSpacing: CGFloat = 16
    
    // Typography parameters
    struct RenderParams {
        let exportWidth: CGFloat
        let line1Size: CGFloat
        let line2Size: CGFloat
        let textColor: NSColor
        
        init(exportWidth: CGFloat = 1800, line1Size: CGFloat = 46, line2Size: CGFloat = 64, textColor: NSColor = .black) {
            self.exportWidth = exportWidth
            self.line1Size = line1Size
            self.line2Size = line2Size
            self.textColor = textColor
        }
    }
    
    static func renderPolaroidFreePrints(
        image: NSImage,
        line1: String,
        line2: String,
        exportWidth: CGFloat = 1800,
        outerMargin: CGFloat = 72,
        bottomBand: CGFloat = 340,
        cardCorner: CGFloat = 28,
        photoCorner: CGFloat = 16,
        line1Font: NSFont = NSFont(name: "Georgia", size: 46) ?? NSFont.systemFont(ofSize: 46, weight: .regular),
        line2Font: NSFont? = nil,
        textColor: NSColor = .black,
        line1Kern: CGFloat = 0.5,
        line2Kern: CGFloat = 1.5,
        line2Baseline: CGFloat = -2
    ) -> NSImage? {
        
        // Safety checks
        guard image.size.width > 0 && image.size.height > 0 else {
            print("Invalid image size: \(image.size)")
            return nil
        }
        
        guard exportWidth > 0 && exportWidth <= 10000 else {
            print("Invalid export width: \(exportWidth)")
            return nil
        }
        
        let line1FontResolved = line1Font
        let line2FontResolved = line2Font ?? (NSFont(name: "Georgia", size: 64) ?? NSFont.systemFont(ofSize: 64, weight: .regular))
        
        // Calculate layout dimensions with consistent top padding
        let topInset = outerMargin  // Consistent top padding
        let maxPhotoW = exportWidth - 2 * outerMargin
        
        // Apply 5% width reduction for consistent visual top padding
        let photoW = maxPhotoW * 0.95
        let scale = photoW / image.size.width
        let photoH = image.size.height * scale
        
        let canvasW = exportWidth
        let canvasH = outerMargin + photoH + bottomBand + topInset  // Top margin + top inset + photo + bottom band
        
        let canvasSize = NSSize(width: canvasW, height: canvasH)
        
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvasW),
            pixelsHigh: Int(canvasH),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current = nsContext
        
        // Clear background to transparent
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()
        
        // Draw white card background with shadow
        drawCardWithShadow(size: canvasSize, cardCorner: cardCorner)
        
        // Draw photo with rounded corners - centered horizontally with consistent top padding
        let photoRect = CGRect(
            x: (exportWidth - photoW) / 2,  // Center horizontally
            y: bottomBand + topInset,       // Consistent top inset
            width: photoW,
            height: photoH
        )
        drawPhotoWithRoundedCorners(image: image, in: photoRect, photoCorner: photoCorner)
        
        // Draw text in bottom band - visible in preview
        let bandRect = CGRect(x: 0, y: 0, width: canvasW, height: bottomBand)
        drawTwoLineTextFreePrints(
            line1: line1,
            line2: line2,
            in: bandRect,
            line1Font: line1FontResolved,
            line2Font: line2FontResolved,
            textColor: textColor,
            line1Kern: line1Kern,
            line2Kern: line2Kern,
            line2Baseline: line2Baseline
        )
        
        NSGraphicsContext.restoreGraphicsState()
        
        let outputImage = NSImage(size: canvasSize)
        outputImage.addRepresentation(bitmapRep)
        return outputImage
    }
    
    // Legacy method for backward compatibility
    static func renderPolaroid(image: NSImage, line1: String, line2: String, params: RenderParams = RenderParams()) -> NSImage? {
        return renderPolaroidFreePrints(
            image: image,
            line1: line1,
            line2: line2,
            exportWidth: params.exportWidth,
            outerMargin: outerMargin,
            bottomBand: bottomBand,
            cardCorner: cardCorner,
            photoCorner: photoCorner,
            line1Font: NSFont(name: "Georgia", size: params.line1Size) ?? NSFont.systemFont(ofSize: params.line1Size, weight: .regular),
            line2Font: NSFont(name: "Georgia", size: params.line2Size) ?? NSFont.systemFont(ofSize: params.line2Size, weight: .regular),
            textColor: params.textColor
        )
    }
    
    private static func drawCardWithShadow(size: NSSize, cardCorner: CGFloat) {
        // Create shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(shadowOpacity)
        shadow.shadowOffset = NSSize(width: shadowOffset.x, height: shadowOffset.y)
        shadow.shadowBlurRadius = shadowRadius
        
        // Draw white rounded rectangle with shadow
        let cardRect = NSRect(origin: .zero, size: size)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: cardCorner, yRadius: cardCorner)
        
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor.white.setFill()
        cardPath.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    
    private static func drawPhotoWithRoundedCorners(image: NSImage, in rect: CGRect, photoCorner: CGFloat) {
        let photoPath = NSBezierPath(roundedRect: rect, xRadius: photoCorner, yRadius: photoCorner)
        
        NSGraphicsContext.saveGraphicsState()
        photoPath.addClip()
        
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
    private static func drawTwoLineTextFreePrints(
        line1: String,
        line2: String,
        in bandRect: CGRect,
        line1Font: NSFont,
        line2Font: NSFont,
        textColor: NSColor,
        line1Kern: CGFloat,
        line2Kern: CGFloat,
        line2Baseline: CGFloat
    ) {
        // New layout parameters for better text positioning
        let bandTopPadding: CGFloat = 10 140  // Reduced by ~20% to move text up
        let bandBottomPadding: CGFloat = 10 // Increased to maintain balance
        let interLineSpacing: CGFloat = 18  // NEW (can be 16–20)
        
        let textRect = bandRect.insetBy(dx: 64, dy: 0) // Remove vertical inset, use our own padding
        
        // Clean and prepare text
        let cleanLine1 = cleanText(line1)
        let cleanLine2 = cleanText(line2)
        
        // Skip if both lines are empty
        guard !cleanLine1.isEmpty || !cleanLine2.isEmpty else { return }
        
        // Create attributed strings with proper styling using settings
        let line1Attrs = createTextAttributes(
            font: line1Font,
            color: textColor,
            tracking: line1Kern,
            baselineOffset: 0
        )
        
        let line2Attrs = createTextAttributes(
            font: line2Font,
            color: textColor,
            tracking: line2Kern,
            baselineOffset: line2Baseline
        )
        
        let line1AttrString = NSAttributedString(string: cleanLine1, attributes: line1Attrs)
        let line2AttrString = NSAttributedString(string: cleanLine2, attributes: line2Attrs)
        
        // Measure text sizes
        let line1Size = measureAttributedString(line1AttrString, maxWidth: textRect.width)
        let line2Size = measureAttributedString(line2AttrString, maxWidth: textRect.width)
        
        // Calculate layout
        let hasLine1 = !cleanLine1.isEmpty
        let hasLine2 = !cleanLine2.isEmpty
        
        // Calculate available space and positioning
        let availableBandHeight = bandRect.height - bandTopPadding - bandBottomPadding
        let line1Height = hasLine1 ? line1Size.height : 0
        let line2Height = hasLine2 ? line2Size.height : 0
        let totalTextHeight = line1Height + (hasLine1 && hasLine2 ? interLineSpacing : 0) + line2Height
        
        // Center the text block within the available space
        let startY = bandRect.origin.y + bandTopPadding + max(0, (availableBandHeight - totalTextHeight) / 2)
        
        // Draw line 1 first (top line - date/location)
        if hasLine1 {
            let line1Rect = CGRect(
                x: textRect.origin.x,
                y: startY,
                width: textRect.width,
                height: line1Height
            )
            drawTruncatedText(line1AttrString, in: line1Rect)
        }
        
        // Draw line 2 second (bottom line - custom text)
        if hasLine2 {
            let line2Y = hasLine1 ? (startY + line1Height + interLineSpacing) : startY
            let line2Rect = CGRect(
                x: textRect.origin.x,
                y: line2Y,
                width: textRect.width,
                height: line2Height
            )
            drawTruncatedText(line2AttrString, in: line2Rect)
        }
    }
    
    private static func cleanText(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private static func createTextAttributes(
        font: NSFont,
        color: NSColor,
        tracking: CGFloat,
        baselineOffset: CGFloat
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        
        if baselineOffset != 0 {
            attributes[.baselineOffset] = baselineOffset
        }
        
        return attributes
    }
    
    private static func measureAttributedString(_ attributedString: NSAttributedString, maxWidth: CGFloat) -> CGSize {
        return attributedString.boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
    }
    
    private static func drawTruncatedText(_ attributedString: NSAttributedString, in rect: CGRect) {
        // Check if text fits
        let textSize = measureAttributedString(attributedString, maxWidth: rect.width)
        
        if textSize.width <= rect.width {
            // Text fits, draw normally
            attributedString.draw(in: rect)
        } else {
            // Text doesn't fit, use Core Text for truncation
            let line = CTLineCreateWithAttributedString(attributedString)
            let truncatedLine = CTLineCreateTruncatedLine(line, rect.width, .middle, nil)
            
            if let truncatedLine = truncatedLine {
                let context = NSGraphicsContext.current!.cgContext
                context.saveGState()
                
                // Flip coordinate system for Core Text
                context.textMatrix = CGAffineTransform.identity
                context.translateBy(x: 0, y: rect.maxY)
                context.scaleBy(x: 1.0, y: -1.0)
                
                // Center the truncated line
                let truncatedSize = CTLineGetBoundsWithOptions(truncatedLine, []).size
                let centeredX = rect.origin.x + (rect.width - truncatedSize.width) / 2
                
                context.textPosition = CGPoint(x: centeredX, y: rect.height / 2 - truncatedSize.height / 2)
                CTLineDraw(truncatedLine, context)
                
                context.restoreGState()
            } else {
                // Fallback to regular drawing
                attributedString.draw(in: rect)
            }
        }
    }
}