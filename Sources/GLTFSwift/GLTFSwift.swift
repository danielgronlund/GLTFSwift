import Foundation
import simd

// MARK: - GLTF
struct GLTFContainer: Decodable {
  let scenes: [GLTFScene]
  let nodes: [GLTFNode]
  let meshes: [GLTFMesh]
  let skins: [GLTFSkin]?
  let asset: GLTFAsset
  let buffers: [GLTFBuffer]
  let bufferViews: [GLTFBufferView]
  let accessors: [GLTFAccessor]
}

// MARK: - Asset
struct GLTFAsset: Decodable {
  let version: String
  let generator: String?
}

// MARK: - Scene
struct GLTFScene: Decodable {
  let nodes: [Int]?
  let name: String?
}

// MARK: - Node
struct GLTFNode: Decodable {
  let mesh: Int?
  let skin: Int?
  let children: [Int]?
  let name: String?
  let translation: simd_float3
  let rotation: simd_quatf
  let scale: simd_float3

  enum CodingKeys: String, CodingKey {
    case mesh, skin, children, name, translation, rotation, scale, matrix
  }

  init(from decoder: Decoder) throws {
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

// MARK: - Primitive
struct GLTFPrimitive: Decodable {
  let indices: Int?
  let attributes: GLTFAttributes
}

// MARK: - Attributes
struct GLTFAttributes: Decodable {
  let POSITION: Int?
  let NORMAL: Int?
  let TANGENT: Int?
  let TEXCOORD_0: Int?
  let TEXCOORD_1: Int?
  let COLOR_0: Int?
  let JOINTS_0: Int?
  let WEIGHTS_0: Int?
}

// MARK: - Skin
struct GLTFSkin: Decodable {
  let inverseBindMatrices: Int?
  let skeleton: Int?
  let joints: [Int]
  let name: String?
}

struct GLTFAccessor: Decodable {
  let bufferView: Int
  let componentType: ComponentType
  let normalized: Bool?
  let count: Int
  let type: DataType
  let max: [Float]?
  let min: [Float]?
  let byteOffset: Int?
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
  let target: BufferViewType?
}

enum BufferViewType: Int, Decodable {
  case unknown = 0
  case vertex = 34962
  case index = 34963
}
