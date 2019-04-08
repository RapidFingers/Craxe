package craxe.common.ast;

import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;

/**
 * Info about interface
 */
typedef InterfaceInfo = {
    /**
     * Real AST type
     */
    var classType(default, null):ClassType;

    /**
     * Params of interface type
     */
    var params(default, null):Array<Type>;

    /**
     * Fields of instance
     */
    var fields(default, null):Array<ClassField>;

    /**
     * Methods of instance
     */
    var methods(default, null):Array<ClassField>;
}