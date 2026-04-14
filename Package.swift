// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheDuckDBMCP",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.0"),
        .package(url: "https://github.com/duckdb/duckdb-swift.git", revision: "d90cf8d1ecf8575a5370b2a5c297b45befec68ed")
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
