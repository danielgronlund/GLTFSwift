import XCTest
import Metal
@testable import GLTFSwift

final class FileLoadingTests: XCTestCase {
  let device: MTLDevice = MTLCreateSystemDefaultDevice()!

  func testLoadFile() throws {
    let scene = try Scene.load(from: "simple-cube.gltf", in: Bundle.module, device: device)
    XCTAssertNotNil(scene["Cube"])
  }
}
