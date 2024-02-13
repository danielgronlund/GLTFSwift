import Foundation

protocol DataInitializable {
  init?(fromBinaryData data: Data, byteOffset: Int)
}

extension DataInitializable {
  init?(fromBinaryData data: Data, byteOffset: Int) {
    guard byteOffset + MemoryLayout<Self>.size <= data.count else { return nil }
    self = data.withUnsafeBytes { $0.load(fromByteOffset: byteOffset, as: Self.self) }
  }
}
