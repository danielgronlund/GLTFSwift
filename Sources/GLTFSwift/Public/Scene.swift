import Foundation
import Metal

public enum SceneLoadingError: LocalizedError {
  case resourceNotFound(String)
  case sceneNotFound

  public var errorDescription: String? {
    switch self {
    case .resourceNotFound(let filename):
      "Could not find resource at \(filename)"
    case .sceneNotFound:
      "Could not find scene"
    }
  }
}

open class Scene {
  public let nodes: [Node]?
  public let name: String?

  init(nodes: [Node]?, name: String?) {
    self.nodes = nodes
    self.name = name
  }

  public subscript(_ name: String) -> Node? {
    nodes?.first(where: {
      $0.name == name
    })
  }

  /// Loads the first scene from a GLTF file.
  ///
  /// This function initializes a GLTFLoader with the given Metal device, then loads and parses the GLTF file specified by the filename. It attempts to return the first `Scene` object found within the loaded GLTF file.
  ///
  /// - Parameters:
  ///   - filename: The name of the GLTF file to load. This should include the `.glft` filetype ending.
  ///   - device: The `MTLDevice` used for creating Metal buffers required for the `Scene`'s geometry.
  /// - Returns: The first `Scene` object found within the GLTF file.
  /// - Throws: `SceneLoadingError.sceneNotFound` if no scenes are present in the GLTF file.
  /// - Note: This function only loads the first scene found in the GLTF file and does not handle multiple scenes.
  public static func load(from filename: String, device: MTLDevice) throws -> Scene {
    let loader = GLTFLoader(device: device)
    let scenes = try loader.load(path: filename)

    guard let scene = scenes.first else {
      throw SceneLoadingError.sceneNotFound
    }

    return scene
  }
}
