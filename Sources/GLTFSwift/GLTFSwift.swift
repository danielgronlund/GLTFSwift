import Foundation
import simd

// MARK: - GLTF
struct GLTFContainer: Decodable {
  let scenes: [GLTFScene]
  let nodes: [GLTFNode]
  let meshes: [GLTFMesh]
  let skins: [GLTFSkin]?
  let asset: GLTFAssetInfo
  let buffers: [GLTFBuffer]
  let bufferViews: [GLTFBufferView]
  let accessors: [GLTFAccessor]
  let materials: [GLTFMaterial]?
}

// MARK: - Asset Info
struct GLTFAssetInfo: Decodable {
  let version: String
  let generator: String?
}

// MARK: - Scene
public class GLTFScene: Decodable {
  public let nodes: [Int]?
  let name: String?
}

// MARK: - Node
public class GLTFNode: Decodable {
  public let mesh: Int?
  public let children: [Int]?
  public let translation: simd_float3
  public let rotation: simd_quatf
  public let scale: simd_float3

  public let skin: Int?
  public let name: String?

  enum CodingKeys: String, CodingKey {
    case mesh, skin, children, name, translation, rotation, scale, matrix
  }

  required public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Optional properties
    mesh = try container.decodeIfPresent(Int.self, forKey: .mesh)
    skin = try container.decodeIfPresent(Int.self, forKey: .skin)
    children = try container.decodeIfPresent([Int].self, forKey: .children)
    name = try container.decodeIfPresent(String.self, forKey: .name)

    let neutralRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    let translation = try container.decodeIfPresent([Float].self, forKey: .translation).flatMap(simd_float3.init)
    let rotation = try container.decodeIfPresent([Float].self, forKey: .rotation).flatMap { simd_quatf(vector: simd_float4($0) ) }
    let scale = try container.decodeIfPresent([Float].self, forKey: .scale).flatMap(simd_float3.init)

    let matrix = try container.decodeIfPresent([Float].self, forKey: .matrix)
    let decomposed = matrix.flatMap { decomposeMatrix($0) }

    self.translation = translation ?? decomposed?.translation ?? .zero
    self.rotation = rotation ?? decomposed?.rotation ?? neutralRotation
    self.scale = scale ?? decomposed?.scale ?? .one

    func decomposeMatrix(_ matrix: [Float]) -> (translation: simd_float3, rotation: simd_quatf, scale: simd_float3) {
      // Ensure the matrix array has 16 elements (4x4 matrix)
      guard matrix.count == 16 else {
        fatalError("Matrix must be a 4x4 transformation matrix.")
      }

      // Extract translation
      let translation = simd_float3(matrix[12], matrix[13], matrix[14])

      // Extract scale factors
      let scaleX = simd_length(simd_float3(matrix[0], matrix[1], matrix[2]))
      let scaleY = simd_length(simd_float3(matrix[4], matrix[5], matrix[6]))
      let scaleZ = simd_length(simd_float3(matrix[8], matrix[9], matrix[10]))
      let scale = simd_float3(scaleX, scaleY, scaleZ)

      // Remove scale from the rotation matrix
      var rotationMatrix = matrix
      rotationMatrix[0] /= scaleX
      rotationMatrix[1] /= scaleX
      rotationMatrix[2] /= scaleX
      rotationMatrix[4] /= scaleY
      rotationMatrix[5] /= scaleY
      rotationMatrix[6] /= scaleY
      rotationMatrix[8] /= scaleZ
      rotationMatrix[9] /= scaleZ
      rotationMatrix[10] /= scaleZ

      // Convert rotation matrix to quaternion
      let rotation = simd_quaternion(simd_float4x4(
        simd_float4(rotationMatrix[0], rotationMatrix[1], rotationMatrix[2], 0),
        simd_float4(rotationMatrix[4], rotationMatrix[5], rotationMatrix[6], 0),
        simd_float4(rotationMatrix[8], rotationMatrix[9], rotationMatrix[10], 0),
        simd_float4(0, 0, 0, 1)
      ))

      return (translation, rotation, scale)
    }
  }
}

// MARK: - Mesh
struct GLTFMesh: Decodable {
  let primitives: [GLTFPrimitive]
  let name: String?
}

// MARK: - Material
struct GLTFMaterial: Decodable {
  let baseColorFactor: [Float]?
  let metallicFactor: Float?
  let roughnessFactor: Float?

  enum CodingKeys: String, CodingKey {
    case pbrMetallicRoughness
  }

  enum PBRMetallicRoughnessKeys: String, CodingKey {
    case baseColorFactor
    case metallicFactor
    case roughnessFactor
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let pbrContainer = try? container.nestedContainer(keyedBy: PBRMetallicRoughnessKeys.self, forKey: .pbrMetallicRoughness) {
      self.baseColorFactor = try pbrContainer.decodeIfPresent([Float].self, forKey: .baseColorFactor)
      self.metallicFactor = try pbrContainer.decodeIfPresent(Float.self, forKey: .metallicFactor)
      self.roughnessFactor = try pbrContainer.decodeIfPresent(Float.self, forKey: .roughnessFactor)
    } else {
      self.baseColorFactor = nil
      self.metallicFactor = nil
      self.roughnessFactor = nil
    }
  }
}

struct DracoExtension: Decodable {
  let bufferView: Int
  let attributes: GLTFAttributes

  enum CodingKeys: CodingKey {
    case bufferView
    case attributes
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.bufferView = try container.decode(Int.self, forKey: .bufferView)
    self.attributes = try container.decode(GLTFAttributes.self, forKey: .attributes)
  }
}

// MARK: - Primitive
struct GLTFPrimitive: Decodable {
  let indices: Int?
  let attributes: GLTFAttributes
  let material: Int?
  let extensions: PrimitiveExtensions?
}

struct PrimitiveExtensions: Decodable {
  let dracoExtension: DracoExtension
  enum CodingKeys: String, CodingKey {
    case dracoExtension = "KHR_draco_mesh_compression"
  }
}

// MARK: - Attributes
enum GLTFAttribute {
  case position
  case normal
  case tangent
  case texCoord0
  case texCoord1
  case color0
  case joints0
  case weights0
}

struct GLTFAttributes: Decodable {
  let POSITION: Int?
  let NORMAL: Int?
  let TANGENT: Int?
  let TEXCOORD_0: Int?
  let TEXCOORD_1: Int?
  let COLOR_0: Int?
  let JOINTS_0: Int?
  let WEIGHTS_0: Int?

  func accessorIndex(for attribute: GLTFAttribute) -> Int? {
    switch attribute {
    case .position:
      self.POSITION
    case .normal:
      self.NORMAL
    case .tangent:
      self.TANGENT
    case .texCoord0:
      self.TEXCOORD_0
    case .texCoord1:
      self.TEXCOORD_1
    case .color0:
      self.COLOR_0
    case .joints0:
      self.JOINTS_0
    case .weights0:
      self.WEIGHTS_0
    }
  }
}

// MARK: - Skin
public struct GLTFSkin: Decodable {
  public let inverseBindMatrices: Int?
  public let joints: [Int]
  let name: String?

  enum CodingKeys: CodingKey {
    case inverseBindMatrices
    case skeleton
    case joints
    case name
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.inverseBindMatrices = try container.decodeIfPresent(Int.self, forKey: .inverseBindMatrices)
    self.joints = try container.decode([Int].self, forKey: .joints)
    self.name = try container.decodeIfPresent(String.self, forKey: .name)
  }
}

struct GLTFAccessor: Decodable {
  let bufferView: Int?
  let componentType: ComponentType
  let normalized: Bool?
  let count: Int
  let type: DataType
  let max: [Float]?
  let min: [Float]?
  let byteOffset: Int?

  var boundingBox: (min: simd_float3, max: simd_float3)? {
    guard
      type == .vec3,
      let min,
      min.count == 3,
      let max,
      max.count == 3
    else {
      return nil
    }
    return (
      simd_float3(min),
      simd_float3(max)
    )
  }
}

// MARK: - Buffer
struct GLTFBuffer: Decodable {
  let byteLength: Int
  let uri: String?
}

// MARK: - BufferView
struct GLTFBufferView: Decodable {
  let buffer: Int
  let byteOffset: Int
  let byteLength: Int
  let byteStride: Int?
  let target: BufferType?
}

enum BufferType: Int, Decodable {
  case unknown = 0
  case vertex = 34962
  case index = 34963
}
