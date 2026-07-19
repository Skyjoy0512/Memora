// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Seeder",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../../../../../Packages/MemoraSharedData")
    ],
    targets: [
        .executableTarget(
            name: "Seeder",
            dependencies: [
                .product(name: "MemoraSharedSchema", package: "MemoraSharedData"),
                .product(name: "MemoraSharedData", package: "MemoraSharedData")
            ]
        )
    ]
)
