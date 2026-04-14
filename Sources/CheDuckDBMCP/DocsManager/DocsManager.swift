import Foundation

/// Manages DuckDB documentation download, caching, and access
public actor DocsManager {
    /// Documentation URLs
    private static let llmsURL = "https://duckdb.org/llms.txt"
    private static let docsURL = "https://blobs.duckdb.org/docs/duckdb-docs.md"

    /// Cache directory
    private static let cacheDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cache/che-duckdb-mcp")
    }()

    /// Cache file paths
    private static let llmsCacheFile: URL = { cacheDir.appendingPathComponent("llms.txt") }()
    private static let docsCacheFile: URL = { cacheDir.appendingPathComponent("duckdb-docs.md") }()
    private static let metadataFile: URL = { cacheDir.appendingPathComponent("cache-meta.json") }()

    /// Source identifier constants
    private static let llmsSourceName = "llms.txt"
    private static let docsSourceName = "duckdb-docs.md"

    /// Parsed documentation sections (from both sources)
    private var sections: [Section] = []

    /// Per-source raw content
    private var llmsContent: String = ""
    private var docsContent: String = ""

    /// Per-source section counts
    private var llmsSectionCount: Int = 0
    private var docsSectionCount: Int = 0

    /// Per-source last update times
    private var llmsLastUpdated: Date?
    private var docsLastUpdated: Date?

    /// Cache metadata for conditional HTTP
    private var cacheMetadata: CacheMetadata = CacheMetadata()

    /// Whether documentation is loaded
    private var isLoaded: Bool = false

    // MARK: - Public Interface

    public init() {}

    /// Initialize and load documentation
    public func initialize() async throws {
        try loadCacheMetadata()
        try await loadAllSources()
        isLoaded = true
    }

    /// Get documentation info (per-source)
    public func getDocInfo() -> DocInfo {
        var sources: [SourceInfo] = []

        if !llmsContent.isEmpty {
            sources.append(SourceInfo(
                source: Self.llmsURL,
                cachePath: Self.llmsCacheFile.path,
                lastUpdated: llmsLastUpdated,
                sectionCount: llmsSectionCount,
                contentSize: llmsContent.count
            ))
        }

        if !docsContent.isEmpty {
            sources.append(SourceInfo(
                source: Self.docsURL,
                cachePath: Self.docsCacheFile.path,
                lastUpdated: docsLastUpdated,
                sectionCount: docsSectionCount,
                contentSize: docsContent.count
            ))
        }

        return DocInfo(
            sources: sources,
            isLoaded: isLoaded,
            totalSectionCount: sections.count
        )
    }

    /// Force refresh documentation from all sources
    public func refresh() async throws {
        // Clear existing metadata to force re-download
        cacheMetadata = CacheMetadata()
        try await loadAllSources()
    }

    /// Get all sections
    public func getAllSections() -> [Section] {
        sections
    }

    /// Get sections by level
    public func getSections(level: Int? = nil, parentId: String? = nil) -> [Section] {
        var result = sections

        if let level = level {
            result = result.filter { $0.level == level }
        }

        if let parentId = parentId {
            result = result.filter { $0.parentId == parentId }
        }

        return result
    }

    /// Get section by ID or title
    public func getSection(id: String? = nil, title: String? = nil, includeChildren: Bool = true) -> Section? {
        var section: Section?

        if let id = id {
            section = sections.first { $0.id == id }
        } else if let title = title {
            let lowerTitle = title.lowercased()
            section = sections.first { $0.title.lowercased().contains(lowerTitle) }
        }

        if var result = section, includeChildren {
            result.children = sections.filter { $0.parentId == result.id }
            return result
        }

        return section
    }

    /// Search documentation (delegates to SearchEngine for TF-IDF in v2)
    public func search(query: String, mode: SearchMode = .all, limit: Int = 10) -> [SearchResult] {
        let lowerQuery = query.lowercased()
        var results: [SearchResult] = []

        for section in sections {
            var score = 0
            var matches: [String] = []

            if mode == .title || mode == .all {
                if section.title.lowercased().contains(lowerQuery) {
                    score += 10
                    matches.append("title")
                }
            }

            if mode == .content || mode == .all {
                if section.content.lowercased().contains(lowerQuery) {
                    score += 5
                    matches.append("content")
                }
            }

            // Bonus for llms.txt source
            if section.source == Self.llmsSourceName {
                score = Int(Double(score) * 1.5)
            }

            if score > 0 {
                results.append(SearchResult(
                    section: section,
                    score: score,
                    matches: matches,
                    snippet: extractSnippet(from: section.content, around: lowerQuery),
                    source: section.source
                ))
            }
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(limit))
    }

    /// Get raw content (combined)
    public func getRawContent() -> String {
        docsContent
    }

    // MARK: - Private: Source Loading

    private func loadAllSources() async throws {
        let parser = MarkdownParser()
        var allSections: [Section] = []

        // Ensure cache directory exists
        try FileManager.default.createDirectory(at: Self.cacheDir, withIntermediateDirectories: true)

        // Load llms.txt (lightweight, load first)
        do {
            let content = try await loadSource(
                url: Self.llmsURL,
                cacheFile: Self.llmsCacheFile,
                sourceKey: Self.llmsSourceName
            )
            llmsContent = content
            llmsLastUpdated = cacheMetadata.entries[Self.llmsSourceName]?.downloadedAt ?? Date()
            var parsed = parser.parse(content)
            for i in parsed.indices { parsed[i].source = Self.llmsSourceName }
            llmsSectionCount = parsed.count
            allSections.append(contentsOf: parsed)
        } catch {
            // llms.txt failure is non-fatal
            logWarning("Failed to load llms.txt: \(error.localizedDescription)")
            llmsContent = ""
            llmsSectionCount = 0
        }

        // Load duckdb-docs.md (full documentation)
        do {
            let content = try await loadSource(
                url: Self.docsURL,
                cacheFile: Self.docsCacheFile,
                sourceKey: Self.docsSourceName
            )
            docsContent = content
            docsLastUpdated = cacheMetadata.entries[Self.docsSourceName]?.downloadedAt ?? Date()
            var parsed = parser.parse(content)
            for i in parsed.indices { parsed[i].source = Self.docsSourceName }
            docsSectionCount = parsed.count
            allSections.append(contentsOf: parsed)
        } catch {
            // If duckdb-docs.md fails, try cache
            if let cached = try? String(contentsOf: Self.docsCacheFile, encoding: .utf8) {
                logWarning("Failed to update duckdb-docs.md, using cached version: \(error.localizedDescription)")
                docsContent = cached
                var parsed = parser.parse(cached)
                for i in parsed.indices { parsed[i].source = Self.docsSourceName }
                docsSectionCount = parsed.count
                allSections.append(contentsOf: parsed)
            } else if allSections.isEmpty {
                // No sources available at all
                throw DocsError.downloadFailed
            } else {
                logWarning("Failed to load duckdb-docs.md: \(error.localizedDescription)")
                docsContent = ""
                docsSectionCount = 0
            }
        }

        sections = allSections
    }

    /// Load a single source with conditional HTTP caching
    private func loadSource(url urlString: String, cacheFile: URL, sourceKey: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw DocsError.invalidURL
        }

        let fm = FileManager.default
        let hasCachedFile = fm.fileExists(atPath: cacheFile.path)
        let entry = cacheMetadata.entries[sourceKey]

        // Build conditional request
        var request = URLRequest(url: url)
        if hasCachedFile, let entry = entry {
            if let etag = entry.etag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            if let lastModified = entry.lastModified {
                request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DocsError.downloadFailed
            }

            if httpResponse.statusCode == 304 {
                // Not modified — use cache
                return try String(contentsOf: cacheFile, encoding: .utf8)
            }

            guard httpResponse.statusCode == 200 else {
                throw DocsError.downloadFailed
            }

            guard let content = String(data: data, encoding: .utf8) else {
                throw DocsError.invalidContent
            }

            // Save to cache
            try content.write(to: cacheFile, atomically: true, encoding: .utf8)

            // Update metadata
            var newEntry = CacheMetadata.CacheEntry(downloadedAt: Date())
            newEntry.etag = httpResponse.value(forHTTPHeaderField: "ETag")
            newEntry.lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
            cacheMetadata.entries[sourceKey] = newEntry
            try saveCacheMetadata()

            return content
        } catch let error as DocsError {
            throw error
        } catch {
            // Network error — fall back to cache if available
            if hasCachedFile {
                logWarning("Network error for \(sourceKey), using cache: \(error.localizedDescription)")
                return try String(contentsOf: cacheFile, encoding: .utf8)
            }
            throw DocsError.downloadFailed
        }
    }

    // MARK: - Private: Cache Metadata

    private func loadCacheMetadata() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.metadataFile.path) else { return }

        let data = try Data(contentsOf: Self.metadataFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        cacheMetadata = try decoder.decode(CacheMetadata.self, from: data)
    }

    private func saveCacheMetadata() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cacheMetadata)
        try data.write(to: Self.metadataFile, options: .atomic)
    }

    // MARK: - Private: Helpers

    private func logWarning(_ message: String) {
        // Log to stderr so it doesn't interfere with MCP stdio
        FileHandle.standardError.write(Data("[WARNING] \(message)\n".utf8))
    }

    private func extractSnippet(from content: String, around query: String, contextChars: Int = 100) -> String {
        guard let range = content.lowercased().range(of: query) else {
            let endIndex = content.index(content.startIndex, offsetBy: min(contextChars, content.count))
            return String(content[..<endIndex]) + "..."
        }

        let matchStart = content.distance(from: content.startIndex, to: range.lowerBound)
        let snippetStart = max(0, matchStart - contextChars / 2)
        let snippetEnd = min(content.count, matchStart + query.count + contextChars / 2)

        let startIdx = content.index(content.startIndex, offsetBy: snippetStart)
        let endIdx = content.index(content.startIndex, offsetBy: snippetEnd)

        var snippet = String(content[startIdx..<endIdx])

        if snippetStart > 0 { snippet = "..." + snippet }
        if snippetEnd < content.count { snippet = snippet + "..." }

        return snippet
    }
}

// MARK: - Supporting Types

/// Documentation section
public struct Section: Codable, Sendable {
    public let id: String
    public let title: String
    public let level: Int
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public var parentId: String?
    public var children: [Section]
    public var source: String

    public init(id: String, title: String, level: Int, content: String,
                startLine: Int, endLine: Int, parentId: String? = nil,
                children: [Section] = [], source: String = "duckdb-docs.md") {
        self.id = id
        self.title = title
        self.level = level
        self.content = content
        self.startLine = startLine
        self.endLine = endLine
        self.parentId = parentId
        self.children = children
        self.source = source
    }
}

/// Per-source documentation info
public struct SourceInfo: Codable, Sendable {
    public let source: String
    public let cachePath: String
    public let lastUpdated: Date?
    public let sectionCount: Int
    public let contentSize: Int
}

/// Overall documentation info
public struct DocInfo: Codable, Sendable {
    public let sources: [SourceInfo]
    public let isLoaded: Bool
    public let totalSectionCount: Int
}

/// Cache metadata for conditional HTTP requests
public struct CacheMetadata: Codable, Sendable {
    public var entries: [String: CacheEntry]

    public struct CacheEntry: Codable, Sendable {
        public var etag: String?
        public var lastModified: String?
        public var downloadedAt: Date
    }

    public init() {
        entries = [:]
    }
}

/// Search mode
public enum SearchMode: String, Codable, Sendable {
    case title
    case content
    case all
}

/// Search result
public struct SearchResult: Codable, Sendable {
    public let section: Section
    public let score: Int
    public let matches: [String]
    public let snippet: String
    public let source: String
}

/// Documentation errors
public enum DocsError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case invalidContent
    case notLoaded
    case sectionNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid documentation URL"
        case .downloadFailed:
            return "Failed to download documentation"
        case .invalidContent:
            return "Invalid documentation content"
        case .notLoaded:
            return "Documentation not loaded"
        case .sectionNotFound:
            return "Section not found"
        }
    }
}
