package craxe.common.ast;

/**
 * Information of resolved argument
 */
typedef ResolvedArgumentInfo = {
    /**
     * Name of argument
     */
    var name(default, null):String;

    /**
     * Is optional
     */
    var opt(default, null):Bool;

    /**
     * Resolved type of argument
     */
    var t(default, null):String;
}