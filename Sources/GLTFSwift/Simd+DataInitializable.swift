import Foundation
import simd

struct Vec3 {
  let x: Float
  let y: Float
  let z: Float
}

extension simd_float4: DataInitializable {}
extension simd_float3: DataInitializable {
  init?(fromBinaryData data: Data, byteOffset: Int) {
    guard byteOffset + MemoryLayout<Vec3>.size <= data.count else { return nil }
    let intermediate = data.withUnsafeBytes { $0.load(fromByteOffset: byteOffset, as: Vec3.self) }
    self = .init(intermediate.x, intermediate.y, intermediate.z)
  }
}

extension Vec3: DataInitializable {
  var float3: simd_float3 {
    simd_float3(x,y,z)
  }
}

extension Float: DataInitializable {
    init?(fromBinaryData data: Data, byteOffset: Int) {
        guard byteOffset + MemoryLayout<Float>.size <= data.count else { return nil }
        self = data.withUnsafeBytes { $0.load(fromByteOffset: byteOffset, as: Float.self) }
    }
}
