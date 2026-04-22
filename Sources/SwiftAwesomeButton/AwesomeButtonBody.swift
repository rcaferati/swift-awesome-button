import SwiftUI

internal struct AwesomeButtonBody: View, Animatable {
    @ObservedObject var controller: AwesomeButtonController
    let configuration: AwesomeButtonResolvedConfiguration
    var presentationVector: AwesomeButtonShellPresentationVector

    init(
        controller: AwesomeButtonController,
        configuration: AwesomeButtonResolvedConfiguration,
        targetWidth: CGFloat?,
        targetHeight: CGFloat,
        targetPressProgress: CGFloat
    ) {
        self.controller = controller
        self.configuration = configuration
        self.presentationVector = AwesomeButtonShellPresentationVector(
            width: targetWidth ?? configuration.width ?? 0,
            height: targetHeight,
            pressProgress: clampedVisualPressProgress(targetPressProgress),
            styleTransitionProgress: controller.styleTransitionProgress
        )
    }

    var animatableData: AwesomeButtonShellPresentationVector {
        get { presentationVector }
        set { presentationVector = newValue }
    }

    private var effectiveHeight: CGFloat { max(0, presentationVector.height) }
    private var raiseAmount: CGFloat { interpolatedStyle.raiseAmount ?? 6 }
    private var totalHeight: CGFloat { effectiveHeight + raiseAmount }
    private var shadowHeight: CGFloat { max(0, effectiveHeight - raiseAmount) }
    private var clampedPressProgress: CGFloat {
        clampedVisualPressProgress(presentationVector.pressProgress)
    }
    private var clampedStyleTransitionProgress: CGFloat {
        max(0, min(presentationVector.styleTransitionProgress, 1))
    }
    private var geometryPressProgress: CGFloat {
        shellGeometryPressProgress(presentationVector.pressProgress)
    }
    private var animatedShellWidth: CGFloat {
        max(0, presentationVector.width)
    }
    private var interpolatedStyle: AwesomeButtonStyle {
        guard let sourceStyle = controller.styleTransitionSourceStyle else {
            return resolvedVisualStyle(configuration.style)
        }

        return interpolateAwesomeButtonStyle(
            sourceStyle,
            configuration.style,
            progress: clampedStyleTransitionProgress
        )
    }
    private var shadowTopOffset: CGFloat {
        // Match Flutter's shadow plane placement:
        // - shadow is anchored with `bottom: -(raiseAmount / 2)` at rest
        // - then translated upward by `(raiseAmount / 2) * press`
        // In top-origin coordinates this becomes:
        // `2.5 * raiseAmount - 0.5 * raiseAmount * press`.
        (raiseAmount * 2.5) - ((raiseAmount / 2) * geometryPressProgress)
    }
    private var faceOffset: CGFloat {
        raiseAmount * geometryPressProgress
    }

    private var backgroundColor: Color {
        if configuration.disabled {
            return interpolatedStyle.disabledBackgroundColor ?? interpolatedStyle.backgroundColor ?? AwesomeButtonThemeData.fallbackStyle.backgroundColor!
        }
        return interpolatedStyle.backgroundColor ?? AwesomeButtonThemeData.fallbackStyle.backgroundColor!
    }

    private var depthColor: Color {
        if configuration.disabled {
            return interpolatedStyle.disabledDepthColor ?? interpolatedStyle.depthColor ?? AwesomeButtonThemeData.fallbackStyle.depthColor!
        }
        return interpolatedStyle.depthColor ?? AwesomeButtonThemeData.fallbackStyle.depthColor!
    }

    private var shadowColor: Color {
        if configuration.disabled {
            return interpolatedStyle.disabledShadowColor ?? interpolatedStyle.shadowColor ?? AwesomeButtonThemeData.fallbackStyle.shadowColor!
        }
        return interpolatedStyle.shadowColor ?? AwesomeButtonThemeData.fallbackStyle.shadowColor!
    }

    private var borderColor: Color {
        if configuration.disabled {
            return interpolatedStyle.disabledBorderColor ?? interpolatedStyle.borderColor ?? .clear
        }
        return interpolatedStyle.borderColor ?? .clear
    }

    private var foregroundColor: Color {
        if configuration.disabled {
            return interpolatedStyle.disabledForegroundColor ?? interpolatedStyle.foregroundColor ?? AwesomeButtonThemeData.fallbackStyle.foregroundColor!
        }
        return interpolatedStyle.foregroundColor ?? AwesomeButtonThemeData.fallbackStyle.foregroundColor!
    }

    private var activityColor: Color {
        interpolatedStyle.activityColor ?? AwesomeButtonThemeData.fallbackStyle.activityColor!
    }

    private var progressColor: Color {
        interpolatedStyle.backgroundProgress ?? depthColor
    }

    private var placeholderColor: Color {
        interpolatedStyle.backgroundPlaceholder ?? shadowColor
    }

    private var pressedFaceColor: Color {
        if let explicit = interpolatedStyle.backgroundActive {
            return explicit
        }

        return blendColors(-0.08, backgroundColor, toward: .black, linear: true)
    }

    private var faceColor: Color {
        interpolateColor(backgroundColor, pressedFaceColor, progress: clampedPressProgress) ?? backgroundColor
    }

    private var contentOpacity: Double {
        if configuration.progress == false {
            return 1 - ((1 - configuration.activeOpacity) * Double(clampedPressProgress))
        }

        return Double(max(0, min(controller.contentTransitionValue, 1)))
    }

    private var activityOpacity: Double {
        Double(max(0, min(controller.activityTransitionValue, 1)))
    }

    private var contentGap: CGFloat {
        interpolatedStyle.contentGap ?? AwesomeButtonThemeData.fallbackStyle.contentGap ?? 10
    }

    private var cornerRadii: ResolvedCornerRadii {
        resolvedCornerRadii(style: interpolatedStyle)
    }

    private var font: Font {
        let size = interpolatedStyle.textSize ?? 14
        if let family = interpolatedStyle.textFontFamily {
            return .custom(family, size: size)
        }

        return .system(size: size, weight: .bold)
    }

    var body: some View {
        Group {
            if configuration.widthMode == .stretch {
                GeometryReader { proxy in
                    shellContent(width: proxy.size.width)
                }
            } else {
                shellContent(width: animatedShellWidth)
            }
        }
        .frame(width: configuration.widthMode == .stretch ? nil : animatedShellWidth, height: totalHeight, alignment: .top)
        .frame(maxWidth: configuration.widthMode == .stretch ? .infinity : nil, alignment: .top)
        .disabled(configuration.isEffectivelyDisabled)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(configuration.childText ?? "Awesome Button"))
        .accessibilityValue(Text(controller.isBusy ? "Loading" : (configuration.isEffectivelyDisabled ? "Disabled" : "Idle")))
        .accessibilityHidden(false)
        .opacity(configuration.disabled ? 0.96 : 1)
    }

    private func shellContent(width: CGFloat) -> some View {
        let shellMetrics = resolveAwesomeButtonShellMetrics(
            width: width,
            height: effectiveHeight
        )

        return ZStack(alignment: .top) {
            shellStack(shellMetrics: shellMetrics)

#if canImport(UIKit)
            if configuration.isEffectivelyDisabled == false {
                ButtonTouchSurface(
                    isDisabled: controller.isBusy,
                    onTouchChange: { isInside in
                        controller.handleTouchChange(isInside: isInside)
                    },
                    onTouchEnd: { isInside in
                        controller.handleTouchEnd(isInside: isInside)
                    },
                    onLongPress: {
                        controller.handleLongPress()
                    }
                )
                .frame(width: shellMetrics.shellWidth, height: totalHeight)
            }
#endif
        }
        .frame(width: shellMetrics.shellWidth, height: totalHeight, alignment: .top)
        .contentShape(Rectangle())
    }

    private func shellStack(shellMetrics: AwesomeButtonShellMetrics) -> some View {
        ZStack(alignment: .top) {
            AwesomeRoundedRectangle(radii: cornerRadii)
                .fill(shadowColor)
                .frame(
                    width: shellMetrics.shadowWidth,
                    height: shadowHeight
                )
                .position(
                    x: shellMetrics.shellWidth / 2,
                    y: shadowTopOffset + (shadowHeight / 2)
                )

            AwesomeRoundedRectangle(radii: cornerRadii)
                .fill(depthColor)
                .frame(width: shellMetrics.depthWidth, height: shellMetrics.shellHeight)
                .offset(y: raiseAmount)

            faceLayer(shellMetrics: shellMetrics)
                .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
                .clipShape(AwesomeRoundedRectangle(radii: cornerRadii))
                .offset(y: faceOffset)
        }
    }

    private func faceLayer(shellMetrics: AwesomeButtonShellMetrics) -> some View {
        let borderWidth = interpolatedStyle.borderWidth ?? 0

        return ZStack {
            AwesomeRoundedRectangle(radii: cornerRadii)
                .fill(faceColor)
                .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)

            if let extraView = configuration.extraView {
                extraView
                    .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
                    .clipShape(AwesomeRoundedRectangle(radii: cornerRadii))
            }

            if controller.showProgressVisuals && configuration.showProgressBar {
                Rectangle()
                    .fill(progressColor)
                    .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
                    .offset(x: (controller.progressValue - 1) * shellMetrics.faceWidth)
                    .clipShape(AwesomeRoundedRectangle(radii: cornerRadii))
                    .opacity(Double(controller.progressOverlayOpacity))
            }

            if configuration.isPlaceholder {
                ZStack(alignment: .center) {
                    PlaceholderFace(
                        tint: placeholderColor,
                        height: interpolatedStyle.textLineHeight ?? AwesomeButtonThemeData.fallbackStyle.textLineHeight ?? 20,
                        animated: configuration.animatedPlaceholder
                    )
                    .padding(.horizontal, configuration.paddingHorizontal)
                    .padding(.top, configuration.paddingTop)
                    .padding(.bottom, configuration.paddingBottom)
                    .allowsHitTesting(false)
                }
                .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
                .clipped()
            } else {
                ZStack(alignment: controller.contentClipAlignment.swiftUIAlignment) {
                    HStack(spacing: contentGap) {
                        if let beforeView = configuration.beforeView {
                            beforeView
                        }
                        labelContent
                        if let afterView = configuration.afterView {
                            afterView
                        }
                    }
                    .padding(.horizontal, configuration.paddingHorizontal)
                    .padding(.top, configuration.paddingTop)
                    .padding(.bottom, configuration.paddingBottom)
                    .opacity(contentOpacity)
                    .scaleEffect(controller.contentTransitionValue)
                }
                .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
                .clipped()

                if controller.showProgressVisuals {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(activityColor)
                        .scaleEffect(controller.activityTransitionValue)
                        .opacity(activityOpacity)
                        .allowsHitTesting(false)
                }
            }

            if borderWidth > 0 {
                AwesomeRoundedRectangle(radii: cornerRadii)
                    .stroke(borderColor, lineWidth: borderWidth)
                    .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
            }
        }
        .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
    }

    @ViewBuilder
    private var labelContent: some View {
        if let text = controller.displayedText {
            Text(text)
                .font(font)
                .foregroundStyle(foregroundColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .animation(nil, value: text)
        } else if let labelView = configuration.labelView {
            labelView
        } else {
            EmptyView()
        }
    }
}
