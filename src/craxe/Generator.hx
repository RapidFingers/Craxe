package craxe;

import haxe.macro.Type;
import craxe.common.ast.CommonAstPreprocessor;
import craxe.common.generator.BaseGenerator;

/**
 * Code generator
 */
class Generator {
	#if macro
	public static function generate() {
		haxe.macro.Context.onGenerate(onGenerate);
	}
	#end

    /**
	 * Callback on generating code from context
	 */
	public static function onGenerate(types:Array<Type>):Void {
		var preprocessor = new CommonAstPreprocessor();
		var builder:BaseGenerator = null;		

		var processed = preprocessor.process(types);

		#if nim
		builder = new craxe.nim.NimGenerator(processed);
		#end

		if (builder == null)
			throw "Not supported builder type";

		builder.build();
	}
} 