package craxe.nim.db;

import craxe.nim.db.native.SqliteNative;

/**
 * Connection to Sqlite
 */
class SqliteConnection implements IConnection {
	/**
	 * Native connection
	 */
	var nativeConn:SqliteConnectionNative;

	/**
	 * Constructor
	 */
	public function new() {}

	/**
	 * Open connection
	 */
	public function open(connectionSettings:ConnectionSettings):Void {
        nativeConn = SqliteNative.open(connectionSettings.database, "" , "", "");
    }

	/**
	 * Executue SQL without result
	 */
	public function exec(sql:String):Void {
        nativeConn.exec(sql);
    }
}
