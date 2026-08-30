# Themed Buttons

Use ``ThemedButton`` when a button should resolve a built-in theme, semantic variant, and named size before applying explicit overrides.

```swift
ThemedButton(
  child: "Continue",
  onPress: { _ in advance() },
  theme: .basic,
  type: .primary,
  size: .medium
)
```

Disabled styling overrides flat and requested variants. Explicit overrides take precedence over variant and size values. The canonical social variant is ``ButtonVariant/x``.
