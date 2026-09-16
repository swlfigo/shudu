// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"])
    ],
    targets: [
        .target(
            name: "SudokuCore",
            path: "Shared",
            sources: ["Engine", "Game"]
        ),
        .testTarget(
            name: "SudokuCoreTests",
            dependencies: ["SudokuCore"],
            path: "Tests"
        )
    ]
)
