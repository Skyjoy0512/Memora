// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MemoraSharedData",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "MemoraSharedData", targets: ["MemoraSharedData"]),
    .library(name: "MemoraSharedSchema", targets: ["MemoraSharedSchema"])
  ],
  targets: [
    .target(name: "MemoraSharedSchema"),
    .target(name: "MemoraSharedData", dependencies: ["MemoraSharedSchema"]),
    .testTarget(name: "MemoraSharedDataTests", dependencies: ["MemoraSharedData", "MemoraSharedSchema"])
  ]
)
