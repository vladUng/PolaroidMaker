//
//  Fonts.swift
//  PolaroidMaker
//
//  Created by Vlad Ungureanu on 08/09/2025.
//

import Foundation
import AppKit

extension NSFont {
    func withFallback(to preferred: NSFont) -> NSFont {
        return preferred.familyName != nil ? preferred : self
    }
}

struct Fonts {
    static func handFont(size: CGFloat) -> NSFont {
        NSFont(name: "PatrickHand-Regular", size: size) ?? .systemFont(ofSize: size, weight: .regular)
    }
    
    static func loadFont(family: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        // Ensure size is reasonable
        let safeSize = max(1.0, min(size, 1000.0))
        
        // Special handling for SF Pro (system font)
        if family == "SF Pro" {
            return NSFont.systemFont(ofSize: safeSize, weight: weight)
        }
        
        // Try to resolve by family (preferred) - with safety checks
        let desc = NSFontDescriptor(fontAttributes: [.family: family])
        if let font = NSFont(descriptor: desc, size: safeSize) {
            return font // Return the found font directly
        }
        
        // Fallbacks: try common faces inside family
        let candidates = [
            "\(family)-Regular", "\(family) Regular", "\(family)-Book",
            "\(family)-Text", "\(family) Text", "\(family)-Roman"
        ]
        
        for name in candidates {
            if let font = NSFont(name: name, size: safeSize) {
                return font
            }
        }
        
        // Legacy font name handling for backward compatibility
        switch family {
        case "SF Pro Rounded":
            return NSFont(name: "SFRounded-Regular", size: size) ?? .systemFont(ofSize: size, weight: weight)
        case "New York":
            return NSFont(name: "NewYork-Regular", size: size) ?? NSFont(name: "New York", size: size) ?? .systemFont(ofSize: size, weight: weight)
        case "Patrick Hand":
            return NSFont(name: "PatrickHand-Regular", size: size) ?? .systemFont(ofSize: size, weight: weight)
        default:
            return NSFont(name: family, size: size) ?? .systemFont(ofSize: size, weight: weight)
        }
    }
    
    // Legacy method for backward compatibility
    static func loadFont(name: String, size: CGFloat) -> NSFont {
        return loadFont(family: name, size: size)
    }
    
    static func drawCentered(_ string: String, in rect: CGRect, font: NSFont, color: NSColor, tracking: CGFloat = 0, baselineOffset: CGFloat = 0) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        guard !trimmedString.isEmpty else { return }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: baselineOffset
        ]
        
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        
        let attributedString = NSAttributedString(string: trimmedString, attributes: attributes)
        let textSize = attributedString.boundingRect(
            with: NSSize(width: rect.width, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        
        let drawRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.height - textSize.height) / 2,
            width: rect.width,
            height: textSize.height
        )
        
        attributedString.draw(in: drawRect)
    }
    
    static func measureText(_ string: String, font: NSFont, tracking: CGFloat = 0, maxWidth: CGFloat = .greatestFiniteMagnitude) -> CGSize {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        guard !trimmedString.isEmpty else { return .zero }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        
        let attributedString = NSAttributedString(string: trimmedString, attributes: attributes)
        return attributedString.boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
    }
}