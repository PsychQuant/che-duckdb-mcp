import Foundation

/// Centralized version management for CheDuckDBMCP
public enum AppVersion {
    /// Current version
    public static let current = "1.1.0"

    /// Application name (used in MCP server registration)
    public static let name = "che-duckdb-mcp"

    /// Display name for human-readable output
    public static let displayName = "DuckDB MCP Server"

    /// Version string for --version output
    public static var versionString: String {
        "CheDuckDBMCP \(current)"
    }

    /// Help message for --help output
    public static var helpMessage: String {
        """
        \(displayName) v\(current)

        An integrated MCP (Model Context Protocol) server for DuckDB.
        Combines documentation queries and database operations.

        USAGE:
            CheDuckDBMCP [OPTIONS]

        OPTIONS:
            -v, --version    Print version information
            -h, --help       Print this help message

        DESCRIPTION:
            This MCP server provides 14 tools for working with DuckDB:

            Documentation Tools (8):
            - search_docs      Search documentation by keyword
            - list_sections    List all documentation sections
            - get_section      Get content of a specific section
            - get_function_docs Get documentation for a specific function
            - list_functions   List all documented functions
            - get_sql_syntax   Get SQL syntax documentation
            - refresh_docs     Force re-download documentation
            - get_doc_info     Get documentation version info

            Database Tools (6):
            - db_connect       Connect to a DuckDB database
            - db_query         Execute SELECT queries
            - db_execute       Execute DDL/DML statements
            - db_list_tables   List tables and views
            - db_describe      Describe table or query structure
            - db_info          Get database information

        DOCUMENTATION SOURCE:
            https://blobs.duckdb.org/docs/duckdb-docs.md

        CACHE LOCATION:
            ~/.cache/che-duckdb-mcp/

        INSTALLATION:
            claude mcp add --scope user che-duckdb-mcp -- ~/bin/CheDuckDBMCP

        REQUIREMENTS:
            - macOS 13.0+
            - Internet connection (for documentation download)

        For more information: https://github.com/kiki830621/che-duckdb-mcp
        """
    }
}
