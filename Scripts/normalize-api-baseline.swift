import Foundation

enum BaselineNormalizationError: Error, CustomStringConvertible {
  case usage
  case malformed(String)

  var description: String {
    switch self {
    case .usage:
      return "usage: swift Scripts/normalize-api-baseline.swift <baseline-path>"
    case .malformed(let reason):
      return "Cannot normalize API baseline: \(reason)"
    }
  }
}

func normalize() throws {
  guard CommandLine.arguments.count == 2 else {
    throw BaselineNormalizationError.usage
  }

  let url = URL(fileURLWithPath: CommandLine.arguments[1])
  let data = try Data(contentsOf: url)
  guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    var abiRoot = root["ABIRoot"] as? [String: Any],
    abiRoot["tool_arguments"] is [Any]
  else {
    throw BaselineNormalizationError.malformed("missing ABIRoot.tool_arguments array")
  }

  // The compiler writes absolute DerivedData and output paths here. They are
  // invocation provenance, not exported API, and make an otherwise identical
  // immutable-tag baseline differ on every machine. Provenance is recorded in
  // a separate checked artifact.
  abiRoot["tool_arguments"] = []
  root["ABIRoot"] = abiRoot

  let normalized = try JSONSerialization.data(
    withJSONObject: root,
    options: [.prettyPrinted, .sortedKeys]
  )
  var output = normalized
  output.append(0x0A)
  try output.write(to: url, options: .atomic)
  print("Canonicalized non-semantic compiler invocation arguments in \(url.path).")
}

do {
  try normalize()
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8))
  exit(1)
}
