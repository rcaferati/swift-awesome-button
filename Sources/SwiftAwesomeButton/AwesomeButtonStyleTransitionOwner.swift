import SwiftUI

internal enum AwesomeButtonStyleTransitionCommand {
  case prepare(generation: Int, sourceStyle: AwesomeButtonStyle)
  case animate(generation: Int, timing: AwesomeButtonAnimationTiming)
  case reset(generation: Int)

  var generation: Int {
    switch self {
    case .prepare(let generation, _), .animate(let generation, _), .reset(let generation):
      return generation
    }
  }
}

@MainActor
internal final class AwesomeButtonStyleTransitionOwner {
  private weak var sink: AwesomeButtonControllerCommandSink?
  private var kickoffWorkItem: DispatchWorkItem?
  private(set) var generation = 0

  init(sink: AwesomeButtonControllerCommandSink) {
    self.sink = sink
  }

  func connect(to sink: AwesomeButtonControllerCommandSink) {
    self.sink = sink
  }

  func start(
    from sourceStyle: AwesomeButtonStyle,
    to targetStyle: AwesomeButtonStyle,
    timing: AwesomeButtonAnimationTiming
  ) {
    kickoffWorkItem?.cancel()
    generation += 1
    let generation = generation
    guard
      sink?.receive(
        .prepare(generation: generation, sourceStyle: resolvedVisualStyle(sourceStyle))
      ) == .accepted
    else { return }

    let workItem = DispatchWorkItem { [weak self, weak sink] in
      guard let self, self.generation == generation else { return }
      _ = sink?.receive(.animate(generation: generation, timing: timing))
    }
    kickoffWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  func reset() {
    kickoffWorkItem?.cancel()
    kickoffWorkItem = nil
    generation += 1
    _ = sink?.receive(.reset(generation: generation))
  }

  func isCurrent(_ generation: Int) -> Bool {
    self.generation == generation
  }

  func cleanup() {
    generation += 1
    kickoffWorkItem?.cancel()
    kickoffWorkItem = nil
    sink = nil
  }
}
