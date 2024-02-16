import Foundation
import Metal
import simd

public struct PublicPrimitive {
  public let indexBuffer: MTLBuffer
  public let vertexBuffer: MTLBuffer
  public let indexCount: Int
  public let boundingBox: (min: simd_float3, max: simd_float3)?
}

public struct PublicMesh {
  public let primitives: [PublicPrimitive]
}

public struct PublicSkin {
  public let inverseBindMatrixBuffer: MTLBuffer
  public let joints: [Int]
}

public class GLTFAsset {
  public let scenes: [GLTFScene]
  public let nodes: [GLTFNode]
  public let meshes: [PublicMesh]

  public let skins: [PublicSkin]?
  let accessors: [GLTFAccessor]

  init(scenes: [GLTFScene], nodes: [GLTFNode], meshes: [PublicMesh], skins: [PublicSkin]?, accessors: [GLTFAccessor]) {
    self.scenes = scenes
    self.nodes = nodes
    self.meshes = meshes
    self.skins = skins
    self.accessors = accessors
  }

  public subscript(_ name: String) -> GLTFNode? {
    nodes.first { node in
      node.name == name
    }
  }
}

public func load(_ filename: String, in bundle: Bundle = .main, device: MTLDevice) throws -> GLTFAsset {
  let loader = GLTFLoader(device: device)
  return try loader.loadContainer(path: filename, in: bundle)
}
