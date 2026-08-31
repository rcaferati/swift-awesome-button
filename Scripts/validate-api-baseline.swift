import Foundation

enum BaselineValidationError: Error, CustomStringConvertible {
  case usage
  case missing(String)
  case empty(String)
  case malformed(String)
  case wrongModule(String)
  case nonCanonicalArguments

  var description: String {
    switch self {
    case .usage:
      return "usage: swift Scripts/validate-api-baseline.swift <baseline-path>"
    case .missing(let path):
      return "API baseline is missing: \(path)"
    case .empty(let path):
      return "API baseline is empty: \(path)"
    case .malformed(let reason):
      return "API baseline is not valid JSON: \(reason)"
    case .wrongModule(let module):
      return "API baseline root module must be SwiftAwesomeButton, found: \(module)"
    case .nonCanonicalArguments:
      return "API baseline contains machine-specific ABIRoot.tool_arguments"
    }
  }
}

func validate() throws {
  guard CommandLine.arguments.count == 2 else {
    throw BaselineValidationError.usage
  }

  let path = CommandLine.arguments[1]
  guard FileManager.default.fileExists(atPath: path) else {
    throw BaselineValidationError.missing(path)
  }

  let data = try Data(contentsOf: URL(fileURLWithPath: path))
  guard data.isEmpty == false else {
    throw BaselineValidationError.empty(path)
  }

  let object: Any
  do {
    object = try JSONSerialization.jsonObject(with: data)
  } catch {
    throw BaselineValidationError.malformed(error.localizedDescription)
  }

  guard
    let root = object as? [String: Any],
    let abiRoot = root["ABIRoot"] as? [String: Any],
    let module = abiRoot["name"] as? String
  else {
    throw BaselineValidationError.malformed("missing ABIRoot.name")
  }

  guard module == "SwiftAwesomeButton" else {
    throw BaselineValidationError.wrongModule(module)
  }

  guard let toolArguments = abiRoot["tool_arguments"] as? [Any], toolArguments.isEmpty else {
    throw BaselineValidationError.nonCanonicalArguments
  }

  print("Validated \(data.count)-byte SwiftAwesomeButton API baseline at \(path)")
}

do {
  try validate()
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8))
  exit(1)
}
