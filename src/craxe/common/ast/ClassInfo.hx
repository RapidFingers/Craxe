package craxe.common.ast;

import haxe.macro.Type;
import haxe.macro.Type.ClassType;

/**
 * Info about class
 */
typedef ClassInfo = {
    var classType(default, null):ClassType;
    var params(default, null):Array<Type>;
}