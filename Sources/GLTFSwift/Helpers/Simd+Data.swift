import simd
import Foundation

public enum LoadingError: LocalizedError {
  case unsupportedComponentType(ComponentType)

  public var errorDescription: String? {
    switch self {
    case .unsupportedComponentType(let componentType):
      "Unsupported component type \(componentType)"
    }
  }
}

extension [simd_float3] {
  static func from(data: Data) throws -> [simd_float3] {
    let componentSize = MemoryLayout<Float>.size
    let strideBy = 3 * componentSize
    var result: [simd_float3] = []

    data.withUnsafeBytes { rawPointer in
      for offset in stride(from: 0, to: data.count, by: strideBy) {
        let floatPointer = rawPointer.baseAddress!.assumingMemoryBound(to: Float.self)
        let vec = simd_float3(
          floatPointer[offset / componentSize],
          floatPointer[offset / componentSize + 1],
          floatPointer[offset / componentSize + 2]
        )
        result.append(vec)
      }
    }

    return result
  }
}

extension [simd_float4] {
  static func from(data: Data, componentType: ComponentType, normalize: Bool) throws -> [simd_float4] {
    let actualStride = componentType.size * 4
    var result: [simd_float4] = []

    try data.withUnsafeBytes { rawPointer in
      for offset in stride(from: 0, to: data.count, by: actualStride) {
        let baseAddress = rawPointer.baseAddress!.advanced(by: offset)

        let vec: simd_float4 = try {
          switch componentType {
          case .float:
            return baseAddress.assumingMemoryBound(to: Float.self).withMemoryRebound(to: simd_float4.self, capacity: 1) { $0.pointee }
          case .unsignedByte:
            let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
            return simd_float4(
              Float(bytes[0]),
              Float(bytes[1]),
              Float(bytes[2]),
              Float(bytes[3])
            ) * (normalize ? 1.0 / 255.0 : 1.0)
          case .unsignedShort:
            let shorts = baseAddress.assumingMemoryBound(to: UInt16.self)
            return simd_float4(
              Float(shorts[0]),
              Float(shorts[1]),
              Float(shorts[2]),
              Float(shorts[3])
            ) * (normalize ? 1.0 / 65535.0 : 1.0)
          default:
            throw LoadingError.unsupportedComponentType(componentType)
          }
        }()

        result.append(vec)
      }
    }

    return result
  }
}

extension [simd_uchar4] {
  static func from(data: Data) throws -> [simd_uchar4] {
    guard data.count % MemoryLayout<simd_uchar4>.size == 0 else {
      throw NSError(domain: "InvalidDataError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Data size is not aligned with simd_uchar4 size."])
    }

    return data.withUnsafeBytes { bufferPointer -> [simd_uchar4] in
      let count = data.count / MemoryLayout<simd_uchar4>.size
      return Array(UnsafeBufferPointer<simd_uchar4>(start: bufferPointer.baseAddress!.assumingMemoryBound(to: simd_uchar4.self), count: count))
    }
  }
}

extension [simd_short4] {
  static func from(data: Data) throws -> [simd_short4] {
    guard data.count % MemoryLayout<simd_short4>.size == 0 else {
      throw NSError(domain: "InvalidDataError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Data size is not aligned with simd_short4 size."])
    }

    return data.withUnsafeBytes { bufferPointer -> [simd_short4] in
      let count = data.count / MemoryLayout<simd_short4>.size
      return Array(UnsafeBufferPointer<simd_short4>(start: bufferPointer.baseAddress!.assumingMemoryBound(to: simd_short4.self), count: count))
    }
  }
}

extension [simd_float4x4] {
  static func from(data: Data) throws -> [simd_float4x4] {
    guard data.count % MemoryLayout<simd_float4x4>.stride == 0 else {
      throw NSError(domain: "com.yourdomain.error", code: 100, userInfo: [NSLocalizedDescriptionKey: "Data size is not a multiple of simd_float4x4 stride."])
    }

    return data.withUnsafeBytes { bufferPointer -> [simd_float4x4] in
      let elements = bufferPointer.bindMemory(to: simd_float4x4.self)
      return Array(elements)
    }
  }
}
