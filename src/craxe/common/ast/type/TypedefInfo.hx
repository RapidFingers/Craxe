package craxe.common.ast.type;

import haxe.macro.Type;
import haxe.macro.Type.DefType;

/**
 * Info about typedef
 */
typedef TypedefInfo = {
    /**
     * AST typedef info
     */
    var typedefInfo:DefType;

    /**
     * Type parameters
     */
    var params:Array<Type>;
}