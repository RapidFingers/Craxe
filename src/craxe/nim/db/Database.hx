package craxe.nim.db;

/**
 * For working with relational database
 */
class Database {
    /**
     * Create connection and opens it
     */
    public static function openDatabase(connection:String):IConnection {
        var connectionString = ConnectionSettings.parse(connection);
        var connection = switch connectionString.driver {
            case Sqlite:
                new SqliteConnection();
            case Mysql:
                null;
                //new MysqlConnection();
            case Postgress:
                //new PostgresqlConnection();
                null;
            case _:
                throw "Unknown database driver type";
        }        

        connection.open(connectionString);
        return connection;
    }
}