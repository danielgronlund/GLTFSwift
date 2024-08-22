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
    .package(url: "git@github.com:danielgronlund/decompress-draco-swift.git", exact: Version(0, 0, 4))
  ],
  targets: [
    .target(
      name: "GLTFSwift",
      dependencies: [
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
