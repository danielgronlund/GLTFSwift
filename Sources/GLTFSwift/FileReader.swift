import Foundation

struct FileReader {
  enum Error: LocalizedError {
    case fileNotFound(String)
    case emptyFilename

    var errorDescription: String? {
      switch self {
      case .fileNotFound(let filename):
        "File not found \(filename)"
      case .emptyFilename:
        "Filename is nil"
      }
    }
  }

  static func readFile(_ filename: String?, in bundle: Bundle = .main) throws -> Data {
    guard let filename else {
      throw Error.emptyFilename
    }

    guard let path = bundle.path(forResource: filename, ofType: nil) else {
      throw Error.fileNotFound(filename)
    }

    let url = URL(fileURLWithPath: path)
    return try Data(contentsOf: url)
  }
}
