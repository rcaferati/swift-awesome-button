import SwiftUI
import UIKit
import SwiftAwesomeButton

private struct ThemeCharacterConfig {
    let resourceName: String
    let width: CGFloat
    let height: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct ThemeCharacterOverlay: View {
    private static let enterDelay: TimeInterval = 0.185
    private static let initialOffsetX: CGFloat = 200
    private static let springAnimation = Animation.interpolatingSpring(
        stiffness: 447.4,
        damping: 21.25
    )
    private static let characters: [ThemeName: ThemeCharacterConfig] = [
        .bojack: ThemeCharacterConfig(resourceName: "bojack", width: 492 / 2, height: 696 / 2, x: 42, y: 0),
        .rick: ThemeCharacterConfig(resourceName: "rick", width: 547 / 2, height: 768 / 2, x: 90, y: 0),
        .c137: ThemeCharacterConfig(resourceName: "c137", width: 416 / 2, height: 639 / 2, x: 40, y: 0),
        .cartman: ThemeCharacterConfig(resourceName: "cartman", width: 640 / 2, height: 590 / 2, x: 70, y: 0),
        .bruce: ThemeCharacterConfig(resourceName: "batman", width: 1280 / 3.5, height: 1538 / 3.5, x: 90, y: -25),
        .mysterion: ThemeCharacterConfig(resourceName: "mysterion", width: 640 / 2, height: 590 / 2, x: 70, y: 0),
        .summer: ThemeCharacterConfig(resourceName: "summer", width: 395 / 2, height: 727 / 2, x: 30, y: -10),
    ]

    let themeName: ThemeName

    @State private var offsetX: CGFloat = Self.initialOffsetX
    @State private var scheduledAnimation: DispatchWorkItem?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let config = Self.characters[themeName], let image = Self.loadImage(named: config.resourceName) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: config.width, height: config.height)
                    // Flutter positions from `right: 0, bottom: config.y`, then translates on x.
                    .offset(x: offsetX, y: -config.y)
                    .id(themeName)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(false)
        .onAppear {
            syncOverlayState(for: themeName)
        }
        .onChange(of: themeName) { newThemeName in
            syncOverlayState(for: newThemeName)
        }
        .onDisappear {
            scheduledAnimation?.cancel()
            scheduledAnimation = nil
        }
    }

    private func syncOverlayState(for themeName: ThemeName) {
        guard let config = Self.characters[themeName] else {
            scheduledAnimation?.cancel()
            scheduledAnimation = nil
            offsetX = Self.initialOffsetX
            return
        }

        scheduleEntrance(using: config)
    }

    private func scheduleEntrance(using config: ThemeCharacterConfig) {
        scheduledAnimation?.cancel()
        offsetX = Self.initialOffsetX

        let workItem = DispatchWorkItem {
            withAnimation(Self.springAnimation) {
                offsetX = config.x
            }
        }
        scheduledAnimation = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.enterDelay, execute: workItem)
    }

    private static func loadImage(named name: String) -> UIImage? {
        if let cached = ThemeCharacterImageCache.shared.object(forKey: name as NSString) {
            return cached
        }

        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Characters")

        guard let url else {
            return nil
        }

        guard let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }

        ThemeCharacterImageCache.shared.setObject(image, forKey: name as NSString)
        return image
    }
}

private enum ThemeCharacterImageCache {
    static let shared = NSCache<NSString, UIImage>()
}
