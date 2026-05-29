// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheDuckDBMCP",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.0"),
        .package(url: "https://github.com/duckdb/duckdb-swift.git", revision: "4d9fb7c8ed24610dac96e82b0901b6d3904fc3a8")
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
