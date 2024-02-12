import Foundation
import Metal
import simd

class GLTFLoader {
  let device: MTLDevice

  init(device: MTLDevice) {
    self.device = device
  }

  func load(path: String) throws -> [Scene] {
    let gltfContainer = try load(file: path)

    let scenes = try gltfContainer.scenes.map { scene -> Scene in
      let sceneNodes = try scene.nodes?.compactMap { nodeIndex in
        try createNode(from: gltfContainer.nodes[nodeIndex], in: gltfContainer)
      }
      return Scene(nodes: sceneNodes, name: scene.name)
    }

    return scenes
  }

  private func createNode(from gltfNode: GLTFNode, in gltfContainer: GLTFContainer) throws -> Node? {
    guard let meshIndex = gltfNode.mesh else { return nil }
    let gltfMesh = gltfContainer.meshes[meshIndex]

    let (vertexBuffer, indexBuffer, indexCount) = try createBuffers(for: gltfMesh, in: gltfContainer)

    let childNodes = try gltfNode.children?.compactMap { childIndex in
      try createNode(from: gltfContainer.nodes[childIndex], in: gltfContainer)
    }

    return Node(
      children: childNodes,
      vertexBuffer: vertexBuffer,
      indexBuffer: indexBuffer,
      name: gltfNode.name,
      position: gltfNode.translation,
      scale: gltfNode.scale,
      rotation: gltfNode.rotation,
      indexCount: indexCount
    )
  }

  private func createBuffers(for mesh: GLTFMesh, in gltfContainer: GLTFContainer) throws -> (MTLBuffer, MTLBuffer, Int) {
    var vertices: [Vertex] = []
    var indices: [UInt32] = []

    for primitive in mesh.primitives {
      let positions: [simd_float3]
      var colors: [simd_float4]? = nil

      // Extract positions - assuming this must exist
      if let positionAccessorIndex = primitive.attributes.POSITION {
        positions = try extractFloat3Data(for: positionAccessorIndex, in: gltfContainer)
      } else {
        continue
      }

      if let colorAccessorIndex = primitive.attributes.COLOR_0 {
        colors = try extractFloat4Data(for: colorAccessorIndex, in: gltfContainer)
      }

      for (index, position) in positions.enumerated() {
        let color = colors?.count ?? 0 > index ? colors![index] : simd_float4(1, 1, 1, 1)
        vertices.append(Vertex(position: position, color: color))
      }

      if let indicesAccessorIndex = primitive.indices {
        let extractedIndices = try extractIndicesData(for: indicesAccessorIndex, in: gltfContainer)
        indices.append(contentsOf: extractedIndices)
      }
    }

    let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)!
    let indexBuffer = device.makeBuffer(bytes: indices.compactMap { UInt32($0) }, length: indices.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)!

    return (vertexBuffer, indexBuffer, indices.count)
  }

  private func extractFloat3Data(for accessorIndex: Int, in gltfContainer: GLTFContainer) throws -> [simd_float3] {
    let accessor = gltfContainer.accessors[accessorIndex]
    let bufferView = gltfContainer.bufferViews[accessor.bufferView]
    let buffer = gltfContainer.buffers[bufferView.buffer]
    let binaryData = try FileReader.readFile(buffer.uri)

    let dataStart = bufferView.byteOffset
    let dataEnd = bufferView.byteOffset + bufferView.byteLength

    var extractedData: [simd_float3] = []

    for offset in stride(from: dataStart, to: dataEnd, by: MemoryLayout<Float>.stride * 3) {
      let dataSlice = binaryData.subdata(in: offset..<offset+(MemoryLayout<simd_float3>.size))
      let float3Values = dataSlice.withUnsafeBytes { $0.bindMemory(to: simd_float3.self) }
      if let value = float3Values.first {
        extractedData.append(value)
      }
    }

    return extractedData
  }

  private func extractFloat4Data(for accessorIndex: Int, in gltfContainer: GLTFContainer) throws -> [simd_float4] {
    let accessor = gltfContainer.accessors[accessorIndex]
    let bufferView = gltfContainer.bufferViews[accessor.bufferView]
    let buffer = gltfContainer.buffers[bufferView.buffer]
    let binaryData = try FileReader.readFile(buffer.uri)

    let dataStart = bufferView.byteOffset
    let dataEnd = dataStart + accessor.count * MemoryLayout<simd_float4>.stride

    var extractedData: [simd_float4] = []
    for offset in stride(from: dataStart, to: dataEnd, by: MemoryLayout<simd_float4>.stride) {
      let dataSlice = binaryData.subdata(in: offset..<offset+MemoryLayout<simd_float4>.size)
      let float4Values = dataSlice.withUnsafeBytes { $0.bindMemory(to: simd_float4.self) }
      if let value = float4Values.first {
        extractedData.append(value)
      }
    }

    return extractedData
  }

  private func extractIndicesData(for accessorIndex: Int, in gltfContainer: GLTFContainer) throws -> [UInt32] {
    let accessor = gltfContainer.accessors[accessorIndex]
    let bufferView = gltfContainer.bufferViews[accessor.bufferView]
    let buffer = gltfContainer.buffers[bufferView.buffer]
    let binaryData = try FileReader.readFile(buffer.uri)

    let dataStart = bufferView.byteOffset
    let count = accessor.count
    var indices: [UInt32] = []

    switch accessor.componentType {
    case .unsignedByte:
      for i in 0..<count {
        let index = UInt32(binaryData[dataStart + i])
        indices.append(index)
      }
    case .unsignedShort:
      for i in 0..<count {
        let offset = dataStart + i * 2
        let index = binaryData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self) }
        indices.append(UInt32(index))
      }
    case .unsignedInt:
      for i in 0..<count {
        let offset = dataStart + i * 4
        let index = binaryData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        indices.append(index)
      }
    case .float:
      break
    }

    return indices
  }

  private func load(file gltfFile: String) throws -> GLTFContainer {
    let jsonData = try FileReader.readFile(gltfFile)
    let decoder = JSONDecoder()
    let gltfContainer = try decoder.decode(GLTFContainer.self, from: jsonData)

    return gltfContainer
  }
}