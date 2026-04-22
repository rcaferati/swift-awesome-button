import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
#endif

internal struct AutoWidthMeasurementSignature: Hashable {
    let text: String
    let textFontFamily: String?
    let textSize: CGFloat
    let textLineHeight: CGFloat?
    let paddingHorizontal: CGFloat
    let borderWidth: CGFloat
}

internal final class AutoWidthMeasurementService {
    static let shared = AutoWidthMeasurementService()

    private let lock = NSLock()
    private var cache: [AutoWidthMeasurementSignature: CGFloat] = [:]
    private var order: [AutoWidthMeasurementSignature] = []
    private let maxEntries = 250

    private init() {}

    func measureWidth(for signature: AutoWidthMeasurementSignature) -> CGFloat {
        lock.lock()
        if let cached = cache[signature] {
            promote(signature)
            lock.unlock()
            return cached
        }
        lock.unlock()

        let measured = measureIntrinsicWidth(for: signature)

        lock.lock()
        cache[signature] = measured
        promote(signature)
        trimIfNeeded()
        lock.unlock()

        return measured
    }

    private func promote(_ signature: AutoWidthMeasurementSignature) {
        order.removeAll { $0 == signature }
        order.append(signature)
    }

    private func trimIfNeeded() {
        while order.count > maxEntries {
            let removed = order.removeFirst()
            cache.removeValue(forKey: removed)
        }
    }

    private func measureIntrinsicWidth(for signature: AutoWidthMeasurementSignature) -> CGFloat {
        let font = resolvedFont(signature: signature)
        let paragraph = NSMutableParagraphStyle()
        if let lineHeight = signature.textLineHeight {
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
        ]
        let bounds = (signature.text as NSString).boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        let contentWidth = ceil(bounds.width)
        return contentWidth + (signature.paddingHorizontal * 2) + (signature.borderWidth * 2)
    }

    private func resolvedFont(signature: AutoWidthMeasurementSignature) -> PlatformFont {
        #if canImport(UIKit)
        if let family = signature.textFontFamily, let font = UIFont(name: family, size: signature.textSize) {
            return font
        }

        return UIFont.systemFont(ofSize: signature.textSize, weight: .bold)
        #elseif canImport(AppKit)
        if let family = signature.textFontFamily, let font = NSFont(name: family, size: signature.textSize) {
            return font
        }

        return NSFont.systemFont(ofSize: signature.textSize, weight: .bold)
        #endif
    }
}
