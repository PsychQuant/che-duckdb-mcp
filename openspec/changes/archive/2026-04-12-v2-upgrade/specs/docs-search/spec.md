## ADDED Requirements

### Requirement: TF-IDF weighted search scoring

The search engine SHALL compute relevance scores using TF-IDF (Term Frequency–Inverse Document Frequency) weighting. Each document section SHALL have a pre-computed TF-IDF vector built at documentation load time. Search results SHALL be ranked by cosine similarity between the query vector and document vectors.

#### Scenario: Search returns results ranked by relevance

- **WHEN** user calls `search_docs` with query "read_csv options"
- **THEN** sections containing both "read_csv" and "options" SHALL rank higher than sections containing only one term
- **AND** the `score` field in each result SHALL reflect TF-IDF weighted relevance

#### Scenario: Inverted index is built on documentation load

- **WHEN** documentation is loaded or refreshed via `refresh_docs`
- **THEN** an inverted index SHALL be constructed mapping each normalized term to the list of sections containing it
- **AND** subsequent searches SHALL use the index instead of scanning all sections

### Requirement: Fuzzy matching for function names

The search engine SHALL support fuzzy matching for DuckDB function names using case-insensitive and underscore-insensitive normalization, combined with Levenshtein distance matching (threshold ≤ 2).

#### Scenario: Underscore-insensitive function name matching

- **WHEN** user calls `get_function_docs` with function_name "readcsv"
- **THEN** the system SHALL match it to the documentation for `read_csv`

#### Scenario: Case-insensitive function name matching

- **WHEN** user calls `get_function_docs` with function_name "JSON_EXTRACT"
- **THEN** the system SHALL match it to the documentation for `json_extract`

#### Scenario: Levenshtein distance matching within threshold

- **WHEN** user calls `get_function_docs` with function_name "read_csvs" (distance 1 from "read_csv")
- **THEN** the system SHALL match it to `read_csv`

#### Scenario: No match beyond Levenshtein threshold

- **WHEN** user calls `get_function_docs` with function_name "completely_wrong"
- **THEN** the system SHALL return a "Function not found" error with a suggestion to use `search_docs`

### Requirement: Multi-source search result merging

The search engine SHALL merge results from both `llms.txt` sections and `duckdb-docs.md` sections. Results from `llms.txt` SHALL receive a bonus score multiplier of 1.5x to prioritize concise, LLM-optimized content.

#### Scenario: llms.txt results ranked above equivalent duckdb-docs.md results

- **WHEN** user calls `search_docs` with a query that matches sections in both sources
- **THEN** the `llms.txt` match SHALL appear before the `duckdb-docs.md` match when their base TF-IDF scores are equal

#### Scenario: Deduplication across sources

- **WHEN** both `llms.txt` and `duckdb-docs.md` contain sections with identical titles
- **THEN** the search results SHALL deduplicate by title, keeping the higher-scored entry
- **AND** the result SHALL indicate which source it came from via a `source` field

### Requirement: Search mode support

The search engine SHALL support three search modes: `title` (section titles only), `content` (body text only), and `all` (both). The default mode SHALL be `all`.

#### Scenario: Title-only search

- **WHEN** user calls `search_docs` with mode "title" and query "SELECT"
- **THEN** only sections whose title contains "SELECT" SHALL be returned
- **AND** body text matches SHALL be excluded

#### Scenario: Content-only search

- **WHEN** user calls `search_docs` with mode "content" and query "COPY"
- **THEN** only sections whose body content contains "COPY" SHALL be returned
- **AND** title-only matches SHALL be excluded
