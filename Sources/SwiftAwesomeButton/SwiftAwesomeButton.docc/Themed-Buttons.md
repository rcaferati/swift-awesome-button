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

Requested flat styling is preserved while disabled. Otherwise disabled styling overrides the requested variant. Explicit overrides take precedence over variant and size values. The canonical social variant is ``ButtonVariant/x``.

The inner button owns the complete style transition. Variant changes use 200 ms; same-variant changes, including named size changes, use the resolved style duration. Package-owned string labels interpolate effective font size and line height with that progress. When the font size changes, the label scales from `1` to `1.04` at the midpoint and returns to `1`. `animateSize: false` and Reduce Motion snap typography without the bump, and custom label views remain consumer-owned.

Label identity remains independent from style progress. With `textTransition` enabled, theme changes cannot cancel an active scramble/reveal generation. When it is disabled, a changed plain-string label is committed immediately and does not inherit the visual-style animation transaction.

For auto-width plain-string labels, the accepted source and target measurements own the size transition. Temporary scramble frames do not retarget that animation, so growth and shrink remain monotonic and settle without overshoot. Custom content and auxiliary-slot rows continue to use native rendered-row measurement.
