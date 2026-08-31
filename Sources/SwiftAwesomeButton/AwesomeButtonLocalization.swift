import Foundation

internal enum AwesomeButtonLocalization {
  static var busyState: String { localized("awesome_button_busy_state") }
  static var longPressAction: String { localized("awesome_button_long_press_action") }
  static var placeholderState: String { localized("awesome_button_placeholder_state") }

  private static func localized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
  }
}
