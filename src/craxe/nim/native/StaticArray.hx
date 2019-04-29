package craxe.nim.native;

import haxe.io.Bytes;

/**
 * Nim's static array[size, type]
 */
extern class StaticArray<T> {}

/**
 * Helper for static array
 */
extern class StaticArrayHelper {
    /**
     * Convert uint8[] to Haxe Bytes
     */
    public static function toBytes(data:StaticArray<UInt8>):Bytes;
}
