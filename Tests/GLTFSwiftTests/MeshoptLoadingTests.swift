import XCTest
import simd

@testable import GLTFSwift

final class MeshoptLoadingTests: XCTestCase {
  private var directories: [URL] = []
  override func tearDownWithError() throws {
    for directory in directories { try FileManager.default.removeItem(at: directory) }
    try super.tearDownWithError()
  }

  func testQuantizedMeshMorphsAndTimingLoadFromExternalBuffers() throws {
    let asset = try GLTFSwift.load(from: fixtureURL())
    let mesh = try XCTUnwrap(asset.meshes.first)
    let primitive = try XCTUnwrap(mesh.primitives.first)
    XCTAssertEqual(primitive.indices, [0, 1, 2])
    XCTAssertEqual(
      primitive.vertices.map(\.position),
      [simd_float3(-1, 0, 0), simd_float3(1, 0, 0), simd_float3(0, 1, 0)])
    XCTAssertEqual(primitive.boundingBox?.min, simd_float3(-1, 0, 0))
    XCTAssertEqual(primitive.boundingBox?.max, simd_float3(1, 1, 0))
    XCTAssertEqual(primitive.vertices[0].normal.z, 1, accuracy: 0.002)
    XCTAssertEqual(primitive.vertices[2].uv.x, 0.5, accuracy: 0.0001)
    XCTAssertEqual(primitive.vertices[2].uv.y, 1)
    XCTAssertEqual(primitive.morphTargets.count, 2)
    XCTAssertEqual(try XCTUnwrap(primitive.morphTargets[0].positions)[1].y, 0.5, accuracy: 0.0001)
    XCTAssertEqual(try XCTUnwrap(primitive.morphTargets[1].positions)[0].x, 1)
    XCTAssertEqual(mesh.weights, [0.25, 0.75])
    XCTAssertEqual(asset.nodes[0].weights, [1, 0])
    XCTAssertEqual(asset.nodes[0].translation, simd_float3(5, 0, 0))
    XCTAssertEqual(asset.nodes[0].scale, simd_float3(2, 2, 2))
    let clip = try XCTUnwrap(asset.animations.first)
    XCTAssertEqual(clip.name, "Water")
    XCTAssertEqual(clip.duration, 10)
    XCTAssertEqual(clip.samplers[0].times, [0, 10])
    XCTAssertEqual(clip.samplers[0].values, [1, 0, 0, 1])
    XCTAssertEqual(clip.samplers[0].componentsPerValue, 2)
    XCTAssertEqual(clip.samplers[0].interpolation, .linear)
    XCTAssertEqual(clip.channels[0].targetPath, .weights)
    XCTAssertEqual(clip.channels[0].targetNodeIndex, 0)
    XCTAssertEqual(clip.channels[0].samplerIndex, 0)
  }

  func testIndexSequenceAndAccessorOffset() throws {
    let reader = try makeReader(document())
    XCTAssertEqual(try reader.indices(8), [2, 1, 0, 2, 1])
  }

  func testQuaternionFilter() throws {
    let values = try makeReader(document()).floats(9, expectedType: .vec4)
    XCTAssertEqual(values.count, 8)
    XCTAssertEqual(values[3], 1, accuracy: 0.0001)
    XCTAssertEqual(values[5], sqrt(0.5), accuracy: 0.0001)
    XCTAssertEqual(values[7], sqrt(0.5), accuracy: 0.0001)
  }

  func testExponentialFilter() throws {
    XCTAssertEqual(try makeReader(document()).floats(10), [1.25, -2.5, 100, 0.125, 64, -0.5])
  }

  func testPlainStridedPositionsAndOffsetIndices() throws {
    var bytes = Data([0xaa, 0xbb, 0xcc, 0xdd])
    for value: Int16 in [-32768, 0, 0, 99, 32767, 0, 0, 99, 0, 32767, 0, 99] {
      append(value.littleEndian, to: &bytes)
    }
    for value: UInt16 in [999, 0, 1, 2] { append(value.littleEndian, to: &bytes) }
    let doc: [String: Any] = [
      "asset": ["version": "2.0"], "extensionsRequired": ["KHR_mesh_quantization"],
      "scenes": [["nodes": [0]]], "nodes": [["mesh": 0]],
      "meshes": [["primitives": [["attributes": ["POSITION": 0], "indices": 1]]]],
      "buffers": [
        [
          "uri": "data:application/octet-stream;base64," + bytes.base64EncodedString(),
          "byteLength": bytes.count,
        ]
      ],
      "bufferViews": [
        ["buffer": 0, "byteOffset": 4, "byteLength": 24, "byteStride": 8],
        ["buffer": 0, "byteOffset": 28, "byteLength": 8],
      ],
      "accessors": [
        ["bufferView": 0, "componentType": 5122, "normalized": true, "count": 3, "type": "VEC3"],
        ["bufferView": 1, "byteOffset": 2, "componentType": 5123, "count": 3, "type": "SCALAR"],
      ],
    ]
    let p = try GLTFSwift.load(from: write(doc)).meshes[0].primitives[0]
    XCTAssertEqual(p.indices, [0, 1, 2])
    XCTAssertEqual(p.vertices[0].position.x, -1)
    XCTAssertEqual(p.vertices[1].position.x, 1)
    XCTAssertEqual(p.vertices[2].position.y, 1)
  }

  func testOmittedOffsetsDefaultToZeroAndBuffersAreReusable() throws {
    var doc = try document()
    var views = doc["bufferViews"] as! [[String: Any]]
    views[0].removeValue(forKey: "byteOffset")
    var extensions = views[0]["extensions"] as! [String: Any]
    var compression = extensions["EXT_meshopt_compression"] as! [String: Any]
    compression.removeValue(forKey: "byteOffset")
    extensions["EXT_meshopt_compression"] = compression
    views[0]["extensions"] = extensions
    doc["bufferViews"] = views
    let reader = try makeReader(doc)
    XCTAssertEqual(try reader.floats(0), try reader.floats(0))
  }

  func testNodeWeightsMayBeAbsent() throws {
    var doc = try document()
    var nodes = doc["nodes"] as! [[String: Any]]
    nodes[0].removeValue(forKey: "weights")
    doc["nodes"] = nodes
    let asset = try GLTFSwift.load(from: write(doc))
    XCTAssertNil(asset.nodes[0].weights)
    XCTAssertEqual(asset.meshes[0].weights, [0.25, 0.75])
  }

  func testCubicSplineWeightsRetainTangentsAndComponentCount() throws {
    var doc = try document()
    let output = appendFloats([0, 0, 1, 0, 0.5, 0.5, 0, 0, 0, 1, 0, 0], type: "SCALAR", to: &doc)
    var animations = doc["animations"] as! [[String: Any]]
    animations[0]["samplers"] = [["input": 6, "output": output, "interpolation": "CUBICSPLINE"]]
    doc["animations"] = animations
    let sampler = try GLTFSwift.load(from: write(doc)).animations[0].samplers[0]
    XCTAssertEqual(sampler.interpolation, .cubicSpline)
    XCTAssertEqual(sampler.componentsPerValue, 2)
    XCTAssertEqual(sampler.values.count, 12)
    XCTAssertEqual(sampler.values[4], 0.5)
  }

  func testTranslationScaleAndRotationChannelsAreImportedAsData() throws {
    var doc = try document()
    let translation = appendFloats([0, 1, 2, 3, 4, 5], type: "VEC3", to: &doc)
    let rotation = appendFloats([0, 0, 0, 1, 0, 0, 1, 0], type: "VEC4", to: &doc)
    doc["animations"] = [
      [
        "samplers": [
          ["input": 6, "output": translation, "interpolation": "STEP"],
          ["input": 6, "output": rotation],
        ],
        "channels": [
          ["sampler": 0, "target": ["node": 0, "path": "translation"]],
          ["sampler": 0, "target": ["node": 0, "path": "scale"]],
          ["sampler": 1, "target": ["node": 0, "path": "rotation"]],
        ],
      ]
    ]
    let clip = try GLTFSwift.load(from: write(doc)).animations[0]
    XCTAssertEqual(clip.channels.map(\.targetPath), [.translation, .scale, .rotation])
    XCTAssertEqual(clip.samplers[0].interpolation, .step)
    XCTAssertEqual(clip.samplers[1].values.suffix(4), [0, 0, 1, 0])
  }

  func testMissingInterpolationDefaultsToLinearAndTimesRemainAuthored() throws {
    var doc = try document()
    let times = appendFloats([2, 12], type: "SCALAR", to: &doc)
    var animations = doc["animations"] as! [[String: Any]]
    animations[0]["samplers"] = [["input": times, "output": 7]]
    doc["animations"] = animations
    let clip = try GLTFSwift.load(from: write(doc)).animations[0]
    XCTAssertEqual(clip.startTime, 2)
    XCTAssertEqual(clip.endTime, 12)
    XCTAssertEqual(clip.duration, 10)
    XCTAssertEqual(clip.samplers[0].interpolation, .linear)
  }

  func testUnsupportedRequiredExtensionIsReported() throws {
    var doc = try document()
    doc["extensionsRequired"] = ["EXT_unknown"]
    XCTAssertThrowsError(try GLTFSwift.load(from: write(doc))) {
      XCTAssertEqual($0 as? GLTFLoadingError, .unsupportedExtension("EXT_unknown"))
    }
  }

  func testSparseAccessorsFailExplicitly() throws {
    var doc = try document()
    var accessors = doc["accessors"] as! [[String: Any]]
    accessors[0]["sparse"] = ["count": 1]
    accessors[0].removeValue(forKey: "bufferView")
    doc["accessors"] = accessors
    XCTAssertThrowsError(try GLTFSwift.load(from: write(doc))) {
      XCTAssertEqual($0 as? GLTFLoadingError, .unsupportedFeature("Sparse accessors"))
    }
  }

  func testCorruptCompressedPayloadThrows() throws {
    var doc = try document()
    var bytes = try Data(
      contentsOf: fixtureURL().deletingLastPathComponent().appendingPathComponent(
        "meshopt-features.bin"))
    bytes[0] = 0
    var buffers = doc["buffers"] as! [[String: Any]]
    buffers[0]["uri"] = "data:application/octet-stream;base64," + bytes.base64EncodedString()
    doc["buffers"] = buffers
    XCTAssertThrowsError(try GLTFSwift.load(from: write(doc))) { error in
      guard case GLTFLoadingError.meshoptDecodingFailed = error else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testBadMeshoptDescriptorsFailBeforeDecoding() throws {
    for change: [String: Any] in [
      ["mode": "INVALID"], ["filter": "INVALID"], ["filter": "QUATERNION", "byteStride": 4],
      ["count": Int.max], ["byteOffset": -1], ["byteLength": Int.max],
    ] {
      var doc = try document()
      var views = doc["bufferViews"] as! [[String: Any]]
      var extensions = views[0]["extensions"] as! [String: Any]
      var compression = extensions["EXT_meshopt_compression"] as! [String: Any]
      compression.merge(change) { _, new in new }
      extensions["EXT_meshopt_compression"] = compression
      views[0]["extensions"] = extensions
      doc["bufferViews"] = views
      XCTAssertThrowsError(try GLTFSwift.load(from: write(doc)), "Expected failure for \(change)")
    }
  }

  func testAccessorOverrunsAndInvalidReferencesThrow() throws {
    for change: [String: Any] in [
      ["count": 4], ["bufferView": 999], ["byteOffset": 1], ["byteOffset": Int.max], ["count": -1],
    ] {
      var doc = try document()
      var accessors = doc["accessors"] as! [[String: Any]]
      accessors[0].merge(change) { _, new in new }
      doc["accessors"] = accessors
      XCTAssertThrowsError(try GLTFSwift.load(from: write(doc)))
    }
  }

  func testInvalidMorphCountThrows() throws {
    var doc = try document()
    var accessors = doc["accessors"] as! [[String: Any]]
    accessors[4]["count"] = 2
    doc["accessors"] = accessors
    XCTAssertThrowsError(try GLTFSwift.load(from: write(doc)))
  }

  func testNonIncreasingAnimationTimesThrow() throws {
    for values: [Float] in [[0, 0], [10, 0], [-1, 1]] {
      var doc = try document()
      let input = appendFloats(values, type: "SCALAR", to: &doc)
      var animations = doc["animations"] as! [[String: Any]]
      animations[0]["samplers"] = [["input": input, "output": 7]]
      doc["animations"] = animations
      XCTAssertThrowsError(try GLTFSwift.load(from: write(doc)))
    }
  }

  func testAnimationCountAndChannelReferencesAreValidated() throws {
    for channel: [String: Any] in [
      ["sampler": 99, "target": ["node": 0, "path": "weights"]],
      ["sampler": 0, "target": ["node": 99, "path": "weights"]],
      ["sampler": 0, "target": ["node": 0, "path": "rotation"]],
    ] {
      var doc = try document()
      var animations = doc["animations"] as! [[String: Any]]
      animations[0]["channels"] = [channel]
      doc["animations"] = animations
      XCTAssertThrowsError(try GLTFSwift.load(from: write(doc)))
    }
    var doc = try document()
    let output = appendFloats([1, 0, 0], type: "SCALAR", to: &doc)
    var animations = doc["animations"] as! [[String: Any]]
    animations[0]["samplers"] = [["input": 6, "output": output]]
    doc["animations"] = animations
    XCTAssertThrowsError(try GLTFSwift.load(from: write(doc)))
  }

  func testGLBHasClearUnsupportedError() throws {
    let directory = try makeDirectory()
    let url = directory.appendingPathComponent("model.glb")
    try Data([0x67, 0x6c, 0x54, 0x46]).write(to: url)
    XCTAssertThrowsError(try GLTFSwift.load(from: url)) {
      guard case GLTFLoadingError.unsupportedFeature = $0 else {
        return XCTFail("Unexpected error: \($0)")
      }
    }
  }

  /// Optional end-to-end check against an externally exported water/deformation asset.
  func testExternalDeformationAssetWhenProvided() throws {
    guard let path = ProcessInfo.processInfo.environment["GLTFSWIFT_DEFORMATION_FIXTURE"] else {
      throw XCTSkip(
        "Set GLTFSWIFT_DEFORMATION_FIXTURE to a Meshopt .gltf for external export validation.")
    }
    let asset = try GLTFSwift.load(from: URL(fileURLWithPath: path))
    let primitives = asset.meshes.flatMap(\.primitives)
    XCTAssertFalse(primitives.isEmpty)
    XCTAssertFalse(asset.animations.isEmpty)
    XCTAssertTrue(primitives.contains { !$0.morphTargets.isEmpty })
    for primitive in primitives {
      for target in primitive.morphTargets {
        XCTAssertEqual(target.positions?.count, primitive.vertices.count)
      }
    }
    XCTAssertTrue(asset.animations.allSatisfy { $0.duration > 0 && !$0.channels.isEmpty })
    print(
      "External deformation: \(primitives.reduce(0) { $0 + $1.vertices.count }) vertices, \(primitives.reduce(0) { $0 + $1.morphTargets.count }) targets, durations \(asset.animations.map(\.duration))"
    )
  }

  private func fixtureURL() throws -> URL {
    try XCTUnwrap(Bundle.module.url(forResource: "meshopt-features", withExtension: "gltf"))
  }
  private func document() throws -> [String: Any] {
    try JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL())) as! [String: Any]
  }
  private func write(_ source: [String: Any]) throws -> URL {
    var doc = source
    var buffers = doc["buffers"] as! [[String: Any]]
    for i in buffers.indices where buffers[i]["uri"] as? String == "meshopt-features.bin" {
      buffers[i]["uri"] = try fixtureURL().deletingLastPathComponent().appendingPathComponent(
        "meshopt-features.bin"
      ).absoluteString
    }
    doc["buffers"] = buffers
    let url = try makeDirectory().appendingPathComponent("model.gltf")
    try JSONSerialization.data(withJSONObject: doc).write(to: url)
    return url
  }
  private func makeReader(_ doc: [String: Any]) throws -> AccessorReader {
    let url = try write(doc)
    let container = try JSONDecoder().decode(GLTFContainer.self, from: Data(contentsOf: url))
    return try AccessorReader(container: container, fileURL: url)
  }
  private func makeDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    directories.append(directory)
    return directory
  }
  private func append<T>(_ value: T, to data: inout Data) {
    var value = value
    withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
  }
  private func appendFloats(_ values: [Float], type: String, to doc: inout [String: Any]) -> Int {
    var bytes = Data()
    for value in values { append(value.bitPattern.littleEndian, to: &bytes) }
    var buffers = doc["buffers"] as! [[String: Any]]
    let bufferIndex = buffers.count
    buffers.append([
      "uri": "data:application/octet-stream;base64," + bytes.base64EncodedString(),
      "byteLength": bytes.count,
    ])
    doc["buffers"] = buffers
    var views = doc["bufferViews"] as! [[String: Any]]
    let viewIndex = views.count
    views.append(["buffer": bufferIndex, "byteLength": bytes.count])
    doc["bufferViews"] = views
    var accessors = doc["accessors"] as! [[String: Any]]
    let index = accessors.count
    accessors.append([
      "bufferView": viewIndex, "componentType": 5126,
      "count": values.count / (type == "VEC4" ? 4 : type == "VEC3" ? 3 : 1), "type": type,
    ])
    doc["accessors"] = accessors
    return index
  }
}
