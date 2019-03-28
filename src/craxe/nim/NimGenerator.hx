package craxe.nim;

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import craxe.common.ast.EnumInfo;
import craxe.common.ast.ClassInfo;
import craxe.common.IndentStringBuilder;
import craxe.common.generator.BaseGenerator;

/**
 * Builder for nim code
 */
class NimGenerator extends BaseGenerator {
	/**
	 * Default out file
	 */
	static inline final DEFAULT_OUT = "main.nim";

	/**
	 * Libs to include
	 */
	final includeLibs = ["NimBoot.nim"];

	/**
	 * Add libraries to out path
	 */
	function addLibraries(outPath:String) {
		// TODO: cache
		var libPath = Context.resolvePath(".");		
		for (lib in includeLibs) {
			var lowLib = lib.toLowerCase();
			var srcPath = Path.join([libPath, "craxe", "nim", lowLib]);
			var dstPath = Path.join([outPath, lowLib]);
			File.copy(srcPath, dstPath);
		}
	}

	/**
	 * Add code helpers to header
	 */
	function addCodeHelpers(sb:IndentStringBuilder) {
		var header = Context.getDefines().get("source-header");		

		sb.add('# ${header}');
		sb.addNewLine();
		sb.add('# Hail to Mighty CRAXE!!!');
		sb.addNewLine();
		sb.addNewLine(None, true);
		sb.add('{.experimental: "codeReordering".}');
		sb.addNewLine();
		sb.addNewLine(None, true);

		for (lib in includeLibs) {
			var name = Path.withoutExtension(lib).toLowerCase();
			sb.add('import ${name}');
			sb.addNewLine();
		}
		sb.addNewLine(None, true);
	}

	/**
	 * Fix type name
	 */
	function fixTypeName(name:String):String {
		switch name {
			case "Array":
				return "HaxeArray";
		}

		return name;
	}

	/**
	 * Check type is simple by type name
	 */
	function isSimpleType(name:String):Bool {
		switch name {
			case "Int" | "Float" | "String" | "Bool":
				return true;
			default:
				return false;
		}
	}

	/**
	 * Generate simple type
	 */
	function generateSimpleType(sb:IndentStringBuilder, type:String) {
		switch type {
			case "Int":
				sb.add("int");
			case "Float":
				sb.add("float");
			case "String":
				sb.add("string");
			case "Bool":
				sb.add("bool");
		}
	}

	/**
	 * Generate TEnum
	 */
	function generateTEnum(sb:IndentStringBuilder, t:EnumType, params:Array<Type>) {
		sb.add(t.name);
	}

	/**
	 * Generate TAbstract
	 */
	function generateTAbstract(sb:IndentStringBuilder, t:AbstractType, params:Array<Type>) {
		if (isSimpleType(t.name)) {
			generateSimpleType(sb, t.name);
		} else {
			throw 'Unsupported ${t}';
		}
	}

	/**
	 * Generate TInst
	 */
	function generateTInst(sb:IndentStringBuilder, t:ClassType, params:Array<Type>) {
		if (isSimpleType(t.name)) {
			generateSimpleType(sb, t.name);
		} else {
			var typeName = fixTypeName(t.name);
			sb.add(typeName);
			sb.add("[");
			if (params != null) {
				for (par in params) {
					switch (par) {
						case TInst(t, params):
							generateTInst(sb, t.get(), params);
						case TAbstract(t, params):
							generateTAbstract(sb, t.get(), params);
						case v:
							throw 'Unsupported paramter ${v}';
					}
				}
			}
			sb.add("]");
		}
	}

	/**
	 * Generate fields for type
	 * Example:
	 *
	 *	MyType = ref object of RootObject
	 *		field1 : int
	 * 		field2 : float
	 */
	function generateTypeFields(sb:IndentStringBuilder, args:Array<{name:String, opt:Bool, t:Type}>) {
		for (arg in args) {
			sb.add(arg.name);
			sb.add(" : ");
			generateCommonTypes(sb, arg.t);
			sb.addNewLine(Same);
		}
	}

	/**
	 * Generate function arguments
	 * Example:
	 *
	 * 	proc someproc(arg1:int, arg2:float) =
	 */
	function generateFuncArguments(sb:IndentStringBuilder, args:Array<{name:String, opt:Bool, t:Type}>) {
		for (i in 0...args.length) {
			var arg = args[i];
			sb.add(arg.name);
			sb.add(":");
			generateCommonTypes(sb, arg.t);
			if (i + 1 < args.length)
				sb.add(", ");
		}
	}

	/**
	 * Generate common types
	 */
	function generateCommonTypes(sb:IndentStringBuilder, type:Type):Void {
		switch (type) {
			case TEnum(t, params):
				generateTEnum(sb, t.get(), params);
			case TInst(t, params):
				generateTInst(sb, t.get(), params);
			case TAbstract(t, params):
				generateTAbstract(sb, t.get(), params);
			case v:
				throw 'Unsupported type ${v}';
		}
	}

	/**
	 * Build classes code
	 */
	function buildClasses(sb:IndentStringBuilder, classes:Array<ClassInfo>) {

	}

	/**
	 * Generate types for enum
	 */
	function generateEnumFields(sb:IndentStringBuilder, type:Type):Void {
		switch (type) {
			case TEnum(_, _):
			// skip
			case TFun(args, _):
				generateTypeFields(sb, args);
			case v:
				generateCommonTypes(sb, v);
		}
	}

	/**
	 * Generate arguments for enum
	 */
	function generateEnumArguments(sb:IndentStringBuilder, type:Type):Void {
		switch (type) {
			case TEnum(_, _):
			// skip
			case TFun(args, _):
				generateFuncArguments(sb, args);
			case v:
				generateCommonTypes(sb, v);
		}
	}

	/**
	 * Generate constructor block for enum
	 */
	function generateEnumConstructor(sb:IndentStringBuilder, index:Int, enumName:String, type:Type):Void {
		sb.add('${enumName}(index: ${index}, tag: "${enumName}"');
		switch (type) {		
			case TEnum(_, _):	
				// Ignore
			case TFun(args, _):
				sb.add(", ");
				for (i in 0...args.length) {
					var arg = args[i];
					sb.add('${arg.name}: ${arg.name}');
					if (i + 1 < args.length)
						sb.add(", ");
				}								
			case v:
				throw 'Unsupported paramter ${v}';
		}

		sb.add(')');
	}

	/**
	 * Build enum
	 */
	function buildEnums(sb:IndentStringBuilder, enums:Array<EnumInfo>) {
		if (enums.length < 1)
			return;

		// Generate types for enums
		sb.add("type ");
		sb.addNewLine(Inc);

		for (en in enums) {
			for (constr in en.enumType.constructs) {
				sb.add('${en.enumType.name}${constr.name} = object of HaxeEnum');
				sb.addNewLine(Inc);

				generateEnumFields(sb, constr.type);

				sb.addNewLine(Dec);
				sb.addNewLine(Same, true);
			}
		}

		sb.addNewLine();
		sb.addNewLine(None, true);

		// Generate enums constructors
		for (en in enums) {
			for (constr in en.enumType.constructs) {
				var enumName = '${en.enumType.name}${constr.name}';

				sb.add('proc new${enumName}(');
				generateEnumArguments(sb, constr.type);
				sb.add(') : ${enumName} {.inline.} =');
				sb.addNewLine(Inc);
				
				generateEnumConstructor(sb, constr.index, enumName, constr.type);

				sb.addNewLine();
				sb.addNewLine(None, true);
			}
		}
	}

	#if macro
	/**
	 * Build sources
	 */
	override function build() {
		trace(types.classes.map(x->x.classType.name).join("\n"));
		trace(types.enums.map(x->x.enumType.name).join("\n"));

		var nimOut = Context.getDefines().get("nim-out");
		if (nimOut == null)
			nimOut = DEFAULT_OUT;
		
		var filename = Path.normalize(nimOut);
		var outPath = Path.directory(filename);		
		FileSystem.createDirectory(outPath);

		var sb = new IndentStringBuilder();

		addLibraries(outPath);
		addCodeHelpers(sb);

		buildClasses(sb, types.classes);
		buildEnums(sb, types.enums);

		File.saveContent(filename, sb.toString());		

		// buildEnums(sb, types.enums);

		// if (types.classes.length > 0) {
		// 	sb.add("type ");
		// 	sb.addNewLine(Inc);
		// }

		// for (c in types.classes) {
		// 	if (c.isExtern == false) {
		// 		buildClassInfo(sb, c);
		// 	}
		// }

		// sb.addNewLine(None, true);

		// // Init static classes
		// for (c in types.classes) {
		// 	if (c.isExtern == false) {
		// 		buildInitStaticClass(sb, c);
		// 	}
		// }

		// sb.addNewLine(None, true);
		// for (c in types.classes) {
		// 	if (c.isExtern == false) {
		// 		buildConstructor(sb, c);
		// 		buildClassMethods(sb, c);
		// 	}
		// }

		// buildMain(sb);
			
	}
	#end
}
