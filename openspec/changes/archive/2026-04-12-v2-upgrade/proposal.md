## Why

che-duckdb-mcp 是唯一同時提供 DuckDB 文檔查詢與資料庫操作的 Swift 原生 MCP Server。但目前文檔搜尋只用 substring match（`lowercased().contains()`），缺乏模糊搜尋和相關度排序；文檔來源只有單一 5.4MB blob，沒有善用 DuckDB 官方的 `llms.txt`（3.3KB 精簡版）；`duckdb-swift` 使用 `branch: "main"` 追蹤導致版本不穩定（曾發生 `DatabaseError error 5`）。同時環境中存在舊版 `CheDuckDBDocsMCP` binary 造成功能重疊。

## What Changes

- **文檔搜尋引擎升級**：從純 substring match 改為 TF-IDF 加權 + fuzzy matching，搜尋結果依相關度排序
- **多來源文檔管理**：整合 `llms.txt`（3.3KB，LLM 快速參考）和 `duckdb-docs.md`（5.4MB，完整文檔），搜尋時先查 llms.txt 再查完整文檔
- **快取策略優化**：從固定 24 小時過期改為 ETag/Last-Modified 條件式更新，避免每天重下 5.4MB
- **DuckDB 引擎版本穩定化**：`duckdb-swift` 從 `branch: "main"` 改為 pinned tag/revision，並加入版本相容性檢查
- **退役舊版 CheDuckDBDocsMCP**：移除 `~/bin/CheDuckDBDocsMCP`、清理 `~/.claude.json` 中的 `che-duckdb-docs-mcp` 設定，統一使用 `che-duckdb-mcp`

## Non-Goals

- 不加入 MotherDuck 雲端 / S3 遠端連線支援（定位為本地 Swift 原生工具，雲端場景由 `mcp-server-motherduck` 處理）
- 不改寫為其他語言（維持全 Swift 生態一致性）
- 不新增 MCP tools（維持現有 14 tools 的 API 介面）

## Capabilities

### New Capabilities

- `docs-search`: 文檔搜尋引擎，涵蓋 TF-IDF 評分、fuzzy matching、多來源整合、snippet 擷取
- `docs-source-management`: 文檔來源管理，涵蓋多來源下載（llms.txt + duckdb-docs.md）、條件式快取更新、快取生命週期管理
- `db-engine-compatibility`: DuckDB 引擎版本相容性，涵蓋 duckdb-swift 版本 pinning、storage format 檢查、版本不匹配錯誤處理

### Modified Capabilities

（無 — 目前沒有現有 specs）

## Impact

- 受影響的程式碼：
  - `Sources/CheDuckDBMCP/DocsManager/SearchEngine.swift` — 搜尋引擎重寫
  - `Sources/CheDuckDBMCP/DocsManager/DocsManager.swift` — 多來源下載 + 快取策略
  - `Sources/CheDuckDBMCP/DocsManager/MarkdownParser.swift` — 可能需配合新搜尋索引
  - `Sources/CheDuckDBMCP/DatabaseManager/DatabaseManager.swift` — 版本相容性檢查
  - `Sources/CheDuckDBMCP/Server.swift` — handler 調整配合新搜尋結果格式
  - `Sources/CheDuckDBMCP/Version.swift` — 版本號升至 2.0.0
  - `Package.swift` — duckdb-swift 依賴改為 pinned version
- 受影響的外部設定：
  - `~/.claude.json` — 移除 `che-duckdb-docs-mcp` 項目
  - `~/bin/CheDuckDBDocsMCP` — 移除舊版 binary
