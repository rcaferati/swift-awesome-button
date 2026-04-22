# SwiftAwesomeButton iOS Demo App

This is the in-repo manual acceptance app for `SwiftAwesomeButton`.

It is a normal iOS Xcode app project under `Examples`, and it consumes the
local Swift package by path so the demo always reflects the package in this
repository.

## Open In Xcode

```bash
open Examples/IOSAwesomeButtonDemoApp/IOSAwesomeButtonDemoApp.xcodeproj
```

## Build From Terminal

```bash
xcodebuild -project Examples/IOSAwesomeButtonDemoApp/IOSAwesomeButtonDemoApp.xcodeproj -scheme IOSAwesomeButtonDemoApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The app is a manual QA surface for:

- themed buttons
- progress buttons
- social-styled buttons
- text transition
- size transition
- placeholder states
