import CSQLite
import Foundation

actor ImportLedger {
    static let directoryName = ".card-importer"
    static let databaseName = "imports.sqlite"
    static let applicationSupportDirectoryName = "CardImporter"

    private var database: OpaquePointer?
    let databaseURL: URL

    init() throws {
        let applicationSupportURL = try Self.applicationSupportURL()
        try FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)

        databaseURL = applicationSupportURL.appendingPathComponent(Self.databaseName)
        if sqlite3_open(databaseURL.path, &database) != SQLITE_OK {
            throw AppError.sqlite(Self.errorMessage(database))
        }

        try Self.execute("""
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS imports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content_hash TEXT NOT NULL,
            byte_count INTEGER NOT NULL,
            original_filename TEXT NOT NULL,
            source_volume_uuid TEXT,
            source_relative_path TEXT NOT NULL,
            capture_date REAL,
            media_kind TEXT NOT NULL,
            destination_root_path TEXT,
            destination_path TEXT NOT NULL,
            destination_absolute_path TEXT,
            destination_volume_uuid TEXT,
            imported_at REAL NOT NULL,
            verified_at REAL NOT NULL,
            UNIQUE(content_hash, byte_count)
        );
        CREATE INDEX IF NOT EXISTS idx_imports_source ON imports(source_volume_uuid, source_relative_path);
        CREATE INDEX IF NOT EXISTS idx_imports_destination ON imports(destination_path);
        CREATE INDEX IF NOT EXISTS idx_imports_absolute_destination ON imports(destination_absolute_path);
        """, database: database)

        try Self.migrateSchemaIfNeeded(database: database)
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    static func applicationSupportURL() throws -> URL {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppError.sqlite("Could not resolve the user Application Support directory.")
        }

        return baseURL.appendingPathComponent(applicationSupportDirectoryName, isDirectory: true)
    }

    static func defaultDatabaseURL() throws -> URL {
        try applicationSupportURL().appendingPathComponent(databaseName)
    }

    func record(contentHash: String, byteCount: Int64) throws -> ImportRecord? {
        var statement: OpaquePointer?
        let sql = """
        SELECT id, content_hash, byte_count, original_filename, source_volume_uuid, source_relative_path,
               capture_date, media_kind, destination_root_path, destination_path, destination_absolute_path,
               destination_volume_uuid, imported_at, verified_at
        FROM imports
        WHERE content_hash = ? AND byte_count = ?
        LIMIT 1;
        """

        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        bindText(contentHash, to: statement, at: 1)
        sqlite3_bind_int64(statement, 2, byteCount)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return readRecord(from: statement)
    }

    func insert(_ record: ImportRecord) throws {
        var statement: OpaquePointer?
        let sql = """
        INSERT OR REPLACE INTO imports (
            content_hash, byte_count, original_filename, source_volume_uuid, source_relative_path,
            capture_date, media_kind, destination_root_path, destination_path, destination_absolute_path,
            destination_volume_uuid, imported_at, verified_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        bindText(record.contentHash, to: statement, at: 1)
        sqlite3_bind_int64(statement, 2, record.byteCount)
        bindText(record.originalFilename, to: statement, at: 3)
        bindText(record.sourceVolumeUUID, to: statement, at: 4)
        bindText(record.sourceRelativePath, to: statement, at: 5)
        bindDate(record.captureDate, to: statement, at: 6)
        bindText(record.mediaKind.rawValue, to: statement, at: 7)
        bindText(record.destinationRootPath, to: statement, at: 8)
        bindText(record.destinationPath, to: statement, at: 9)
        bindText(record.destinationAbsolutePath, to: statement, at: 10)
        bindText(record.destinationVolumeUUID, to: statement, at: 11)
        bindDate(record.importedAt, to: statement, at: 12)
        bindDate(record.verifiedAt, to: statement, at: 13)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw AppError.sqlite(Self.errorMessage(database))
        }
    }

    func count() throws -> Int {
        var statement: OpaquePointer?
        try prepare("SELECT COUNT(*) FROM imports;", statement: &statement)
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    private static func migrateSchemaIfNeeded(database: OpaquePointer?) throws {
        let columns = try columnNames(for: "imports", database: database)

        if !columns.contains("destination_root_path") {
            try Self.execute("ALTER TABLE imports ADD COLUMN destination_root_path TEXT;", database: database)
        }

        if !columns.contains("destination_absolute_path") {
            try Self.execute("ALTER TABLE imports ADD COLUMN destination_absolute_path TEXT;", database: database)
        }

        try Self.execute("""
        CREATE INDEX IF NOT EXISTS idx_imports_absolute_destination ON imports(destination_absolute_path);
        """, database: database)
    }

    private static func columnNames(for tableName: String, database: OpaquePointer?) throws -> Set<String> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA table_info(\(tableName));", -1, &statement, nil) == SQLITE_OK else {
            throw AppError.sqlite(errorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = columnString(statement, 1) {
                columns.insert(name)
            }
        }

        return columns
    }

    private static func execute(_ sql: String, database: OpaquePointer?) throws {
        var error: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? Self.errorMessage(database)
            sqlite3_free(error)
            throw AppError.sqlite(message)
        }
    }

    private func prepare(_ sql: String, statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw AppError.sqlite(Self.errorMessage(database))
        }
    }

    private func bindText(_ text: String?, to statement: OpaquePointer?, at index: Int32) {
        guard let text else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, text, -1, sqliteTransient)
    }

    private func bindDate(_ date: Date?, to statement: OpaquePointer?, at index: Int32) {
        guard let date else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_double(statement, index, date.timeIntervalSince1970)
    }

    private func readRecord(from statement: OpaquePointer?) -> ImportRecord {
        ImportRecord(
            id: sqlite3_column_int64(statement, 0),
            contentHash: columnString(statement, 1) ?? "",
            byteCount: sqlite3_column_int64(statement, 2),
            originalFilename: columnString(statement, 3) ?? "",
            sourceVolumeUUID: columnString(statement, 4),
            sourceRelativePath: columnString(statement, 5) ?? "",
            captureDate: columnDate(statement, 6),
            mediaKind: MediaKind(rawValue: columnString(statement, 7) ?? "") ?? .other,
            destinationRootPath: columnString(statement, 8),
            destinationPath: columnString(statement, 9) ?? "",
            destinationAbsolutePath: columnString(statement, 10),
            destinationVolumeUUID: columnString(statement, 11),
            importedAt: columnDate(statement, 12) ?? .distantPast,
            verifiedAt: columnDate(statement, 13) ?? .distantPast
        )
    }

    private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        Self.columnString(statement, index)
    }

    private static func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: text)
    }

    private func columnDate(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private static func errorMessage(_ database: OpaquePointer?) -> String {
        if let database, let message = sqlite3_errmsg(database) {
            return String(cString: message)
        }
        return "Unknown SQLite error"
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
