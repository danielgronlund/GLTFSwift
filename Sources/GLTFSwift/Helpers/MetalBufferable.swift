import Metal
import Foundation

protocol MetalBufferable {}

extension Array where Element: MetalBufferable {
  func createMetalBuffer(device: MTLDevice) -> MTLBuffer? {
    let bufferSize = count * MemoryLayout<Self.Element>.stride
    guard let buffer = device.makeBuffer(length: bufferSize, options: .storageModeShared) else {
      print("Failed to create Metal buffer")
      return nil
    }

    buffer.contents().copyMemory(from: self, byteCount: bufferSize)
    return buffer
  }
}
