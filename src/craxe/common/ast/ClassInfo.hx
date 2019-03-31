package craxe.common.ast;

import haxe.macro.Type;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.ClassField;

/**
 * Info about class
 */
typedef ClassInfo = {
    /**
     * Real AST type
     */
    var classType(default, null):ClassType;

    /**
     * Params of class type
     */
    var params(default, null):Array<Type>;

    /**
     * Fields of instance
     */
    var instanceFields:Array<ClassField>;

    /**
     * Methods of instance
     */
    var instanceMethods:Array<ClassField>;

    /**
     * Static fields
     */
    var staticFields:Array<ClassField>;

    /**
     * Static methods
     */
    var staticMethods:Array<ClassField>;
}