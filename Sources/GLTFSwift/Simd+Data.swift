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
