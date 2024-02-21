import simd
import Foundation

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
  static func from(data: Data) throws -> [simd_float4] {
    let componentSize = MemoryLayout<Float>.size
    let strideBy = componentSize * 4

    var result: [simd_float4] = []

    data.withUnsafeBytes { rawPointer in
      for offset in stride(from: 0, to: data.count, by: strideBy) {
        let floatPointer = rawPointer.baseAddress!.assumingMemoryBound(to: Float.self)
        let vec = simd_float4(
          floatPointer[offset / componentSize],
          floatPointer[offset / componentSize + 1],
          floatPointer[offset / componentSize + 2],
          floatPointer[offset / componentSize + 3]
        )
        result.append(vec)
      }
    }

    return result
  }
}

extension [simd_char4] {
  static func from(data: Data) throws -> [simd_char4] {
    guard data.count % MemoryLayout<simd_char4>.size == 0 else {
      throw NSError(domain: "InvalidDataError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Data size is not aligned with simd_char4 size."])
    }

    return data.withUnsafeBytes { bufferPointer -> [simd_char4] in
      let count = data.count / MemoryLayout<simd_char4>.size
      return Array(UnsafeBufferPointer<simd_char4>(start: bufferPointer.baseAddress!.assumingMemoryBound(to: simd_char4.self), count: count))
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
