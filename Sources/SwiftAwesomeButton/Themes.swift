import SwiftUI

private let defaultThemeName: ThemeName = .basic
private let themeOrder: [ThemeName] = [
    .basic,
    .bojack,
    .cartman,
    .mysterion,
    .c137,
    .rick,
    .summer,
    .bruce,
]

internal let transparentStyles = ThemeButtonStyle(
    backgroundColor: .clear,
    backgroundDarker: .clear,
    backgroundPlaceholder: .clear,
    backgroundShadow: .clear,
    borderColor: .clear
)

internal func resolveButtonType(
    theme: ThemeDefinition,
    disabled: Bool,
    flat: Bool,
    type: ButtonVariant
) -> ButtonVariant {
    resolveButtonType(buttons: theme.buttons, disabled: disabled, flat: flat, type: type)
}

internal func resolveButtonType(
    theme: RegisteredThemeDefinition,
    disabled: Bool,
    flat: Bool,
    type: ButtonVariant
) -> ButtonVariant {
    resolveButtonType(buttons: theme.buttons, disabled: disabled, flat: flat, type: type)
}

private func resolveButtonType(
    buttons: [ButtonVariant: ThemeButtonStyle],
    disabled: Bool,
    flat: Bool,
    type: ButtonVariant
) -> ButtonVariant {
    let preservesFlatAppearance = flat || type == .flat
    let requestedType: ButtonVariant = preservesFlatAppearance ? .flat : (disabled ? .disabled : type)
    return buttons.keys.contains(requestedType) ? requestedType : .primary
}

internal func themeButtonStyleToAwesomeButtonStyle(_ style: ThemeButtonStyle) -> AwesomeButtonStyle {
    AwesomeButtonStyle(
        backgroundColor: style.backgroundColor,
        backgroundActive: style.backgroundActive,
        backgroundPlaceholder: style.backgroundPlaceholder,
        backgroundProgress: style.backgroundProgress,
        depthColor: style.backgroundDarker,
        shadowColor: style.backgroundShadow,
        activityColor: style.activityColor,
        foregroundColor: style.textColor,
        textSize: style.textSize,
        textLineHeight: style.textLineHeight,
        textFontFamily: style.textFontFamily,
        borderRadius: style.borderRadius,
        borderWidth: style.borderWidth,
        borderColor: style.borderColor,
        raiseAmount: style.raiseLevel
    )
}

internal func interpolateThemeButtonStyle(_ from: ThemeButtonStyle, _ to: ThemeButtonStyle, progress: CGFloat) -> ThemeButtonStyle {
    ThemeButtonStyle(
        borderRadius: to.borderRadius,
        borderBottomLeftRadius: to.borderBottomLeftRadius,
        borderBottomRightRadius: to.borderBottomRightRadius,
        borderTopLeftRadius: to.borderTopLeftRadius,
        borderTopRightRadius: to.borderTopRightRadius,
        height: to.height,
        paddingBottom: to.paddingBottom,
        paddingHorizontal: to.paddingHorizontal,
        paddingTop: to.paddingTop,
        raiseLevel: to.raiseLevel,
        backgroundActive: interpolateColor(from.backgroundActive, to.backgroundActive, progress: progress),
        backgroundColor: interpolateColor(from.backgroundColor, to.backgroundColor, progress: progress),
        backgroundDarker: interpolateColor(from.backgroundDarker, to.backgroundDarker, progress: progress),
        backgroundPlaceholder: interpolateColor(from.backgroundPlaceholder, to.backgroundPlaceholder, progress: progress),
        backgroundProgress: interpolateColor(from.backgroundProgress, to.backgroundProgress, progress: progress),
        backgroundShadow: interpolateColor(from.backgroundShadow, to.backgroundShadow, progress: progress),
        textColor: interpolateColor(from.textColor, to.textColor, progress: progress),
        borderWidth: to.borderWidth,
        borderColor: interpolateColor(from.borderColor, to.borderColor, progress: progress),
        activityColor: interpolateColor(from.activityColor, to.activityColor, progress: progress),
        textFontFamily: to.textFontFamily,
        textLineHeight: to.textLineHeight,
        textSize: to.textSize,
        width: to.width
    )
}

internal func themePaletteForInterpolation(_ style: ThemeButtonStyle) -> ThemeButtonStyle {
    let fallback = AwesomeButtonThemeData.fallbackStyle
    let backgroundColor = style.backgroundColor ?? fallback.backgroundColor!
    let activeColor = style.backgroundActive ?? blendColors(0.08, backgroundColor, toward: .black, linear: true)

        return style.merge(
        ThemeButtonStyle(
            backgroundActive: activeColor,
            backgroundColor: backgroundColor,
            backgroundDarker: style.backgroundDarker ?? fallback.depthColor,
            backgroundPlaceholder: style.backgroundPlaceholder ?? fallback.backgroundPlaceholder,
            backgroundProgress: style.backgroundProgress ?? fallback.backgroundProgress,
            backgroundShadow: style.backgroundShadow ?? fallback.shadowColor,
            textColor: style.textColor ?? fallback.foregroundColor,
            borderColor: style.borderColor ?? fallback.borderColor,
            activityColor: style.activityColor ?? fallback.activityColor
        )
    )
}

private func flatStyle() -> ThemeButtonStyle {
    ThemeButtonStyle(
        borderRadius: 0,
        raiseLevel: 0,
        backgroundColor: .clear,
        backgroundDarker: .clear,
        backgroundShadow: .clear
    )
}

private func createSocialTypes(common: ThemeButtonStyle) -> [ButtonVariant: ThemeButtonStyle] {
    [
        .x: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.090, green: 0.090, blue: 0.090), backgroundDarker: Color(red: 0.020, green: 0.020, blue: 0.020))),
        .messenger: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.192, green: 0.525, blue: 0.965), backgroundDarker: Color(red: 0.145, green: 0.400, blue: 0.737))),
        .facebook: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.282, green: 0.408, blue: 0.678), backgroundDarker: Color(red: 0.196, green: 0.318, blue: 0.580))),
        .github: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.173, green: 0.188, blue: 0.212), backgroundDarker: Color(red: 0.024, green: 0.027, blue: 0.031))),
        .linkedin: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0, green: 0.467, blue: 0.710), backgroundDarker: Color(red: 0, green: 0.345, blue: 0.522))),
        .whatsapp: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.145, green: 0.827, blue: 0.400), backgroundDarker: Color(red: 0.078, green: 0.647, blue: 0.294))),
        .reddit: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.988, green: 0.275, blue: 0.118), backgroundDarker: Color(red: 0.835, green: 0.157, blue: 0.008))),
        .pinterest: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.741, green: 0.035, blue: 0.110), backgroundDarker: Color(red: 0.596, green: 0.012, blue: 0.075))),
        .youtube: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.800, green: 0.094, blue: 0.118), backgroundDarker: Color(red: 0.671, green: 0.051, blue: 0.071))),
    ]
}

private let basicTheme: ThemeDefinition = {
    let common = ThemeButtonStyle(borderRadius: 8, height: 60, raiseLevel: 12)
    let primary = Color(red: 0.275, green: 0.533, blue: 0.773)
    let anchor = Color(red: 0.275, green: 0.773, blue: 0.471)
    let danger = Color(red: 0.694, green: 0.227, blue: 0.227)
    return ThemeDefinition(
        title: "Basic Theme",
        background: Color(red: 0.090, green: 0.459, blue: 0.784),
        color: .white,
        buttons: [
            .primary: ThemeButtonStyle(
                borderRadius: common.borderRadius,
                height: common.height,
                raiseLevel: common.raiseLevel,
                backgroundActive: blendColors(-0.3, primary),
                backgroundColor: primary,
                backgroundDarker: blendColors(-0.5, primary),
                backgroundProgress: blendColors(-0.65, primary),
                textColor: .white,
                activityColor: Color(red: 0.702, green: 0.898, blue: 0.882)
            ),
            .secondary: ThemeButtonStyle(
                borderRadius: common.borderRadius,
                height: common.height,
                raiseLevel: common.raiseLevel,
                backgroundActive: blendColors(0.85, primary),
                backgroundColor: .white,
                backgroundDarker: blendColors(-0.1, primary),
                backgroundPlaceholder: Color(red: 0.118, green: 0.533, blue: 0.898),
                backgroundProgress: Color(red: 0.784, green: 0.890, blue: 0.961),
                textColor: Color(red: 0.118, green: 0.533, blue: 0.898),
                borderWidth: 1,
                borderColor: Color(red: 0.118, green: 0.533, blue: 0.898),
                activityColor: Color(red: 0.118, green: 0.533, blue: 0.898)
            ),
            .anchor: ThemeButtonStyle(
                borderRadius: common.borderRadius,
                height: common.height,
                raiseLevel: common.raiseLevel,
                backgroundColor: anchor,
                backgroundDarker: blendColors(-0.5, anchor),
                backgroundProgress: blendColors(-0.65, anchor),
                textColor: .white,
                activityColor: .white
            ),
            .danger: ThemeButtonStyle(
                borderRadius: common.borderRadius,
                height: common.height,
                raiseLevel: common.raiseLevel,
                backgroundColor: danger,
                backgroundDarker: blendColors(-0.5, danger),
                backgroundProgress: blendColors(-0.65, danger),
                textColor: .white,
                activityColor: .white
            ),
            .disabled: ThemeButtonStyle(
                borderRadius: common.borderRadius,
                height: common.height,
                raiseLevel: common.raiseLevel,
                backgroundColor: Color(red: 0.875, green: 0.875, blue: 0.875),
                backgroundDarker: Color(red: 0.792, green: 0.792, blue: 0.792),
                textColor: Color(red: 0.714, green: 0.714, blue: 0.714)
            ),
            .flat: flatStyle(),
        ].merging(createSocialTypes(common: common)) { current, _ in current },
        size: [
            .icon: ThemeSizeStyle(width: 60, height: 60, textSize: 12, paddingHorizontal: 4),
            .small: ThemeSizeStyle(width: 120, height: 44, textSize: 12),
            .medium: ThemeSizeStyle(width: 200, height: 60),
            .large: ThemeSizeStyle(width: 250, height: 60, textSize: 16),
        ]
    )
}()

private let bojackTheme: ThemeDefinition = {
    let blue = Color(red: 0.400, green: 0.471, blue: 0.773)
    let grey = Color(red: 0.518, green: 0.510, blue: 0.537)
    let pink = Color(red: 0.922, green: 0.627, blue: 0.741)
    let teal = Color(red: 0.243, green: 0.718, blue: 0.725)
    let common = ThemeButtonStyle(borderRadius: 4, height: 55, paddingHorizontal: 20, raiseLevel: 6, textColor: .white, activityColor: .white)
    return ThemeDefinition(
        title: "Bojack Theme",
        background: Color(red: 0.310, green: 0.435, blue: 0.769),
        color: .white,
        buttons: [
            .primary: common.merge(ThemeButtonStyle(backgroundColor: blue, backgroundDarker: blendColors(-0.3, blue), backgroundProgress: Color(red: 0.165, green: 0.259, blue: 0.518))),
            .secondary: common.merge(ThemeButtonStyle(backgroundColor: grey, backgroundDarker: blendColors(-0.3, grey), backgroundProgress: Color(red: 0.247, green: 0.247, blue: 0.247))),
            .anchor: common.merge(ThemeButtonStyle(backgroundColor: teal, backgroundDarker: blendColors(-0.3, teal), backgroundProgress: blendColors(-0.6, teal))),
            .danger: common.merge(ThemeButtonStyle(backgroundColor: blendColors(-0.1, pink), backgroundDarker: blendColors(-0.3, pink), backgroundProgress: blendColors(-0.5, pink))),
            .disabled: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.875, green: 0.875, blue: 0.875), backgroundDarker: Color(red: 0.792, green: 0.792, blue: 0.792), textColor: Color(red: 0.714, green: 0.714, blue: 0.714))),
            .flat: flatStyle(),
        ].merging(createSocialTypes(common: common)) { current, _ in current },
        size: [
            .icon: ThemeSizeStyle(width: 55, height: 55, textSize: 12, paddingHorizontal: 4),
            .small: ThemeSizeStyle(width: 120, height: 42, textSize: 12),
            .medium: ThemeSizeStyle(width: 200, height: 55),
            .large: ThemeSizeStyle(width: 250, height: 60, textSize: 16),
        ]
    )
}()

private let cartmanTheme: ThemeDefinition = {
    let common = ThemeButtonStyle(borderRadius: 8, height: 55, raiseLevel: 8, activityColor: Color(red: 1, green: 0.882, blue: 0.114))
    let blue = Color(red: 0, green: 0.722, blue: 0.769)
    let red = Color(red: 0.859, green: 0.271, blue: 0.341)
    let yellow = Color(red: 0.992, green: 0.953, blue: 0.325)
    let brown = Color(red: 0.529, green: 0.404, blue: 0.325)
    let dark = Color(red: 0.176, green: 0.176, blue: 0.227)
    return ThemeDefinition(
        title: "Cartman Theme",
        background: Color(red: 0.933, green: 0.196, blue: 0.325),
        color: yellow,
        buttons: [
            .primary: common.merge(ThemeButtonStyle(backgroundColor: blue, backgroundDarker: blendColors(-0.35, yellow), textColor: yellow, borderWidth: 2, borderColor: yellow)),
            .secondary: common.merge(ThemeButtonStyle(backgroundColor: red, backgroundDarker: blendColors(-0.35, yellow), textColor: yellow, borderWidth: 2, borderColor: blendColors(-0.1, yellow))),
            .anchor: common.merge(ThemeButtonStyle(backgroundColor: dark, backgroundDarker: blendColors(-0.3, brown), backgroundProgress: blendColors(0.025, dark), textColor: blendColors(0.1, brown), borderWidth: 2, borderColor: brown, activityColor: blendColors(0.1, brown))),
            .danger: common.merge(ThemeButtonStyle(backgroundColor: blendColors(-0.1, dark), backgroundDarker: blendColors(-0.5, red), backgroundProgress: blendColors(0.025, dark), textColor: red, borderWidth: 2, borderColor: red, activityColor: blendColors(0.1, red))),
            .disabled: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.875, green: 0.875, blue: 0.875), backgroundDarker: Color(red: 0.792, green: 0.792, blue: 0.792), textColor: Color(red: 0.714, green: 0.714, blue: 0.714))),
            .flat: flatStyle(),
        ].merging(createSocialTypes(common: common)) { current, _ in current },
        size: [
            .icon: ThemeSizeStyle(width: 55, height: 55, textSize: 12, paddingHorizontal: 4),
            .small: ThemeSizeStyle(width: 120, height: 42, textSize: 12),
            .medium: ThemeSizeStyle(width: 200, height: 55),
            .large: ThemeSizeStyle(width: 250, height: 60, textSize: 16),
        ]
    )
}()

private let mysterionTheme: ThemeDefinition = {
    let common = ThemeButtonStyle(borderRadius: 24, height: 55, raiseLevel: 8, activityColor: .white)
    let primary = Color(red: 0.275, green: 0.220, blue: 0.337)
    let secondary = Color(red: 0.604, green: 0.549, blue: 0.616)
    let anchor = Color(red: 0.455, green: 0.592, blue: 0.263)
    let anchorBorder = Color(red: 0.404, green: 0.541, blue: 0.216)
    let danger = Color(red: 0.859, green: 0.271, blue: 0.341)
    let yellow = Color(red: 0.992, green: 0.953, blue: 0.325)
    return ThemeDefinition(
        title: "Mysterion Theme",
        background: primary,
        color: .white,
        buttons: [
            .primary: common.merge(ThemeButtonStyle(backgroundColor: primary, backgroundDarker: blendColors(-0.85, primary), textColor: .white, borderWidth: 1, borderColor: primary)),
            .secondary: common.merge(ThemeButtonStyle(backgroundColor: secondary, backgroundDarker: blendColors(-0.6218, secondary), textColor: .white, borderWidth: 1, borderColor: secondary)),
            .anchor: common.merge(ThemeButtonStyle(backgroundColor: anchor, backgroundDarker: blendColors(-0.6218, anchor), textColor: .white, borderWidth: 1, borderColor: anchorBorder)),
            .danger: common.merge(ThemeButtonStyle(backgroundColor: danger, backgroundDarker: blendColors(-0.5, danger), backgroundProgress: blendColors(-0.65, danger), textColor: yellow, activityColor: yellow)),
            .disabled: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.875, green: 0.875, blue: 0.875), backgroundDarker: Color(red: 0.792, green: 0.792, blue: 0.792), textColor: Color(red: 0.714, green: 0.714, blue: 0.714))),
            .flat: flatStyle(),
        ].merging(createSocialTypes(common: common)) { current, _ in current },
        size: [
            .icon: ThemeSizeStyle(width: 55, height: 55, textSize: 12, paddingHorizontal: 4),
            .small: ThemeSizeStyle(width: 120, height: 42, textSize: 12),
            .medium: ThemeSizeStyle(width: 200, height: 55),
            .large: ThemeSizeStyle(width: 250, height: 60, textSize: 16),
        ]
    )
}()

private let c137Theme: ThemeDefinition = {
    let blue = Color(red: 0.286, green: 0.325, blue: 0.435)
    let yellow = Color(red: 0.996, green: 0.988, blue: 0.506)
    let green = Color(red: 0.239, green: 0.714, blue: 0.294)
    let skin = Color(red: 0.925, green: 0.792, blue: 0.694)
    let radioactive = Color(red: 0.824, green: 0.878, blue: 0.329)
    let brown = Color(red: 0.427, green: 0.294, blue: 0.161)
    let common = ThemeButtonStyle(borderRadius: 25, height: 55, raiseLevel: 6, activityColor: Color(red: 0.702, green: 0.898, blue: 0.882))
    return ThemeDefinition(
        title: "C-137 Theme",
        background: yellow,
        color: Color(red: 0.325, green: 0.314, blue: 0.082),
        buttons: [
            .primary: common.merge(ThemeButtonStyle(backgroundColor: blue, backgroundDarker: blendColors(-0.3, blue), backgroundProgress: blendColors(-0.62, blue), textColor: blendColors(0.75, blue), activityColor: blendColors(0.75, blue))),
            .secondary: common.merge(ThemeButtonStyle(backgroundColor: yellow, backgroundDarker: blendColors(-0.3, yellow), backgroundProgress: blendColors(-0.62, yellow), textColor: blendColors(-0.9, yellow), activityColor: blendColors(-0.9, yellow))),
            .anchor: common.merge(ThemeButtonStyle(backgroundColor: skin, backgroundDarker: brown, backgroundProgress: blendColors(-0.5, skin), textColor: brown, activityColor: brown)),
            .danger: common.merge(ThemeButtonStyle(backgroundColor: green, backgroundDarker: radioactive, backgroundProgress: blendColors(-0.62, green), textColor: radioactive, borderColor: radioactive, activityColor: radioactive)),
            .disabled: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.875, green: 0.875, blue: 0.875), backgroundDarker: Color(red: 0.792, green: 0.792, blue: 0.792), textColor: Color(red: 0.714, green: 0.714, blue: 0.714))),
            .flat: flatStyle(),
        ].merging(createSocialTypes(common: common)) { current, _ in current },
        size: [
            .icon: ThemeSizeStyle(width: 55, height: 55, textSize: 12, paddingHorizontal: 4),
            .small: ThemeSizeStyle(width: 120, height: 42, textSize: 12),
            .medium: ThemeSizeStyle(width: 200, height: 55),
            .large: ThemeSizeStyle(width: 250, height: 60, textSize: 16),
        ]
    )
}()

private let rickTheme: ThemeDefinition = {
    let green = Color(red: 0.239, green: 0.714, blue: 0.294)
    let radioactive = Color(red: 0.824, green: 0.878, blue: 0.329)
    let unityLight = Color(red: 0.545, green: 0.200, blue: 0.341)
    let unityDark = Color(red: 0.325, green: 0.094, blue: 0.286)
    let unityEyes = Color(red: 0.894, green: 0.914, blue: 0.580)
    let common = ThemeButtonStyle(borderRadius: 25, height: 55, raiseLevel: 6, activityColor: .white)
    return ThemeDefinition(
        title: "Rick Theme",
        background: Color(red: 0.667, green: 0.827, blue: 0.918),
        color: Color(red: 0.180, green: 0.518, blue: 0.694),
        buttons: [
            .primary: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.667, green: 0.827, blue: 0.918), backgroundDarker: Color(red: 0.341, green: 0.663, blue: 0.831), backgroundPlaceholder: Color(red: 0.553, green: 0.741, blue: 0.851), backgroundProgress: Color(red: 0.341, green: 0.663, blue: 0.831), textColor: Color(red: 0.180, green: 0.518, blue: 0.694))),
            .secondary: common.merge(ThemeButtonStyle(backgroundActive: Color(red: 0.906, green: 0.988, blue: 0.984), backgroundColor: Color(red: 0.980, green: 0.980, blue: 0.980), backgroundDarker: Color(red: 0.404, green: 0.796, blue: 0.765), backgroundPlaceholder: Color(red: 0.702, green: 0.898, blue: 0.882), backgroundProgress: Color(red: 0.773, green: 0.925, blue: 0.910), textColor: Color(red: 0.204, green: 0.596, blue: 0.565), borderWidth: 2, borderColor: Color(red: 0.702, green: 0.898, blue: 0.882), activityColor: Color(red: 0.204, green: 0.596, blue: 0.565))),
            .anchor: common.merge(ThemeButtonStyle(backgroundColor: green, backgroundDarker: radioactive, backgroundProgress: blendColors(-0.62, green), textColor: radioactive, borderWidth: 2, borderColor: radioactive, activityColor: radioactive)),
            .danger: common.merge(ThemeButtonStyle(backgroundColor: unityLight, backgroundDarker: unityDark, backgroundProgress: unityDark, textColor: unityEyes, borderWidth: 2, borderColor: unityDark, activityColor: unityEyes)),
            .disabled: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.910, green: 0.988, blue: 0.855), backgroundDarker: Color(red: 0.741, green: 0.882, blue: 0.635), textColor: Color(red: 0.780, green: 0.949, blue: 0.663), borderWidth: 2, borderColor: Color(red: 0.780, green: 0.910, blue: 0.682))),
            .flat: flatStyle(),
        ].merging(createSocialTypes(common: common)) { current, _ in current },
        size: [
            .icon: ThemeSizeStyle(width: 55, height: 55, textSize: 12, paddingHorizontal: 4),
            .small: ThemeSizeStyle(width: 120, height: 42, textSize: 12),
            .medium: ThemeSizeStyle(width: 200, height: 55),
            .large: ThemeSizeStyle(width: 250, height: 60, textSize: 16),
        ]
    )
}()

private let summerTheme: ThemeDefinition = {
    let primary = Color(red: 0.780, green: 0.486, blue: 0.706)
    let secondary = Color(red: 0.902, green: 0.569, blue: 0.243)
    let anchor = Color.white
    let beth = Color(red: 0.890, green: 0.435, blue: 0.369)
    let common = ThemeButtonStyle(borderRadius: 24, height: 55, raiseLevel: 8, activityColor: .white)
    return ThemeDefinition(
        title: "Summer Theme",
        background: primary,
        color: .white,
        buttons: [
            .primary: common.merge(ThemeButtonStyle(backgroundColor: primary, backgroundDarker: blendColors(-0.38, primary), backgroundProgress: blendColors(-0.62, primary), textColor: .white, borderWidth: 0, borderColor: primary)),
            .secondary: common.merge(ThemeButtonStyle(backgroundColor: anchor, backgroundDarker: blendColors(-0.6, primary), textColor: blendColors(-0.3, primary), borderWidth: 1, borderColor: blendColors(-0.3, primary), activityColor: blendColors(-0.3, primary))),
            .anchor: common.merge(ThemeButtonStyle(backgroundColor: secondary, backgroundDarker: blendColors(-0.62, secondary), textColor: .white, borderWidth: 0, borderColor: secondary)),
            .danger: common.merge(ThemeButtonStyle(backgroundColor: beth, backgroundDarker: blendColors(-0.38, beth), backgroundProgress: blendColors(-0.62, beth), textColor: .white, borderWidth: 0, borderColor: beth)),
            .disabled: common.merge(ThemeButtonStyle(backgroundColor: Color(red: 0.875, green: 0.875, blue: 0.875), backgroundDarker: Color(red: 0.792, green: 0.792, blue: 0.792), textColor: Color(red: 0.714, green: 0.714, blue: 0.714))),
            .flat: flatStyle(),
        ].merging(createSocialTypes(common: common)) { current, _ in current },
        size: [
            .icon: ThemeSizeStyle(width: 55, height: 55, textSize: 12, paddingHorizontal: 4),
            .small: ThemeSizeStyle(width: 120, height: 42, textSize: 12),
            .medium: ThemeSizeStyle(width: 200, height: 55),
            .large: ThemeSizeStyle(width: 250, height: 60, textSize: 16),
        ]
    )
}()

private let bruceTheme: ThemeDefinition = {
    let dark = Color(red: 0.227, green: 0.227, blue: 0.227)
    let white = Color(red: 0.984, green: 0.984, blue: 0.984)
    let purple = Color(red: 0.451, green: 0.188, blue: 0.525)
    let green = Color(red: 0.467, green: 0.804, blue: 0.220)
    let yellow = Color(red: 1.0, green: 0.906, blue: 0.153)
    let common = ThemeButtonStyle(borderRadius: 8, height: 62, raiseLevel: 10, borderWidth: 2)
    return ThemeDefinition(
        title: "Bruce Theme",
        background: Color(red: 0.184, green: 0.184, blue: 0.184),
        color: .white,
        buttons: [
            .primary: common.merge(ThemeButtonStyle(backgroundColor: dark, backgroundDarker: blendColors(-0.38, dark), backgroundProgress: blendColors(-0.62, dark), textColor: white, borderColor: blendColors(-0.38, dark), activityColor: white)),
            .secondary: common.merge(ThemeButtonStyle(backgroundColor: white, backgroundDarker: dark, backgroundPlaceholder: dark, backgroundProgress: blendColors(-0.38, white), textColor: dark, borderColor: blendColors(-0.38, dark), activityColor: dark)),
            .anchor: common.merge(ThemeButtonStyle(backgroundColor: yellow, backgroundDarker: blendColors(-0.38, dark), backgroundProgress: Color(red: 0.251, green: 0.251, blue: 0.251), textColor: blendColors(-0.38, dark), borderWidth: 2, borderColor: dark, activityColor: dark)),
            .danger: common.merge(ThemeButtonStyle(backgroundColor: purple, backgroundDarker: blendColors(-0.62, purple), backgroundProgress: blendColors(-0.62, purple), textColor: green, borderColor: blendColors(-0.62, purple), activityColor: green)),
            .disabled: common.merge(ThemeButtonStyle(backgroundColor: blendColors(0.38, dark), backgroundDarker: blendColors(0.13, dark), textColor: blendColors(0.13, dark), borderColor: blendColors(0.13, dark))),
            .flat: flatStyle(),
        ].merging(createSocialTypes(common: common)) { current, _ in current },
        size: [
            .icon: ThemeSizeStyle(width: 60, height: 60, textSize: 12, paddingHorizontal: 4),
            .small: ThemeSizeStyle(width: 120, height: 42, textSize: 12),
            .medium: ThemeSizeStyle(width: 200, height: 60),
            .large: ThemeSizeStyle(width: 250, height: 60, textSize: 16),
        ]
    )
}()

private let builtInThemes: [ThemeName: ThemeDefinition] = [
    .basic: basicTheme,
    .bojack: bojackTheme,
    .cartman: cartmanTheme,
    .mysterion: mysterionTheme,
    .c137: c137Theme,
    .rick: rickTheme,
    .summer: summerTheme,
    .bruce: bruceTheme,
]

private func registeredTheme(at safeIndex: Int) -> RegisteredThemeDefinition {
    let name = themeOrder[safeIndex]
    let theme = builtInThemes[name] ?? builtInThemes[defaultThemeName]!
    return RegisteredThemeDefinition(
        title: theme.title,
        background: theme.background,
        color: theme.color,
        buttons: theme.buttons,
        size: theme.size,
        name: name,
        next: safeIndex + 1 < themeOrder.count,
        prev: safeIndex - 1 >= 0
    )
}

public func getTheme(index: Int = 0) -> RegisteredThemeDefinition {
    guard themeOrder.indices.contains(index) else {
        return registeredTheme(at: 0)
    }

    return registeredTheme(at: index)
}

public func getTheme(name: ThemeName) -> RegisteredThemeDefinition {
    let index = themeOrder.firstIndex(of: name) ?? 0
    return registeredTheme(at: index)
}
