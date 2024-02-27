import simd

public struct Vertex {
  /// The position of the vertex in 3D space, represented as a vector of three floating-point numbers.
  /// This is typically used to define the vertex's location within a model's geometry.
  public var position: simd_float3

  /// The surface normal of the vertex, represented as a vector of three floating-point numbers.
  /// This is typically used to calculate how light bounces of the surface.
  public var normal: simd_float3

  /// The color of the vertex, represented as a vector of four floating-point numbers corresponding to
  /// the red, green, blue, and alpha (transparency) components of the color. This allows each vertex to
  /// carry its own color information, which can be used for vertex coloring techniques in rendering.
  public var color: simd_float4

  /// The indices of the joints that influence this vertex, represented as a four-component vector. Each component is an
  /// index into the array of joints in the skeleton. For vertices not influenced by any joint, this can be set to a
  /// default value (e.g., 255). This is used for skeletal animation, where the joints' movements influence the mesh's vertices.
  public var joints: simd_uchar4

  /// The weights corresponding to the influence of each joint specified in the `joints` property, represented as a
  /// four-component vector. These weights determine how much each joint affects the vertex's final position. For vertices
  /// not influenced by joints, weights can be set to zero. The sum of all weights for a vertex should be 1.0 for proper
  /// blending but may need normalization in practice.
  public var weights: simd_float4

  static let invalidJointIndices: simd_uchar4 = simd_uchar4(255, 255, 255, 255)

  init(
    position: simd_float3,
    normal: simd_float3,
    color: simd_float4,
    joints: simd_uchar4?,
    weights: simd_float4?
  ) {
    self.position = position
    self.normal = normal
    self.color = color
    self.joints = joints ?? Self.invalidJointIndices
    self.weights = weights ?? .zero
  }
}
