import Foundation

/// TF-IDF search engine for DuckDB documentation
/// Provides inverted index search, fuzzy function lookup, and SQL syntax search
public struct SearchEngine {

    /// Inverted index: term → [(sectionIndex, termFrequency)]
    private var invertedIndex: [String: [(index: Int, tf: Double)]] = [:]

    /// IDF values: term → log(N/df)
    private var idfValues: [String: Double] = [:]

    /// All indexed sections (reference kept for lookup)
    private var indexedSections: [Section] = []

    /// Whether the index has been built
    private var isIndexed: Bool = false

    /// llms.txt source name for bonus scoring
    private static let llmsSource = "llms.txt"

    /// Bonus multiplier for llms.txt results
    private static let llmsBonus: Double = 1.5

    public init() {}

    // MARK: - Index Building

    /// Build TF-IDF inverted index from sections
    public mutating func buildIndex(sections: [Section]) {
        indexedSections = sections
        invertedIndex = [:]
        idfValues = [:]

        let n = Double(sections.count)
        var documentFrequency: [String: Int] = [:]

        // Pass 1: compute term frequencies per document and document frequencies
        var perDocTermFreqs: [[String: Int]] = []

        for section in sections {
            let terms = tokenize(section.title + " " + section.content)
            var termCounts: [String: Int] = [:]
            for term in terms {
                termCounts[term, default: 0] += 1
            }
            perDocTermFreqs.append(termCounts)

            for term in termCounts.keys {
                documentFrequency[term, default: 0] += 1
            }
        }

        // Pass 2: compute IDF and build inverted index
        for (term, df) in documentFrequency {
            idfValues[term] = log(n / Double(df))
        }

        for (docIdx, termCounts) in perDocTermFreqs.enumerated() {
            let totalTerms = Double(termCounts.values.reduce(0, +))
            guard totalTerms > 0 else { continue }

            for (term, count) in termCounts {
                let tf = Double(count) / totalTerms
                invertedIndex[term, default: []].append((index: docIdx, tf: tf))
            }
        }

        isIndexed = true
    }

    // MARK: - TF-IDF Search

    /// Search using TF-IDF scoring with multi-source merging
    public func searchWithTFIDF(
        query: String,
        mode: SearchMode = .all,
        limit: Int = 10
    ) -> [SearchResult] {
        guard isIndexed else { return [] }

        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty else { return [] }

        // Compute query TF-IDF vector
        var queryVector: [String: Double] = [:]
        let queryTermCounts: [String: Int] = {
            var counts: [String: Int] = [:]
            for t in queryTerms { counts[t, default: 0] += 1 }
            return counts
        }()
        let totalQueryTerms = Double(queryTerms.count)

        for (term, count) in queryTermCounts {
            let tf = Double(count) / totalQueryTerms
            let idf = idfValues[term] ?? 0
            queryVector[term] = tf * idf
        }

        // Find candidate documents from inverted index
        var candidateScores: [Int: Double] = [:]

        for term in queryTerms {
            guard let postings = invertedIndex[term],
                  let idf = idfValues[term] else { continue }

            for posting in postings {
                let section = indexedSections[posting.index]

                // Apply search mode filter
                switch mode {
                case .title:
                    let titleTerms = Set(tokenize(section.title))
                    guard titleTerms.contains(term) else { continue }
                case .content:
                    let contentTerms = Set(tokenize(section.content))
                    guard contentTerms.contains(term) else { continue }
                case .all:
                    break
                }

                let docTfIdf = posting.tf * idf
                let queryTfIdf = queryVector[term] ?? 0
                candidateScores[posting.index, default: 0] += docTfIdf * queryTfIdf
            }
        }

        // Build results with source bonus
        var results: [SearchResult] = []
        var seenTitles: Set<String> = []

        for (docIdx, score) in candidateScores {
            let section = indexedSections[docIdx]

            // Deduplication by title
            let titleKey = section.title.lowercased()
            guard !seenTitles.contains(titleKey) else { continue }
            seenTitles.insert(titleKey)

            // Apply llms.txt bonus
            var finalScore = score
            if section.source == Self.llmsSource {
                finalScore *= Self.llmsBonus
            }

            // Determine what matched
            var matches: [String] = []
            let titleTerms = Set(tokenize(section.title))
            let contentTerms = Set(tokenize(section.content))
            if !titleTerms.isDisjoint(with: queryTerms) { matches.append("title") }
            if !contentTerms.isDisjoint(with: queryTerms) { matches.append("content") }

            let snippet = extractSnippet(
                from: section.content,
                around: query.lowercased()
            )

            results.append(SearchResult(
                section: section,
                score: Int(finalScore * 1000),
                matches: matches,
                snippet: snippet,
                source: section.source
            ))
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(limit))
    }

    // MARK: - Function Search (with Fuzzy Matching)

    /// Find function documentation with fuzzy matching
    public func findFunction(name: String, in sections: [Section]) -> FunctionDoc? {
        let normalized = normalizeFunctionName(name)

        // Pass 1: exact normalized match in titles
        for section in sections {
            let titleNorm = normalizeFunctionName(section.title)
            if titleNorm.contains(normalized) {
                return extractFunctionDoc(from: section)
            }
        }

        // Pass 2: Levenshtein distance ≤ 2 on titles
        var bestMatch: (section: Section, distance: Int)?
        for section in sections {
            // Extract potential function names from title
            let titleWords = section.title.components(separatedBy: .whitespaces)
            for word in titleWords {
                let wordNorm = normalizeFunctionName(word)
                guard !wordNorm.isEmpty else { continue }
                let dist = levenshteinDistance(normalized, wordNorm)
                if dist <= 2 {
                    if bestMatch == nil || dist < bestMatch!.distance {
                        bestMatch = (section: section, distance: dist)
                    }
                }
            }
        }

        if let match = bestMatch {
            return extractFunctionDoc(from: match.section)
        }

        // Pass 3: content search for function call pattern
        for section in sections {
            let contentNorm = normalizeFunctionName(section.content)
            if contentNorm.contains("\(normalized)(") ||
               contentNorm.contains("`\(normalized)`") {
                return extractFunctionDoc(from: section)
            }
        }

        return nil
    }

    /// List all functions found in documentation
    public func listFunctions(in sections: [Section]) -> [String] {
        var functions = Set<String>()

        let patterns = [
            #"([a-z_]+)\("#,
            #"`([a-z_]+)`\("#,
        ]

        for section in sections {
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(section.content.startIndex..., in: section.content)
                    let matches = regex.matches(in: section.content, options: [], range: range)

                    for match in matches {
                        if let funcRange = Range(match.range(at: 1), in: section.content) {
                            let funcName = String(section.content[funcRange])
                            if !isCommonWord(funcName) && funcName.count > 2 {
                                functions.insert(funcName)
                            }
                        }
                    }
                }
            }
        }

        return functions.sorted()
    }

    // MARK: - SQL Syntax Search

    /// Find SQL syntax documentation
    public func findSQLSyntax(statement: String, in sections: [Section]) -> SQLSyntaxDoc? {
        let lowerStatement = statement.lowercased()

        let sqlKeywords = [
            "select", "insert", "update", "delete", "create", "drop", "alter",
            "copy", "export", "import", "attach", "detach", "use", "describe",
            "explain", "analyze", "vacuum", "checkpoint", "pragma", "set"
        ]

        let keyword = sqlKeywords.first { lowerStatement.contains($0) } ?? lowerStatement

        for section in sections {
            let lowerTitle = section.title.lowercased()
            if lowerTitle.contains(keyword) &&
               (lowerTitle.contains("statement") || lowerTitle.contains("syntax") ||
                lowerTitle.contains("clause") || section.level <= 2) {
                return extractSQLSyntaxDoc(from: section, keyword: keyword)
            }
        }

        for section in sections {
            if section.content.lowercased().contains("\(keyword) ") &&
               section.content.lowercased().contains("syntax") {
                return extractSQLSyntaxDoc(from: section, keyword: keyword)
            }
        }

        return nil
    }

    // MARK: - Tokenization & Normalization

    /// Tokenize text into normalized terms
    private func tokenize(_ text: String) -> [String] {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")

        let separators = CharacterSet.alphanumerics.inverted
        return normalized
            .components(separatedBy: separators)
            .filter { $0.count > 1 }
    }

    /// Normalize function name for matching (lowercase, remove underscores)
    private func normalizeFunctionName(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "_", with: "")
    }

    // MARK: - Levenshtein Distance

    /// Compute Levenshtein edit distance between two strings
    func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                curr[j] = min(
                    curr[j - 1] + 1,      // insertion
                    prev[j] + 1,            // deletion
                    prev[j - 1] + cost      // substitution
                )
            }
            prev = curr
        }

        return prev[n]
    }

    // MARK: - Private Helpers

    private func extractFunctionDoc(from section: Section) -> FunctionDoc {
        let signature = extractSignature(from: section.content)
        let parameters = extractParameters(from: section.content)
        let returnType = extractReturnType(from: section.content)

        return FunctionDoc(
            name: section.title,
            signature: signature,
            description: section.content,
            parameters: parameters,
            returnType: returnType,
            sectionId: section.id
        )
    }

    private func extractSQLSyntaxDoc(from section: Section, keyword: String) -> SQLSyntaxDoc {
        let syntax = extractCodeBlock(from: section.content, containing: keyword)

        return SQLSyntaxDoc(
            statement: keyword.uppercased(),
            syntax: syntax ?? "See documentation",
            description: section.content,
            sectionId: section.id
        )
    }

    private func extractSignature(from content: String) -> String? {
        let patterns = [
            #"```\n([^`]+\([^)]*\)[^`]*)\n```"#,
            #"`([^`]+\([^)]*\))`"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(content.startIndex..., in: content)
                if let match = regex.firstMatch(in: content, options: [], range: range),
                   let sigRange = Range(match.range(at: 1), in: content) {
                    return String(content[sigRange])
                }
            }
        }

        return nil
    }

    private func extractParameters(from content: String) -> [String] {
        var params: [String] = []

        let pattern = #"\|\s*`?([a-z_]+)`?\s*\|[^|]+\|"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)

            for match in matches {
                if let paramRange = Range(match.range(at: 1), in: content) {
                    params.append(String(content[paramRange]))
                }
            }
        }

        return params
    }

    private func extractReturnType(from content: String) -> String? {
        let patterns = [
            #"returns?\s+(?:a\s+)?`?([A-Z][A-Za-z]+)`?"#,
            #"→\s*`?([A-Z][A-Za-z]+)`?"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(content.startIndex..., in: content)
                if let match = regex.firstMatch(in: content, options: [], range: range),
                   let typeRange = Range(match.range(at: 1), in: content) {
                    return String(content[typeRange])
                }
            }
        }

        return nil
    }

    private func extractCodeBlock(from content: String, containing keyword: String) -> String? {
        let pattern = #"```(?:sql)?\n([^`]+)\n```"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, options: [], range: range)

            for match in matches {
                if let blockRange = Range(match.range(at: 1), in: content) {
                    let block = String(content[blockRange])
                    if block.lowercased().contains(keyword.lowercased()) {
                        return block.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        return nil
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

    private func isCommonWord(_ word: String) -> Bool {
        let common = ["the", "and", "for", "from", "with", "this", "that", "are", "was", "were", "has", "have", "had", "not", "all", "can", "but", "use", "set", "get"]
        return common.contains(word.lowercased())
    }
}

// MARK: - Supporting Types

/// Function documentation
public struct FunctionDoc: Codable, Sendable {
    public let name: String
    public let signature: String?
    public let description: String
    public let parameters: [String]
    public let returnType: String?
    public let sectionId: String
}

/// SQL syntax documentation
public struct SQLSyntaxDoc: Codable, Sendable {
    public let statement: String
    public let syntax: String
    public let description: String
    public let sectionId: String
}

/// Fuzzy search result (kept for backward compat)
public struct FuzzySearchResult: Codable, Sendable {
    public let section: Section
    public let score: Int
    public let matchedIn: String
}
