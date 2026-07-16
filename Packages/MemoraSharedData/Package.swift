// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MemoraSharedData",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "MemoraSharedData", targets: ["MemoraSharedData"]),
    .library(name: "MemoraSharedSchema", targets: ["MemoraSharedSchema"]),
    .library(name: "MemoraSharedCore", targets: ["MemoraSharedCore"]),
    .library(name: "MemoraSharedSummary", targets: ["MemoraSharedSummary"])
  ],
  targets: [
    .target(name: "MemoraSharedCore"),
    .target(name: "MemoraSharedSummary", dependencies: ["MemoraSharedCore"]),
    .target(name: "MemoraSharedSchema"),
    .target(name: "MemoraSharedData", dependencies: ["MemoraSharedSchema"]),
    .testTarget(name: "MemoraSharedDataTests", dependencies: ["MemoraSharedData", "MemoraSharedSchema", "MemoraSharedCore", "MemoraSharedSummary"])
  ]
)
