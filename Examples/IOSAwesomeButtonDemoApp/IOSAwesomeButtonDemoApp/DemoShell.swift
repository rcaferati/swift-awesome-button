import SwiftUI
import SwiftAwesomeButton

private enum DemoIconName: String {
    case paintbrush = "fa-paintbrush"
    case gauge = "fa-gauge"
    case shareNodes = "fa-share-nodes"
    case sizeChanges = "fa-up-right-and-down-left-from-center"
    case rightLeft = "fa-right-left"
    case forwardStep = "fa-forward-step"
    case bars = "fa-bars"
    case tableCellsLarge = "fa-table-cells-large"
    case trashCan = "fa-trash-can"
    case squarePlus = "fa-square-plus"
    case userPlus = "fa-user-plus"
    case locationArrow = "fa-location-arrow"
    case facebook = "fa-facebook-f"
    case x = "fa-x-twitter"
    case messenger = "fa-facebook-messenger"
    case instagram = "fa-instagram"
    case whatsapp = "fa-whatsapp"
    case youtube = "fa-youtube"
    case linkedin = "fa-linkedin-in"
    case pinterest = "fa-pinterest-p"
}

private struct DemoIcon: View {
    let name: DemoIconName
    let size: CGFloat
    let color: Color

    var body: some View {
        Image(name.rawValue)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size, alignment: .center)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

private enum DemoTab: Int, CaseIterable {
    case themed
    case progress
    case social
    case sizeChanges
}

private enum ThemedHeaderDirection {
    private static let titlePushDistance: CGFloat = 40

    case forward
    case backward

    var titleTransition: AnyTransition {
        switch self {
        case .forward:
            return .asymmetric(
                insertion: .offset(x: Self.titlePushDistance).combined(with: .opacity),
                removal: .offset(x: -Self.titlePushDistance).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .offset(x: -Self.titlePushDistance).combined(with: .opacity),
                removal: .offset(x: Self.titlePushDistance).combined(with: .opacity)
            )
        }
    }
}

private let secondaryHeaderColor = Color(red: 0.31, green: 0.44, blue: 0.77)

struct DemoShell: View {
    @State private var selectedTab: DemoTab = .themed
    @State private var themePath: [Int] = []
    @State private var themedHeaderDirection: ThemedHeaderDirection = .forward

    private var currentThemeIndex: Int {
        themePath.last ?? 0
    }

    private var currentTheme: RegisteredThemeDefinition {
        getTheme(index: currentThemeIndex)
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                headerView(topInset: proxy.safeAreaInsets.top)

                TabView(selection: $selectedTab) {
                    themedTab
                        .tabItem {
                            Label {
                                Text("Themed")
                            } icon: {
                                DemoIcon(name: .paintbrush, size: 21, color: .primary)
                            }
                        }
                        .tag(DemoTab.themed)

                    ProgressScreen()
                        .tabItem {
                            Label {
                                Text("Progress")
                            } icon: {
                                DemoIcon(name: .gauge, size: 21, color: .primary)
                            }
                        }
                        .tag(DemoTab.progress)

                    SocialScreen()
                        .tabItem {
                            Label {
                                Text("Social")
                            } icon: {
                                DemoIcon(name: .shareNodes, size: 21, color: .primary)
                            }
                        }
                        .tag(DemoTab.social)

                    SizeChangesScreen()
                        .tabItem {
                            Label {
                                Text("Size Changes")
                            } icon: {
                                DemoIcon(name: .sizeChanges, size: 21, color: .primary)
                            }
                        }
                        .tag(DemoTab.sizeChanges)
                }
                .tint(Color(red: 0.03, green: 0.55, blue: 0.85))
                .background(Color.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
        }
    }

    private var themedTab: some View {
        NavigationStack(path: $themePath) {
            ThemedButtonsScreen(index: 0)
                .navigationDestination(for: Int.self) { index in
                    ThemedButtonsScreen(index: index)
                }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func headerView(topInset: CGFloat) -> some View {
        switch selectedTab {
        case .themed:
            ThemedHeaderBar(
                theme: currentTheme,
                themeIndex: currentThemeIndex,
                direction: themedHeaderDirection,
                topInset: topInset,
                onPrev: popTheme,
                onNext: pushNextTheme
            )
        case .progress:
            StaticHeaderBar(title: "Progress Buttons", topInset: topInset)
        case .social:
            StaticHeaderBar(title: "Social Buttons", topInset: topInset)
        case .sizeChanges:
            StaticHeaderBar(title: "Size Changes", topInset: topInset)
        }
    }

    private func pushNextTheme() {
        guard currentTheme.next else {
            return
        }

        themedHeaderDirection = .forward
        themePath.append(currentThemeIndex + 1)
    }

    private func popTheme() {
        guard themePath.isEmpty == false else {
            return
        }

        themedHeaderDirection = .backward
        themePath.removeLast()
    }
}

private struct StaticHeaderBar: View {
    private static let contentHeight: CGFloat = 72

    let title: String
    let topInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: topInset)

            ZStack {
                secondaryHeaderColor
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 18)
            }
            .frame(height: Self.contentHeight)
        }
        .background(secondaryHeaderColor)
    }
}

private struct ThemedHeaderBar: View {
    private static let headerButtonSlotWidth: CGFloat = 88
    private static let contentHeight: CGFloat = 72
    private static let titleSideInset: CGFloat = 8

    let theme: RegisteredThemeDefinition
    let themeIndex: Int
    let direction: ThemedHeaderDirection
    let topInset: CGFloat
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: topInset)

            ZStack {
                theme.background
                    .animation(.easeOut(duration: 0.24), value: theme.name)

                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: Self.titleSideInset)

                    ThemedHeaderTitle(
                        title: theme.title,
                        color: theme.color,
                        themeIndex: themeIndex,
                        direction: direction
                    )

                    Color.clear
                        .frame(width: Self.titleSideInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                HStack {
                    SizedBox(width: Self.headerButtonSlotWidth) {
                        ThemeHeaderButton(
                            label: "Prev",
                            themeName: theme.name,
                            foregroundColor: theme.color,
                            disabled: theme.prev == false,
                            onPress: onPrev
                        )
                    }

                    Spacer(minLength: 16)
                    Spacer(minLength: 16)

                    SizedBox(width: Self.headerButtonSlotWidth) {
                        ThemeHeaderButton(
                            label: "Next",
                            themeName: theme.name,
                            foregroundColor: theme.color,
                            disabled: theme.next == false,
                            onPress: onNext
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(height: Self.contentHeight)
        }
        .background(
            theme.background
                .animation(.easeOut(duration: 0.24), value: theme.name)
        )
    }
}

private struct ThemedHeaderTitle: View {
    private static let edgeFadeFraction: CGFloat = 0.06

    let title: String
    let color: Color
    let themeIndex: Int
    let direction: ThemedHeaderDirection

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .id(themeIndex)
                .transition(direction.titleTransition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: Self.edgeFadeFraction),
                    .init(color: .white, location: 1 - Self.edgeFadeFraction),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .animation(.easeInOut(duration: 0.24), value: themeIndex)
    }
}

private struct ThemeHeaderButton: View {
    let label: String
    let themeName: ThemeName
    let foregroundColor: Color
    let disabled: Bool
    let onPress: () -> Void

    var body: some View {
        themedTextButton(
            label,
            name: themeName,
            type: .flat,
            size: .small,
            onPress: { _ in
                onPress()
            },
            disabled: disabled,
            width: 80,
            style: AwesomeButtonStyle(
                backgroundActive: Color.black.opacity(0.05),
                foregroundColor: foregroundColor,
                disabledForegroundColor: foregroundColor.opacity(0.45)
            ),
            activeOpacity: 0.6,
            debouncedPressTime: 0.875
        )
    }
}

private struct ThemedButtonsScreen: View {
    private static let transitionVariants: [ButtonVariant] = [
        .primary,
        .secondary,
        .anchor,
        .danger,
    ]
    private static let textTransitionLabels = [
        "welcome",
        "Level 2",
        "Mission#42",
        "Go#3",
    ]
    private static let sizeTransitionLabels = [
        "Launch",
        "View analytics dashboard",
    ]

    let index: Int

    @State private var transitionVariantIndex = 0
    @State private var textTransitionIndex = 0
    @State private var sizeTransitionIndex = 0

    private var theme: RegisteredThemeDefinition {
        getTheme(index: index)
    }

    private var transitionVariant: ButtonVariant {
        Self.transitionVariants[transitionVariantIndex]
    }

    private var textTransitionLabel: String {
        Self.textTransitionLabels[textTransitionIndex]
    }

    private var sizeTransitionLabel: String {
        Self.sizeTransitionLabels[sizeTransitionIndex]
    }

    private var primaryButtonColor: Color {
        theme.buttons[.primary]?.backgroundColor ?? theme.color
    }

    private var sectionHeaderWidthFactor: CGFloat {
        theme.name == .basic ? 0.6 : 0.5
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ThemeCharacterOverlay(themeName: theme.name)
            DemoContainer {
                VStack(alignment: .leading, spacing: 0) {
                    DemoSection(title: "Common", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            themedTextButton("Primary", name: theme.name, type: .primary)
                        }
                        sectionButton {
                            themedTextButton("Secondary", name: theme.name, type: .secondary)
                        }
                        sectionButton {
                            themedTextButton("Anchor", name: theme.name, type: .anchor)
                        }
                        sectionButton {
                            themedTextButton("Danger", name: theme.name, type: .danger)
                        }
                        sectionButton {
                            themedTextButton("Disabled", name: theme.name, type: .primary, disabled: true)
                        }
                    }

                    DemoSection(title: "Progress", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            themedTextButton("Primary", name: theme.name, type: .primary, onPress: delayedCompletion(seconds: 0.5), progress: true)
                        }
                        sectionButton {
                            themedTextButton("Secondary", name: theme.name, type: .secondary, onPress: delayedCompletion(seconds: 0.5), progress: true)
                        }
                        sectionButton {
                            themedTextButton("Anchor", name: theme.name, type: .anchor, onPress: delayedCompletion(seconds: 0.5), progress: true)
                        }
                        sectionButton {
                            themedTextButton("Danger", name: theme.name, type: .danger, onPress: delayedCompletion(seconds: 0.5), progress: true)
                        }
                    }

                    DemoSection(title: "Variant Transition", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            DemoInlineAction {
                                themedTextButton(transitionVariant.rawValue, name: theme.name, type: transitionVariant)
                            } action: {
                                flatIconButton(
                                    themeName: theme.name,
                                    color: primaryButtonColor,
                                    icon: .rightLeft,
                                    accessibilityLabel: "Cycle variant",
                                    action: advanceVariant
                                )
                            }
                        }
                    }

                    DemoSection(title: "Text Transition", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            DemoInlineAction {
                                themedTextButton(textTransitionLabel, name: theme.name, type: .primary, textTransition: true)
                            } action: {
                                flatIconButton(
                                    themeName: theme.name,
                                    color: primaryButtonColor,
                                    icon: .forwardStep,
                                    accessibilityLabel: "Cycle text",
                                    action: advanceTextTransition
                                )
                            }
                        }
                    }

                    DemoSection(title: "Size Transition", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            DemoInlineAction {
                                themedTextButton(sizeTransitionLabel, name: theme.name, type: .primary, textTransition: true, autoWidth: true)
                            } action: {
                                flatIconButton(
                                    themeName: theme.name,
                                    color: primaryButtonColor,
                                    icon: .forwardStep,
                                    accessibilityLabel: "Cycle size",
                                    action: advanceSizeTransition
                                )
                            }
                        }
                    }

                    DemoSection(title: "Empty Placeholder", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            ThemedButton(name: theme.name, type: .primary)
                        }
                        sectionButton {
                            ThemedButton(name: theme.name, type: .secondary)
                        }
                        sectionButton {
                            ThemedButton(name: theme.name, type: .anchor)
                        }
                        sectionButton {
                            ThemedButton(name: theme.name, type: .danger)
                        }
                    }

                    DemoSection(title: "Flat Buttons", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            themedTextButton("Primary", name: theme.name, type: .primary, style: AwesomeButtonStyle(raiseAmount: 0), activeOpacity: 0.75)
                        }
                        sectionButton {
                            themedTextButton("Secondary", name: theme.name, type: .secondary, style: AwesomeButtonStyle(raiseAmount: 0), activeOpacity: 0.75)
                        }
                        sectionButton {
                            themedTextButton("Anchor", name: theme.name, type: .anchor, style: AwesomeButtonStyle(raiseAmount: 0), activeOpacity: 0.75)
                        }
                        sectionButton {
                            themedTextButton("Danger", name: theme.name, type: .danger, onPress: delayedCompletion(seconds: 0.5), style: AwesomeButtonStyle(raiseAmount: 0), activeOpacity: 0.75, progress: true)
                        }
                    }

                    DemoSection(title: "Before / After / Icon", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            themedTextButton(
                                "Button Icon",
                                name: theme.name,
                                type: .primary,
                                style: AwesomeButtonStyle(contentGap: 8),
                                before: iconView(.bars, color: buttonTextColor(themeName: theme.name, type: .primary))
                            )
                        }
                        sectionButton {
                            themedTextButton(
                                "Button Icon",
                                name: theme.name,
                                type: .anchor,
                                style: AwesomeButtonStyle(contentGap: 8),
                                after: iconView(.tableCellsLarge, color: buttonTextColor(themeName: theme.name, type: .anchor))
                            )
                        }
                        sectionButton {
                            themedTextButton(
                                "Button Icon",
                                name: theme.name,
                                type: .danger,
                                onPress: delayedCompletion(seconds: 0.5),
                                style: AwesomeButtonStyle(contentGap: 8),
                                progress: true,
                                before: iconView(.trashCan, color: buttonTextColor(themeName: theme.name, type: .danger))
                            )
                        }
                        sectionButton {
                            ThemedButton(name: theme.name, type: .primary, size: .icon, accessibilityLabel: "Add") {
                                DemoIcon(
                                    name: .squarePlus,
                                    size: 24,
                                    color: buttonTextColor(themeName: theme.name, type: .primary)
                                )
                            }
                        }
                        sectionButton {
                            ThemedButton(name: theme.name, type: .anchor, size: .icon, accessibilityLabel: "Add user") {
                                DemoIcon(
                                    name: .userPlus,
                                    size: 24,
                                    color: buttonTextColor(themeName: theme.name, type: .anchor)
                                )
                            }
                        }
                        sectionButton {
                            ThemedButton(
                                name: theme.name,
                                type: .danger,
                                size: .icon,
                                accessibilityLabel: "Delete",
                                onPress: delayedCompletion(seconds: 0.5),
                                progress: true
                            ) {
                                DemoIcon(
                                    name: .trashCan,
                                    size: 24,
                                    color: buttonTextColor(themeName: theme.name, type: .danger)
                                )
                            }
                        }
                    }

                    DemoSection(title: "With auto and stretch", headerWidthFactor: sectionHeaderWidthFactor) {
                        sectionButton {
                            themedTextButton("Primary Auto", name: theme.name, type: .primary, autoWidth: true)
                        }
                        sectionButton {
                            themedTextButton("Secondary Small Auto", name: theme.name, type: .secondary, size: .small, autoWidth: true)
                        }
                        sectionButton {
                            themedTextButton("Anchor Large Auto", name: theme.name, type: .anchor, size: .large, autoWidth: true)
                        }
                        sectionButton {
                            themedTextButton("Primary Large Stretch", name: theme.name, type: .danger, size: .large, stretch: true)
                        }
                        sectionButton {
                            themedTextButton("Stretch Progress + Async Task", name: theme.name, type: .primary, size: .large, onPress: delayedCompletion(seconds: 0.9), stretch: true, progress: true)
                        }
                        Text("This demo keeps the long-running progress example app-local, so the package remains focused on the button itself.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.39, green: 0.46, blue: 0.54))
                            .padding(.top, 4)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func advanceVariant() {
        transitionVariantIndex = (transitionVariantIndex + 1) % Self.transitionVariants.count
    }

    private func advanceTextTransition() {
        textTransitionIndex = (textTransitionIndex + 1) % Self.textTransitionLabels.count
    }

    private func advanceSizeTransition() {
        sizeTransitionIndex = (sizeTransitionIndex + 1) % Self.sizeTransitionLabels.count
    }
}

private struct ProgressScreen: View {
    private let themeName: ThemeName = .mysterion

    var body: some View {
        DemoContainer {
            VStack(alignment: .leading, spacing: 0) {
                DemoSection(title: "Labeled Buttons") {
                    sectionButton {
                        themedTextButton("Progress", name: themeName, type: .primary, onPress: delayedCompletion(seconds: 1), width: 200, progress: true)
                    }
                    sectionButton {
                        themedTextButton("Slower", name: themeName, type: .secondary, onPress: delayedCompletion(seconds: 1), width: 200, progress: true, progressLoadingTime: 6)
                    }
                    sectionButton {
                        themedTextButton("No Bar", name: themeName, type: .anchor, onPress: delayedCompletion(seconds: 1), width: 200, progress: true, showProgressBar: false)
                    }
                    sectionButton {
                        themedTextButton("Flat Progress", name: themeName, type: .danger, onPress: delayedCompletion(seconds: 1), width: 200, style: AwesomeButtonStyle(borderRadius: 0, raiseAmount: 0), progress: true)
                    }
                    sectionButton {
                        ThemedButton(
                            name: themeName,
                            type: .anchor,
                            size: .icon,
                            accessibilityLabel: "Send",
                            onPress: delayedCompletion(seconds: 1),
                            style: AwesomeButtonStyle(borderRadius: 30, raiseAmount: 6),
                            progress: true
                        ) {
                            DemoIcon(
                                name: .locationArrow,
                                size: 24,
                                color: buttonTextColor(themeName: themeName, type: .anchor)
                            )
                        }
                    }
                    sectionButton {
                        ThemedButton(
                            name: themeName,
                            type: .secondary,
                            size: .icon,
                            accessibilityLabel: "Facebook",
                            onPress: delayedCompletion(seconds: 1),
                            style: AwesomeButtonStyle(borderRadius: 30, raiseAmount: 0),
                            progress: true
                        ) {
                            DemoIcon(
                                name: .facebook,
                                size: 24,
                                color: buttonTextColor(themeName: themeName, type: .secondary)
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SocialScreen: View {
    private let themeName: ThemeName = .bojack

    var body: some View {
        DemoContainer {
            VStack(alignment: .leading, spacing: 0) {
                DemoSection(title: "Labeled Buttons") {
                    sectionButton {
                        themedTextButton(
                            "Facebook",
                            name: themeName,
                            type: .facebook,
                            onPress: delayedCompletion(seconds: 1),
                            width: 180,
                            style: AwesomeButtonStyle(borderRadius: 50, raiseAmount: 8, contentGap: 8),
                            progress: true,
                            before: iconView(.facebook, color: buttonTextColor(themeName: themeName, type: .facebook))
                        )
                    }
                    sectionButton {
                        themedTextButton(
                            "LinkedIn",
                            name: themeName,
                            type: .linkedin,
                            onPress: delayedCompletion(seconds: 1),
                            width: 180,
                            style: AwesomeButtonStyle(borderRadius: 8, raiseAmount: 8, contentGap: 8),
                            progress: true,
                            before: iconView(.linkedin, color: buttonTextColor(themeName: themeName, type: .linkedin))
                        )
                    }
                    sectionButton {
                        themedTextButton(
                            "Messenger",
                            name: themeName,
                            type: .messenger,
                            onPress: delayedCompletion(seconds: 1),
                            width: 180,
                            style: AwesomeButtonStyle(borderRadius: 0, raiseAmount: 6, contentGap: 8),
                            progress: true,
                            before: iconView(.messenger, color: buttonTextColor(themeName: themeName, type: .messenger))
                        )
                    }
                    sectionButton {
                        themedTextButton(
                            "Instagram",
                            name: themeName,
                            onPress: delayedCompletion(seconds: 1),
                            width: 180,
                            style: AwesomeButtonStyle(
                                backgroundActive: Color.black.opacity(0.15),
                                backgroundProgress: Color.black.opacity(0.15),
                                depthColor: Color(red: 0.92, green: 0.67, blue: 0.12),
                                shadowColor: Color.black.opacity(0.15),
                                contentGap: 8
                            ),
                            progress: true,
                            before: iconView(.instagram, color: .white),
                            extra: instagramGradientView()
                        )
                    }
                }

                DemoSection(title: "Iconed Buttons") {
                    sectionButton {
                        ThemedButton(
                            name: themeName,
                            type: .whatsapp,
                            accessibilityLabel: "WhatsApp",
                            onPress: delayedCompletion(seconds: 1),
                            width: 60,
                            style: AwesomeButtonStyle(borderRadius: 0, raiseAmount: 0),
                            progress: true
                        ) {
                            DemoIcon(
                                name: .whatsapp,
                                size: 24,
                                color: buttonTextColor(themeName: themeName, type: .whatsapp)
                            )
                        }
                    }
                    sectionButton {
                        ThemedButton(
                            name: themeName,
                            type: .youtube,
                            accessibilityLabel: "YouTube",
                            onPress: delayedCompletion(seconds: 1),
                            width: 60,
                            style: AwesomeButtonStyle(borderRadius: 0, raiseAmount: 8),
                            progress: true
                        ) {
                            DemoIcon(
                                name: .youtube,
                                size: 24,
                                color: buttonTextColor(themeName: themeName, type: .youtube)
                            )
                        }
                    }
                    sectionButton {
                        ThemedButton(
                            name: themeName,
                            type: .x,
                            accessibilityLabel: "X",
                            onPress: delayedCompletion(seconds: 1),
                            width: 60,
                            style: AwesomeButtonStyle(borderRadius: 8, raiseAmount: 8),
                            progress: true
                        ) {
                            DemoIcon(
                                name: .x,
                                size: 24,
                                color: buttonTextColor(themeName: themeName, type: .x)
                            )
                        }
                    }
                    sectionButton {
                        ThemedButton(
                            name: themeName,
                            type: .pinterest,
                            accessibilityLabel: "Pinterest",
                            onPress: delayedCompletion(seconds: 1),
                            width: 60,
                            height: 60,
                            style: AwesomeButtonStyle(borderRadius: 80, raiseAmount: 8),
                            progress: true
                        ) {
                            DemoIcon(
                                name: .pinterest,
                                size: 24,
                                color: buttonTextColor(themeName: themeName, type: .pinterest)
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SizeChangesScreen: View {
    private static let themeSizes: [ButtonSize] = [.small, .medium, .large]

    @State private var isLongLabel = false
    @State private var sizeIndex = 1

    private var autoWidthLabel: String {
        isLongLabel ? "View analytics dashboard" : "Launch"
    }

    private var currentThemeSize: ButtonSize {
        Self.themeSizes[sizeIndex]
    }

    private var currentThemeSizeLabel: String {
        currentThemeSize.rawValue.capitalized
    }

    var body: some View {
        DemoContainer {
            VStack(alignment: .leading, spacing: 0) {
                DemoSection(title: "Auto Width String Change") {
                    Text("Evaluates how the button reacts when a plain string label switches between short and long content.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.36, green: 0.39, blue: 0.45))
                        .padding(.bottom, 10)

                    sectionButton {
                        themedTextButton(
                            "Toggle Label Length",
                            name: .bruce,
                            type: .secondary,
                            size: .small,
                            onPress: { _ in
                                isLongLabel.toggle()
                            },
                            autoWidth: true,
                            style: AwesomeButtonStyle(raiseAmount: 0),
                            activeOpacity: 0.6
                        )
                    }

                    SizingVariantLabel("Animated with text transition")
                    sectionButton {
                        textDemoButton(autoWidthLabel, textTransition: true)
                    }

                    SizingVariantLabel("Animated without text transition")
                    sectionButton {
                        textDemoButton(autoWidthLabel)
                    }

                    SizingVariantLabel("Instant opt-out")
                    sectionButton {
                        textDemoButton(autoWidthLabel, animateSize: false)
                    }
                }

                DemoSection(title: "Themed Fixed Size Change") {
                    Text("Evaluates how a themed button behaves when its built-in size preset changes between fixed widths.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.36, green: 0.39, blue: 0.45))
                        .padding(.bottom, 10)

                    sectionButton {
                        themedTextButton(
                            "Cycle Theme Size",
                            name: .bruce,
                            type: .secondary,
                            size: .small,
                            onPress: { _ in
                                sizeIndex = (sizeIndex + 1) % Self.themeSizes.count
                            },
                            autoWidth: true,
                            style: AwesomeButtonStyle(raiseAmount: 0),
                            activeOpacity: 0.6
                        )
                    }

                    SizingVariantLabel("Animated with text transition")
                    sectionButton {
                        themedTextButton(currentThemeSizeLabel, name: .bruce, type: .danger, size: currentThemeSize, textTransition: true)
                    }

                    SizingVariantLabel("Animated without text transition")
                    sectionButton {
                        themedTextButton(currentThemeSizeLabel, name: .bruce, type: .danger, size: currentThemeSize)
                    }

                    SizingVariantLabel("Instant opt-out")
                    sectionButton {
                        themedTextButton(currentThemeSizeLabel, name: .bruce, type: .danger, size: currentThemeSize, animateSize: false)
                    }
                }
            }
        }
    }
}

private struct DemoContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.top, 30)
            .padding(.bottom, 50)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct DemoSection<Content: View>: View {
    let title: String
    let headerWidthFactor: CGFloat
    @ViewBuilder let content: () -> Content

    init(title: String, headerWidthFactor: CGFloat = 0.6, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.headerWidthFactor = headerWidthFactor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color(red: 0.27, green: 0.27, blue: 0.27))
                        .padding(.vertical, 4)
                    Rectangle()
                        .fill(Color(red: 0.27, green: 0.27, blue: 0.27).opacity(0.5))
                        .frame(height: 0.5)
                        .padding(.bottom, 8)
                }
                .frame(width: proxy.size.width * headerWidthFactor, alignment: .leading)
            }
            .frame(height: 29)
            content()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

private struct DemoInlineAction<MainView: View, ActionView: View>: View {
    @ViewBuilder let main: () -> MainView
    @ViewBuilder let action: () -> ActionView

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            main()
            action()
        }
    }
}

private struct SizingVariantLabel: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 12, weight: .bold))
            .tracking(0.2)
            .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

private struct SizedBox<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    init(width: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.width = width
        self.content = content
    }

    var body: some View {
        content()
            .frame(width: width)
    }
}

@ViewBuilder
private func sectionButton<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding(.vertical, 8)
}

private func delayedCompletion(seconds: Double) -> AwesomeButtonPressCallback {
    { handle in
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            await MainActor.run {
                handle?.callAsFunction()
            }
        }
    }
}

private func flatIconButton(
    themeName: ThemeName,
    color: Color,
    icon: DemoIconName,
    accessibilityLabel: String,
    action: @escaping () -> Void
) -> some View {
    ThemedButton(
        name: themeName,
        type: .flat,
        size: .icon,
        accessibilityLabel: accessibilityLabel,
        onPress: { _ in
            action()
        }
    ) {
        DemoIcon(name: icon, size: 18, color: color)
    }
}

private func themedTextButton(
    _ child: String,
    name: ThemeName? = nil,
    type: ButtonVariant = .primary,
    size: ButtonSize = .medium,
    flat: Bool = false,
    textTransition: Bool = false,
    accessibilityLabel: String? = nil,
    onPress: AwesomeButtonPressCallback? = nil,
    onPressOut: (() -> Void)? = nil,
    onPressedOut: (() -> Void)? = nil,
    disabled: Bool = false,
    width: CGFloat? = nil,
    autoWidth: Bool = false,
    stretch: Bool = false,
    style: AwesomeButtonStyle? = nil,
    activeOpacity: Double = 1,
    debouncedPressTime: TimeInterval = 0,
    progress: Bool = false,
    showProgressBar: Bool = true,
    progressLoadingTime: TimeInterval = 3,
    animateSize: Bool = true,
    before: AnyView? = nil,
    after: AnyView? = nil,
    extra: AnyView? = nil
) -> some View {
    ThemedButton(
        child: child,
        name: name,
        type: type,
        size: size,
        flat: flat,
        textTransition: textTransition,
        accessibilityLabel: accessibilityLabel,
        onPress: onPress,
        disabled: disabled,
        width: width,
        autoWidth: autoWidth,
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
        onPressOut: onPressOut,
        onPressedOut: onPressedOut
    )
}

private func textDemoButton(_ child: String, textTransition: Bool = false, animateSize: Bool = true) -> some View {
    themedTextButton(
        child,
        name: .bruce,
        type: .anchor,
        textTransition: textTransition,
        autoWidth: true,
        animateSize: animateSize
    )
}

private func buttonTextColor(themeName: ThemeName, type: ButtonVariant) -> Color {
    let theme = getTheme(name: themeName)
    return theme.buttons[type]?.textColor ?? theme.color
}

private func iconView(_ name: DemoIconName, color: Color, size: CGFloat = 24) -> AnyView {
    AnyView(
        DemoIcon(name: name, size: size, color: color)
    )
}

private func instagramGradientView() -> AnyView {
    AnyView(
        LinearGradient(
            colors: [
                Color(red: 0.30, green: 0.39, blue: 0.82),
                Color(red: 0.74, green: 0.19, blue: 0.51),
                Color(red: 0.96, green: 0.44, blue: 0.20),
                Color(red: 0.99, green: 0.84, blue: 0.46),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
