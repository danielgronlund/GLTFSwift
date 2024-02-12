import Foundation

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
  let type: String
  let max: [Float]?
  let min: [Float]?
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
