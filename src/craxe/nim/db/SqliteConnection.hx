package craxe.nim.db;

import craxe.nim.db.native.SqlQuery;
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
        nativeConn.exec(new SqlQuery(sql));
    }

	/**
     * Exequte SQL and return rows with data     
     */
    public function query(sql:String):ResultSet {
		var iter = nativeConn.fastRows(new SqlQuery(sql));
		return new ResultSet(iter.toHaxeIterator());
	}
}
