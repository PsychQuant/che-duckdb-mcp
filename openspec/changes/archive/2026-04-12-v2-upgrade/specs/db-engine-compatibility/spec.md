## ADDED Requirements

### Requirement: Pinned duckdb-swift dependency version

The `Package.swift` file SHALL specify the `duckdb-swift` dependency using a pinned revision (`.revision("commit_hash")`) instead of `branch: "main"`. The pinned revision SHALL be documented in CHANGELOG.md with the corresponding DuckDB engine version.

#### Scenario: Package.swift uses pinned revision

- **WHEN** the project is built with `swift build`
- **THEN** Swift Package Manager SHALL resolve `duckdb-swift` to the exact pinned revision
- **AND** the resolved version SHALL NOT change unless the pin is explicitly updated

### Requirement: Storage format version detection

The system SHALL detect the storage format version of a `.duckdb` file before attempting to open it. The storage version SHALL be read from the file header (offset 0x30).

#### Scenario: Compatible storage version

- **WHEN** user calls `db_connect` with a `.duckdb` file whose storage version is within the supported range of the pinned duckdb-swift version
- **THEN** the connection SHALL proceed normally

#### Scenario: Incompatible storage version

- **WHEN** user calls `db_connect` with a `.duckdb` file whose storage version is newer than the pinned duckdb-swift supports
- **THEN** the system SHALL return an error message that includes:
  1. The file's storage version
  2. The supported version range
  3. A suggestion to upgrade che-duckdb-mcp or use the DuckDB CLI to export/re-import the data

#### Scenario: In-memory database skips version check

- **WHEN** user calls `db_connect` without a path (in-memory mode)
- **THEN** the system SHALL skip storage version detection and connect directly

### Requirement: DuckDB engine version reporting

The `db_info` tool SHALL report both the DuckDB engine version (from `SELECT version()`) and the pinned duckdb-swift revision hash.

#### Scenario: db_info includes version details

- **WHEN** user calls `db_info` while connected to a database
- **THEN** the response SHALL include a `duckdbVersion` field (e.g., "v1.2.0") and a `swiftBindingRevision` field (e.g., "d90cf8d")

### Requirement: Graceful handling of version mismatch errors

The system SHALL catch `DuckDB.DatabaseError` with error code 5 (IO error caused by storage format mismatch) and provide a user-friendly error message instead of the raw error.

#### Scenario: Storage format mismatch error is caught

- **WHEN** `db_connect` encounters `DuckDB.DatabaseError` error code 5
- **THEN** the system SHALL return a structured error with `error_type: "storage_version_mismatch"` and a human-readable message explaining the version incompatibility
- **AND** the raw DuckDB error message SHALL be included in a `details` field
