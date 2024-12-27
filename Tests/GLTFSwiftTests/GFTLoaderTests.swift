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
    _ = try loader.loadContainer(path: "simple-cube.gltf", in: .module)
  }

  func testLoadFileWithJoints() throws {
    _ = try loader.loadContainer(path: "simple-cube-joints.gltf", in: .module)
  }

  func testLoadCompressedModel() throws {
    _ = try loader.loadContainer(path: "draco-compressed.gltf", in: .module)
  }

  func testLoadUV() throws {
    _ = try loader.loadContainer(path: "uv_cube.gltf", in: .module)
    // TODO: Verify UV Coordinates
  }

  func testLoadUVCompressed() throws {
    _ = try loader.loadContainer(path: "uv_cube_compressed.gltf", in: .module)
    // TODO: Verify UV Coordinates
  }
}
