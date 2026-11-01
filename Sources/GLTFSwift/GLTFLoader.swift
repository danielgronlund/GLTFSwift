import DracoDecompressSwift
import Foundation
import simd

enum DataLoadingError: Swift.Error {
  case unsupportedDataType
  case decompressionFailure
  case missingData
}

class GLTFLoader {
  func loadContainer(from filepath: URL) throws -> GLTFAsset {
    let data = try FileReader.readFile(at: filepath)
    if data.prefix(4) == Data([0x67, 0x6c, 0x54, 0x46]) {
      throw GLTFLoadingError.unsupportedFeature(
        "GLB containers; use .gltf with external .bin buffers")
    }
    let container = try JSONDecoder().decode(GLTFContainer.self, from: data)
    let reader = try AccessorReader(container: container, fileURL: filepath)
    let meshes = try container.meshes.map { mesh in
      let primitives = try mesh.primitives.map {
        try primitive($0, container: container, reader: reader, filepath: filepath)
      }
      let targetCount = primitives.first?.morphTargets.count ?? 0
      guard primitives.allSatisfy({ $0.morphTargets.count == targetCount }),
        mesh.weights == nil || mesh.weights?.count == targetCount,
        (mesh.weights ?? []).allSatisfy({ $0.isFinite })
      else { throw invalid("Inconsistent mesh morph targets or weights.") }
      return Mesh(
        primitives: primitives, weights: mesh.weights ?? .init(repeating: 0, count: targetCount))
    }
    for node in container.nodes {
      if let weights = node.weights {
        guard let mesh = node.mesh, meshes.indices.contains(mesh),
          weights.count == meshes[mesh].weights.count,
          weights.allSatisfy({ $0.isFinite })
        else { throw invalid("Invalid node morph weights.") }
      }
    }
    let skins = try (container.skins ?? []).map { skin -> Skin in
      guard skin.joints.allSatisfy({ container.nodes.indices.contains($0) }) else {
        throw invalid("Skin joint node is out of range.")
      }
      let matrices: [simd_float4x4]
      if let index = skin.inverseBindMatrices {
        let values = try reader.floats(index, expectedType: .mat4)
        guard values.count == skin.joints.count * 16 else {
          throw invalid("Inverse bind matrix count does not match joints.")
        }
        matrices = stride(from: 0, to: values.count, by: 16).map { i in
          simd_float4x4(
            simd_float4(values[i], values[i + 1], values[i + 2], values[i + 3]),
            simd_float4(values[i + 4], values[i + 5], values[i + 6], values[i + 7]),
            simd_float4(values[i + 8], values[i + 9], values[i + 10], values[i + 11]),
            simd_float4(values[i + 12], values[i + 13], values[i + 14], values[i + 15]))
        }
      } else {
        matrices = .init(repeating: matrix_identity_float4x4, count: skin.joints.count)
      }
      return Skin(inverseBindMatrices: matrices, joints: skin.joints)
    }
    let animations = try clips(container: container, meshes: meshes, reader: reader)
    return GLTFAsset(
      scenes: container.scenes, nodes: container.nodes, meshes: meshes, skins: skins,
      accessors: container.accessors, animations: animations)
  }

  private func primitive(
    _ primitive: GLTFPrimitive, container: GLTFContainer, reader: AccessorReader, filepath: URL
  ) throws -> Primitive {
    guard (primitive.mode ?? 4) == 4 else {
      throw GLTFLoadingError.unsupportedFeature("Non-triangle primitives")
    }
    let positions: [simd_float3]
    let indices: [UInt32]
    let normals: [simd_float3]?
    let colors: [simd_float4]?
    let uv: [simd_float2]?
    let joints: [simd_uchar4]?
    let weights: [simd_float4]?
    if let draco = primitive.extensions?.dracoExtension {
      let decoded = try decompressDracoBuffer(reader.view(draco.bufferView))
      positions = try .from(data: decoded.positions)
      indices = decoded.indices.withUnsafeBytes { bytes in
        stride(from: 0, to: bytes.count, by: 4).map {
          bytes.loadUnaligned(fromByteOffset: $0, as: UInt32.self)
        }
      }
      normals = try decoded.normals.map { try .from(data: $0) }
      colors = try decoded.colors.map {
        try .from(data: $0, componentType: .float, dataType: .vec3, normalize: false)
      }
      uv = try decoded.textureCoordinates.map {
        try .from(data: $0, componentType: .float, normalize: false)
      }
      joints = try decoded.joints.map { try .from(data: $0) }
      weights = try decoded.weights.map {
        try .from(data: $0, componentType: .float, normalize: false)
      }
    } else {
      guard let positionIndex = primitive.attributes.POSITION else {
        throw invalid("Primitive has no POSITION accessor.")
      }
      positions = try vectors3(positionIndex, reader: reader)
      indices =
        try primitive.indices.map { try reader.indices($0) } ?? positions.indices.map { UInt32($0) }
      normals = try primitive.attributes.NORMAL.map { try vectors3($0, reader: reader) }
      if let colorIndex = primitive.attributes.COLOR_0 {
        let descriptor = try reader.accessor(colorIndex)
        guard descriptor.type == .vec3 || descriptor.type == .vec4 else {
          throw invalid("Vertex colors must be VEC3 or VEC4.")
        }
        let values = try reader.floats(colorIndex)
        let size = descriptor.type.numberOfComponents
        colors = stride(from: 0, to: values.count, by: size).map { i in
          simd_float4(values[i], values[i + 1], values[i + 2], size == 4 ? values[i + 3] : 1)
        }
      } else {
        colors = nil
      }
      if let index = primitive.attributes.TEXCOORD_0 {
        let values = try reader.floats(index, expectedType: .vec2)
        uv = stride(from: 0, to: values.count, by: 2).map {
          simd_float2(values[$0], values[$0 + 1])
        }
      } else {
        uv = nil
      }
      if let index = primitive.attributes.JOINTS_0 {
        let descriptor = try reader.accessor(index)
        guard [.unsignedByte, .unsignedShort].contains(descriptor.componentType),
          descriptor.normalized != true
        else { throw invalid("Invalid joint component type.") }
        let values = try reader.floats(index, expectedType: .vec4)
        guard values.allSatisfy({ $0 >= 0 && $0 <= 255 }) else {
          throw GLTFLoadingError.unsupportedFeature("Joint indices above 255")
        }
        joints = stride(from: 0, to: values.count, by: 4).map {
          simd_uchar4(
            UInt8(values[$0]), UInt8(values[$0 + 1]), UInt8(values[$0 + 2]), UInt8(values[$0 + 3]))
        }
      } else {
        joints = nil
      }
      if let index = primitive.attributes.WEIGHTS_0 {
        let values = try reader.floats(index, expectedType: .vec4)
        weights = stride(from: 0, to: values.count, by: 4).map {
          simd_float4(values[$0], values[$0 + 1], values[$0 + 2], values[$0 + 3])
        }
      } else {
        weights = nil
      }
    }
    guard !positions.isEmpty,
      positions.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
      indices.count % 3 == 0, indices.allSatisfy({ UInt64($0) < UInt64(positions.count) })
    else { throw invalid("Invalid primitive vertices or indices.") }
    for count in [normals?.count, colors?.count, uv?.count, joints?.count, weights?.count]
      .compactMap({ $0 })
    {
      guard count == positions.count else { throw invalid("Vertex attribute count mismatch.") }
    }
    let targets = try (primitive.targets ?? []).map { attributes -> MorphTarget in
      let positionsDelta = try attributes.POSITION.map { try vectors3($0, reader: reader) }
      let normalsDelta = try attributes.NORMAL.map { try vectors3($0, reader: reader) }
      let tangentsDelta = try attributes.TANGENT.map { try vectors3($0, reader: reader) }
      guard positionsDelta != nil || normalsDelta != nil || tangentsDelta != nil else {
        throw invalid("Empty morph target.")
      }
      for count in [positionsDelta?.count, normalsDelta?.count, tangentsDelta?.count].compactMap({
        $0
      }) {
        guard count == positions.count else { throw invalid("Morph target vertex count mismatch.") }
      }
      return MorphTarget(positions: positionsDelta, normals: normalsDelta, tangents: tangentsDelta)
    }
    let vertices = positions.indices.map { i in
      Vertex(
        position: positions[i], normal: normals?[i] ?? .zero, color: colors?[i] ?? .one,
        uv: uv?[i] ?? .zero, joints: joints?[i], weights: weights?[i])
    }
    let low = positions.reduce(simd_float3(repeating: .greatestFiniteMagnitude)) {
      simd.min($0, $1)
    }
    let high = positions.reduce(simd_float3(repeating: -.greatestFiniteMagnitude)) {
      simd.max($0, $1)
    }
    let material = primitive.material.flatMap { container.materials?[safe: $0] }.map {
      Material(material: $0, in: container, relativeTo: filepath)
    }
    return Primitive(
      indices: indices, vertices: vertices, boundingBox: (low, high), material: material,
      morphTargets: targets)
  }

  private func vectors3(_ index: Int, reader: AccessorReader) throws -> [simd_float3] {
    let values = try reader.floats(index, expectedType: .vec3)
    return stride(from: 0, to: values.count, by: 3).map {
      simd_float3(values[$0], values[$0 + 1], values[$0 + 2])
    }
  }

  private func clips(container: GLTFContainer, meshes: [Mesh], reader: AccessorReader) throws
    -> [AnimationClip]
  {
    try (container.animations ?? []).map { animation in
      let samplers = try animation.samplers.map { sampler -> AnimationSampler in
        let input = try reader.accessor(sampler.input)
        let output = try reader.accessor(sampler.output)
        guard input.componentType == .float, output.componentType == .float else {
          throw invalid("Animation inputs and outputs must be FLOAT accessors.")
        }
        let times = try reader.floats(sampler.input, expectedType: .scalar)
        guard !times.isEmpty, times[0] >= 0, zip(times, times.dropFirst()).allSatisfy({ $0 < $1 })
        else { throw invalid("Animation times must be nonnegative and strictly increasing.") }
        let values = try reader.floats(sampler.output)
        let interpolation = sampler.interpolation ?? .linear
        let groups = times.count.multipliedReportingOverflow(
          by: interpolation == .cubicSpline ? 3 : 1)
        guard !groups.overflow, !values.isEmpty, values.count % groups.partialValue == 0 else {
          throw invalid("Animation output count does not match input times.")
        }
        return AnimationSampler(
          times: times, values: values, interpolation: interpolation,
          componentsPerValue: values.count / groups.partialValue)
      }
      let channels = try animation.channels.map { channel -> AnimationChannel in
        guard samplers.indices.contains(channel.sampler), let nodeIndex = channel.target.node,
          container.nodes.indices.contains(nodeIndex)
        else { throw invalid("Animation sampler or target node is out of range.") }
        let sampler = samplers[channel.sampler]
        let output = try reader.accessor(animation.samplers[channel.sampler].output)
        switch channel.target.path {
        case .weights:
          guard let mesh = container.nodes[nodeIndex].mesh, meshes.indices.contains(mesh),
            !meshes[mesh].weights.isEmpty, sampler.componentsPerValue == meshes[mesh].weights.count,
            output.type == .scalar
          else { throw invalid("Weights animation does not match the node's morph targets.") }
        case .rotation:
          guard sampler.componentsPerValue == 4, output.type == .vec4 else {
            throw invalid("Rotation animation must have VEC4 values.")
          }
        case .translation, .scale:
          guard sampler.componentsPerValue == 3, output.type == .vec3 else {
            throw invalid("Translation/scale animation must have VEC3 values.")
          }
        }
        return AnimationChannel(
          samplerIndex: channel.sampler, targetNodeIndex: nodeIndex, targetPath: channel.target.path
        )
      }
      return AnimationClip(name: animation.name, samplers: samplers, channels: channels)
    }
  }

  private func invalid(_ message: String) -> GLTFLoadingError { .invalidData(message) }
}
