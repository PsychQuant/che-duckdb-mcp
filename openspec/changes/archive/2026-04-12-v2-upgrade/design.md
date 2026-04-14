## Context

che-duckdb-mcp 是一個 Swift 原生的 DuckDB MCP Server，提供 14 個 tools（8 docs + 6 DB）。目前的架構：

```
DocsManager/
├── DocsManager.swift       下載 duckdb-docs.md (5.4MB)，24 小時快取
├── MarkdownParser.swift     解析 Markdown → Section 陣列
└── SearchEngine.swift       substring match 搜尋 + function/syntax 查找

DatabaseManager/
├── DatabaseManager.swift    DuckDB 連線、查詢（duckdb-swift, branch: main）
└── ResultFormatter.swift    JSON/Markdown/CSV 輸出
```

環境中同時存在三個 DuckDB MCP：
1. `che-duckdb-mcp`（本專案，14 tools）
2. `CheDuckDBDocsMCP`（舊版 docs-only，8 tools，功能完全重疊）
3. `mcp-server-motherduck`（Python，4 DB tools，雲端/本地）

## Goals / Non-Goals

**Goals:**

- 搜尋引擎從 O(n) substring scan 升級為 TF-IDF 加權索引 + fuzzy matching
- 整合 `llms.txt`（3.3KB）作為輕量快速回答來源，`duckdb-docs.md` 作為深度查詢來源
- 快取改為條件式更新（ETag/Last-Modified），減少不必要的 5.4MB 下載
- `duckdb-swift` 改為 pinned version，並在 `db_connect` 時做版本相容性前置檢查
- 統一 DuckDB MCP 為單一入口，退役 `CheDuckDBDocsMCP`

**Non-Goals:**

- 不支援 MotherDuck 雲端或 S3 遠端連線（由 `mcp-server-motherduck` 負責）
- 不新增或移除 MCP tools（維持 14 tools API 穩定）
- 不導入外部搜尋引擎庫（純 Swift 實作）
- 不做語意搜尋 / embedding-based search

## Decisions

### 搜尋引擎架構：TF-IDF 倒排索引

**選擇**：在 `SearchEngine.swift` 中實作 TF-IDF 倒排索引（inverted index）。

**替代方案**：
- BM25：比 TF-IDF 更精確，但實作複雜度高，對文檔搜尋場景的改善有限
- SQLite FTS：需要額外依賴，與「零外部依賴」目標衝突
- 維持 substring match 不改：無法處理拼字變體（`read_csv` vs `ReadCSV`）

**理由**：TF-IDF 是文檔搜尋的標準演算法，Swift 原生實作約 200 行，無外部依賴。倒排索引在文檔載入時建構，搜尋時 O(k) 查找（k = query terms 數量），比目前逐 section 掃描快一個數量級。

### Fuzzy Matching：Levenshtein distance + case-insensitive normalization

**選擇**：對搜尋 query 做 case-insensitive + underscore-insensitive 正規化，並對函式名用 Levenshtein distance（閾值 ≤ 2）做模糊比對。

**替代方案**：
- Soundex/Metaphone：設計給英文姓名，不適合技術術語
- n-gram：對短 query 效果好，但索引記憶體開銷大

**理由**：DuckDB 函式名常見的查詢變體（`readcsv` → `read_csv`、`json_extract` → `jsonextract`）可以用正規化 + 低閾值 Levenshtein 解決。

### 多來源文檔策略：llms.txt 優先、duckdb-docs.md 深度查詢

**選擇**：啟動時同時下載 `llms.txt` 和 `duckdb-docs.md`，搜尋時：
1. 先在 `llms.txt` sections 中搜尋
2. 再在 `duckdb-docs.md` sections 中搜尋
3. 結果合併去重，`llms.txt` 命中的結果獲得額外加分

**替代方案**：
- 只用 llms.txt：太精簡（3.3KB），無法回答細節問題
- 只用 duckdb-docs.md：沒有善用 LLM 最佳化的精簡版
- 用 context7 查詢取代：需要外部 MCP 依賴，不符合自給自足原則

**理由**：兩層來源互補 — `llms.txt` 提供精準摘要（函式概覽、常見模式），`duckdb-docs.md` 提供完整細節（參數說明、範例）。

### 快取策略：HTTP 條件式請求

**選擇**：儲存上次下載的 ETag 和 Last-Modified header，下次更新時用 `If-None-Match` / `If-Modified-Since` 發送條件式請求。304 Not Modified 時跳過下載。

**替代方案**：
- 維持固定 24 小時過期：每天至少下載一次 5.4MB
- 延長過期時間到 7 天：文檔可能過時

**理由**：DuckDB 文檔更新頻率不高（約每週一次），條件式請求在大多數情況下只需 1 個 HTTP HEAD/GET 就能確認不需更新。

### duckdb-swift 版本策略：pinned revision + 相容性檢查

**選擇**：`Package.swift` 從 `branch: "main"` 改為 `.exact("版本號")` 或 `.revision("commit hash")`。在 `db_connect` 時讀取目標 `.duckdb` 檔案的 storage version header，與當前 duckdb-swift 支援的版本範圍比對。

**替代方案**：
- 繼續追 main branch：每次 automated update 都可能 break
- 用 semver range：duckdb-swift 的 semver tag 不穩定

**理由**：`duckdb-swift` 的 main branch 每月自動更新，storage format 變更會導致 `DatabaseError error 5`。pin 到已驗證的 revision 可確保穩定性，升級時透過 CHANGELOG 記錄。

## Risks / Trade-offs

- **[TF-IDF 索引記憶體開銷]** → 5.4MB 文檔的倒排索引約增加 2-5MB 記憶體。Mitigation：MCP server 是長駐 process，可接受的開銷。
- **[llms.txt 格式無保證]** → DuckDB 官方未承諾 llms.txt 格式穩定性。Mitigation：解析時做防禦性處理，格式異常時 fallback 到只用 duckdb-docs.md。
- **[duckdb-swift pin 版本需手動升級]** → 不再自動追蹤最新版。Mitigation：在 CLAUDE.md 和 CHANGELOG 中記錄升級流程，每月檢查一次。
- **[退役 CheDuckDBDocsMCP 影響其他設定]** → 如果有其他 project-level 設定引用 `che-duckdb-docs-mcp`，移除 binary 會導致 MCP 連線失敗。Mitigation：在 migration plan 中全面搜尋設定檔。
