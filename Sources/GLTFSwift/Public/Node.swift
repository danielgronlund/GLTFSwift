import Foundation
import Metal
import simd

open class Node {
  public let children: [Node]?
  public let joints: [Joint]?
  public let name: String?
  public let mesh: Mesh?

  open var position: simd_float3
  open var scale: simd_float3
  open var rotation: simd_quatf

  init(
    children: [Node]?,
    joints: [Joint]?,
    mesh: Mesh?,
    name: String?,
    position: simd_float3,
    scale: simd_float3,
    rotation: simd_quatf
  ) {
    self.children = children
    self.joints = joints
    self.mesh = mesh
    self.name = name
    self.position = position
    self.scale = scale
    self.rotation = rotation
  }

  public subscript(_ name: String) -> Node? {
    children?.first(where: {
      $0.name == name
    })
  }
}
