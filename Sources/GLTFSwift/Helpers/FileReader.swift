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

  static func readFile(at filepath: URL) throws -> Data {
    let url = filepath
    return try Data(contentsOf: url)
  }
}
