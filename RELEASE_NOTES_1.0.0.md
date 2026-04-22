# 🎉 SwiftAwesomeButton 1.0.0

The first public release of **SwiftAwesomeButton** is here.

A production-ready SwiftUI button component for iOS with layered 3D visuals,
progress handling, themed variants, text transitions, animated size changes,
placeholder states, and UIKit wrappers.

## ✨ Highlights

- 🎛️ 3D layered button visuals
- ⏳ Progress/loading flow with completion handle
- 🎨 Built-in themed variants
- 🔤 Text transitions
- 📏 Animated size changes
- 🫥 Placeholder loading states
- 🧩 Clean Swift Package surface
- 📱 UIKit wrapper support for integration flexibility

## 📦 Package Surface

This release includes:

- `AwesomeButton`
- `ThemedButton`
- `getTheme(...)`
- `AwesomeButtonStyle`
- `AwesomeButtonThemeData`
- `ThemeName`
- `ButtonVariant`
- `ButtonSize`
- `ThemeButtonStyle`
- `ThemeSizeStyle`
- `ThemeDefinition`
- `RegisteredThemeDefinition`
- `AwesomeButtonControl`
- `ThemedButtonControl`

## 🚀 Installation

Add the package in Xcode with:

```text
https://github.com/rcaferati/swift-awesome-button.git
```

Then add the `SwiftAwesomeButton` product to your iOS target.

## 🧪 Validation

Validated with:

```bash
xcodebuild -scheme swift-awesome-button -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

and

```bash
xcodebuild -project Examples/IOSAwesomeButtonDemoApp/IOSAwesomeButtonDemoApp.xcodeproj -scheme IOSAwesomeButtonDemoApp -destination 'generic/platform=iOS Simulator' build
```

## 📚 Documentation

- README includes installation, usage, feature coverage, and demo details
- Example app included under `Examples/IOSAwesomeButtonDemoApp`

## 🙌 Notes

This is the **1.0.0** baseline release for the Swift package.
From here, future releases can focus on API expansion, demo polish, and
ecosystem visibility.

Thanks for checking it out.
