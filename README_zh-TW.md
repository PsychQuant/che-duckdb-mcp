# che-duckdb-mcp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

**DuckDB 文檔與資料庫 MCP Server** - 整合文檔查詢與資料庫操作的一站式解決方案。

[English](README.md) | [繁體中文](README_zh-TW.md)

---

## 為什麼選擇 che-duckdb-mcp？

| 功能 | 其他 DuckDB MCP | che-duckdb-mcp |
|------|-----------------|----------------|
| 資料庫查詢 | 是 | 是 |
| **文檔搜索** | 否 | **是** |
| **函數文檔** | 否 | **是** |
| **SQL 語法參考** | 否 | **是** |
| **多種輸出格式** | 部分 | **是 (JSON/Markdown/CSV)** |
| **記憶體資料庫** | 部分 | **是** |
| 語言 | Python | **Swift (原生)** |

---

## 快速開始

### Claude Code (CLI)

```bash
# 建立 ~/bin（如果不存在）
mkdir -p ~/bin

# 編譯
git clone https://github.com/kiki830621/che-duckdb-mcp.git
cd che-duckdb-mcp
swift build -c release

# 安裝
cp .build/release/CheDuckDBMCP ~/bin/

# 加入 Claude Code
claude mcp add --scope user --transport stdio che-duckdb-mcp -- ~/bin/CheDuckDBMCP
```

### Claude Desktop

編輯 `~/Library/Application Support/Claude/claude_desktop_config.json`：

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

## 全部 14 個工具

<details>
<summary><b>文檔工具 (8 個)</b></summary>

| 工具 | 功能 | 只讀 |
|------|------|------|
| `search_docs` | 搜索 DuckDB 文檔 | ✓ |
| `list_sections` | 列出所有文檔章節 | ✓ |
| `get_section` | 取得特定章節內容 | ✓ |
| `get_function_docs` | 查詢函數文檔 | ✓ |
| `list_functions` | 列出所有已記錄的函數 | ✓ |
| `get_sql_syntax` | 查詢 SQL 語法文檔 | ✓ |
| `refresh_docs` | 強制重新下載文檔 | ✗ |
| `get_doc_info` | 取得文檔快取資訊 | ✓ |

</details>

<details>
<summary><b>資料庫工具 (6 個)</b></summary>

| 工具 | 功能 | 只讀 |
|------|------|------|
| `db_connect` | 連接資料庫（檔案或記憶體） | ✗ |
| `db_query` | 執行 SELECT 查詢 | ✓ |
| `db_execute` | 執行 DDL/DML 語句 | ✗ |
| `db_list_tables` | 列出所有表格和視圖 | ✓ |
| `db_describe` | 描述表格結構或查詢結果 | ✓ |
| `db_info` | 取得目前連線資訊 | ✓ |

</details>

---

## 使用範例

### 文檔查詢

```
「搜索 read_csv 的用法」
「json_extract 函數怎麼用？」
「COPY 語句的語法是什麼？」
「列出所有 DuckDB 函數」
```

### 資料庫操作

```
「連接到記憶體資料庫」
「建立一個使用者表格，包含 id 和 name 欄位」
「插入幾筆測試資料」
「用 Markdown 格式顯示所有使用者」
「列出所有表格」
「描述 users 表格的結構」
```

### 連接檔案資料庫

```
「連接到 /path/to/database.duckdb」
「以唯讀模式開啟資料庫」
```

---

## 輸出格式

`db_query` 支援三種輸出格式：

### JSON 格式（預設）
```json
[
  {"id": 1, "name": "Alice"},
  {"id": 2, "name": "Bob"}
]
```

### Markdown 格式（推薦閱讀）
```markdown
| id | name  |
|---:|-------|
| 1  | Alice |
| 2  | Bob   |
```

### CSV 格式
```csv
id,name
1,Alice
2,Bob
```

---

## 安全考量

1. **查詢驗證**：`db_query` 僅允許 SELECT、WITH、SHOW、DESCRIBE、EXPLAIN、PRAGMA
2. **資源限制**：預設限制返回 1000 行
3. **唯讀模式**：支援以唯讀模式開啟資料庫
4. **本地存取**：僅支援本地檔案，不支援遠端連線

---

## 技術細節

- **目前版本**：v1.1.0
- **框架**：[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) v0.11.0
- **DuckDB 綁定**：[duckdb-swift](https://github.com/duckdb/duckdb-swift)（main branch，~v1.5.0-dev）
- **傳輸方式**：stdio
- **平台需求**：macOS 13.0+
- **工具數量**：14 個（8 文檔 + 6 資料庫）

---

## 快取位置

- **文檔快取**：系統暫存目錄（自動清理）
- **快取過期**：24 小時

---

## 疑難排解

| 問題 | 解決方案 |
|------|----------|
| Server disconnected | 重新編譯 `swift build -c release` |
| 文檔載入失敗 | 檢查網路連線，或使用 `refresh_docs` 強制更新 |
| 資料庫連線失敗 | 確認檔案路徑正確且有讀取權限 |

---

## 授權

MIT License - 詳見 [LICENSE](LICENSE)

---

## 作者

由 **Che Cheng** ([@kiki830621](https://github.com/kiki830621)) 創建

如果這個專案對你有幫助，歡迎給個星星！
