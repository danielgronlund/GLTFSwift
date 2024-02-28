import Foundation
import simd

class GLTFLoader {
  func extractData(forAccessor accessorIndex: Int?, fromContainer gltfContainer: GLTFContainer, in bundle: Bundle) -> Data? {
    guard let accessorIndex, gltfContainer.accessors.indices.contains(accessorIndex) else {
      return nil
    }
    let accessor = gltfContainer.accessors[accessorIndex]
    let bufferView = gltfContainer.bufferViews[accessor.bufferView]
    let descriptor = BufferTypeDescriptor(componentType: accessor.componentType, dataType: accessor.type)
    let totalSize = descriptor.totalSize * accessor.count
    let buffer = gltfContainer.buffers[bufferView.buffer]

    return self.dataForBuffer(buffer, offset: bufferView.byteOffset + (accessor.byteOffset ?? 0), length: totalSize, in: bundle)
  }

  func extractBoundingBox(for accessorIndex: Int?, fromContainer gltfContainer: GLTFContainer, in bundle: Bundle) -> (min: simd_float3, max: simd_float3)? {
    guard let accessorIndex, gltfContainer.accessors.indices.contains(accessorIndex) else {
      return nil
    }

    let accessor = gltfContainer.accessors[accessorIndex]

    guard let min = accessor.min.flatMap(simd_float3.init), let max = accessor.max.flatMap(simd_float3.init) else {
      return nil
    }

    return (min, max)
  }

  func loadContainer(path: String, in bundle: Bundle) throws -> GLTFAsset {
    let gltfContainer = try load(file: path, in: bundle)

    return GLTFAsset(
      scenes: gltfContainer.scenes,
      nodes: gltfContainer.nodes,
      meshes: try mapMeshes(of: gltfContainer, in: bundle),
      skins: try mapSkins(of: gltfContainer, in: bundle),
      accessors: gltfContainer.accessors
    )
  }

  func mapSkins(of gltfContainer: GLTFContainer, in bundle: Bundle) throws -> [Skin] {
    // TODO: Clean up implementation for readiblity.

    return try gltfContainer.skins?.compactMap { skin in
      guard let data = extractData(forAccessor: skin.inverseBindMatrices, fromContainer: gltfContainer, in: bundle) else {
        return nil
      }

      let inverseMatrices: [simd_float4x4] = try .from(data: data)

      return Skin(inverseBindMatrices: inverseMatrices, joints: skin.joints)
    } ?? []
  }

  func mapMeshes(of gltfContainer: GLTFContainer, in bundle: Bundle) throws -> [Mesh] {
    // TODO: Clean up implementation for readiblity.

    return try gltfContainer.meshes.compactMap({ mesh in
      let publicPrimitives: [Primitive] = try mesh.primitives.compactMap({ primitive in
        guard let primtiveInterleavedData = try extractAndInterleaveData(forPrimitive: primitive, fromContainer: gltfContainer, in: bundle) else {
          return nil
        }

        return Primitive(
          indices: primtiveInterleavedData.indices,
          vertices: primtiveInterleavedData.vertices,
          boundingBox: primtiveInterleavedData.boundingBox ?? (.zero, .zero)
        )
      })

      return Mesh(primitives: publicPrimitives)
    })
  }

  func extractAndInterleaveData(forPrimitive primitive: GLTFPrimitive, fromContainer container: GLTFContainer, in bundle: Bundle) throws -> (vertices: [Vertex], indices: [UInt32], boundingBox: (min: simd_float3, max: simd_float3)?)? {
    guard
      let positionsData = extractData(forAccessor: primitive.attributes.POSITION, fromContainer: container, in: bundle),
      let indicesAccessorIndex = primitive.indices
    else {
      return nil
    }

    let indices = try extractIndicesData(for: indicesAccessorIndex, in: container, offset: 0, in: bundle)
    let boundingBox = extractBoundingBox(for: primitive.attributes.POSITION, fromContainer: container, in: bundle)

    let positions: [simd_float3] = try .from(data: positionsData)

    let normals: [simd_float3]? = try primitive.attributes.NORMAL.flatMap { normalsAccessorIndex in
      guard let data = extractData(forAccessor: normalsAccessorIndex, fromContainer: container, in: bundle) else {
        return nil
      }

      return try .from(data: data)
    }

    let joints: [simd_uchar4]? = try primitive.attributes.JOINTS_0.flatMap { jointsAccessorIndex in
      guard let data = extractData(forAccessor: jointsAccessorIndex, fromContainer:container, in: bundle) else {
        return nil
      }

      return try .from(data: data)
    }

    let colors: [simd_float4]? = try primitive.attributes.COLOR_0.flatMap { colorsAccessorIndex in
      guard let data = extractData(forAccessor: colorsAccessorIndex, fromContainer: container, in: bundle) else {
        return nil
      }

      // TODO: Optimization – Instead of referencing the accessor directly here we should return it from the extact data function.
      let accessor = container.accessors[colorsAccessorIndex]
      return try .from(data: data, componentType: accessor.componentType, normalize: accessor.normalized ?? false)
    }

    let weights: [simd_float4]? = try primitive.attributes.WEIGHTS_0.flatMap { weightsAccessorIndex in
      guard let data = extractData(forAccessor: weightsAccessorIndex, fromContainer: container, in: bundle) else {
        return nil
      }

      let accessor = container.accessors[weightsAccessorIndex]
      return try .from(data: data, componentType: accessor.componentType, normalize: accessor.normalized ?? false)
    }

    var vertices: [Vertex] = []
    for (index, position) in positions.enumerated() {
      let vertex = Vertex(
        position: position,
        normal: normals?[safe: index] ?? simd_float3(0, 0, 0),
        color: colors?[safe: index] ?? simd_float4(0, 0, 0, 1),
        joints: joints?[safe: index],
        weights: weights?[safe: index]
      )
      vertices.append(vertex)
    }

    return (vertices: vertices, indices: indices, boundingBox: boundingBox)
  }

  private func extractIndicesData(for accessorIndex: Int, in gltfContainer: GLTFContainer, offset: Int, in bundle: Bundle) throws -> [UInt32] {
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

  func dataForBuffer(_ buffer: GLTFBuffer, offset: Int, length: Int, in bundle: Bundle) -> Data {
    do {
      let fileData = try FileReader.readFile(buffer.uri, in: bundle)
      guard offset + length <= fileData.count else {
        print("Requested data range exceeds file size.")
        return Data()
      }
      return fileData.subdata(in: offset..<(offset + length))
    } catch {
      print("Failed to read buffer data: \(error.localizedDescription)")
      return Data()
    }
  }

  private func load(file gltfFile: String, in bundle: Bundle) throws -> GLTFContainer {
    let jsonData = try FileReader.readFile(gltfFile, in: bundle)
    let decoder = JSONDecoder()
    let gltfContainer = try decoder.decode(GLTFContainer.self, from: jsonData)

    return gltfContainer
  }
}
