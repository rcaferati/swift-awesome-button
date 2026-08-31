# Direct Buttons

Configure a SwiftUI button directly when the product surface owns its colors and dimensions.

```swift
AwesomeButton(
  child: "Save",
  onPress: { _ in save() },
  style: AwesomeButtonStyle(
    backgroundColor: .blue,
    foregroundColor: .white
  )
)
```

Use the generic-label initializer for arbitrary SwiftUI content. `before` and `after` participate in intrinsic width; `extra` is an overlay and does not.
