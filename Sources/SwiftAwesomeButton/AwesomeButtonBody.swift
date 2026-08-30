import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

private struct AwesomeButtonAutoWidthRowPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct AwesomeButtonContentHeightPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

internal func resolvedAwesomeButtonDisplayText(
  childText: String?,
  transitionText: String?
) -> String? {
  guard let childText else {
    return nil
  }

  return transitionText ?? childText
}

internal struct AwesomeButtonBody: View, Animatable {
  @Environment(\.layoutDirection) private var layoutDirection
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

  nonisolated var animatableData: AwesomeButtonShellPresentationVector {
    get { presentationVector }
    set { presentationVector = newValue }
  }

  private var effectiveHeight: CGFloat {
    max(0, max(presentationVector.height, controller.measuredContentHeight))
  }
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
      return interpolatedStyle.disabledBackgroundColor ?? interpolatedStyle.backgroundColor
        ?? AwesomeButtonThemeData.fallbackStyle.backgroundColor!
    }
    return interpolatedStyle.backgroundColor ?? AwesomeButtonThemeData.fallbackStyle
      .backgroundColor!
  }

  private var depthColor: Color {
    if configuration.disabled {
      return interpolatedStyle.disabledDepthColor ?? interpolatedStyle.depthColor
        ?? AwesomeButtonThemeData.fallbackStyle.depthColor!
    }
    return interpolatedStyle.depthColor ?? AwesomeButtonThemeData.fallbackStyle.depthColor!
  }

  private var shadowColor: Color {
    if configuration.disabled {
      return interpolatedStyle.disabledShadowColor ?? interpolatedStyle.shadowColor
        ?? AwesomeButtonThemeData.fallbackStyle.shadowColor!
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
      return interpolatedStyle.disabledForegroundColor ?? interpolatedStyle.foregroundColor
        ?? AwesomeButtonThemeData.fallbackStyle.foregroundColor!
    }
    return interpolatedStyle.foregroundColor ?? AwesomeButtonThemeData.fallbackStyle
      .foregroundColor!
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
    resolvedPressedFaceColor(
      style: interpolatedStyle,
      restingBackground: backgroundColor
    )
  }

  private var faceColor: Color {
    interpolateColor(backgroundColor, pressedFaceColor, progress: clampedPressProgress)
      ?? backgroundColor
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
    resolvedCornerRadii(style: interpolatedStyle, layoutDirection: layoutDirection)
  }

  private var typographyFrame: AwesomeButtonTypographyFrame {
    resolvedAwesomeButtonTypographyFrame(
      sourceStyle: controller.styleTransitionSourceStyle,
      targetStyle: configuration.style,
      progress: clampedStyleTransitionProgress,
      animateSize: configuration.animateSize,
      reduceMotion: configuration.reduceMotion
    )
  }

  private var scaledTypographyTextSize: CGFloat {
    awesomeButtonScaledTextSize(
      typographyFrame.textSize,
      dynamicTypeSize: configuration.dynamicTypeSize
    )
  }

  private var scaledTypographyLineHeight: CGFloat {
    awesomeButtonScaledTextSize(
      typographyFrame.lineHeight,
      dynamicTypeSize: configuration.dynamicTypeSize
    )
  }

  private var font: Font {
    if let family = typographyFrame.fontFamily {
      return .custom(family, size: scaledTypographyTextSize)
    }

    return .system(size: scaledTypographyTextSize, weight: .bold)
  }

  var body: some View {
    let visualSurface = GeometryReader { proxy in
      shellContent(
        width: configuration.widthMode == .stretch
          ? proxy.size.width
          : animatedShellWidth
      )
    }
    .frame(
      width: configuration.widthMode == .stretch ? nil : max(animatedShellWidth, 44),
      height: max(totalHeight, 44),
      alignment: .center
    )
    .frame(maxWidth: configuration.widthMode == .stretch ? .infinity : nil, alignment: .top)
    .disabled(configuration.isEffectivelyDisabled)
    .opacity(configuration.disabled ? 0.96 : 1)
    return ZStack {
      visualSurface.modifier(
        AwesomeButtonAccessibilityModifier(
          controller: controller,
          configuration: configuration
        )
      )

      #if canImport(UIKit)
        ButtonTouchSurface(
          isDisabled: configuration.isEffectivelyDisabled || controller.isBusy,
          onConfigurationUpdate: {
            // `updateUIView` runs inside SwiftUI's graph transaction. Refresh live
            // callbacks and eligibility there, while the owning view task applies
            // @Published visual highlight changes after that transaction unwinds.
            controller.refreshLiveConfiguration(
              configuration,
              applyVisualUpdates: false
            )
          },
          onTouchChange: { isInside in
            controller.handleTouchChange(isInside: isInside, configuration: configuration)
          },
          onTouchEnd: { isInside in
            controller.handleTouchEnd(isInside: isInside, configuration: configuration)
          },
          onLongPress: configuration.onLongPress.map { _ in
            { controller.handleLongPress(configuration: configuration) }
          },
          onDismantle: {
            controller.handleTouchSurfaceDismantle()
          }
        )
        .frame(
          width: configuration.widthMode == .stretch ? nil : max(animatedShellWidth, 44),
          height: max(totalHeight, 44)
        )
        .frame(maxWidth: configuration.widthMode == .stretch ? .infinity : nil)
        .accessibilityHidden(true)
      #endif
    }
    .frame(
      width: configuration.widthMode == .stretch ? nil : max(animatedShellWidth, 44),
      height: max(totalHeight, 44)
    )
    .frame(maxWidth: configuration.widthMode == .stretch ? .infinity : nil)
  }

  private func shellContent(width: CGFloat) -> some View {
    let shellMetrics = resolveAwesomeButtonShellMetrics(
      width: width,
      height: effectiveHeight
    )

    return ZStack(alignment: .center) {
      shellStack(shellMetrics: shellMetrics)
        .frame(width: shellMetrics.shellWidth, height: totalHeight, alignment: .top)
    }
    .frame(
      width: max(shellMetrics.shellWidth, 44), height: max(totalHeight, 44), alignment: .center
    )
    .contentShape(Rectangle())
    .onPreferenceChange(AwesomeButtonAutoWidthRowPreferenceKey.self) { measuredWidth in
      controller.updateMeasuredAutoWidth(
        measuredWidth,
        configuration: configuration
      )
    }
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
          .accessibilityHidden(true)
      }

      if controller.showProgressVisuals && configuration.showProgressBar {
        Rectangle()
          .fill(progressColor)
          .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
          .offset(
            x: awesomeButtonProgressOffset(
              progress: controller.progressValue,
              width: shellMetrics.faceWidth,
              layoutDirection: layoutDirection
            )
          )
          .clipShape(AwesomeRoundedRectangle(radii: cornerRadii))
          .opacity(Double(controller.progressOverlayOpacity))
      }

      if configuration.isPlaceholder {
        ZStack(alignment: .center) {
          PlaceholderFace(
            tint: placeholderColor,
            height: interpolatedStyle.textLineHeight ?? AwesomeButtonThemeData.fallbackStyle
              .textLineHeight ?? 20,
            animated: configuration.animatedPlaceholder && configuration.reduceMotion == false
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
              beforeView.accessibilityHidden(true)
            }
            labelContent
            if let afterView = configuration.afterView {
              afterView.accessibilityHidden(true)
            }
          }
          .padding(.horizontal, configuration.paddingHorizontal)
          .padding(.top, configuration.paddingTop)
          .padding(.bottom, configuration.paddingBottom)
          .fixedSize(
            horizontal: configuration.dynamicTypeSize <= .large,
            vertical: false
          )
          .background {
            GeometryReader { proxy in
              Color.clear.preference(
                key: AwesomeButtonAutoWidthRowPreferenceKey.self,
                value: proxy.size.width + (borderWidth * 2)
              )
              .preference(
                key: AwesomeButtonContentHeightPreferenceKey.self,
                value: proxy.size.height + (borderWidth * 2)
              )
            }
          }
          .opacity(contentOpacity)
          .scaleEffect(controller.contentTransitionValue)
        }
        .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
        .clipped()

        if controller.showProgressVisuals {
          if configuration.reduceMotion {
            Circle()
              .trim(from: 0, to: 0.72)
              .stroke(activityColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
              .frame(width: 22, height: 22)
              .rotationEffect(.degrees(-90))
              .opacity(activityOpacity)
              .allowsHitTesting(false)
          } else {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(activityColor)
              .scaleEffect(controller.activityTransitionValue)
              .opacity(activityOpacity)
              .allowsHitTesting(false)
          }
        }
      }

      if borderWidth > 0 {
        AwesomeRoundedRectangle(radii: cornerRadii)
          .stroke(borderColor, lineWidth: borderWidth)
          .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
      }
    }
    .frame(width: shellMetrics.faceWidth, height: shellMetrics.shellHeight)
    .onPreferenceChange(AwesomeButtonContentHeightPreferenceKey.self) { measuredHeight in
      if configuration.dynamicTypeSize > .large {
        controller.updateMeasuredContentHeight(measuredHeight, configuration: configuration)
      }
    }
  }

  @ViewBuilder
  private var labelContent: some View {
    if let text = resolvedAwesomeButtonDisplayText(
      childText: configuration.childText,
      transitionText: controller.displayedText
    ) {
      Text(text)
        .font(font)
        .foregroundStyle(foregroundColor)
        .lineSpacing(max(0, scaledTypographyLineHeight - scaledTypographyTextSize))
        .lineLimit(configuration.dynamicTypeSize > .large ? nil : 1)
        .fixedSize(horizontal: configuration.dynamicTypeSize <= .large, vertical: true)
        .scaleEffect(typographyFrame.scale)
        .transaction { transaction in
          // String replacement is package-owned. Explicit text transitions
          // provide their own frames and must not inherit a style animation.
          transaction.animation = nil
          transaction.disablesAnimations = true
        }
    } else if let labelView = configuration.labelView {
      labelView
    } else {
      EmptyView()
    }
  }
}

internal func awesomeButtonProgressOffset(
  progress: CGFloat,
  width: CGFloat,
  layoutDirection: LayoutDirection
) -> CGFloat {
  let remainingWidth = (1 - min(max(progress, 0), 1)) * width
  return layoutDirection == .rightToLeft ? remainingWidth : -remainingWidth
}

private struct AwesomeButtonAccessibilityModifier: ViewModifier {
  @ObservedObject var controller: AwesomeButtonController
  let configuration: AwesomeButtonResolvedConfiguration

  @ViewBuilder
  func body(content: Content) -> some View {
    let base =
      content
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isButton)

    if configuration.isPlaceholder && configuration.accessibilityLabel == nil {
      base.accessibilityHidden(true)
    } else {
      actions(for: state(for: identity(for: base)))
    }
  }

  @ViewBuilder
  private func identity<ContentView: View>(for content: ContentView) -> some View {
    if let label = configuration.accessibilityLabel {
      content.accessibilityLabel(Text(label))
    } else {
      content
    }
  }

  @ViewBuilder
  private func state<ContentView: View>(for content: ContentView) -> some View {
    if controller.isBusy {
      content.accessibilityValue(Text(AwesomeButtonLocalization.busyState))
    } else if configuration.isPlaceholder {
      content.accessibilityValue(Text(AwesomeButtonLocalization.placeholderState))
    } else if configuration.isEffectivelyDisabled == false,
      configuration.hasAtomicActivationSink,
      let hint = configuration.accessibilityHint
    {
      content.accessibilityHint(Text(hint))
    } else {
      content
    }
  }

  @ViewBuilder
  private func actions<ContentView: View>(for content: ContentView) -> some View {
    let eligible = configuration.isEffectivelyDisabled == false && controller.isBusy == false
    let hasDefault = eligible && configuration.hasAtomicActivationSink
    let hasLong = eligible && configuration.onLongPress != nil

    if hasDefault && hasLong {
      content
        .accessibilityAction {
          controller.activateAtomically(configuration: configuration)
        }
        .accessibilityAction(
          named: Text(
            configuration.accessibilityLongPressLabel ?? AwesomeButtonLocalization.longPressAction
          )
        ) {
          controller.activateLongPressAtomically(configuration: configuration)
        }
    } else if hasDefault {
      content.accessibilityAction {
        controller.activateAtomically(configuration: configuration)
      }
    } else if hasLong {
      content.accessibilityAction(
        named: Text(
          configuration.accessibilityLongPressLabel ?? AwesomeButtonLocalization.longPressAction
        )
      ) {
        controller.activateLongPressAtomically(configuration: configuration)
      }
    } else {
      content
    }
  }
}

internal func awesomeButtonScaledTextSize(
  _ baseSize: CGFloat,
  dynamicTypeSize: DynamicTypeSize
) -> CGFloat {
  #if canImport(UIKit)
    let category: UIContentSizeCategory
    switch dynamicTypeSize {
    case .xSmall: category = .extraSmall
    case .small: category = .small
    case .medium: category = .medium
    case .large: category = .large
    case .xLarge: category = .extraLarge
    case .xxLarge: category = .extraExtraLarge
    case .xxxLarge: category = .extraExtraExtraLarge
    case .accessibility1: category = .accessibilityMedium
    case .accessibility2: category = .accessibilityLarge
    case .accessibility3: category = .accessibilityExtraLarge
    case .accessibility4: category = .accessibilityExtraExtraLarge
    case .accessibility5: category = .accessibilityExtraExtraExtraLarge
    @unknown default: category = .large
    }
    return UIFontMetrics(forTextStyle: .body).scaledValue(
      for: baseSize,
      compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
    )
  #else
    return baseSize
  #endif
}
