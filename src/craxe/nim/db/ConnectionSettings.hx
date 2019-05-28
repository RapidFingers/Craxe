package craxe.nim.db;

/**
 * Known database driver type
 */
enum DriverType {
	Sqlite;
	Mysql;
	Postgress;
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
     * Parse string and return parsed connection string data
     */
    public static function parse(value:String):ConnectionSettings {
        return new ConnectionSettings(Sqlite);
    }

	/**
	 * Private constructor
	 */
	function new(driver:DriverType) {
        this.driver = driver;
    }
}
