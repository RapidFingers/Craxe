package craxe.common.ast.type;

import haxe.macro.Type.AnonType;

/**
 * Information about anonymous
 */
typedef AnonInfo = {
    /**
     * Generated name
     */
    var name:String;

    /**
     * Anon type
     */
    var anon:AnonType;
}