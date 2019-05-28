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
     * Execute SQL with result
     */
    public function query(sql:String):Void;
}