package craxe.nim.db;

/**
 * Interface of database connection
 */
interface IConnection {
    /**
     * Open connection
     */
    public function open(connectionSettings:ConnectionSettings):Void;

    /**
     * Execute SQL without result     
     */
    public function exec(sql:String):Void;


    /**
     * Exequte SQL and return rows with data     
     */
    public function query(sql:String):ResultSet;
}