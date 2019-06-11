package craxe.nim.db.native;

/**
 * Connection to Sqlite
 */
@:native("db_sqlite")
@:require("db_sqlite")
extern class SqliteNative {
    /**
     * Open connection
     */
    public static function open(connection:String, user:String, password:String, database: String):SqliteConnectionNative;    
}

/**
 * Row with data
 */
@:native("Row")
extern class DataRow {
}

/**
 * Sqlite native connection
 */
@:native("DbConn")
extern class SqliteConnectionNative {
    /**
     * Executue SQL without result     
     */
    public function exec(sql:SqlQuery):Void;

    /**
     * Execute SQL and return iterator of rows
     */    
    public function fastRows(sql:SqlQuery):NimIterator<{db:SqliteConnectionNative, sql:String}, DataRow>;
}