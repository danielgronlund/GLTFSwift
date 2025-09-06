import Foundation
import simd
import DracoDecompressSwift

enum DataLoadingError: Swift.Error {
  case unsupportedDataType
  case decompressionFailure
  case missingData
}

class GLTFLoader {

  func extractData(for primitive: GLTFPrimitive, attribute: GLTFAttribute, from container: GLTFContainer, from filepath: URL) throws -> (
    positions: Data,
    indices: Data,
    normals: Data?,
    colors: Data?,
    textureCoordinates: Data?,
    weights: Data?,
    joints: Data?
  )? {
    if let dracoExtension = primitive.extensions?.dracoExtension {
      let bufferView = container.bufferViews[dracoExtension.bufferView]
      let buffer = container.buffers[bufferView.buffer]

      let compressedData = self.dataForBuffer(buffer, offset: bufferView.byteOffset, length: bufferView.byteLength, from: filepath)

      let decodedData = try decompressDracoBuffer(compressedData)
      return (
        decodedData.positions,
        decodedData.indices,
        decodedData.normals,
        decodedData.colors,
        decodedData.textureCoordinates,
        decodedData.weights,
        decodedData.joints
      )
    }
    return nil
  }

  func extractData(forAccessor accessorIndex: Int?, fromContainer container: GLTFContainer, from filepath: URL) -> Data? {
    guard let accessorIndex, container.accessors.indices.contains(accessorIndex)  else {
      return nil
    }

    let accessor = container.accessors[accessorIndex]

    guard let bufferViewIndex = accessor.bufferView else {
      return nil
    }

    let bufferView = container.bufferViews[bufferViewIndex]
    let descriptor = BufferTypeDescriptor(componentType: accessor.componentType, dataType: accessor.type)
    let totalSize = descriptor.totalSize * accessor.count
    let buffer = container.buffers[bufferView.buffer]

    return self.dataForBuffer(buffer, offset: bufferView.byteOffset + (accessor.byteOffset ?? 0), length: totalSize, from: filepath)
  }

  func extractBoundingBox(for accessorIndex: Int?, fromContainer gltfContainer: GLTFContainer) -> (min: simd_float3, max: simd_float3)? {
    guard let accessorIndex, gltfContainer.accessors.indices.contains(accessorIndex) else {
      return nil
    }

    let accessor = gltfContainer.accessors[accessorIndex]

    guard let min = accessor.min.flatMap(simd_float3.init), let max = accessor.max.flatMap(simd_float3.init) else {
      return nil
    }

    return (min, max)
  }

  func loadContainer(from filepath: URL) throws -> GLTFAsset {
    let gltfContainer = try load(file: filepath)

    return GLTFAsset(
      scenes: gltfContainer.scenes,
      nodes: gltfContainer.nodes,
      meshes: try mapMeshes(of: gltfContainer, from: filepath),
      skins: try mapSkins(of: gltfContainer, from: filepath),
      accessors: gltfContainer.accessors
    )
  }

  func mapSkins(of gltfContainer: GLTFContainer, from filepath: URL) throws -> [Skin] {
    return try gltfContainer.skins?.compactMap { skin in
      guard let data = extractData(forAccessor: skin.inverseBindMatrices, fromContainer: gltfContainer, from: filepath) else {
        return nil
      }

      let inverseMatrices: [simd_float4x4] = try .from(data: data)

      return Skin(inverseBindMatrices: inverseMatrices, joints: skin.joints)
    } ?? []
  }

  func mapMeshes(of gltfContainer: GLTFContainer, from filepath: URL) throws -> [Mesh] {
    return try gltfContainer.meshes.compactMap({ mesh in
      let publicPrimitives: [Primitive] = try mesh.primitives.concurrentMap({ primitive in
        guard let primitiveInterleavedData = try self.extractAndInterleaveData(forPrimitive: primitive, fromContainer: gltfContainer, from: filepath) else {
          return nil
        }

        return Primitive(
          indices: primitiveInterleavedData.indices,
          vertices: primitiveInterleavedData.vertices,
          boundingBox: primitiveInterleavedData.boundingBox ?? (.zero, .zero),
          material: primitiveInterleavedData.material.map(Material.init(material:))
        )
      })

      return Mesh(primitives: publicPrimitives)
    })
  }

  func extractAndInterleaveData(forPrimitive primitive: GLTFPrimitive, fromContainer container: GLTFContainer, from filepath: URL) throws -> (
    vertices: [Vertex],
    indices: [UInt32],
    boundingBox: (min: simd_float3, max: simd_float3)?,
    material: GLTFMaterial?
  )? {

    let indices: [UInt32]
    let positions: [simd_float3]
    let boundingBox: (min: simd_float3, max: simd_float3)?

    var normals: [simd_float3]? = nil
    var joints: [simd_uchar4]? = nil
    var colors: [simd_float4]? = nil
    var textureCoordinates: [simd_float2]? = nil

    var weights: [simd_float4]? = nil

    if let decompressedBuffers = try extractData(for: primitive, attribute: .position, from: container, from: filepath) {
      positions = try .from(data: decompressedBuffers.positions)
      normals = try decompressedBuffers.normals.map {
        try .from(data: $0)
      }

      colors = try decompressedBuffers.colors.map {
        try .from(data: $0, componentType: .float, dataType: .vec3, normalize: false)
      }

      textureCoordinates = try decompressedBuffers.textureCoordinates.map {
        try .from(data: $0, componentType: .float, normalize: false)
      }

      weights = try decompressedBuffers.weights.map {
        try .from(data: $0, componentType: .float, normalize: false)
      }

      // TODO: Verify that this is correct?
      joints = try decompressedBuffers.joints.map {
        try .from(data: $0)
      }

      // TODO: Support texture coordinates.

      let indexCount = decompressedBuffers.indices.count / MemoryLayout<UInt32>.size
      let mappedIndices = decompressedBuffers.indices.withUnsafeBytes { buffer in
        Array(UnsafeBufferPointer<UInt32>(start: buffer.bindMemory(to: UInt32.self).baseAddress!, count: indexCount))
      }

      indices = mappedIndices

      boundingBox = extractBoundingBox(for: primitive.attributes.POSITION, fromContainer: container)
    } else {
      guard
        let positionsData = extractData(forAccessor: primitive.attributes.POSITION, fromContainer: container, from: filepath),
        let indicesAccessorIndex = primitive.indices
      else {
        throw DataLoadingError.missingData
      }

      indices = try extractIndicesData(for: indicesAccessorIndex, in: container, offset: 0, from: filepath)
      boundingBox = extractBoundingBox(for: primitive.attributes.POSITION, fromContainer: container)
      positions = try .from(data: positionsData)

      normals = try primitive.attributes.NORMAL.flatMap { normalsAccessorIndex in
        guard let data = extractData(forAccessor: normalsAccessorIndex, fromContainer: container, from: filepath) else {
          return nil
        }

        return try .from(data: data)
      }

      joints = try primitive.attributes.JOINTS_0.flatMap { jointsAccessorIndex in
        guard let data = extractData(forAccessor: jointsAccessorIndex, fromContainer:container, from: filepath) else {
          return nil
        }

        return try .from(data: data)
      }

      colors = try primitive.attributes.COLOR_0.flatMap { colorsAccessorIndex in
        guard let data = extractData(forAccessor: colorsAccessorIndex, fromContainer: container, from: filepath) else {
          return nil
        }

        // TODO: Optimization – Instead of referencing the accessor directly here we should return it from the extact data function.
        let accessor = container.accessors[colorsAccessorIndex]
        return try .from(data: data, componentType: accessor.componentType, dataType: accessor.type, normalize: accessor.normalized ?? false)
      }

      textureCoordinates = try primitive.attributes.TEXCOORD_0.flatMap { colorsAccessorIndex in
        guard let data = extractData(forAccessor: colorsAccessorIndex, fromContainer: container, from: filepath) else {
          return nil
        }

        // TODO: Optimization – Instead of referencing the accessor directly here we should return it from the extact data function.
        let accessor = container.accessors[colorsAccessorIndex]
        return try .from(data: data, componentType: accessor.componentType, dataType: accessor.type, normalize: accessor.normalized ?? false)
      }

      weights = try primitive.attributes.WEIGHTS_0.flatMap { weightsAccessorIndex in
        guard let data = extractData(forAccessor: weightsAccessorIndex, fromContainer: container, from: filepath) else {
          return nil
        }

        let accessor = container.accessors[weightsAccessorIndex]
        return try .from(data: data, componentType: accessor.componentType, normalize: accessor.normalized ?? false)
      }
    }

    let material: GLTFMaterial? = {
      if let accessor = primitive.material, let material = container.materials?[accessor] {
        return material
      } else {
        return nil
      }
    }()

    var vertices: [Vertex] = []
    for (index, position) in positions.enumerated() {
      let vertex = Vertex(
        position: position,
        normal: normals?[safe: index] ?? simd_float3(0, 0, 0),
        color: colors?[safe: index] ?? simd_float4(0, 0, 0, 1),
        uv: textureCoordinates?[safe: index] ?? .zero,
        joints: joints?[safe: index],
        weights: weights?[safe: index]
      )
      vertices.append(vertex)
    }

    return (vertices: vertices, indices: indices, boundingBox: boundingBox, material: material)
  }

  private func load(file filepath: URL) throws -> GLTFContainer {
    let jsonData = try FileReader.readFile(at: filepath)
    let decoder = JSONDecoder()
    let gltfContainer = try decoder.decode(GLTFContainer.self, from: jsonData)

    return gltfContainer
  }

  private func extractIndicesData(for accessorIndex: Int, in gltfContainer: GLTFContainer, offset: Int, from filepath: URL) throws -> [UInt32] {
    let accessor = gltfContainer.accessors[accessorIndex]
    guard let bufferViewIndex = accessor.bufferView else {
      return []
    }

    let bufferView = gltfContainer.bufferViews[bufferViewIndex]
    let buffer = gltfContainer.buffers[bufferView.buffer]
    let gltfDirectory = filepath.deletingLastPathComponent()
    let bufferURL = gltfDirectory.appendingPathComponent(buffer.uri ?? "")
    let binaryData = try Data(contentsOf: bufferURL)

    let dataStart = bufferView.byteOffset
    let count = accessor.count
    var indices: [UInt32] = []

    let batchSize = 1024
    indices.reserveCapacity(count)
    let offsetAddition = UInt32(offset)

    binaryData.withUnsafeBytes { bytes in
      switch accessor.componentType {
      case .unsignedByte:
        for batchStart in stride(from: 0, to: count, by: batchSize) {
          let batchEnd = min(batchStart + batchSize, count)

          for i in batchStart..<batchEnd {
            let index = UInt32(bytes[dataStart + i])
            indices.append(index + offsetAddition)
          }
        }

      case .unsignedShort:
        let pointer = bytes.baseAddress!.assumingMemoryBound(to: UInt16.self)
        for batchStart in stride(from: 0, to: count, by: batchSize) {
          let batchEnd = min(batchStart + batchSize, count)

          for i in batchStart..<batchEnd {
            let index = pointer[(dataStart / MemoryLayout<UInt16>.stride) + i]
            indices.append(UInt32(index) + offsetAddition)
          }
        }

      case .unsignedInt:
        let pointer = bytes.baseAddress!.assumingMemoryBound(to: UInt32.self)
        for batchStart in stride(from: 0, to: count, by: batchSize) {
          let batchEnd = min(batchStart + batchSize, count)

          for i in batchStart..<batchEnd {
            let index = pointer[(dataStart / MemoryLayout<UInt32>.stride) + i]
            indices.append(index + offsetAddition)
          }
        }
      default:
        fatalError("Unsupported type for indices")
      }
    }

    return indices
  }

  func dataForBuffer(_ buffer: GLTFBuffer, offset: Int, length: Int, from filepath: URL) -> Data {
    do {
      let gltfDirectory = filepath.deletingLastPathComponent()
      let bufferURL = gltfDirectory.appendingPathComponent(buffer.uri ?? "")
      let fileData = try Data(contentsOf: bufferURL)
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
}
