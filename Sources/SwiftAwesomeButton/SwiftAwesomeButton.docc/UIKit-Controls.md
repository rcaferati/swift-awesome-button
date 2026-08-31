# UIKit Controls

Use ``AwesomeButtonControl`` or ``ThemedButtonControl`` as normal `UIControl` instances. They forward primary actions, enabled/highlighted state, accessibility activation, intrinsic sizing, mutable configuration, and view-controller containment to the shared package implementation.

```swift
let button = AwesomeButtonControl(
  configuration: .init(child: "Save")
)
button.addTarget(self, action: #selector(save), for: .primaryActionTriggered)
```

Update `configuration` to refresh the hosted SwiftUI content. Add the control to a UIKit hierarchy; the control owns and removes its hosting controller correctly.
