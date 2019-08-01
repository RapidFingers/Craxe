package craxe.nim;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Core methods that will be processed by generator
 */
extern class NimExtern {
    /**
     * Paste raw code
     */
    public static extern function rawCode(expr:String):Void;
}

class Nim {
    /**
     * Add raw nim code
     */
    public macro static function code(expr:String) {
        return macro {
            NimExtern.rawCode($v{expr});
        }
    }
}