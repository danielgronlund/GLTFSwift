import XCTest
@testable import GLTFSwift

final class FileLoadingTests: XCTestCase {
  var device: MTLDevice!
  var loader: GLTFLoader!

  override func setUpWithError() throws {
    self.device = MTLCreateSystemDefaultDevice()!
    self.loader = GLTFLoader()
    try super.setUpWithError()
  }

  func testLoadFile() throws {
    let url = try given(resource: "simple-cube.gltf", in: .module)
    _ = try loader.loadContainer(from: url)
  }

  func testLoadFileWithJoints() throws {
    let url = try given(resource: "simple-cube-joints.gltf", in: .module)
    _ = try loader.loadContainer(from: url)
  }

  func testLoadCompressedModel() throws {
    let url = try given(resource: "draco-compressed.gltf", in: .module)

    _ = try loader.loadContainer(from: url)
  }

  func testLoadUV() throws {
    let url = try given(resource: "uv_cube.gltf", in: .module)

    _ = try loader.loadContainer(from: url)
    // TODO: Verify UV Coordinates
  }

  func testLoadUVCompressed() throws {
    let url = try given(resource: "uv_cube_compressed.gltf", in: .module)
    _ = try loader.loadContainer(from: url)
    // TODO: Verify UV Coordinates
  }

  func testLoadMaterialTexture() throws {
    let url = try given(resource: "gold-box.gltf", in: .module)
    let asset = try loader.loadContainer(from: url)

    let primitive = try XCTUnwrap(asset.meshes.first?.primitives.first)
    let material = try XCTUnwrap(primitive.material)
    let baseColorTexture = try XCTUnwrap(material.baseColorTexture)

    XCTAssertEqual(baseColorTexture.uri, "Material_001_baseColor.png")
    XCTAssertEqual(baseColorTexture.mimeType, "image/png")
    XCTAssertFalse((baseColorTexture.data ?? Data()).isEmpty)
  }

  func testDefaultVertexColorIsWhiteWhenColorAttributeIsMissing() throws {
    let url = try given(resource: "gold-box.gltf", in: .module)
    let asset = try loader.loadContainer(from: url)

    let primitive = try XCTUnwrap(asset.meshes.first?.primitives.first)
    let firstColor = try XCTUnwrap(primitive.vertices.first?.color)

    XCTAssertEqual(firstColor.x, 1, accuracy: 0.0001)
    XCTAssertEqual(firstColor.y, 1, accuracy: 0.0001)
    XCTAssertEqual(firstColor.z, 1, accuracy: 0.0001)
    XCTAssertEqual(firstColor.w, 1, accuracy: 0.0001)
  }

  func given(resource: String, in bundle: Bundle, file: StaticString = #file, line: UInt =  #line) throws -> URL {
    let url = bundle.url(forResource: resource, withExtension: nil)
    return try given(url: url, file: file, line: line)
  }

  func given(url: URL?, file: StaticString = #file, line: UInt = #line) throws -> URL {
    try XCTUnwrap(url, file: file, line: line)
  }
}
