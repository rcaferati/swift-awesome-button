import Foundation

struct SymbolGraph: Decodable {
  let module: Module
  let symbols: [Symbol]

  struct Module: Decodable {
    let name: String
  }

  struct Symbol: Decodable {
    let identifier: Identifier
    let kind: Kind
    let pathComponents: [String]
    let accessLevel: String
    let location: Location?
    let docComment: DocComment?
  }

  struct Identifier: Decodable {
    let precise: String
  }

  struct Kind: Decodable {
    let identifier: String
  }

  struct Location: Decodable {
    let uri: String
    let position: Position
  }

  struct Position: Decodable {
    let line: Int
  }

  struct DocComment: Decodable {
    let lines: [Line]
  }

  struct Line: Decodable {
    let text: String
  }
}

enum DocumentationCheckError: Error, CustomStringConvertible {
  case usage
  case noGraph(String)
  case wrongModule(String)
  case invalidExemptions(String)
  case undocumented([String])
  case staleExemptions([String])

  var description: String {
    switch self {
    case .usage:
      return "usage: swift Scripts/check-public-documentation.swift --derived-data <path>"
    case .noGraph(let root):
      return "No arm64 SwiftAwesomeButton.symbols.json was found under \(root)"
    case .wrongModule(let module):
      return "Expected SwiftAwesomeButton symbol graph, found \(module)"
    case .invalidExemptions(let reason):
      return "Invalid DocumentationExemptions.json: \(reason)"
    case .undocumented(let symbols):
      return "Undocumented public symbols:\n" + symbols.joined(separator: "\n")
    case .staleExemptions(let identifiers):
      return "Documentation exemptions do not match an otherwise-undocumented symbol:\n"
        + identifiers.joined(separator: "\n")
    }
  }
}

func parseDerivedDataPath() throws -> String {
  guard CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--derived-data" else {
    throw DocumentationCheckError.usage
  }
  return CommandLine.arguments[2]
}

func findSymbolGraph(under root: String) throws -> URL {
  guard let enumerator = FileManager.default.enumerator(atPath: root) else {
    throw DocumentationCheckError.noGraph(root)
  }

  let matches = enumerator.compactMap { value -> String? in
    guard let path = value as? String,
      path.hasSuffix("/arm64-apple-ios-simulator/SwiftAwesomeButton.symbols.json")
    else { return nil }
    return path
  }.sorted()

  guard let relativePath = matches.first else {
    throw DocumentationCheckError.noGraph(root)
  }
  return URL(fileURLWithPath: root).appendingPathComponent(relativePath)
}

func loadExemptions(repositoryRoot: URL) throws -> [String: String] {
  let url = repositoryRoot.appendingPathComponent("DocumentationExemptions.json")
  guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
  let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
  guard let exemptions = object as? [String: String] else {
    throw DocumentationCheckError.invalidExemptions(
      "expected an object of precise IDs to rationales")
  }
  for (identifier, rationale) in exemptions {
    if identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      throw DocumentationCheckError.invalidExemptions(
        "every precise ID and rationale must be non-empty")
    }
  }
  return exemptions
}

func check() throws {
  let derivedData = try parseDerivedDataPath()
  let graphURL = try findSymbolGraph(under: derivedData)
  let graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: graphURL))
  guard graph.module.name == "SwiftAwesomeButton" else {
    throw DocumentationCheckError.wrongModule(graph.module.name)
  }

  let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  let exemptions = try loadExemptions(repositoryRoot: repositoryRoot)
  var usedExemptions = Set<String>()
  var failures: [String] = []
  var checkedCount = 0

  for symbol in graph.symbols {
    guard symbol.accessLevel == "public",
      let location = symbol.location,
      location.uri.contains("/Sources/SwiftAwesomeButton/"),
      symbol.identifier.precise.contains("::SYNTHESIZED::") == false
    else { continue }

    checkedCount += 1
    let summary =
      symbol.docComment?.lines.map(\.text).joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard summary.isEmpty else { continue }

    if exemptions[symbol.identifier.precise] != nil {
      usedExemptions.insert(symbol.identifier.precise)
      continue
    }

    let path = symbol.pathComponents.joined(separator: ".")
    failures.append(
      "- \(symbol.identifier.precise) [\(symbol.kind.identifier)] \(path) at \(location.uri):\(location.position.line + 1)"
    )
  }

  if failures.isEmpty == false {
    throw DocumentationCheckError.undocumented(failures.sorted())
  }

  let stale = Set(exemptions.keys).subtracting(usedExemptions).sorted()
  if stale.isEmpty == false {
    throw DocumentationCheckError.staleExemptions(stale)
  }

  print("Validated documentation summaries for \(checkedCount) user-authored public symbols.")
}

do {
  try check()
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8))
  exit(1)
}
