package craxe.ast2obj;

import haxe.macro.Type;
import haxe.macro.Type.EnumType;

/**
 * Enum information
 */
typedef OEnum = {
    var enumType:EnumType;
    var params:Array<Type>;
}
