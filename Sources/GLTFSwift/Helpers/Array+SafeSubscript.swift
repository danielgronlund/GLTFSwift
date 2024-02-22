import Foundation

extension Array {
  subscript(safe index: Index) -> Element? {
    guard indices.contains(index) else {
      return nil
    }
    return self[index]
  }
}
