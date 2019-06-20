package craxe.nim;

/**
 * Adapter for nim iterator
 */
extern class NimIterator<TParams, TReturn> {
    /**
     * Converts to haxe iterator
     */
    public function toHaxeIterator():Iterator<TReturn>;
}