# che-duckdb-mcp

DuckDB 文檔查詢 + 資料庫操作的 MCP Server（Swift）。

## 架構

```
Sources/CheDuckDBMCP/
├── main.swift              # 進入點
├── Server.swift            # MCP Server 設定、tool 註冊
├── Version.swift           # 版本常數
├── DatabaseManager/
│   ├── DatabaseManager.swift   # DuckDB 連線、查詢、DDL/DML
│   └── ResultFormatter.swift   # JSON/Markdown/CSV 輸出
└── DocsManager/
    ├── DocsManager.swift       # 文檔下載、快取管理
    ├── MarkdownParser.swift    # 文檔 Markdown 解析
    └── SearchEngine.swift      # 全文搜尋引擎
```

## DuckDB 版本相容性（重要）

DuckDB 每個大版本更新 storage format，**不向後相容**。

| 項目 | 說明 |
|------|------|
| 目前使用的 `duckdb-swift` | 查看 `Package.resolved` 確認實際版本 |
| `duckdb-swift` 穩定版現況 | 落後官方 Python/CLI 版本，更新較慢 |
| 版本不匹配症狀 | `DuckDB.DatabaseError error 5`（IO error） |

### 檢查資料庫檔案版本

```bash
# 檔案 header offset 0x30 處可讀到建立版本
xxd database.duckdb | head -5
```

### 升級 duckdb-swift 後必做

1. `swift package update`
2. `swift build -c release`
3. 同步 binary：`mcpb/server/` 和 `~/bin/`
4. 測試 `db_connect` + `db_query` 確認可讀取目標檔案

## 開發

```bash
swift build              # 開發版
swift build -c release   # Release 版
```

## 部署

使用 `/mcp-tools:mcp-deploy` 執行完整部署流程。
