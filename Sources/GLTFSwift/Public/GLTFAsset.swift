import Foundation
import simd

public struct PublicPrimitive {
  public let indexBuffer: [UInt32]
  public let vertexBuffer: [Vertex]
  public let boundingBox: (min: simd_float3, max: simd_float3)?
}

public struct PublicMesh {
  public let primitives: [PublicPrimitive]
}

public struct PublicSkin {
  public let inverseBindMatrices: [simd_float4x4]
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

public func load(_ filename: String, in bundle: Bundle = .main) throws -> GLTFAsset {
  let loader = GLTFLoader()
  return try loader.loadContainer(path: filename, in: bundle)
}
