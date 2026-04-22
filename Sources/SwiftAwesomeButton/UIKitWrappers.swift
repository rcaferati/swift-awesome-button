#if canImport(UIKit)
import SwiftUI
import UIKit

public final class AwesomeButtonControl: UIControl {
    private let hostingController: UIHostingController<AnyView>

    public init(
        child: String? = nil,
        onPress: AwesomeButtonPressCallback? = nil,
        onLongPress: (() -> Void)? = nil,
        disabled: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat = 52,
        paddingHorizontal: CGFloat? = nil,
        paddingTop: CGFloat? = nil,
        paddingBottom: CGFloat? = nil,
        before: AnyView? = nil,
        after: AnyView? = nil,
        extra: AnyView? = nil,
        stretch: Bool = false,
        style: AwesomeButtonStyle? = nil,
        activeOpacity: Double = 1,
        debouncedPressTime: TimeInterval = 0,
        progress: Bool = false,
        showProgressBar: Bool = true,
        progressLoadingTime: TimeInterval = 3,
        animateSize: Bool = true,
        textTransition: Bool = false,
        textTransitionSlotStaggerMs: Int = 7,
        animatedPlaceholder: Bool = true,
        hapticOnPress: Bool = true,
        onPressIn: (() -> Void)? = nil,
        onPressOut: (() -> Void)? = nil,
        onPressedIn: (() -> Void)? = nil,
        onPressedOut: (() -> Void)? = nil,
        onProgressStart: (() -> Void)? = nil,
        onProgressEnd: (() -> Void)? = nil
    ) {
        let button = AwesomeButton(
            child: child,
            onPress: onPress,
            onLongPress: onLongPress,
            disabled: disabled,
            width: width,
            height: height,
            paddingHorizontal: paddingHorizontal,
            paddingTop: paddingTop,
            paddingBottom: paddingBottom,
            before: before,
            after: after,
            extra: extra,
            stretch: stretch,
            style: style,
            activeOpacity: activeOpacity,
            debouncedPressTime: debouncedPressTime,
            progress: progress,
            showProgressBar: showProgressBar,
            progressLoadingTime: progressLoadingTime,
            animateSize: animateSize,
            textTransition: textTransition,
            textTransitionSlotStaggerMs: textTransitionSlotStaggerMs,
            animatedPlaceholder: animatedPlaceholder,
            hapticOnPress: hapticOnPress,
            onPressIn: onPressIn,
            onPressOut: onPressOut,
            onPressedIn: onPressedIn,
            onPressedOut: onPressedOut,
            onProgressStart: onProgressStart,
            onProgressEnd: onProgressEnd
        )

        hostingController = UIHostingController(rootView: AnyView(button))
        super.init(frame: .zero)
        embedHostingController()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func embedHostingController() {
        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

public final class ThemedButtonControl: UIControl {
    private let hostingController: UIHostingController<AnyView>

    public init(
        child: String? = nil,
        config: ThemeDefinition? = nil,
        index: Int? = nil,
        name: ThemeName? = nil,
        type: ButtonVariant = .primary,
        size: ButtonSize = .medium,
        flat: Bool = false,
        transparent: Bool = false,
        textTransition: Bool = false,
        textTransitionSlotStaggerMs: Int = 7,
        animatedPlaceholder: Bool = true,
        hapticOnPress: Bool = true,
        onPress: AwesomeButtonPressCallback? = nil,
        onLongPress: (() -> Void)? = nil,
        disabled: Bool = false,
        width: CGFloat? = nil,
        autoWidth: Bool = false,
        height: CGFloat? = nil,
        paddingHorizontal: CGFloat? = nil,
        paddingTop: CGFloat? = nil,
        paddingBottom: CGFloat? = nil,
        before: AnyView? = nil,
        after: AnyView? = nil,
        extra: AnyView? = nil,
        stretch: Bool = false,
        style: AwesomeButtonStyle? = nil,
        activeOpacity: Double = 1,
        debouncedPressTime: TimeInterval = 0,
        progress: Bool = false,
        showProgressBar: Bool = true,
        progressLoadingTime: TimeInterval = 3,
        animateSize: Bool = true,
        onPressIn: (() -> Void)? = nil,
        onPressOut: (() -> Void)? = nil,
        onPressedIn: (() -> Void)? = nil,
        onPressedOut: (() -> Void)? = nil,
        onProgressStart: (() -> Void)? = nil,
        onProgressEnd: (() -> Void)? = nil
    ) {
        let button = ThemedButton(
            child: child,
            config: config,
            index: index,
            name: name,
            type: type,
            size: size,
            flat: flat,
            transparent: transparent,
            textTransition: textTransition,
            textTransitionSlotStaggerMs: textTransitionSlotStaggerMs,
            animatedPlaceholder: animatedPlaceholder,
            hapticOnPress: hapticOnPress,
            onPress: onPress,
            onLongPress: onLongPress,
            disabled: disabled,
            width: width,
            autoWidth: autoWidth,
            height: height,
            paddingHorizontal: paddingHorizontal,
            paddingTop: paddingTop,
            paddingBottom: paddingBottom,
            before: before,
            after: after,
            extra: extra,
            stretch: stretch,
            style: style,
            activeOpacity: activeOpacity,
            debouncedPressTime: debouncedPressTime,
            progress: progress,
            showProgressBar: showProgressBar,
            progressLoadingTime: progressLoadingTime,
            animateSize: animateSize,
            onPressIn: onPressIn,
            onPressOut: onPressOut,
            onPressedIn: onPressedIn,
            onPressedOut: onPressedOut,
            onProgressStart: onProgressStart,
            onProgressEnd: onProgressEnd
        )

        hostingController = UIHostingController(rootView: AnyView(button))
        super.init(frame: .zero)
        embedHostingController()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func embedHostingController() {
        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
#endif
