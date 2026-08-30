#if canImport(UIKit)
  import SwiftUI
  import UIKit

  internal enum AwesomeButtonNativeDispatchResult {
    case dispatched
    case mountedIneligible
    case unmounted
  }

  @MainActor
  internal final class AwesomeButtonNativeControlBridge {
    weak var control: UIControl?
    var setHighlighted: ((Bool) -> Void)?
    var invalidateIntrinsicSize: (() -> Void)?
    var eventDispatcher: ((UIControl, UIControl.Event) -> Void)?
    var accessibilityStateDidChange: (() -> Void)?
    private var atomicActivation: (() -> Bool)?
    private var atomicLongPressActivation: (() -> Bool)?

    private(set) var isInteractionMounted = false
    private(set) var hostAllowsInteraction = true
    private var componentAllowsInteraction = false
    private(set) var componentIsBusy = false
    private(set) var measuredAutoWidth: CGFloat?
    private var ownsPhysicalTrackingCycle = false
    private var progressHandle: AwesomeButtonProgressHandle?

    var allowsHighlight: Bool {
      hostAllowsInteraction && componentAllowsInteraction
    }

    func setInteractionMounted(_ mounted: Bool) {
      isInteractionMounted = mounted
      if mounted == false {
        teardown()
      }
    }

    func hasConsumerActivationSink(physical: Bool = true) -> Bool {
      guard let control, isInteractionMounted else {
        return false
      }
      let relevantEvents: UIControl.Event =
        physical
        ? [.touchUpInside, .primaryActionTriggered]
        : [.primaryActionTriggered]
      var found = false
      control.enumerateEventHandlers { _, _, registeredEvents, stop in
        if registeredEvents.intersection(relevantEvents).isEmpty == false {
          found = true
          stop = true
        }
      }
      return found
    }

    func updateEligibility(_ eligible: Bool, isBusy: Bool = false) {
      componentAllowsInteraction = eligible
      componentIsBusy = isBusy
      if allowsHighlight == false {
        setHighlighted?(false)
      }
      accessibilityStateDidChange?()
    }

    func updateHostEligibility(_ eligible: Bool) {
      hostAllowsInteraction = eligible
      if allowsHighlight == false {
        setHighlighted?(false)
      }
      accessibilityStateDidChange?()
    }

    func updateAtomicHandlers(
      activation: @escaping () -> Bool,
      longPress: @escaping () -> Bool
    ) {
      atomicActivation = activation
      atomicLongPressActivation = longPress
      accessibilityStateDidChange?()
    }

    func performAtomicActivation() -> Bool { atomicActivation?() ?? false }
    func performAtomicLongPressActivation() -> Bool { atomicLongPressActivation?() ?? false }

    func touchDidBegin() {
      guard isInteractionMounted, allowsHighlight, ownsPhysicalTrackingCycle == false else {
        return
      }
      ownsPhysicalTrackingCycle = true
      setHighlighted?(true)
      sendActions(for: .touchDown)
    }

    func touchDidEnd() {
      setHighlighted?(false)
    }

    func cancelPhysicalTracking() {
      guard ownsPhysicalTrackingCycle else {
        return
      }
      ownsPhysicalTrackingCycle = false
      progressHandle = nil
      setHighlighted?(false)
      if isInteractionMounted {
        sendActions(for: .touchCancel)
      }
    }

    func prepareProgressHandle(_ handle: AwesomeButtonProgressHandle) {
      progressHandle = handle
    }

    func dispatchAcceptedActivation(physical: Bool) -> AwesomeButtonNativeDispatchResult {
      guard control != nil, isInteractionMounted else {
        teardown()
        return .unmounted
      }
      guard hostAllowsInteraction else {
        return .mountedIneligible
      }

      if physical {
        ownsPhysicalTrackingCycle = false
        sendActions(for: .touchUpInside)
        guard isInteractionMounted else {
          teardown()
          return .unmounted
        }
        guard hostAllowsInteraction else {
          return .mountedIneligible
        }
      }

      sendActions(for: .primaryActionTriggered)
      guard isInteractionMounted else {
        teardown()
        return .unmounted
      }
      guard hostAllowsInteraction else {
        return .mountedIneligible
      }
      return .dispatched
    }

    func completeProgress(_ completion: (() -> Void)?) {
      let handle = progressHandle
      progressHandle = nil
      handle?(completion)
    }

    func progressDidEnd() {
      progressHandle = nil
      invalidateIntrinsicSize?()
    }

    func measuredWidthDidChange(_ width: CGFloat) {
      measuredAutoWidth = width
      invalidateIntrinsicSize?()
    }

    func teardown() {
      ownsPhysicalTrackingCycle = false
      progressHandle = nil
      componentAllowsInteraction = false
      componentIsBusy = false
      atomicActivation = nil
      atomicLongPressActivation = nil
      setHighlighted?(false)
      accessibilityStateDidChange?()
    }

    private func sendActions(for events: UIControl.Event) {
      guard let control else {
        return
      }
      if let eventDispatcher {
        eventDispatcher(control, events)
      } else {
        control.sendActions(for: events)
      }
    }
  }

  internal struct AwesomeButtonNativeControlContext {
    let bridge: AwesomeButtonNativeControlBridge
    let externallyHighlighted: Bool
  }

  private struct AwesomeButtonNativeControlContextKey: EnvironmentKey {
    static let defaultValue: AwesomeButtonNativeControlContext? = nil
  }

  extension EnvironmentValues {
    var awesomeButtonNativeControlContext: AwesomeButtonNativeControlContext? {
      get { self[AwesomeButtonNativeControlContextKey.self] }
      set { self[AwesomeButtonNativeControlContextKey.self] = newValue }
    }
  }
#endif
