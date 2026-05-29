# che-duckdb-mcp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

**DuckDB Documentation & Database MCP Server** — All-in-one Swift-native solution for DuckDB documentation search and database operations.

[English](README.md) | [繁體中文](README_zh-TW.md)

---

## Why che-duckdb-mcp?

| Feature | Other DuckDB MCPs | che-duckdb-mcp v2 |
|---------|-------------------|-------------------|
| Database Queries | Yes | Yes |
| **TF-IDF Documentation Search** | No | **Yes** (inverted index + cosine similarity) |
| **Fuzzy Function Matching** | No | **Yes** (Levenshtein ≤ 2) |
| **Dual-source docs** (llms.txt + full) | No | **Yes** |
| **SQL Syntax Reference** | No | **Yes** |
| **Multiple Output Formats** | Some | **Yes** (JSON / Markdown / CSV) |
| **In-Memory Database** | Some | **Yes** |
| **Rich DuckDB error messages** | Partial | **Yes** (Binder/Catalog/Parser) |
| Language | Python | **Swift (native binary, zero runtime deps)** |

---

## Install

Three ways to install, pick what fits your workflow.

### 1. Claude Code Plugin (recommended — auto-download)

```
/plugin marketplace add psychquant-claude-plugins
/plugin install che-duckdb-mcp@psychquant-claude-plugins
```

On first use, the plugin's wrapper script auto-downloads the latest `CheDuckDBMCP` binary from [GitHub Releases](https://github.com/PsychQuant/che-duckdb-mcp/releases) to `~/bin/`. No manual build required.

### 2. Manual binary (for Claude Code `claude mcp add`)

```bash
# Option A: download pre-built binary
mkdir -p ~/bin
curl -L -o ~/bin/CheDuckDBMCP \
  https://github.com/PsychQuant/che-duckdb-mcp/releases/latest/download/CheDuckDBMCP
chmod +x ~/bin/CheDuckDBMCP

# Option B: build from source (requires Swift 5.9+, macOS 13+)
git clone https://github.com/PsychQuant/che-duckdb-mcp.git
cd che-duckdb-mcp
swift build -c release
cp .build/release/CheDuckDBMCP ~/bin/

# Register with Claude Code
claude mcp add --scope user --transport stdio che-duckdb-mcp -- ~/bin/CheDuckDBMCP
```

### 3. Claude Desktop

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

After install, restart Claude Code / Claude Desktop to load the new MCP server.

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

## What's New in v2.0

- **TF-IDF search engine** — inverted index + cosine similarity ranking, orders of magnitude better than substring match
- **Dual-source documentation** — merges `llms.txt` (3 KB LLM reference) and `duckdb-docs.md` (5 MB full docs); llms.txt matches receive a 1.5× score bonus
- **Fuzzy function matching** — Levenshtein distance ≤ 2 with case / underscore normalization (`read_csvs` → `read_csv`, `JSON_EXTRACT` → `json_extract`)
- **Conditional HTTP caching** — ETag / Last-Modified replace the old 24-hour fixed expiry, so the 5 MB docs blob is no longer re-downloaded daily
- **Pinned duckdb-swift revision** — no more surprise storage-format breakage from automated upstream updates
- **Storage-version compatibility check** — `db_connect` reads the file header before opening
- **Real DuckDB error messages** — `Binder Error` / `Catalog Error` / `Parser Error` now surface cleanly through MCP responses instead of opaque `DuckDB.DatabaseError error N` ([fix #1](https://github.com/PsychQuant/che-duckdb-mcp/issues/1))

---

## Technical Details

- **Current Version**: v2.3.0
- **Framework**: [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) v0.12.0
- **DuckDB Binding**: [duckdb-swift](https://github.com/duckdb/duckdb-swift) pinned revision `4d9fb7c` (DuckDB v1.6.0-dev3343 — reads DBs written by R duckdb v1.5.2)
- **Transport**: stdio
- **Platform**: macOS 13.0+ (Ventura and later)
- **Tools**: 14 tools (8 documentation + 6 database)

---

## Cache Location

- **Cache directory**: `~/.cache/che-duckdb-mcp/`
  - `llms.txt` — lightweight LLM reference
  - `duckdb-docs.md` — full documentation
  - `cache-meta.json` — ETag / Last-Modified metadata
- **Update strategy**: HTTP conditional requests (no fixed expiry)

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
