package craxe.common.ast;

import haxe.macro.Type;
import haxe.macro.Type.EnumType;

/**
 * Enum information
 */
typedef EnumInfo = {
    var enumType:EnumType;
    var params:Array<Type>;
}
