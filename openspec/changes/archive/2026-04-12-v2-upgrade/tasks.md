## 1. 依賴與版本基礎

- [x] 1.1 duckdb-swift 版本策略：pinned revision + 相容性檢查 — 將 `Package.swift` 的 `duckdb-swift` 從 `branch: "main"` 改為 `.revision("d90cf8d1ecf8575a5370b2a5c297b45befec68ed")`，執行 `swift package resolve` 驗證（Pinned duckdb-swift dependency version）
- [x] 1.2 更新 `Version.swift` 版本號為 2.0.0

## 2. 文檔來源管理（docs-source-management）

- [x] 2.1 Dual documentation source loading：修改 `DocsManager.swift`，新增 `llmsURL` 常數指向 `https://duckdb.org/llms.txt`，調整 `initialize()` 同時下載 llms.txt 和 duckdb-docs.md，分別存入 `~/.cache/che-duckdb-mcp/llms.txt` 和 `duckdb-docs.md`
- [x] 2.2 Cache metadata persistence：建立 `CacheMetadata` struct（含 etag、lastModified、downloadedAt），寫入 `~/.cache/che-duckdb-mcp/cache-meta.json`，啟動時讀取
- [x] 2.3 快取策略：HTTP 條件式請求 — 修改 `downloadDocs()` 方法，下載時儲存 response header（ETag、Last-Modified），更新時發送 `If-None-Match` / `If-Modified-Since`，處理 304 Not Modified 和 200 OK 兩種回應（Conditional HTTP caching with ETag and Last-Modified）
- [x] 2.4 llms.txt 解析：在 `MarkdownParser.swift` 中新增 `parseLlmsTxt()` 方法，解析 llms.txt 格式（Markdown 但結構不同於 duckdb-docs.md），每個 section 標記 `source: "llms.txt"`
- [x] 2.5 Documentation source identification in results：修改 `getDocInfo()` 回傳格式，改為陣列包含每個來源的 URL、cachePath、lastUpdated、sectionCount、contentSize
- [x] 2.6 Fallback 處理：llms.txt 下載失敗時 log warning 並繼續只用 duckdb-docs.md；duckdb-docs.md 也失敗時若有快取則用快取，都沒有則回傳錯誤

## 3. 搜尋引擎升級（docs-search）

- [x] 3.1 搜尋引擎架構：TF-IDF 倒排索引 — 實作 TF-IDF weighted search scoring，在 `SearchEngine.swift` 中建立倒排索引（inverted index）資料結構，包含 `term → [(sectionIndex, tf)]` 對照表和每個 term 的 IDF 值
- [x] 3.2 索引建構：新增 `buildIndex(sections:)` 方法，在文檔載入時（`DocsManager.initialize()` 和 `refresh()` 後）建構 TF-IDF 倒排索引，包含 tokenization（空白 + 標點分割）和正規化（lowercased、移除底線）
- [x] 3.3 TF-IDF 搜尋實作：新增 `searchWithTFIDF(query:sections:limit:)` 方法，用倒排索引查找候選 sections，計算 cosine similarity 排序
- [x] 3.4 Fuzzy matching for function names — fuzzy matching：Levenshtein distance + case-insensitive normalization，在 `SearchEngine.swift` 新增 `levenshteinDistance(_:_:)` 方法，修改 `findFunction()` 先做正規化比對（case-insensitive + underscore-insensitive），無完全匹配時用 Levenshtein distance ≤ 2 做模糊匹配
- [x] 3.5 Multi-source search result merging（多來源文檔策略：llms.txt 優先、duckdb-docs.md 深度查詢）— 修改搜尋流程，先搜 llms.txt sections 再搜 duckdb-docs.md sections，合併結果時 llms.txt 命中加 1.5x 分數乘數，按 title 去重保留高分項，每個結果加 `source` 欄位
- [x] 3.6 Search mode support 驗證：確認 title / content / all 三種 mode 在新的 TF-IDF 搜尋中正確運作
- [x] 3.7 更新 `Server.swift` 中的 `handleSearchDocs` 和 `handleGetFunctionDocs`，調用新的搜尋方法，response 格式加入 `source` 欄位

## 4. DB 引擎相容性（db-engine-compatibility）

- [x] 4.1 Storage format version detection：在 `DatabaseManager.swift` 新增 `readStorageVersion(at:)` 方法，讀取 `.duckdb` 檔案 header offset 0x30 的 storage version 值
- [x] 4.2 版本相容性檢查：在 `connect()` 中，開啟檔案前先呼叫 `readStorageVersion()`，比對 pinned duckdb-swift 支援的版本範圍，不相容時回傳包含 file version、supported range、升級建議的錯誤訊息
- [x] 4.3 Graceful handling of version mismatch errors：catch `DuckDB.DatabaseError` error code 5，回傳結構化錯誤（`error_type: "storage_version_mismatch"`）和 human-readable 訊息，raw error 放入 `details` 欄位
- [x] 4.4 DuckDB engine version reporting：修改 `getDatabaseInfo()` 回傳格式，新增 `swiftBindingRevision` 欄位，值為 pinned 的 commit hash

## 5. 清理與遷移

- [x] 5.1 搜尋所有 `~/.claude.json`、`~/.claude/settings.json`、各專案 `.claude.json` 中引用 `che-duckdb-docs-mcp` 的設定，列出影響清單
- [x] 5.2 移除 `~/bin/CheDuckDBDocsMCP` binary，移除 `~/.claude.json` 中的 `che-duckdb-docs-mcp` 設定項
- [x] 5.3 更新 CLAUDE.md 記錄 duckdb-swift 版本 pin 策略和升級流程
- [x] 5.4 更新 CHANGELOG.md 記錄 v2.0.0 所有變更

## 6. 驗證

- [x] 6.1 `swift build -c release` 編譯成功
- [x] 6.2 測試 docs tools：`search_docs`（TF-IDF 排序）、`get_function_docs`（fuzzy matching）、`refresh_docs`（條件式快取）、`get_doc_info`（雙來源資訊）
- [x] 6.3 測試 DB tools：`db_connect`（版本相容性檢查）、`db_info`（含 swiftBindingRevision）、用 incompatible 版本檔案測試錯誤訊息
- [x] 6.4 部署 binary 到 `~/bin/CheDuckDBMCP`，驗證 MCP server 正常啟動
