// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "GLTFSwift",
  products: [
    .library(
      name: "GLTFSwift",
      targets: ["GLTFSwift"]
    )
  ],
  targets: [
    .target(
      name: "GLTFSwift"
    )
  ]
)
