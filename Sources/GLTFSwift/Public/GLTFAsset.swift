import Foundation
import simd

public struct Texture {
  public let uri: String?
  public let mimeType: String?
  public let data: Data?
}

public struct Material {
  public let baseColor: simd_float4?
  public let baseColorTexture: Texture?
  public let metallicFactor: Float
  public let roughnessFactor: Float

  public init(
    baseColor: simd_float4,
    baseColorTexture: Texture? = nil,
    metallicFactor: Float,
    roughnessFactor: Float
  ) {

    self.baseColor = baseColor
    self.baseColorTexture = baseColorTexture
    self.metallicFactor = metallicFactor
    self.roughnessFactor = roughnessFactor
  }

  init(
    material: GLTFMaterial,
    in container: GLTFContainer,
    relativeTo filepath: URL
  ) {

    self.baseColor = material.baseColorFactor.map(simd_float4.init)
    self.baseColorTexture = Self.resolveBaseColorTexture(
      for: material,
      in: container,
      relativeTo: filepath
    )
    self.metallicFactor = material.metallicFactor ?? 1.0
    self.roughnessFactor = material.roughnessFactor ?? 1.0
  }

  private static func resolveBaseColorTexture(
    for material: GLTFMaterial,
    in container: GLTFContainer,
    relativeTo filepath: URL
  ) -> Texture? {

    guard
      let textureIndex = material.baseColorTexture?.index,
      let texture = container.textures?[safe: textureIndex],
      let imageSourceIndex = texture.source,
      let image = container.images?[safe: imageSourceIndex]
    else {
      return nil
    }

    let imageData: Data? = {
      guard let uri = image.uri else {
        return nil
      }

      let gltfDirectory = filepath.deletingLastPathComponent()
      let imageURL = gltfDirectory.appendingPathComponent(uri)
      return try? Data(contentsOf: imageURL)
    }()

    return Texture(uri: image.uri, mimeType: image.mimeType, data: imageData)
  }
}

public struct Primitive {
  public let indices: [UInt32]
  public let vertices: [Vertex]
  public let boundingBox: (min: simd_float3, max: simd_float3)?
  public let material: Material?
  /// Local-space deltas, in the same vertex order as `vertices`.
  public let morphTargets: [MorphTarget]

  public init(indices: [UInt32], vertices: [Vertex], boundingBox: (min: simd_float3, max: simd_float3)?,
              material: Material?, morphTargets: [MorphTarget] = []) {
    self.indices = indices
    self.vertices = vertices
    self.boundingBox = boundingBox
    self.material = material
    self.morphTargets = morphTargets
  }
}

public struct Mesh {
  public let primitives: [Primitive]
  /// Default morph weights. Node.weights overrides these when present.
  public let weights: [Float]

  public init(primitives: [Primitive], weights: [Float] = []) {
    self.primitives = primitives
    self.weights = weights
  }
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
  public let animations: [AnimationClip]
  let accessors: [GLTFAccessor]

  init(scenes: [GLTFScene], nodes: [GLTFNode], meshes: [Mesh], skins: [Skin]?, accessors: [GLTFAccessor], animations: [AnimationClip] = []) {
    self.scenes = scenes
    self.nodes = nodes
    self.meshes = meshes
    self.skins = skins
    self.accessors = accessors
    self.animations = animations
  }

  public subscript(_ name: String) -> GLTFNode? {
    nodes.first { node in
      node.name == name
    }
  }
}

public func load(_ filename: String, in bundle: Bundle = .main) throws -> GLTFAsset {
  guard let filepath = bundle.path(forResource: filename, ofType: nil) else {
    throw FileReader.Error.fileNotFound(filename)
  }
  return try load(from: URL(fileURLWithPath: filepath))
}

public func load(from filepath: URL) throws -> GLTFAsset {
  let loader = GLTFLoader()
  return try loader.loadContainer(from: filepath)
}
