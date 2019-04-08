package craxe.common.ast;

import craxe.common.ast.type.ClassInfo;
import haxe.macro.Type.ClassField;

/**
 * Entry point info
 */
typedef EntryPointInfo = {
    /**
     * Class information
     */
    var classInfo:ClassInfo;

    /**
     * Method information
     */
    var method(default, null):ClassField;
}