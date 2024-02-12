import Foundation

// MARK: - GLTF
public struct GLTFContainer: Decodable {
  let scenes: [Scene]
  let nodes: [Node]
  let meshes: [Mesh]
  let skins: [Skin]?
  let asset: Asset
}

// MARK: - Asset
public struct Asset: Decodable {
  let version: String
  let generator: String?
}

// MARK: - Scene
public struct Scene: Decodable {
  let nodes: [Int]?
  let name: String?
}

// MARK: - Node
public struct Node: Decodable {
  let mesh: Int?
  let skin: Int?
  let children: [Int]?
  let name: String?
}

// MARK: - Mesh
public struct Mesh: Decodable {
  let primitives: [Primitive]
  let name: String?
}

// MARK: - Primitive
public struct Primitive: Decodable {
  let indices: Int?
  let attributes: Attributes
}

// MARK: - Attributes
public struct Attributes: Decodable {
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
public struct Skin: Decodable {
  let inverseBindMatrices: Int?
  let skeleton: Int?
  let joints: [Int]
  let name: String?
}
