import CMeshopt
import Foundation

public enum GLTFLoadingError: Error, Equatable, LocalizedError {
  case invalidData(String)
  case unsupportedExtension(String)
  case unsupportedFeature(String)
  case meshoptDecodingFailed(Int32)

  public var errorDescription: String? {
    switch self {
    case .invalidData(let message): return "Invalid glTF data: \(message)"
    case .unsupportedExtension(let name): return "Unsupported required glTF extension: \(name)"
    case .unsupportedFeature(let name): return "Unsupported glTF feature: \(name)"
    case .meshoptDecodingFailed(let code): return "Meshopt decoding failed (\(code))."
    }
  }
}

/// One reader per load. All accessors share cached files and decoded bufferViews.
/// Used serially while the asset is constructed; no mutable global decode state.
final class AccessorReader {
  let container: GLTFContainer
  let fileURL: URL
  private var buffers: [Int: Data] = [:]
  private var views: [Int: Data] = [:]

  init(container: GLTFContainer, fileURL: URL) throws {
    self.container = container
    self.fileURL = fileURL
    let supported: Set<String> = [
      "EXT_meshopt_compression", "KHR_mesh_quantization", "KHR_draco_mesh_compression",
    ]
    for name in container.extensionsRequired ?? [] where !supported.contains(name) {
      throw GLTFLoadingError.unsupportedExtension(name)
    }
  }

  func accessor(_ index: Int) throws -> GLTFAccessor {
    guard container.accessors.indices.contains(index) else {
      throw invalid("Accessor index \(index) is out of range.")
    }
    return container.accessors[index]
  }

  func buffer(_ index: Int) throws -> Data {
    if let cached = buffers[index] { return cached }
    guard container.buffers.indices.contains(index) else {
      throw invalid("Buffer index is out of range.")
    }
    let descriptor = container.buffers[index]
    guard descriptor.byteLength >= 0 else { throw invalid("Negative buffer length.") }
    guard let uri = descriptor.uri else {
      throw GLTFLoadingError.unsupportedFeature(
        "Embedded/placeholder buffer requested without decoded Meshopt data; GLB is not supported.")
    }
    let data: Data
    if uri.hasPrefix("data:") {
      guard let comma = uri.firstIndex(of: ","), uri[..<comma].hasSuffix(";base64"),
        let decoded = Data(base64Encoded: String(uri[uri.index(after: comma)...]))
      else {
        throw invalid("Invalid or unsupported buffer data URI.")
      }
      data = decoded
    } else {
      guard let url = URL(string: uri, relativeTo: fileURL.deletingLastPathComponent()),
        url.isFileURL
      else {
        throw invalid("Buffer URI must reference a local file or base64 data URI.")
      }
      data = try Data(contentsOf: url)
    }
    guard data.count >= descriptor.byteLength else {
      throw invalid("Buffer is shorter than its declared length.")
    }
    let declaredData = data.prefix(descriptor.byteLength)
    buffers[index] = Data(declaredData)
    return Data(declaredData)
  }

  func view(_ index: Int) throws -> Data {
    if let cached = views[index] { return cached }
    guard container.bufferViews.indices.contains(index) else {
      throw invalid("BufferView index is out of range.")
    }
    let descriptor = container.bufferViews[index]
    let result: Data
    if let compression = descriptor.extensions?.meshopt {
      let size = try product(compression.count, compression.byteStride)
      guard compression.count > 0, compression.byteStride > 0, size == descriptor.byteLength,
        descriptor.byteStride == nil || descriptor.byteStride == compression.byteStride
      else {
        throw invalid("Meshopt count/stride does not match the bufferView.")
      }
      let modes: [String: Int32] = ["ATTRIBUTES": 0, "TRIANGLES": 1, "INDICES": 2]
      let filters: [String: Int32] = [
        "NONE": 0, "OCTAHEDRAL": 1, "QUATERNION": 2, "EXPONENTIAL": 3,
      ]
      guard let mode = modes[compression.mode], let filter = filters[compression.filter ?? "NONE"]
      else {
        throw invalid("Unknown Meshopt mode or filter.")
      }
      guard compression.byteLength > 0 else { throw invalid("Empty Meshopt payload.") }
      let source = try slice(
        buffer(compression.buffer), offset: compression.byteOffset ?? 0,
        length: compression.byteLength)
      // Validate descriptors before allocating or entering the decoder's assertion-based C API.
      if mode == 0 {
        guard compression.byteStride <= 256, compression.byteStride % 4 == 0,
          filter != 1 || [4, 8].contains(compression.byteStride),
          filter != 2 || compression.byteStride == 8
        else { throw invalid("Invalid Meshopt attribute filter/stride.") }
      } else {
        guard [2, 4].contains(compression.byteStride), filter == 0,
          mode != 1 || compression.count % 3 == 0
        else { throw invalid("Invalid Meshopt index mode/stride.") }
      }
      var decoded = Data(count: size)
      let status = decoded.withUnsafeMutableBytes { destination in
        source.withUnsafeBytes { input in
          gltf_meshopt_decode(
            destination.baseAddress!, size, input.bindMemory(to: UInt8.self).baseAddress!,
            source.count, compression.count, compression.byteStride, mode, filter)
        }
      }
      guard status == 0 else { throw GLTFLoadingError.meshoptDecodingFailed(status) }
      result = decoded
    } else {
      result = try slice(
        buffer(descriptor.buffer), offset: descriptor.byteOffset ?? 0, length: descriptor.byteLength
      )
    }
    views[index] = result
    return result
  }

  func floats(_ index: Int, expectedType: DataType? = nil) throws -> [Float] {
    let accessor = try accessor(index)
    if let expectedType, accessor.type != expectedType {
      throw invalid("Unexpected accessor type.")
    }
    let (data, offset, stride, componentOffsets) = try layout(index)
    var result: [Float] = []
    result.reserveCapacity(try product(accessor.count, componentOffsets.count))
    try data.withUnsafeBytes { bytes in
      for element in 0..<accessor.count {
        for component in componentOffsets {
          let position = offset + element * stride + component
          let value: Float
          switch accessor.componentType {
          case .byte:
            let x = bytes.loadUnaligned(fromByteOffset: position, as: Int8.self)
            value = accessor.normalized == true ? max(Float(x) / 127, -1) : Float(x)
          case .unsignedByte:
            let x = bytes.loadUnaligned(fromByteOffset: position, as: UInt8.self)
            value = accessor.normalized == true ? Float(x) / 255 : Float(x)
          case .short:
            let x = Int16(
              littleEndian: bytes.loadUnaligned(fromByteOffset: position, as: Int16.self))
            value = accessor.normalized == true ? max(Float(x) / 32767, -1) : Float(x)
          case .unsignedShort:
            let x = UInt16(
              littleEndian: bytes.loadUnaligned(fromByteOffset: position, as: UInt16.self))
            value = accessor.normalized == true ? Float(x) / 65535 : Float(x)
          case .unsignedInt:
            let x = UInt32(
              littleEndian: bytes.loadUnaligned(fromByteOffset: position, as: UInt32.self))
            guard accessor.normalized != true else {
              throw invalid("UNSIGNED_INT cannot be normalized.")
            }
            value = Float(x)
          case .float:
            guard accessor.normalized != true else { throw invalid("FLOAT cannot be normalized.") }
            value = Float(
              bitPattern: UInt32(
                littleEndian: bytes.loadUnaligned(fromByteOffset: position, as: UInt32.self)))
          }
          guard value.isFinite else { throw invalid("Accessor contains a non-finite value.") }
          result.append(value)
        }
      }
    }
    return result
  }

  func indices(_ index: Int) throws -> [UInt32] {
    let accessor = try accessor(index)
    guard accessor.type == .scalar, accessor.normalized != true,
      [.unsignedByte, .unsignedShort, .unsignedInt].contains(accessor.componentType)
    else { throw invalid("Invalid index accessor.") }
    let (data, offset, stride, _) = try layout(index)
    return data.withUnsafeBytes { bytes in
      (0..<accessor.count).map { i in
        let position = offset + i * stride
        switch accessor.componentType {
        case .unsignedByte:
          return UInt32(bytes.loadUnaligned(fromByteOffset: position, as: UInt8.self))
        case .unsignedShort:
          return UInt32(
            UInt16(littleEndian: bytes.loadUnaligned(fromByteOffset: position, as: UInt16.self)))
        default:
          return UInt32(
            littleEndian: bytes.loadUnaligned(fromByteOffset: position, as: UInt32.self))
        }
      }
    }
  }

  private func layout(_ index: Int) throws -> (Data, Int, Int, [Int]) {
    let accessor = try accessor(index)
    guard accessor.count >= 0 else { throw invalid("Negative accessor count.") }
    guard accessor.sparse == nil else {
      throw GLTFLoadingError.unsupportedFeature("Sparse accessors")
    }
    guard let viewIndex = accessor.bufferView, container.bufferViews.indices.contains(viewIndex)
    else {
      throw invalid("Accessor has no valid bufferView.")
    }
    let descriptor = container.bufferViews[viewIndex]
    let size = accessor.componentType.size
    let rows: Int
    let columns: Int
    switch accessor.type {
    case .mat2:
      rows = 2
      columns = 2
    case .mat3:
      rows = 3
      columns = 3
    case .mat4:
      rows = 4
      columns = 4
    default:
      rows = accessor.type.numberOfComponents
      columns = 1
    }
    let columnSize = columns == 1 ? rows * size : (rows * size + 3) / 4 * 4
    let elementSize = columnSize * columns
    let offsets = (0..<columns).flatMap { column in
      (0..<rows).map { column * columnSize + $0 * size }
    }
    let stride = descriptor.byteStride ?? descriptor.extensions?.meshopt?.byteStride ?? elementSize
    let offset = accessor.byteOffset ?? 0
    guard stride >= elementSize, stride % size == 0, offset >= 0, offset % size == 0 else {
      throw invalid("Invalid accessor offset or stride.")
    }
    let data = try view(viewIndex)
    let end = try sum(
      offset, accessor.count == 0 ? 0 : sum(product(accessor.count - 1, stride), elementSize))
    guard end <= data.count else { throw invalid("Accessor extends beyond its bufferView.") }
    return (data, offset, stride, offsets)
  }

  private func slice(_ data: Data, offset: Int, length: Int) throws -> Data {
    guard offset >= 0, length >= 0, try sum(offset, length) <= data.count else {
      throw invalid("Buffer range is out of bounds.")
    }
    return data.subdata(in: offset..<(offset + length))
  }
  private func product(_ a: Int, _ b: Int) throws -> Int {
    let (value, overflow) = a.multipliedReportingOverflow(by: b)
    guard a >= 0, b >= 0, !overflow else { throw invalid("Invalid or overflowing data size.") }
    return value
  }
  private func sum(_ a: Int, _ b: Int) throws -> Int {
    let (value, overflow) = a.addingReportingOverflow(b)
    guard a >= 0, b >= 0, !overflow else { throw invalid("Invalid or overflowing data range.") }
    return value
  }
  private func invalid(_ message: String) -> GLTFLoadingError { .invalidData(message) }
}
