<!-- SPECTRA:START v1.0.1 -->

# Spectra Instructions

This project uses Spectra for Spec-Driven Development(SDD). Specs live in `openspec/specs/`, change proposals in `openspec/changes/`.

## Use `/spectra:*` skills when:

- A discussion needs structure before coding → `/spectra:discuss`
- User wants to plan, propose, or design a change → `/spectra:propose`
- Tasks are ready to implement → `/spectra:apply`
- There's an in-progress change to continue → `/spectra:ingest`
- User asks about specs or how something works → `/spectra:ask`
- Implementation is done → `/spectra:archive`

## Workflow

discuss? → propose → apply ⇄ ingest → archive

- `discuss` is optional — skip if requirements are clear
- Requirements change mid-work? Plan mode → `ingest` → resume `apply`

## Parked Changes

Changes can be parked（暫存）— temporarily moved out of `openspec/changes/`. Parked changes won't appear in `spectra list` but can be found with `spectra list --parked`. To restore: `spectra unpark <name>`. The `/spectra:apply` and `/spectra:ingest` skills handle parked changes automatically.

<!-- SPECTRA:END -->

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
| `duckdb-swift` 版本策略 | **Pinned revision**（不追 main branch） |
| 目前 pinned revision | `d90cf8d`（查看 `Package.swift`） |
| 版本不匹配症狀 | `storageVersionMismatch` 結構化錯誤 |

### 版本 pin 策略

`Package.swift` 使用 `.revision("commit_hash")` 而非 `branch: "main"`。
這避免了 automated update 導致的 storage format 不匹配。

### 升級 duckdb-swift 流程

1. 查看 [duckdb/duckdb-swift](https://github.com/duckdb/duckdb-swift) 最新 commit
2. 更新 `Package.swift` 中的 revision hash
3. 更新 `DatabaseManager.swift` 中的 `swiftBindingRevision` 常數
4. `swift package resolve && swift build -c release`
5. 測試 `db_connect` + `db_query` 確認可讀取目標檔案
6. 同步 binary 到 `~/bin/`
7. 更新 CHANGELOG.md

## 開發

```bash
swift build              # 開發版
swift build -c release   # Release 版
```

## 部署

使用 `/mcp-tools:mcp-deploy` 執行完整部署流程。
