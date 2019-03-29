package craxe.common.ast;

/**
 * Information of argument
 */
typedef ArgumentInfo = {
    /**
     * Name of argument
     */
    var name(default, null):String;

    /**
     * Is optional
     */
    var opt(default, null):Bool;

    /**
     * Type of argument
     */
    var t(default, null):haxe.macro.Type;
}