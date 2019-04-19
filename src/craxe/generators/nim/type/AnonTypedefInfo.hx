package craxe.generators.nim.type;

import haxe.io.Bytes;
import haxe.crypto.Crc32;
import haxe.macro.Type;
import haxe.macro.Type.DefType;

/**
 * Info about anon object typedef
 */
typedef AnonTypedefInfo = {
    /**
     * Type id
     */
    var id:String;

    /**
     * Type of anonimous
     */
    var name:String;

    /**
     * Fields of anon
     */
    var fields:Array<{name:String, type:Type}>;
}