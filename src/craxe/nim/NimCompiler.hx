package craxe.nim;

import haxe.macro.Context;
import sys.FileSystem;
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
		if (!FileSystem.exists(out))
			Context.fatalError("Error: output file does not exists", Context.currentPos());
		#end

		var proc = new Process("nim", ["c", "-d:release", out]);
		Sys.println(proc.stdout.readAll());
		Sys.println(proc.stderr.readAll());
		proc.close();
	}
}
