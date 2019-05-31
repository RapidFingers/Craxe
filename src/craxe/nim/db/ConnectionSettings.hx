package craxe.nim.db;

/**
 * Known database driver type
 */
enum abstract DriverType(Int) from Int to Int {
	var Sqlite = 0;
	var Mysql = 1;
	var Postgress = 2;
}

/**
 * Database connection settings
 */
class ConnectionSettings {
	/**
	 * Database driver type
	 */
	public final driver:DriverType;

	/**
	 * Name of database
	 */
	public final database:String;


    /**
     * Parse string and return parsed connection string data
     */
    public static function parse(value:String):ConnectionSettings {
        return new ConnectionSettings(DriverType.Sqlite, "test.db");
    }

	/**
	 * Private constructor
	 */
	function new(driver:DriverType, database:String) {
        this.driver = driver;
		this.database = database;
    }
}
