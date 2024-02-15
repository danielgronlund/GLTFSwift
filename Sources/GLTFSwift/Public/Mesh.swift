import Foundation
import Metal
import simd

open class Mesh {
  public var vertexBuffer: MTLBuffer
  public var indexBuffer: MTLBuffer
  public let indexCount: Int
  public let boundingBox: (min: simd_float3, max: simd_float3)?

  init(
    vertexBuffer: MTLBuffer,
    indexBuffer: MTLBuffer,
    indexCount: Int,
    boundingBox: (min: simd_float3, max: simd_float3)?
  ) {

    self.vertexBuffer = vertexBuffer
    self.indexBuffer = indexBuffer
    self.indexCount = indexCount
    self.boundingBox = boundingBox
  }
}
