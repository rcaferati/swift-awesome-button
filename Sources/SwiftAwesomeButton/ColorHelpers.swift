import SwiftUI
#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformColor = NSColor
#endif

internal extension AwesomeButtonAnimationCurve {
    func animation(duration: TimeInterval?) -> Animation {
        let resolvedDuration = duration ?? 0.14
        switch self {
        case .easeOutCubic:
            return .timingCurve(0.33, 1, 0.68, 1, duration: resolvedDuration)
        case .easeOut:
            return .easeOut(duration: resolvedDuration)
        case .linear:
            return .linear(duration: resolvedDuration)
        }
    }
}

internal extension AwesomeButtonStyle {
    var sizeSignature: Int {
        var hasher = Hasher()
        hasher.combine(textSize)
        hasher.combine(textLineHeight)
        hasher.combine(textFontFamily)
        hasher.combine(borderRadius)
        hasher.combine(borderWidth)
        hasher.combine(raiseAmount)
        hasher.combine(contentGap)
        hasher.combine(animationDuration)
        hasher.combine(animationCurve?.rawValue)
        combine(color: borderColor, into: &hasher)
        combine(color: backgroundColor, into: &hasher)
        combine(color: backgroundActive, into: &hasher)
        combine(color: foregroundColor, into: &hasher)
        return hasher.finalize()
    }

    var visualSignature: Int {
        var hasher = Hasher()
        hasher.combine(textSize)
        hasher.combine(textLineHeight)
        hasher.combine(textFontFamily)
        hasher.combine(borderRadius)
        hasher.combine(borderWidth)
        hasher.combine(raiseAmount)
        hasher.combine(contentGap)
        hasher.combine(animationDuration)
        hasher.combine(animationCurve?.rawValue)
        hasher.combine(pressInAnimationDuration)
        combine(color: activityColor, into: &hasher)
        combine(color: backgroundActive, into: &hasher)
        combine(color: backgroundColor, into: &hasher)
        combine(color: backgroundPlaceholder, into: &hasher)
        combine(color: backgroundProgress, into: &hasher)
        combine(color: depthColor, into: &hasher)
        combine(color: shadowColor, into: &hasher)
        combine(color: pressedOverlayColor, into: &hasher)
        combine(color: foregroundColor, into: &hasher)
        combine(color: borderColor, into: &hasher)
        combine(color: disabledBackgroundColor, into: &hasher)
        combine(color: disabledDepthColor, into: &hasher)
        combine(color: disabledShadowColor, into: &hasher)
        combine(color: disabledForegroundColor, into: &hasher)
        combine(color: disabledBorderColor, into: &hasher)
        return hasher.finalize()
    }
}

internal extension ThemeButtonStyle {
    var signature: Int {
        var hasher = Hasher()
        hasher.combine(borderRadius)
        hasher.combine(borderBottomLeftRadius)
        hasher.combine(borderBottomRightRadius)
        hasher.combine(borderTopLeftRadius)
        hasher.combine(borderTopRightRadius)
        hasher.combine(borderWidth)
        hasher.combine(height)
        hasher.combine(paddingBottom)
        hasher.combine(paddingHorizontal)
        hasher.combine(paddingTop)
        hasher.combine(raiseLevel)
        hasher.combine(textFontFamily)
        hasher.combine(textLineHeight)
        hasher.combine(textSize)
        hasher.combine(width)
        combine(color: activityColor, into: &hasher)
        combine(color: backgroundActive, into: &hasher)
        combine(color: backgroundColor, into: &hasher)
        combine(color: backgroundDarker, into: &hasher)
        combine(color: backgroundPlaceholder, into: &hasher)
        combine(color: backgroundProgress, into: &hasher)
        combine(color: backgroundShadow, into: &hasher)
        combine(color: borderColor, into: &hasher)
        combine(color: textColor, into: &hasher)
        return hasher.finalize()
    }
}

internal struct ResolvedCornerRadii {
    var topLeading: CGFloat
    var bottomLeading: CGFloat
    var bottomTrailing: CGFloat
    var topTrailing: CGFloat

    static let zero = ResolvedCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 0, topTrailing: 0)
}

internal func blendColors(
    _ percentage: CGFloat,
    _ startColor: Color,
    toward endColor: Color? = nil,
    linear: Bool = false
) -> Color {
    let start = PlatformColor(startColor)
    let target = PlatformColor(endColor ?? (percentage < 0 ? .black : .white))
    let ratio = abs(percentage)
    let inverse = 1 - ratio

    func mix(_ startValue: CGFloat, _ targetValue: CGFloat) -> CGFloat {
        if linear {
            return (inverse * startValue) + (ratio * targetValue)
        }

        return sqrt((inverse * startValue * startValue) + (ratio * targetValue * targetValue))
    }

    var sr: CGFloat = 0
    var sg: CGFloat = 0
    var sb: CGFloat = 0
    var sa: CGFloat = 0
    start.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)

    var tr: CGFloat = 0
    var tg: CGFloat = 0
    var tb: CGFloat = 0
    var ta: CGFloat = 0
    target.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)

    let alpha = (sa == 1 && ta == 1) ? 1 : ((inverse * sa) + (ratio * ta))
    return Color(
        red: mix(sr, tr),
        green: mix(sg, tg),
        blue: mix(sb, tb),
        opacity: alpha
    )
}

internal func interpolateColor(_ from: Color?, _ to: Color?, progress: CGFloat) -> Color? {
    switch (from, to) {
    case (nil, nil):
        return nil
    case let (lhs?, nil):
        return interpolateColor(lhs, .clear, progress: progress)
    case let (nil, rhs?):
        return interpolateColor(.clear, rhs, progress: progress)
    case let (lhs?, rhs?):
        let left = rgbaComponents(for: lhs)
        let right = rgbaComponents(for: rhs)
        let t = max(0, min(progress, 1))
        return Color(
            red: left.red + ((right.red - left.red) * t),
            green: left.green + ((right.green - left.green) * t),
            blue: left.blue + ((right.blue - left.blue) * t),
            opacity: left.alpha + ((right.alpha - left.alpha) * t)
        )
    }
}

internal func resolvedVisualStyle(_ style: AwesomeButtonStyle) -> AwesomeButtonStyle {
    let fallback = AwesomeButtonThemeData.fallbackStyle
    return AwesomeButtonStyle(
        backgroundColor: style.backgroundColor ?? fallback.backgroundColor,
        backgroundActive: style.backgroundActive ?? fallback.backgroundActive,
        backgroundPlaceholder: style.backgroundPlaceholder ?? fallback.backgroundPlaceholder,
        backgroundProgress: style.backgroundProgress ?? fallback.backgroundProgress,
        depthColor: style.depthColor ?? fallback.depthColor,
        shadowColor: style.shadowColor ?? fallback.shadowColor,
        activityColor: style.activityColor ?? fallback.activityColor,
        pressedOverlayColor: style.pressedOverlayColor ?? fallback.pressedOverlayColor,
        foregroundColor: style.foregroundColor ?? fallback.foregroundColor,
        textSize: style.textSize ?? fallback.textSize,
        textLineHeight: style.textLineHeight ?? fallback.textLineHeight,
        textFontFamily: style.textFontFamily ?? fallback.textFontFamily,
        borderRadius: style.borderRadius ?? fallback.borderRadius,
        borderWidth: style.borderWidth ?? fallback.borderWidth,
        borderColor: style.borderColor ?? fallback.borderColor,
        raiseAmount: style.raiseAmount ?? fallback.raiseAmount,
        contentGap: style.contentGap ?? fallback.contentGap,
        animationDuration: style.animationDuration ?? fallback.animationDuration,
        animationCurve: style.animationCurve ?? fallback.animationCurve,
        pressInAnimationDuration: style.pressInAnimationDuration ?? fallback.pressInAnimationDuration,
        // Preserve explicit disabled overrides only. If these are nil, the renderer
        // should fall back to the resolved regular palette, not to the package default
        // disabled fill, otherwise transparent flat buttons gain a background.
        disabledBackgroundColor: style.disabledBackgroundColor,
        disabledDepthColor: style.disabledDepthColor,
        disabledShadowColor: style.disabledShadowColor,
        disabledForegroundColor: style.disabledForegroundColor,
        disabledBorderColor: style.disabledBorderColor
    )
}

private func interpolateCGFloat(_ from: CGFloat?, _ to: CGFloat?, progress: CGFloat) -> CGFloat? {
    switch (from, to) {
    case (nil, nil):
        return nil
    case let (lhs?, nil):
        return lhs + ((0 - lhs) * progress)
    case let (nil, rhs?):
        return 0 + ((rhs - 0) * progress)
    case let (lhs?, rhs?):
        return lhs + ((rhs - lhs) * progress)
    }
}

internal func interpolateAwesomeButtonStyle(
    _ from: AwesomeButtonStyle,
    _ to: AwesomeButtonStyle,
    progress: CGFloat
) -> AwesomeButtonStyle {
    let resolvedFrom = resolvedVisualStyle(from)
    let resolvedTo = resolvedVisualStyle(to)

    return AwesomeButtonStyle(
        backgroundColor: interpolateColor(resolvedFrom.backgroundColor, resolvedTo.backgroundColor, progress: progress),
        backgroundActive: interpolateColor(resolvedFrom.backgroundActive, resolvedTo.backgroundActive, progress: progress),
        backgroundPlaceholder: interpolateColor(resolvedFrom.backgroundPlaceholder, resolvedTo.backgroundPlaceholder, progress: progress),
        backgroundProgress: interpolateColor(resolvedFrom.backgroundProgress, resolvedTo.backgroundProgress, progress: progress),
        depthColor: interpolateColor(resolvedFrom.depthColor, resolvedTo.depthColor, progress: progress),
        shadowColor: interpolateColor(resolvedFrom.shadowColor, resolvedTo.shadowColor, progress: progress),
        activityColor: interpolateColor(resolvedFrom.activityColor, resolvedTo.activityColor, progress: progress),
        pressedOverlayColor: interpolateColor(resolvedFrom.pressedOverlayColor, resolvedTo.pressedOverlayColor, progress: progress),
        foregroundColor: interpolateColor(resolvedFrom.foregroundColor, resolvedTo.foregroundColor, progress: progress),
        textSize: interpolateCGFloat(resolvedFrom.textSize, resolvedTo.textSize, progress: progress),
        textLineHeight: interpolateCGFloat(resolvedFrom.textLineHeight, resolvedTo.textLineHeight, progress: progress),
        textFontFamily: progress < 1 ? resolvedFrom.textFontFamily : resolvedTo.textFontFamily,
        borderRadius: interpolateCGFloat(resolvedFrom.borderRadius, resolvedTo.borderRadius, progress: progress),
        borderWidth: interpolateCGFloat(resolvedFrom.borderWidth, resolvedTo.borderWidth, progress: progress),
        borderColor: interpolateColor(resolvedFrom.borderColor, resolvedTo.borderColor, progress: progress),
        raiseAmount: interpolateCGFloat(resolvedFrom.raiseAmount, resolvedTo.raiseAmount, progress: progress),
        contentGap: interpolateCGFloat(resolvedFrom.contentGap, resolvedTo.contentGap, progress: progress),
        animationDuration: progress < 1 ? resolvedFrom.animationDuration : resolvedTo.animationDuration,
        animationCurve: progress < 1 ? resolvedFrom.animationCurve : resolvedTo.animationCurve,
        pressInAnimationDuration: progress < 1 ? resolvedFrom.pressInAnimationDuration : resolvedTo.pressInAnimationDuration,
        disabledBackgroundColor: interpolateColor(resolvedFrom.disabledBackgroundColor, resolvedTo.disabledBackgroundColor, progress: progress),
        disabledDepthColor: interpolateColor(resolvedFrom.disabledDepthColor, resolvedTo.disabledDepthColor, progress: progress),
        disabledShadowColor: interpolateColor(resolvedFrom.disabledShadowColor, resolvedTo.disabledShadowColor, progress: progress),
        disabledForegroundColor: interpolateColor(resolvedFrom.disabledForegroundColor, resolvedTo.disabledForegroundColor, progress: progress),
        disabledBorderColor: interpolateColor(resolvedFrom.disabledBorderColor, resolvedTo.disabledBorderColor, progress: progress)
    )
}

internal func colorsEqual(_ lhs: Color?, _ rhs: Color?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case (nil, _), (_, nil):
        return false
    case let (left?, right?):
        return cgColor(for: left).__unsafeComponentsApproxEqual(to: cgColor(for: right))
    }
}

private extension CGColor {
    func __unsafeComponentsApproxEqual(to other: CGColor, tolerance: CGFloat = 0.001) -> Bool {
        guard let left = converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
              let right = other.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
              let leftComponents = left.components,
              let rightComponents = right.components,
              leftComponents.count == rightComponents.count else {
            return false
        }

        for (lhs, rhs) in zip(leftComponents, rightComponents) {
            if abs(lhs - rhs) > tolerance {
                return false
            }
        }

        return true
    }
}

internal func combine(color: Color?, into hasher: inout Hasher) {
    guard let color else {
        hasher.combine(false)
        return
    }

    let rgba = rgbaComponents(for: color)
    hasher.combine(true)
    hasher.combine(Int((rgba.red * 1000).rounded()))
    hasher.combine(Int((rgba.green * 1000).rounded()))
    hasher.combine(Int((rgba.blue * 1000).rounded()))
    hasher.combine(Int((rgba.alpha * 1000).rounded()))
}

internal func resolvedCornerRadii(style: AwesomeButtonStyle) -> ResolvedCornerRadii {
    let radius = style.borderRadius ?? 0
    return ResolvedCornerRadii(
        topLeading: radius,
        bottomLeading: radius,
        bottomTrailing: radius,
        topTrailing: radius
    )
}

internal func resolvedCornerRadii(style: ThemeButtonStyle) -> ResolvedCornerRadii {
    let fallback = style.borderRadius ?? 0
    return ResolvedCornerRadii(
        topLeading: style.borderTopLeftRadius ?? fallback,
        bottomLeading: style.borderBottomLeftRadius ?? fallback,
        bottomTrailing: style.borderBottomRightRadius ?? fallback,
        topTrailing: style.borderTopRightRadius ?? fallback
    )
}

internal extension ResolvedCornerRadii {
    var clamped: ResolvedCornerRadii {
        ResolvedCornerRadii(
            topLeading: max(0, topLeading),
            bottomLeading: max(0, bottomLeading),
            bottomTrailing: max(0, bottomTrailing),
            topTrailing: max(0, topTrailing)
        )
    }
}

private func cgColor(for color: Color) -> CGColor {
    #if canImport(UIKit)
    return UIColor(color).cgColor
    #elseif canImport(AppKit)
    return NSColor(color).cgColor
    #endif
}

private func rgbaComponents(for color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
    #if canImport(UIKit)
    let platformColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (red, green, blue, alpha)
    #elseif canImport(AppKit)
    let platformColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .clear
    return (platformColor.redComponent, platformColor.greenComponent, platformColor.blueComponent, platformColor.alphaComponent)
    #endif
}

internal struct AwesomeRoundedRectangle: InsettableShape {
    var radii: ResolvedCornerRadii
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radii = radii.clamped
        let width = insetRect.width
        let height = insetRect.height
        let topLeft = min(min(radii.topLeading, height / 2), width / 2)
        let topRight = min(min(radii.topTrailing, height / 2), width / 2)
        let bottomRight = min(min(radii.bottomTrailing, height / 2), width / 2)
        let bottomLeft = min(min(radii.bottomLeading, height / 2), width / 2)

        var path = Path()
        path.move(to: CGPoint(x: insetRect.minX + topLeft, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX - topRight, y: insetRect.minY))
        path.addArc(
            center: CGPoint(x: insetRect.maxX - topRight, y: insetRect.minY + topRight),
            radius: topRight,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - bottomRight))
        path.addArc(
            center: CGPoint(x: insetRect.maxX - bottomRight, y: insetRect.maxY - bottomRight),
            radius: bottomRight,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: insetRect.minX + bottomLeft, y: insetRect.maxY))
        path.addArc(
            center: CGPoint(x: insetRect.minX + bottomLeft, y: insetRect.maxY - bottomLeft),
            radius: bottomLeft,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY + topLeft))
        path.addArc(
            center: CGPoint(x: insetRect.minX + topLeft, y: insetRect.minY + topLeft),
            radius: topLeft,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
