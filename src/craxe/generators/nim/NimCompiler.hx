package craxe.generators.nim;

#if macro
import haxe.macro.Context;
#end

import sys.io.Process;
import craxe.common.compiler.BaseCompiler;

/**
 * Compiles nim code
 */
class NimCompiler extends BaseCompiler {
	/**
	 * Constructor
	 */
	public function new() {}

	/**
	 * Compile code
	 */
	override function compile() {
		var out:String = null;
		#if macro
		var out = haxe.macro.Context.getDefines().get("nim-out");
		if (out == null)
			Context.fatalError("Error: no output", Context.currentPos());
		if (!sys.FileSystem.exists(out))
			Context.fatalError("Error: output file does not exists", Context.currentPos());
		#end

		var proc = new Process("nim", ["c", "-d:release", out]);
		var errText = proc.stderr.readAll();
		if (errText != null && errText.length > 0) {
			trace(errText);
		} else {
			Sys.println(proc.stdout.readAll());
		}
		proc.close();
	}
}
