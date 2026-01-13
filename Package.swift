// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChePDFMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ChePDFMCP", targets: ["ChePDFMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "ChePDFMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ]
        )
    ]
)
