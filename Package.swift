// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheDuckDBMCP",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/duckdb/duckdb-swift.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "CheDuckDBMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "DuckDB", package: "duckdb-swift")
            ],
            path: "Sources/CheDuckDBMCP"
        )
    ]
)
