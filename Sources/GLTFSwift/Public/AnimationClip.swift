import simd

/// Morph deltas remain in mesh-local coordinates, including for quantized assets.
/// Apply the node transform after morphing the base position and deltas.
public struct MorphTarget {
  public let positions: [simd_float3]?
  public let normals: [simd_float3]?
  public let tangents: [simd_float3]?
}

public enum AnimationInterpolation: String, Decodable {
  case linear = "LINEAR"
  case step = "STEP"
  case cubicSpline = "CUBICSPLINE"
}

public enum AnimationTargetPath: String, Decodable {
  case translation, rotation, scale, weights
}

public struct AnimationSampler {
  /// Strictly increasing keyframe times in seconds, retained as authored.
  public let times: [Float]
  /// Flattened values. For cubic splines each key stores in-tangent, value, out-tangent.
  /// Rotation values use glTF quaternion order x, y, z, w.
  public let values: [Float]
  public let interpolation: AnimationInterpolation
  /// Values per key (or per tangent/value group for cubic splines).
  /// A weights sampler has one component per morph target, not merely one SCALAR.
  public let componentsPerValue: Int
}

public struct AnimationChannel {
  public let samplerIndex: Int
  /// Index into GLTFAsset.nodes, not a node name.
  public let targetNodeIndex: Int
  public let targetPath: AnimationTargetPath
}

/// Imported animation data only. The caller controls playback and interpolation.
public struct AnimationClip {
  public let name: String?
  public let samplers: [AnimationSampler]
  public let channels: [AnimationChannel]
  public var startTime: Float { samplers.compactMap { $0.times.first }.min() ?? 0 }
  public var endTime: Float { samplers.compactMap { $0.times.last }.max() ?? 0 }
  public var duration: Float { endTime - startTime }
}
