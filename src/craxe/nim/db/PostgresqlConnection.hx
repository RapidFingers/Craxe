package craxe.nim.db;

/**
 * Connection to Postgresql
 */
extern class PostgresqlConnection implements IConnection {
	/**
	 * Constructor
	 */
	@:native("newPostgresqlConnection")
	public function new();

	/**
	 * Open connection
	 */
	public function open(connectionSettings:ConnectionSettings):Void;

	/**
	 * Executue SQL without result
	 */
	public function exec(sql:String):Void;

	/**
	 * Execute SQL with result
	 */
	public function query(sql:String):Void;
}
