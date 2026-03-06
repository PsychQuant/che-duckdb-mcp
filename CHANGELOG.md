# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-03-07

### Changed
- Upgrade DuckDB engine from v1.1.3 to v1.5.0-dev (supports storage format v1.0 ~ v1.5)
- Upgrade MCP Swift SDK from 0.10.2 to 0.11.0
- Switch `duckdb-swift` dependency to `branch: "main"` for latest engine

### Fixed
- Fix `DuckDB.DatabaseError error 5` when opening databases created with DuckDB v1.2+

## [1.0.0] - 2025-01-19

### Added
- Initial release combining documentation search and database operations
- **Documentation Tools (8 tools)**:
  - `search_docs` - Search DuckDB documentation by keyword
  - `list_sections` - List all documentation sections
  - `get_section` - Get content of a specific documentation section
  - `get_function_docs` - Get documentation for a specific DuckDB function
  - `list_functions` - List all documented DuckDB functions
  - `get_sql_syntax` - Get SQL syntax documentation for a statement type
  - `refresh_docs` - Force re-download the DuckDB documentation
  - `get_doc_info` - Get information about the loaded documentation
- **Database Tools (6 tools)**:
  - `db_connect` - Connect to a DuckDB database file or in-memory database
  - `db_query` - Execute SELECT queries with JSON/Markdown/CSV output
  - `db_execute` - Execute DDL/DML statements
  - `db_list_tables` - List all tables and views
  - `db_describe` - Describe table structure or query result schema
  - `db_info` - Get information about the current database connection
- Support for JSON, Markdown, and CSV output formats
- Automatic documentation caching in temporary directory
