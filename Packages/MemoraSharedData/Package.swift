// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MemoraSharedData",
  platforms: [.iOS(.v16)],
  products: [
    .library(name: "MemoraSharedData", targets: ["MemoraSharedData"])
  ],
  targets: [
    .target(name: "MemoraSharedData"),
    .testTarget(name: "MemoraSharedDataTests", dependencies: ["MemoraSharedData"])
  ]
)
