import Foundation
import SQLite3
import AppKit

class DatabaseManager {
    private var db: OpaquePointer?
    
    init() {
        openDatabase()
        createTable()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    private func openDatabase() {
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("com.aking.MacCopy")
        
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let dbPath = appDir.appendingPathComponent("history.sqlite").path
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }
    
    private func createTable() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS History(
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Content TEXT,
        Type TEXT,
        Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);
        """
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("History table created.")
            } else {
                print("History table could not be created.")
            }
        } else {
            print("CREATE TABLE statement could not be prepared.")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func insert(content: String, type: String) {
        let checkStatementString = "SELECT Id FROM History WHERE Content = ? AND Type = ?;"
        var checkStatement: OpaquePointer?
        var existingId: Int? = nil
        
        if sqlite3_prepare_v2(db, checkStatementString, -1, &checkStatement, nil) == SQLITE_OK {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(checkStatement, 1, (content as NSString).utf8String, -1, transient)
            sqlite3_bind_text(checkStatement, 2, (type as NSString).utf8String, -1, transient)
            if sqlite3_step(checkStatement) == SQLITE_ROW {
                existingId = Int(sqlite3_column_int(checkStatement, 0))
            }
        }
        sqlite3_finalize(checkStatement)
        
        if let id = existingId {
            let updateStatementString = "UPDATE History SET Timestamp = CURRENT_TIMESTAMP WHERE Id = ?;"
            var updateStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
                sqlite3_bind_int(updateStatement, 1, Int32(id))
                if sqlite3_step(updateStatement) != SQLITE_DONE {
                    print("Could not update row.")
                }
            }
            sqlite3_finalize(updateStatement)
        } else {
            let insertStatementString = "INSERT INTO History (Content, Type) VALUES (?, ?);"
            var insertStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
                let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(insertStatement, 1, (content as NSString).utf8String, -1, transient)
                sqlite3_bind_text(insertStatement, 2, (type as NSString).utf8String, -1, transient)
                
                if sqlite3_step(insertStatement) != SQLITE_DONE {
                    print("Could not insert row.")
                }
            }
            sqlite3_finalize(insertStatement)
        }
    }
    
    func fetchRecent(limit: Int = 50) -> [(id: Int, content: String, type: String)] {
        let queryStatementString = "SELECT Id, Content, Type FROM History ORDER BY Timestamp DESC LIMIT ?;"
        var queryStatement: OpaquePointer?
        var results = [(Int, String, String)]()
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(queryStatement, 1, Int32(limit))
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(queryStatement, 0))
                
                var content = ""
                if let contentPointer = sqlite3_column_text(queryStatement, 1) {
                    content = String(cString: contentPointer)
                }
                
                var type = ""
                if let typePointer = sqlite3_column_text(queryStatement, 2) {
                    type = String(cString: typePointer)
                }
                
                results.append((id, content, type))
            }
        }
        sqlite3_finalize(queryStatement)
        return results
    }
    
    func cleanOldRecords(limit: Int) {
        let getOldRecordsString = """
        SELECT Content, Type FROM History
        WHERE Id NOT IN (
            SELECT Id FROM History ORDER BY Timestamp DESC LIMIT ?
        );
        """
        
        var getStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, getOldRecordsString, -1, &getStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(getStatement, 1, Int32(limit))
            while sqlite3_step(getStatement) == SQLITE_ROW {
                if let typePointer = sqlite3_column_text(getStatement, 1), let contentPointer = sqlite3_column_text(getStatement, 0) {
                    let type = String(cString: typePointer)
                    let content = String(cString: contentPointer)
                    if type == "Image" {
                        try? FileManager.default.removeItem(atPath: content)
                    }
                }
            }
        }
        sqlite3_finalize(getStatement)
        
        let deleteString = """
        DELETE FROM History
        WHERE Id NOT IN (
            SELECT Id FROM History ORDER BY Timestamp DESC LIMIT ?
        );
        """
        var deleteStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStatement, 1, Int32(limit))
            if sqlite3_step(deleteStatement) != SQLITE_DONE {
                print("Could not delete old records.")
            }
        }
        sqlite3_finalize(deleteStatement)
    }
}
