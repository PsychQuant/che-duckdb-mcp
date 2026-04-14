import Foundation
import DuckDB

/// Manages DuckDB database connections and query execution
public actor DatabaseManager {
    /// Current database instance
    private var database: Database?

    /// Current connection
    private var connection: Connection?

    /// Current database path (nil = in-memory)
    private var currentPath: String?

    /// Read-only mode flag
    private var isReadOnly: Bool = false

    // MARK: - Public Interface

    public init() {}

    /// Pinned duckdb-swift revision for version reporting
    static let swiftBindingRevision = "d90cf8d"

    /// Connect to a DuckDB database
    /// - Parameters:
    ///   - path: Database file path. nil for in-memory database.
    ///   - readOnly: Whether to open in read-only mode
    public func connect(path: String? = nil, readOnly: Bool = false) async throws {
        // Close existing connection if any
        await disconnect()

        do {
            if let path = path {
                // Storage version compatibility check
                if let versionInfo = self.readStorageVersion(at: path) {
                    // Log version for diagnostics; actual compatibility is enforced by DuckDB itself
                    FileHandle.standardError.write(Data("[INFO] Database storage version: \(versionInfo)\n".utf8))
                }

                let fileURL = URL(fileURLWithPath: path)
                let store = try Database.Store.file(at: fileURL)
                let config = Database.Configuration()
                database = try Database(store: store, configuration: config)
            } else {
                // In-memory database — skip version check
                database = try Database(store: .inMemory)
            }

            connection = try database?.connect()
            currentPath = path
            isReadOnly = readOnly
        } catch {
            // Graceful handling of version mismatch (error code 5 = IO error)
            let errorMsg = error.localizedDescription
            if errorMsg.contains("error 5") || errorMsg.contains("IO Error") || errorMsg.contains("storage version") {
                throw DatabaseError.storageVersionMismatch(
                    details: errorMsg,
                    suggestion: "The database file was created with a newer DuckDB version. Upgrade che-duckdb-mcp or use the DuckDB CLI to export/re-import the data."
                )
            }
            throw DatabaseError.connectionFailed(errorMsg)
        }
    }

    /// Read storage format version from a .duckdb file header
    /// Returns a description string or nil if the file can't be read
    private func readStorageVersion(at path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fileHandle.closeFile() }

        // DuckDB storage version is at offset 0x30 (48 bytes)
        fileHandle.seek(toFileOffset: 0x30)
        let data = fileHandle.readData(ofLength: 8)
        guard data.count >= 8 else { return nil }

        let version = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        return "v\(version)"
    }

    /// Disconnect from current database
    public func disconnect() async {
        connection = nil
        database = nil
        currentPath = nil
        isReadOnly = false
    }

    /// Check if connected to a database
    public func isConnected() -> Bool {
        return connection != nil
    }

    /// Get current connection info
    public func getConnectionInfo() -> ConnectionInfo {
        ConnectionInfo(
            isConnected: connection != nil,
            path: currentPath,
            isInMemory: currentPath == nil && connection != nil,
            isReadOnly: isReadOnly
        )
    }

    /// Execute a SELECT query and return results
    /// - Parameters:
    ///   - sql: SQL query (must be SELECT)
    ///   - limit: Maximum number of rows to return
    /// - Returns: Query result set
    public func query(_ sql: String, limit: Int = 1000) async throws -> QueryResultSet {
        guard let conn = connection else {
            throw DatabaseError.notConnected
        }

        // Validate that it's a SELECT query
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedSQL.hasPrefix("select") ||
              trimmedSQL.hasPrefix("with") ||
              trimmedSQL.hasPrefix("show") ||
              trimmedSQL.hasPrefix("describe") ||
              trimmedSQL.hasPrefix("explain") ||
              trimmedSQL.hasPrefix("pragma") else {
            throw DatabaseError.queryNotAllowed("Only SELECT, WITH, SHOW, DESCRIBE, EXPLAIN, and PRAGMA queries are allowed. Use db_execute for DDL/DML.")
        }

        // Add LIMIT if not present
        var finalSQL = sql
        if !trimmedSQL.contains("limit") && limit > 0 {
            finalSQL = "SELECT * FROM (\(sql)) LIMIT \(limit)"
        }

        do {
            let result = try conn.query(finalSQL)
            return extractResultSet(from: result, limit: limit)
        } catch {
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }

    /// Execute a DDL/DML statement (CREATE, INSERT, UPDATE, DELETE, etc.)
    /// - Parameter sql: SQL statement
    /// - Returns: Number of affected rows (if applicable)
    public func execute(_ sql: String) async throws -> Int {
        guard let conn = connection else {
            throw DatabaseError.notConnected
        }

        // Check if read-only
        if isReadOnly {
            throw DatabaseError.readOnlyViolation
        }

        do {
            let result = try conn.query(sql)
            // DuckDB doesn't return affected rows directly for all operations
            // Return row count if available
            return Int(result.rowCount)
        } catch {
            throw DatabaseError.executionFailed(error.localizedDescription)
        }
    }

    /// List all tables and optionally views
    /// - Parameters:
    ///   - includeViews: Whether to include views
    ///   - schema: Filter by schema name
    /// - Returns: List of table information
    public func listTables(includeViews: Bool = true, schema: String? = nil) async throws -> [TableInfo] {
        guard let conn = connection else {
            throw DatabaseError.notConnected
        }

        var sql = """
            SELECT table_schema, table_name, table_type
            FROM information_schema.tables
            WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
            """

        if !includeViews {
            sql += " AND table_type = 'BASE TABLE'"
        }

        if let schema = schema {
            sql += " AND table_schema = '\(schema.replacingOccurrences(of: "'", with: "''"))'"
        }

        sql += " ORDER BY table_schema, table_name"

        do {
            let result = try conn.query(sql)
            var tables: [TableInfo] = []

            let schemaCol = result[DBInt(0)].cast(to: String.self)
            let nameCol = result[DBInt(1)].cast(to: String.self)
            let typeCol = result[DBInt(2)].cast(to: String.self)

            for i: DBInt in 0..<result.rowCount {
                let schema = schemaCol[i] ?? ""
                let name = nameCol[i] ?? ""
                let type = typeCol[i] ?? ""

                tables.append(TableInfo(
                    schema: schema,
                    name: name,
                    type: type == "VIEW" ? .view : .table
                ))
            }

            return tables
        } catch {
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }

    /// Describe a table's structure
    /// - Parameter table: Table name (optionally schema-qualified)
    /// - Returns: Column information
    public func describeTable(_ table: String) async throws -> [ColumnInfo] {
        guard let conn = connection else {
            throw DatabaseError.notConnected
        }

        let sql = "DESCRIBE \(table)"

        do {
            let result = try conn.query(sql)
            var columns: [ColumnInfo] = []

            let nameCol = result[DBInt(0)].cast(to: String.self)
            let typeCol = result[DBInt(1)].cast(to: String.self)
            let nullCol = result[DBInt(2)].cast(to: String.self)

            for i: DBInt in 0..<result.rowCount {
                let name = nameCol[i] ?? ""
                let type = typeCol[i] ?? ""
                let nullStr = nullCol[i] ?? ""

                columns.append(ColumnInfo(
                    name: name,
                    type: type,
                    nullable: nullStr == "YES"
                ))
            }

            return columns
        } catch {
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }

    /// Describe a query's result structure
    /// - Parameter query: SQL query
    /// - Returns: Column information for the result
    public func describeQuery(_ query: String) async throws -> [ColumnInfo] {
        guard let conn = connection else {
            throw DatabaseError.notConnected
        }

        // Use DESCRIBE on the query
        let sql = "DESCRIBE (\(query))"

        do {
            let result = try conn.query(sql)
            var columns: [ColumnInfo] = []

            let nameCol = result[DBInt(0)].cast(to: String.self)
            let typeCol = result[DBInt(1)].cast(to: String.self)
            let nullCol = result[DBInt(2)].cast(to: String.self)

            for i: DBInt in 0..<result.rowCount {
                let name = nameCol[i] ?? ""
                let type = typeCol[i] ?? ""
                let nullStr = nullCol[i] ?? ""

                columns.append(ColumnInfo(
                    name: name,
                    type: type,
                    nullable: nullStr == "YES"
                ))
            }

            return columns
        } catch {
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }

    /// Get database information
    public func getDatabaseInfo() async throws -> DatabaseInfo {
        guard let conn = connection else {
            throw DatabaseError.notConnected
        }

        // Get DuckDB version
        let versionResult = try conn.query("SELECT version()")
        let version = versionResult[DBInt(0)].cast(to: String.self)[DBInt(0)] ?? "unknown"

        // Get table count
        let tableCountResult = try conn.query("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
            """)
        let tableCount = tableCountResult[DBInt(0)].cast(to: Int64.self)[DBInt(0)] ?? 0

        return DatabaseInfo(
            version: version,
            swiftBindingRevision: Self.swiftBindingRevision,
            path: currentPath,
            isInMemory: currentPath == nil,
            isReadOnly: isReadOnly,
            tableCount: Int(tableCount)
        )
    }

    // MARK: - Private Helpers

    private func extractResultSet(from result: ResultSet, limit: Int) -> QueryResultSet {
        var columns: [String] = []
        var types: [String] = []
        var rows: [[String?]] = []

        // Extract column names and types
        for i: DBInt in 0..<result.columnCount {
            let col = result[i]
            columns.append(col.name)
            types.append(col.underlyingDatabaseType.description)
        }

        // Extract rows
        let rowCount = min(Int(result.rowCount), limit)
        for rowIdx in 0..<rowCount {
            var row: [String?] = []
            for colIdx: DBInt in 0..<result.columnCount {
                let value = extractCellValue(from: result, row: DBInt(rowIdx), column: colIdx)
                row.append(value)
            }
            rows.append(row)
        }

        return QueryResultSet(
            columns: columns,
            types: types,
            rows: rows,
            rowCount: rows.count,
            totalRowCount: Int(result.rowCount)
        )
    }

    private func extractCellValue(from result: ResultSet, row: DBInt, column: DBInt) -> String? {
        let col = result[column]
        let dataType = col.underlyingDatabaseType

        // Handle based on the underlying type
        switch dataType {
        case .varchar, .blob:
            return col.cast(to: String.self)[row]

        case .boolean:
            if let value = col.cast(to: Bool.self)[row] {
                return String(value)
            }

        case .tinyint:
            if let value = col.cast(to: Int8.self)[row] {
                return String(value)
            }

        case .smallint:
            if let value = col.cast(to: Int16.self)[row] {
                return String(value)
            }

        case .integer:
            if let value = col.cast(to: Int32.self)[row] {
                return String(value)
            }

        case .bigint:
            if let value = col.cast(to: Int64.self)[row] {
                return String(value)
            }

        case .utinyint:
            if let value = col.cast(to: UInt8.self)[row] {
                return String(value)
            }

        case .usmallint:
            if let value = col.cast(to: UInt16.self)[row] {
                return String(value)
            }

        case .uinteger:
            if let value = col.cast(to: UInt32.self)[row] {
                return String(value)
            }

        case .ubigint:
            if let value = col.cast(to: UInt64.self)[row] {
                return String(value)
            }

        case .float:
            if let value = col.cast(to: Float.self)[row] {
                return String(value)
            }

        case .double:
            if let value = col.cast(to: Double.self)[row] {
                return String(value)
            }

        case .decimal:
            if let value = col.cast(to: Decimal.self)[row] {
                return "\(value)"
            }

        case .date:
            if let value = col.cast(to: Date.self)[row] {
                return String(describing: value)
            }

        case .timestamp, .timestampS, .timestampMS, .timestampNS:
            if let value = col.cast(to: Timestamp.self)[row] {
                return String(describing: value)
            }

        case .time:
            if let value = col.cast(to: Time.self)[row] {
                return String(describing: value)
            }

        case .interval:
            if let value = col.cast(to: Interval.self)[row] {
                return String(describing: value)
            }

        case .uuid:
            if let value = col.cast(to: UUID.self)[row] {
                return value.uuidString
            }

        default:
            // For unknown types, try String conversion
            return col.cast(to: String.self)[row]
        }

        return nil
    }
}

// MARK: - Supporting Types

/// Connection information
public struct ConnectionInfo: Codable, Sendable {
    public let isConnected: Bool
    public let path: String?
    public let isInMemory: Bool
    public let isReadOnly: Bool
}

/// Table information
public struct TableInfo: Codable, Sendable {
    public let schema: String
    public let name: String
    public let type: TableType

    public enum TableType: String, Codable, Sendable {
        case table = "TABLE"
        case view = "VIEW"
    }
}

/// Column information
public struct ColumnInfo: Codable, Sendable {
    public let name: String
    public let type: String
    public let nullable: Bool
}

/// Database information
public struct DatabaseInfo: Codable, Sendable {
    public let version: String
    public let swiftBindingRevision: String
    public let path: String?
    public let isInMemory: Bool
    public let isReadOnly: Bool
    public let tableCount: Int
}

/// Query result set
public struct QueryResultSet: Codable, Sendable {
    public let columns: [String]
    public let types: [String]
    public let rows: [[String?]]
    public let rowCount: Int
    public let totalRowCount: Int
}

/// Database errors
public enum DatabaseError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case queryFailed(String)
    case executionFailed(String)
    case queryNotAllowed(String)
    case readOnlyViolation
    case invalidParameter(String)
    case storageVersionMismatch(details: String, suggestion: String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to a database. Use db_connect first."
        case .connectionFailed(let msg):
            return "Connection failed: \(msg)"
        case .queryFailed(let msg):
            return "Query failed: \(msg)"
        case .executionFailed(let msg):
            return "Execution failed: \(msg)"
        case .queryNotAllowed(let msg):
            return "Query not allowed: \(msg)"
        case .readOnlyViolation:
            return "Cannot execute write operations in read-only mode"
        case .invalidParameter(let msg):
            return "Invalid parameter: \(msg)"
        case .storageVersionMismatch(let details, let suggestion):
            return "Storage version mismatch: \(details). \(suggestion)"
        }
    }
}
