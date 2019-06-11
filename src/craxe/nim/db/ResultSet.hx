package craxe.nim.db;

import craxe.nim.db.native.SqliteNative.DataRow;

/**
 * Result rows with data
 */
class ResultSet {
    /**
     * Native iterator of rows
     */
    final dataIterator:Iterator<DataRow>;

    /**
     * Constructor      
     */
    public function new(dataIterator:Iterator<DataRow>) {
        this.dataIterator = dataIterator;
    }

    /**
     * Return iterator of rows
     */
    public inline function iterator():Iterator<DataRow> {        
        return dataIterator;
    }
}