package craxe.common;

import haxe.macro.Context;
import haxe.macro.Expr;
import sys.io.File;
import haxe.io.Path;

/**
 * Macro for working with files
 */
class ContextMacro {    
    /**
     * Get defines
     */
    public static function getDefines():Map<String, String> {        
        #if macro
        return Context.getDefines();
        #end
        throw "Not supported";
    }

    /**
     * Check if AnyType supported and throw exception if not
     */
    public static function ckeckAnyTypeSupport() {
        #if macro
        var supported = Context.getDefines().get("nim-any") == "enable";
        if (supported)
            return;
        
        Context.fatalError("AnyType is restricted. Please, add -D nim-any=enable to your configuration, or remove all Any type from the code.", Context.currentPos());
        #end
        throw "Not supported";
    }

    /**
     * Resolve path
     */
    public static function resolvePath(path:String):String {        
        #if macro
        return Context.resolvePath(path);
        #end
        throw "Not supported";
    }  
}