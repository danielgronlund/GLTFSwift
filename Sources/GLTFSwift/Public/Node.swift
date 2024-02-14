import Foundation
import Metal
import simd

open class Node {
  public var vertexBuffer: MTLBuffer
  public var indexBuffer: MTLBuffer

  public let children: [Node]?
  public let name: String?
  public let indexCount: Int

  open var position: simd_float3
  open var scale: simd_float3
  open var rotation: simd_quatf

  public let boundingBox: (min: simd_float3, max: simd_float3)?

  init(
    children: [Node]?,
    vertexBuffer: MTLBuffer,
    indexBuffer: MTLBuffer,
    name: String?,
    position: simd_float3,
    scale: simd_float3,
    rotation: simd_quatf,
    indexCount: Int,
    boundingBox: (min: simd_float3, max: simd_float3)?
  ) {

    self.children = children
    self.name = name
    self.vertexBuffer = vertexBuffer
    self.indexBuffer = indexBuffer
    self.position = position
    self.scale = scale
    self.rotation = rotation
    self.indexCount = indexCount
    self.boundingBox = boundingBox
  }

  public subscript(_ name: String) -> Node? {
    children?.first(where: {
      $0.name == name
    })
  }
}
