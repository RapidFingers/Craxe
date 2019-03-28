package craxe.common;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import sys.io.File;
import haxe.io.Path;

/**
 * Macro for working with files
 */
class FileMacro {
    /**
     * Load text
     */
    public static function loadText(path:String):String {
        var curpath = Context.resolvePath(".");				
		var fl = Path.join([curpath, path]);
		final content = File.getContent(fl);
        return content;
    }
}

#end