# che-duckdb-mcp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

**DuckDB Documentation & Database MCP Server** - All-in-one solution for DuckDB documentation search and database operations.

[English](README.md) | [繁體中文](README_zh-TW.md)

---

## Why che-duckdb-mcp?

| Feature | Other DuckDB MCPs | che-duckdb-mcp |
|---------|-------------------|----------------|
| Database Queries | Yes | Yes |
| **Documentation Search** | No | **Yes** |
| **Function Docs** | No | **Yes** |
| **SQL Syntax Reference** | No | **Yes** |
| **Multiple Output Formats** | Some | **Yes (JSON/Markdown/CSV)** |
| **In-Memory Database** | Some | **Yes** |
| Language | Python | **Swift (Native)** |

---

## Quick Start

### For Claude Code (CLI)

```bash
# Create ~/bin if needed
mkdir -p ~/bin

# Build from source
git clone https://github.com/kiki830621/che-duckdb-mcp.git
cd che-duckdb-mcp
swift build -c release

# Install
cp .build/release/CheDuckDBMCP ~/bin/

# Register with Claude Code
claude mcp add --scope user --transport stdio che-duckdb-mcp -- ~/bin/CheDuckDBMCP
```

### For Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "che-duckdb-mcp": {
      "command": "/Users/YOUR_USERNAME/bin/CheDuckDBMCP"
    }
  }
}
```

---

## All 14 Tools

<details>
<summary><b>Documentation Tools (8)</b></summary>

| Tool | Description | Read-Only |
|------|-------------|-----------|
| `search_docs` | Search DuckDB documentation by keyword | ✓ |
| `list_sections` | List all documentation sections | ✓ |
| `get_section` | Get content of a specific section | ✓ |
| `get_function_docs` | Get documentation for a DuckDB function | ✓ |
| `list_functions` | List all documented functions | ✓ |
| `get_sql_syntax` | Get SQL syntax documentation | ✓ |
| `refresh_docs` | Force re-download documentation | ✗ |
| `get_doc_info` | Get documentation cache info | ✓ |

</details>

<details>
<summary><b>Database Tools (6)</b></summary>

| Tool | Description | Read-Only |
|------|-------------|-----------|
| `db_connect` | Connect to database (file or in-memory) | ✗ |
| `db_query` | Execute SELECT queries | ✓ |
| `db_execute` | Execute DDL/DML statements | ✗ |
| `db_list_tables` | List all tables and views | ✓ |
| `db_describe` | Describe table structure or query result | ✓ |
| `db_info` | Get current connection info | ✓ |

</details>

---

## Usage Examples

### Documentation Queries

```
"Search for how to use read_csv"
"How do I use the json_extract function?"
"What's the syntax for COPY statement?"
"List all DuckDB functions"
```

### Database Operations

```
"Connect to an in-memory database"
"Create a users table with id and name columns"
"Insert some test data"
"Show all users in Markdown format"
"List all tables"
"Describe the users table structure"
```

### File Database Connection

```
"Connect to /path/to/database.duckdb"
"Open the database in read-only mode"
```

---

## Output Formats

`db_query` supports three output formats:

### JSON Format (Default)
```json
[
  {"id": 1, "name": "Alice"},
  {"id": 2, "name": "Bob"}
]
```

### Markdown Format (Recommended for Reading)
```markdown
| id | name  |
|---:|-------|
| 1  | Alice |
| 2  | Bob   |
```

### CSV Format
```csv
id,name
1,Alice
2,Bob
```

---

## Security Considerations

1. **Query Validation**: `db_query` only allows SELECT, WITH, SHOW, DESCRIBE, EXPLAIN, PRAGMA
2. **Resource Limits**: Default limit of 1000 rows per query
3. **Read-Only Mode**: Support for opening databases in read-only mode
4. **Local Access Only**: Only local files supported, no remote connections

---

## Technical Details

- **Current Version**: v1.1.0
- **Framework**: [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) v0.11.0
- **DuckDB Binding**: [duckdb-swift](https://github.com/duckdb/duckdb-swift) (main branch, ~v1.5.0-dev)
- **Transport**: stdio
- **Platform**: macOS 13.0+ (Ventura and later)
- **Tools**: 14 tools (8 documentation + 6 database)

---

## Cache Location

- **Documentation Cache**: System temporary directory (auto-cleanup)
- **Cache Expiry**: 24 hours

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Server disconnected | Rebuild with `swift build -c release` |
| Documentation load failed | Check network connection, or use `refresh_docs` |
| Database connection failed | Verify file path and read permissions |

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Author

Created by **Che Cheng** ([@kiki830621](https://github.com/kiki830621))

If you find this useful, please consider giving it a star!
