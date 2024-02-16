import XCTest
import Metal
@testable import GLTFSwift

final class FileLoadingTests: XCTestCase {
  var device: MTLDevice!
  var loader: GLTFLoader!

  override func setUpWithError() throws {
    self.device = MTLCreateSystemDefaultDevice()!
    self.loader = GLTFLoader(device: device)
    try super.setUpWithError()
  }

  func testLoadFile() throws {
    _ = try loader.loadContainer(path: "simple-cube.gltf", in: .module)
  }

  func testLoadFileWithJoints() throws {
    _ = try loader.loadContainer(path: "simple-cube-joints.gltf", in: .module)
  }
}
