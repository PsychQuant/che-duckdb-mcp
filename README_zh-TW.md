# che-duckdb-mcp

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

**DuckDB 文檔與資料庫 MCP Server** — Swift 原生的一站式方案，整合文檔查詢與本地資料庫操作。

[English](README.md) | [繁體中文](README_zh-TW.md)

---

## 為什麼選擇 che-duckdb-mcp？

| 功能 | 其他 DuckDB MCP | che-duckdb-mcp v2 |
|------|-----------------|-------------------|
| 資料庫查詢 | 是 | 是 |
| **TF-IDF 文檔搜尋** | 否 | **是**（倒排索引 + cosine similarity） |
| **函數模糊比對** | 否 | **是**（Levenshtein ≤ 2） |
| **雙來源文檔**（llms.txt + 完整版） | 否 | **是** |
| **SQL 語法參考** | 否 | **是** |
| **多種輸出格式** | 部分 | **是**（JSON / Markdown / CSV） |
| **記憶體資料庫** | 部分 | **是** |
| **完整 DuckDB 錯誤訊息** | 部分 | **是**（Binder/Catalog/Parser） |
| 語言 | Python | **Swift（原生 binary、零 runtime 依賴）** |

---

## 安裝

三種方式，任選一種。

### 方式 1：Claude Code Plugin（推薦，自動下載 binary）

```
/plugin marketplace add psychquant-claude-plugins
/plugin install che-duckdb-mcp@psychquant-claude-plugins
```

首次使用時，plugin 的 wrapper script 會自動從 [GitHub Releases](https://github.com/PsychQuant/che-duckdb-mcp/releases) 下載最新的 `CheDuckDBMCP` binary 到 `~/bin/`，不需要手動編譯。

### 方式 2：手動安裝 Binary（供 `claude mcp add` 使用）

```bash
# 選項 A：下載預先編譯的 binary
mkdir -p ~/bin
curl -L -o ~/bin/CheDuckDBMCP \
  https://github.com/PsychQuant/che-duckdb-mcp/releases/latest/download/CheDuckDBMCP
chmod +x ~/bin/CheDuckDBMCP

# 選項 B：從原始碼編譯（需要 Swift 5.9+、macOS 13+）
git clone https://github.com/PsychQuant/che-duckdb-mcp.git
cd che-duckdb-mcp
swift build -c release
cp .build/release/CheDuckDBMCP ~/bin/

# 加入 Claude Code
claude mcp add --scope user --transport stdio che-duckdb-mcp -- ~/bin/CheDuckDBMCP
```

### 方式 3：Claude Desktop

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

安裝完成後，重啟 Claude Code / Claude Desktop 才會載入新的 MCP server。

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

## v2.0 新功能

- **TF-IDF 搜尋引擎** — 倒排索引 + cosine similarity 排序，比 substring match 精準一個數量級
- **雙來源文檔** — 合併 `llms.txt`（3 KB LLM 參考）和 `duckdb-docs.md`（5 MB 完整版），llms.txt 命中額外加 1.5× 分數
- **函數模糊比對** — Levenshtein distance ≤ 2，支援大小寫和底線正規化（`read_csvs` → `read_csv`、`JSON_EXTRACT` → `json_extract`）
- **HTTP 條件式快取** — 以 ETag / Last-Modified 取代固定 24 小時過期，5 MB 的文檔不再每日重下
- **Pinned duckdb-swift revision** — 避免 upstream automated update 造成的 storage format 破壞
- **Storage version 相容性檢查** — `db_connect` 開啟檔案前先讀取 header
- **真實的 DuckDB 錯誤訊息** — `Binder Error` / `Catalog Error` / `Parser Error` 直接透過 MCP response 穿透，不再是 opaque `DuckDB.DatabaseError error N`（[fix #1](https://github.com/PsychQuant/che-duckdb-mcp/issues/1)）

---

## 技術細節

- **目前版本**：v2.3.0
- **框架**：[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) v0.12.0
- **DuckDB 綁定**：[duckdb-swift](https://github.com/duckdb/duckdb-swift) pinned revision `4d9fb7c`（DuckDB v1.6.0-dev3343 — 可讀取 R duckdb v1.5.2 寫入的資料庫）
- **傳輸方式**：stdio
- **平台需求**：macOS 13.0+
- **工具數量**：14 個（8 文檔 + 6 資料庫）

---

## 快取位置

- **快取目錄**：`~/.cache/che-duckdb-mcp/`
  - `llms.txt` — LLM 精簡參考
  - `duckdb-docs.md` — 完整文檔
  - `cache-meta.json` — ETag / Last-Modified metadata
- **更新策略**：HTTP 條件式請求（無固定過期時間）

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
