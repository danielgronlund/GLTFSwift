import Foundation
import simd

public struct Primitive {
  public let indices: [UInt32]
  public let vertices: [Vertex]
  public let boundingBox: (min: simd_float3, max: simd_float3)?
}

public struct Mesh {
  public let primitives: [Primitive]
}

public struct Skin {
  public let inverseBindMatrices: [simd_float4x4]
  public let joints: [Int]
}

public class GLTFAsset {
  public let scenes: [GLTFScene]
  public let nodes: [GLTFNode]
  public let meshes: [Mesh]

  public let skins: [Skin]?
  let accessors: [GLTFAccessor]

  init(scenes: [GLTFScene], nodes: [GLTFNode], meshes: [Mesh], skins: [Skin]?, accessors: [GLTFAccessor]) {
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
