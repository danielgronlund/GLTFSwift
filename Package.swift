// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "GLTFSwift",
  products: [
    .library(
      name: "GLTFSwift",
      targets: ["GLTFSwift"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/danielgronlund/decompress-draco-swift.git", revision: "0.0.7"),
    .package(url: "https://github.com/danielgronlund/meshoptimizer.git", branch: "swift-package-manager")
  ],
  targets: [
    .target(
      name: "CMeshopt",
      dependencies: [
        .product(name: "meshoptimizer", package: "meshoptimizer")
      ],
      publicHeadersPath: "include"
    ),
    .target(
      name: "GLTFSwift",
      dependencies: [
        "CMeshopt",
        .product(name: "DracoDecompressSwift", package: "decompress-draco-swift")]
    ),
    .testTarget(
      name: "GLTFSwiftTests",
      dependencies: [
        "GLTFSwift",
      ],
      resources: [.process("Resources")]
    )
  ]
)
