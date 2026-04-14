## ADDED Requirements

### Requirement: Dual documentation source loading

The system SHALL download and parse two documentation sources on initialization:
1. `https://duckdb.org/llms.txt` (lightweight LLM reference, ~3KB)
2. `https://blobs.duckdb.org/docs/duckdb-docs.md` (full documentation, ~5MB)

Each source SHALL be stored in a separate cache file and parsed independently.

#### Scenario: Both sources loaded successfully

- **WHEN** the MCP server starts and both URLs are reachable
- **THEN** both `llms.txt` and `duckdb-docs.md` SHALL be downloaded and cached
- **AND** sections from both sources SHALL be available for search

#### Scenario: llms.txt download fails

- **WHEN** the `llms.txt` URL returns an error or is unreachable
- **THEN** the system SHALL log a warning and continue with only `duckdb-docs.md`
- **AND** all documentation tools SHALL remain functional

#### Scenario: duckdb-docs.md download fails

- **WHEN** the `duckdb-docs.md` URL returns an error or is unreachable
- **THEN** the system SHALL log a warning and continue with only `llms.txt` if available
- **AND** if neither source is available and no cache exists, the system SHALL return an error indicating documentation is unavailable

### Requirement: Conditional HTTP caching with ETag and Last-Modified

The system SHALL store the `ETag` and `Last-Modified` response headers from each documentation download. On subsequent cache checks, the system SHALL send conditional HTTP requests using `If-None-Match` (for ETag) and `If-Modified-Since` (for Last-Modified).

#### Scenario: Cache is still valid (304 Not Modified)

- **WHEN** cache validation is triggered and the server responds with HTTP 304
- **THEN** the system SHALL use the existing cached file without re-downloading
- **AND** the cache metadata (ETag, Last-Modified) SHALL remain unchanged

#### Scenario: Cache is stale (200 OK with new content)

- **WHEN** cache validation is triggered and the server responds with HTTP 200
- **THEN** the system SHALL replace the cached file with the new content
- **AND** the cache metadata SHALL be updated with the new ETag and Last-Modified values
- **AND** the search index SHALL be rebuilt from the new content

#### Scenario: Cache validation fails (network error)

- **WHEN** cache validation is triggered but the HTTP request fails
- **THEN** the system SHALL use the existing cached file if it exists
- **AND** the system SHALL log a warning about the failed validation

### Requirement: Cache metadata persistence

The system SHALL persist cache metadata (ETag, Last-Modified, download timestamp) in a JSON file alongside each cached documentation file at `~/.cache/che-duckdb-mcp/cache-meta.json`.

#### Scenario: Cache metadata is saved after download

- **WHEN** a documentation file is downloaded successfully
- **THEN** the system SHALL write a `cache-meta.json` file containing `etag`, `lastModified`, and `downloadedAt` fields for each source

#### Scenario: Cache metadata is read on startup

- **WHEN** the MCP server starts and cached files exist
- **THEN** the system SHALL read `cache-meta.json` to determine whether conditional HTTP requests are needed

### Requirement: Documentation source identification in results

The `get_doc_info` tool SHALL report information for each documentation source separately, including source URL, cache status, last update time, and section count.

#### Scenario: get_doc_info reports both sources

- **WHEN** user calls `get_doc_info` and both sources are loaded
- **THEN** the response SHALL include an array of source objects, each containing `source` (URL), `cachePath`, `lastUpdated`, `sectionCount`, and `contentSize`
