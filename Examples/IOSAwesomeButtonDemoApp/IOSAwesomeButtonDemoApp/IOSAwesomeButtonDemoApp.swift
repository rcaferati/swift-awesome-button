import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct IOSAwesomeButtonDemoApp: App {
    init() {
        #if canImport(UIKit)
        // Ship a zero-delay scroll view experience process-wide so taps on
        // buttons inside ScrollView / List commit on the next frame. The
        // default 150 ms `delaysContentTouches` window is the single largest
        // source of perceived press lag for UIButton-like controls.
        UIScrollView.appearance().delaysContentTouches = false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            DemoShell()
        }
    }
}
