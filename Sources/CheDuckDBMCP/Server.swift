import Foundation
import MCP

/// MCP Server for DuckDB - Documentation and Database Operations
public class CheDuckDBMCPServer {
    private let server: Server
    private let transport: StdioTransport
    private let docsManager = DocsManager()
    private var searchEngine = SearchEngine()
    private let databaseManager = DatabaseManager()
    private let resultFormatter = ResultFormatter()

    /// All available tools
    private let tools: [Tool]

    public init() async throws {
        // Define all tools
        tools = Self.defineTools()

        // Create server with tools capability
        server = Server(
            name: AppVersion.name,
            version: AppVersion.current,
            capabilities: .init(tools: .init())
        )

        transport = StdioTransport()

        // Initialize documentation and build search index
        try await docsManager.initialize()
        let allSections = await docsManager.getAllSections()
        searchEngine.buildIndex(sections: allSections)

        // Register handlers
        await registerHandlers()
    }

    public func run() async throws {
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Tool Definitions (14 Tools)

    static func defineTools() -> [Tool] {
        [
            // ============================================
            // Documentation Tools (8)
            // ============================================

            // 1. search_docs
            Tool(
                name: "search_docs",
                description: "Search DuckDB documentation by keyword. Supports title-only, content-only, or combined search.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Search keyword or phrase")
                        ]),
                        "mode": .object([
                            "type": .string("string"),
                            "enum": .array([.string("title"), .string("content"), .string("all")]),
                            "description": .string("Search mode: 'title' (section titles only), 'content' (body text), or 'all' (both). Default: 'all'")
                        ]),
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Maximum number of results. Default: 10")
                        ])
                    ]),
                    "required": .array([.string("query")])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 2. list_sections
            Tool(
                name: "list_sections",
                description: "List all documentation sections. Can filter by heading level (1-3) or parent section.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "level": .object([
                            "type": .string("integer"),
                            "description": .string("Filter by heading level (1, 2, or 3). Omit to list all levels.")
                        ]),
                        "parent": .object([
                            "type": .string("string"),
                            "description": .string("Parent section ID. Only list children of this section.")
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 3. get_section
            Tool(
                name: "get_section",
                description: "Get the content of a specific documentation section by ID or title.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "id": .object([
                            "type": .string("string"),
                            "description": .string("Section ID (anchor ID from documentation)")
                        ]),
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Section title (fuzzy match supported)")
                        ]),
                        "include_children": .object([
                            "type": .string("boolean"),
                            "description": .string("Whether to include child sections. Default: true")
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 4. get_function_docs
            Tool(
                name: "get_function_docs",
                description: "Get documentation for a specific DuckDB function (e.g., read_csv, json_extract, list_aggregate).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "function_name": .object([
                            "type": .string("string"),
                            "description": .string("Function name (e.g., 'read_csv', 'json_extract', 'array_agg')")
                        ])
                    ]),
                    "required": .array([.string("function_name")])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 5. list_functions
            Tool(
                name: "list_functions",
                description: "List all documented DuckDB functions found in the documentation.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 6. get_sql_syntax
            Tool(
                name: "get_sql_syntax",
                description: "Get SQL syntax documentation for a specific statement type (SELECT, CREATE TABLE, COPY, etc.).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "statement": .object([
                            "type": .string("string"),
                            "description": .string("SQL statement type (e.g., 'SELECT', 'CREATE TABLE', 'COPY', 'INSERT')")
                        ])
                    ]),
                    "required": .array([.string("statement")])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 7. refresh_docs
            Tool(
                name: "refresh_docs",
                description: "Force re-download the DuckDB documentation from source. Use when documentation seems outdated.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: false, openWorldHint: true)
            ),

            // 8. get_doc_info
            Tool(
                name: "get_doc_info",
                description: "Get information about the loaded documentation (source, cache location, last update time, section count).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // ============================================
            // Database Tools (6)
            // ============================================

            // 9. db_connect
            Tool(
                name: "db_connect",
                description: "Connect to a DuckDB database. Creates an in-memory database if no path is specified.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Database file path. Leave empty for in-memory database.")
                        ]),
                        "read_only": .object([
                            "type": .string("boolean"),
                            "description": .string("Open database in read-only mode. Default: false")
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: false, openWorldHint: true)
            ),

            // 10. db_query
            Tool(
                name: "db_query",
                description: "Execute a SELECT query and return results. Only read operations are allowed.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "sql": .object([
                            "type": .string("string"),
                            "description": .string("SQL SELECT query to execute")
                        ]),
                        "format": .object([
                            "type": .string("string"),
                            "enum": .array([.string("json"), .string("markdown"), .string("csv")]),
                            "description": .string("Output format: json, markdown, or csv. Default: json")
                        ]),
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Maximum number of rows to return. Default: 1000")
                        ])
                    ]),
                    "required": .array([.string("sql")])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 11. db_execute
            Tool(
                name: "db_execute",
                description: "Execute a DDL/DML statement (CREATE, INSERT, UPDATE, DELETE, etc.). Use db_query for SELECT.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "sql": .object([
                            "type": .string("string"),
                            "description": .string("SQL statement to execute (CREATE, INSERT, UPDATE, DELETE, etc.)")
                        ])
                    ]),
                    "required": .array([.string("sql")])
                ]),
                annotations: .init(readOnlyHint: false, destructiveHint: true, openWorldHint: false)
            ),

            // 12. db_list_tables
            Tool(
                name: "db_list_tables",
                description: "List all tables and optionally views in the connected database.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "include_views": .object([
                            "type": .string("boolean"),
                            "description": .string("Include views in the list. Default: true")
                        ]),
                        "schema": .object([
                            "type": .string("string"),
                            "description": .string("Filter by schema name. Omit to list all schemas.")
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 13. db_describe
            Tool(
                name: "db_describe",
                description: "Describe the structure of a table or query result.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "table": .object([
                            "type": .string("string"),
                            "description": .string("Table name to describe")
                        ]),
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("SQL query to describe its result structure")
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            ),

            // 14. db_info
            Tool(
                name: "db_info",
                description: "Get information about the connected database (version, path, table count, etc.).",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ]),
                annotations: .init(readOnlyHint: true, openWorldHint: false)
            )
        ]
    }

    // MARK: - Handler Registration

    private func registerHandlers() async {
        await server.withMethodHandler(ListTools.self) { [tools] _ in
            ListTools.Result(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                return CallTool.Result(content: [.text("Server error")])
            }
            return await self.executeToolCall(params)
        }
    }

    // MARK: - Tool Execution

    private func executeToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        do {
            let result: String
            switch params.name {
            // Documentation Tools
            case "search_docs":
                result = try await handleSearchDocs(params.arguments)
            case "list_sections":
                result = try await handleListSections(params.arguments)
            case "get_section":
                result = try await handleGetSection(params.arguments)
            case "get_function_docs":
                result = try await handleGetFunctionDocs(params.arguments)
            case "list_functions":
                result = try await handleListFunctions()
            case "get_sql_syntax":
                result = try await handleGetSQLSyntax(params.arguments)
            case "refresh_docs":
                result = try await handleRefreshDocs()
            case "get_doc_info":
                result = try await handleGetDocInfo()

            // Database Tools
            case "db_connect":
                result = try await handleDbConnect(params.arguments)
            case "db_query":
                result = try await handleDbQuery(params.arguments)
            case "db_execute":
                result = try await handleDbExecute(params.arguments)
            case "db_list_tables":
                result = try await handleDbListTables(params.arguments)
            case "db_describe":
                result = try await handleDbDescribe(params.arguments)
            case "db_info":
                result = try await handleDbInfo()

            default:
                return CallTool.Result(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }

    // MARK: - Documentation Tool Handlers

    private func handleSearchDocs(_ arguments: [String: Value]?) async throws -> String {
        guard let args = arguments,
              case .string(let query) = args["query"] else {
            throw DocsError.invalidContent
        }

        var mode: SearchMode = .all
        if case .string(let m) = args["mode"] {
            mode = SearchMode(rawValue: m) ?? .all
        }

        var limit = 10
        if case .int(let l) = args["limit"] {
            limit = l
        }

        let results = searchEngine.searchWithTFIDF(query: query, mode: mode, limit: limit)
        return formatSearchResultsAsJSON(results)
    }

    private func handleListSections(_ arguments: [String: Value]?) async throws -> String {
        let args = arguments ?? [:]

        var level: Int? = nil
        if case .int(let l) = args["level"] {
            level = l
        }

        var parent: String? = nil
        if case .string(let p) = args["parent"] {
            parent = p
        }

        let sections = await docsManager.getSections(level: level, parentId: parent)

        let summaries = sections.map { section -> [String: Any] in
            [
                "id": section.id,
                "title": section.title,
                "level": section.level,
                "hasChildren": !section.children.isEmpty
            ]
        }

        return formatAsJSON(summaries)
    }

    private func handleGetSection(_ arguments: [String: Value]?) async throws -> String {
        let args = arguments ?? [:]

        var id: String? = nil
        if case .string(let i) = args["id"] {
            id = i
        }

        var title: String? = nil
        if case .string(let t) = args["title"] {
            title = t
        }

        var includeChildren = true
        if case .bool(let i) = args["include_children"] {
            includeChildren = i
        }

        guard let section = await docsManager.getSection(id: id, title: title, includeChildren: includeChildren) else {
            throw DocsError.sectionNotFound
        }

        return formatSectionAsJSON(section)
    }

    private func handleGetFunctionDocs(_ arguments: [String: Value]?) async throws -> String {
        guard let args = arguments,
              case .string(let functionName) = args["function_name"] else {
            throw DocsError.invalidContent
        }

        let sections = await docsManager.getAllSections()
        guard let functionDoc = searchEngine.findFunction(name: functionName, in: sections) else {
            return """
            {
                "error": "Function not found",
                "function_name": "\(functionName)",
                "suggestion": "Try searching with search_docs for related documentation"
            }
            """
        }

        return formatFunctionDocAsJSON(functionDoc)
    }

    private func handleListFunctions() async throws -> String {
        let sections = await docsManager.getAllSections()
        let functions = searchEngine.listFunctions(in: sections)

        return """
        {
            "count": \(functions.count),
            "functions": \(formatAsJSON(functions))
        }
        """
    }

    private func handleGetSQLSyntax(_ arguments: [String: Value]?) async throws -> String {
        guard let args = arguments,
              case .string(let statement) = args["statement"] else {
            throw DocsError.invalidContent
        }

        let sections = await docsManager.getAllSections()
        guard let syntaxDoc = searchEngine.findSQLSyntax(statement: statement, in: sections) else {
            return """
            {
                "error": "SQL syntax not found",
                "statement": "\(statement)",
                "suggestion": "Try searching with search_docs for related documentation"
            }
            """
        }

        return formatSQLSyntaxDocAsJSON(syntaxDoc)
    }

    private func handleRefreshDocs() async throws -> String {
        try await docsManager.refresh()

        // Rebuild search index
        let allSections = await docsManager.getAllSections()
        searchEngine.buildIndex(sections: allSections)

        let info = await docsManager.getDocInfo()

        return """
        {
            "success": true,
            "message": "Documentation refreshed successfully",
            "total_section_count": \(info.totalSectionCount),
            "sources_loaded": \(info.sources.count)
        }
        """
    }

    private func handleGetDocInfo() async throws -> String {
        let info = await docsManager.getDocInfo()
        return formatDocInfoAsJSON(info)
    }

    // MARK: - Database Tool Handlers

    private func handleDbConnect(_ arguments: [String: Value]?) async throws -> String {
        let args = arguments ?? [:]

        var path: String? = nil
        if case .string(let p) = args["path"], !p.isEmpty {
            path = p
        }

        var readOnly = false
        if case .bool(let r) = args["read_only"] {
            readOnly = r
        }

        try await databaseManager.connect(path: path, readOnly: readOnly)
        let info = await databaseManager.getConnectionInfo()

        return """
        {
            "success": true,
            "message": "Connected successfully",
            "path": \(info.path.map { "\"\($0)\"" } ?? "null"),
            "is_in_memory": \(info.isInMemory),
            "is_read_only": \(info.isReadOnly)
        }
        """
    }

    private func handleDbQuery(_ arguments: [String: Value]?) async throws -> String {
        guard let args = arguments,
              case .string(let sql) = args["sql"] else {
            throw DatabaseError.invalidParameter("sql is required")
        }

        var format = ResultFormatter.Format.json
        if case .string(let f) = args["format"] {
            format = ResultFormatter.Format(rawValue: f) ?? .json
        }

        var limit = 1000
        if case .int(let l) = args["limit"] {
            limit = l
        }

        let result = try await databaseManager.query(sql, limit: limit)
        return resultFormatter.format(result, as: format)
    }

    private func handleDbExecute(_ arguments: [String: Value]?) async throws -> String {
        guard let args = arguments,
              case .string(let sql) = args["sql"] else {
            throw DatabaseError.invalidParameter("sql is required")
        }

        let affectedRows = try await databaseManager.execute(sql)

        return """
        {
            "success": true,
            "affected_rows": \(affectedRows)
        }
        """
    }

    private func handleDbListTables(_ arguments: [String: Value]?) async throws -> String {
        let args = arguments ?? [:]

        var includeViews = true
        if case .bool(let i) = args["include_views"] {
            includeViews = i
        }

        var schema: String? = nil
        if case .string(let s) = args["schema"] {
            schema = s
        }

        let tables = try await databaseManager.listTables(includeViews: includeViews, schema: schema)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(tables),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func handleDbDescribe(_ arguments: [String: Value]?) async throws -> String {
        let args = arguments ?? [:]

        var table: String? = nil
        if case .string(let t) = args["table"] {
            table = t
        }

        var query: String? = nil
        if case .string(let q) = args["query"] {
            query = q
        }

        let columns: [ColumnInfo]

        if let table = table {
            columns = try await databaseManager.describeTable(table)
        } else if let query = query {
            columns = try await databaseManager.describeQuery(query)
        } else {
            throw DatabaseError.invalidParameter("Either 'table' or 'query' is required")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(columns),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func handleDbInfo() async throws -> String {
        // Check if connected first
        let connInfo = await databaseManager.getConnectionInfo()
        if !connInfo.isConnected {
            return """
            {
                "connected": false,
                "message": "Not connected to any database. Use db_connect first."
            }
            """
        }

        let info = try await databaseManager.getDatabaseInfo()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(info),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    // MARK: - JSON Formatting Helpers

    private func formatSearchResultsAsJSON(_ results: [SearchResult]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(results),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func formatSectionAsJSON(_ section: Section) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(section),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func formatFunctionDocAsJSON(_ doc: FunctionDoc) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(doc),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func formatSQLSyntaxDocAsJSON(_ doc: SQLSyntaxDoc) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(doc),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func formatDocInfoAsJSON(_ info: DocInfo) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(info),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func formatAsJSON(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return json
    }
}
