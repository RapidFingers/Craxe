package craxe.nim.db;

import craxe.nim.db.native.SqliteNative.DataRow;

/**
 * Result rows with data
 */
class ResultSet {
    /**
     * Native iterator of rows
     */
    final nativeIter:NimIterator<DataRow>;

    /**
     * Constructor      
     */
    public function new(nativeIter:NimIterator<DataRow>) {
        this.nativeIter = nativeIter;
    }

    /**
     * Return iterator of rows
     */
    public inline function iterator():Iterator<DataRow> {
        return null;
    }
}