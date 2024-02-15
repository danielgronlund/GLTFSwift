import Foundation
import Metal
import simd

class GLTFLoader {
  let device: MTLDevice

  init(device: MTLDevice) {
    self.device = device
  }

  func load(path: String, in bundle: Bundle) throws -> [Scene] {
    let gltfContainer = try load(file: path, in: bundle)

    let scenes = try gltfContainer.scenes.map { scene -> Scene in
      let sceneNodes = try scene.nodes?.compactMap { nodeIndex in
        try createNode(from: gltfContainer.nodes[nodeIndex], in: gltfContainer, in: bundle)
      }
      return Scene(nodes: sceneNodes, name: scene.name)
    }

    return scenes
  }

  private func createNode(from gltfNode: GLTFNode, in gltfContainer: GLTFContainer, in bundle: Bundle) throws -> Node? {
    let mesh = try mesh(from: gltfNode, in: gltfContainer, in: bundle)

    let childNodes = try gltfNode.children?.compactMap { childIndex in
      try createNode(from: gltfContainer.nodes[childIndex], in: gltfContainer, in: bundle)
    }

    return Node(
      children: childNodes,
      joints: [],
      mesh: mesh,
      name: gltfNode.name,
      position: gltfNode.translation,
      scale: gltfNode.scale,
      rotation: gltfNode.rotation
    )
  }

  private func mesh(from gltfNode: GLTFNode, in gltfContainer: GLTFContainer, in bundle: Bundle) throws -> Mesh? {
    guard let meshIndex = gltfNode.mesh else { return nil }
    let gltfMesh = gltfContainer.meshes[meshIndex]

    let (vertexBuffer, indexBuffer, indexCount, boundingBox) = try createBuffers(for: gltfMesh, in: gltfContainer, in: bundle)
    return Mesh(vertexBuffer: vertexBuffer, indexBuffer: indexBuffer, indexCount: indexCount, boundingBox: boundingBox)
  }

  private func createBuffers(for mesh: GLTFMesh, in gltfContainer: GLTFContainer, in bundle: Bundle) throws -> (MTLBuffer, MTLBuffer, Int, (min: simd_float3, max: simd_float3)?) {
    var vertices: [Vertex] = []
    var indices: [UInt32] = []

    var indexOffset: Int  = 0

    var boundingBox: (min: simd_float3, max: simd_float3)?

    for primitive in mesh.primitives {
      let positions: [simd_float3]
      var colors: [simd_float4]? = nil

      // Extract positions - assuming this must exist
      if let positionAccessorIndex = primitive.attributes.POSITION {
        let accessor = gltfContainer.accessors[positionAccessorIndex]
        positions = try extractData(for: accessor, in: gltfContainer, in: bundle)

        if let accessorBoundingBox = accessor.boundingBox {
          let newBoundingBox = boundingBox ?? (min: simd_float3(repeating: .greatestFiniteMagnitude), max: simd_float3(repeating: -.greatestFiniteMagnitude))
          boundingBox = (
            min(newBoundingBox.min , accessorBoundingBox.min),
            max(newBoundingBox.max, accessorBoundingBox.max)
          )
        }
      } else {
        continue
      }

      if let colorAccessorIndex = primitive.attributes.COLOR_0 {
        colors = try extractData(for: gltfContainer.accessors[colorAccessorIndex], in: gltfContainer, in: bundle)
      }

      for (index, position) in positions.enumerated() {
        let color = colors?.count ?? 0 > index ? colors![index] : simd_float4(0, 0, 0, 1)
        vertices.append(Vertex(position: position, color: color))
      }

      if let indicesAccessorIndex = primitive.indices {
        let extractedIndices = try extractIndicesData(for: indicesAccessorIndex, in: gltfContainer, in: bundle, offset: indexOffset)
        indices.append(contentsOf: extractedIndices)
      }

      indexOffset += positions.count
    }

    let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)!
    let indexBuffer = device.makeBuffer(bytes: indices.compactMap { UInt32($0) }, length: indices.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)!

    return (vertexBuffer, indexBuffer, indices.count, boundingBox)
  }

  private func extractData<T: DataInitializable>(for accessor: GLTFAccessor, in gltfContainer: GLTFContainer, in bundle: Bundle) throws -> [T] {
    let bufferView = gltfContainer.bufferViews[accessor.bufferView]
    let buffer = gltfContainer.buffers[bufferView.buffer]
    let binaryData = try FileReader.readFile(buffer.uri, in: bundle)

    let dataStart = bufferView.byteOffset + (accessor.byteOffset ?? 0)
    let strideBy = bufferView.byteStride ?? accessor.componentType.size * accessor.type.numberOfComponents
    let dataEnd = dataStart + strideBy * accessor.count

    var extractedData: [T] = []
    for offset in stride(from: dataStart, to: dataEnd, by: strideBy) {
      if let value = T(fromBinaryData: binaryData, byteOffset: offset) {
        extractedData.append(value)
      }
    }

    return extractedData
  }

  private func extractIndicesData(for accessorIndex: Int, in gltfContainer: GLTFContainer, in bundle: Bundle, offset: Int) throws -> [UInt32] {
    let accessor = gltfContainer.accessors[accessorIndex]
    let bufferView = gltfContainer.bufferViews[accessor.bufferView]
    let buffer = gltfContainer.buffers[bufferView.buffer]
    let binaryData = try FileReader.readFile(buffer.uri, in: bundle)

    let dataStart = bufferView.byteOffset
    let count = accessor.count
    var indices: [UInt32] = []

    switch accessor.componentType {
    case .unsignedByte:
      for i in 0..<count {
        let index = UInt32(binaryData[dataStart + (i * accessor.componentType.size)])
        indices.append(index)
      }
    case .unsignedShort:
      for i in 0..<count {
        let offset = dataStart + (i * accessor.componentType.size)
        let index = binaryData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self) }
        indices.append(UInt32(index))
      }
    case .unsignedInt:
      for i in 0..<count {
        let offset = dataStart + (i * accessor.componentType.size)
        let index = binaryData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        indices.append(index)
      }
    default:
      fatalError("Unsuported type for indices")
    }

    return indices.map { $0 + UInt32(offset)}
  }

  private func load(file gltfFile: String, in bundle: Bundle) throws -> GLTFContainer {
    let jsonData = try FileReader.readFile(gltfFile, in: bundle)
    let decoder = JSONDecoder()
    let gltfContainer = try decoder.decode(GLTFContainer.self, from: jsonData)

    return gltfContainer
  }
}
