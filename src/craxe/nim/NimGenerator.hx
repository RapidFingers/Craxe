package craxe.nim;

import haxe.macro.Expr;
import haxe.macro.Expr.MetadataEntry;
import craxe.common.ast.EntryPointInfo;
import haxe.macro.Expr.Unop;
import haxe.macro.Expr.Binop;
import haxe.macro.Context;
import craxe.common.ContextMacro;
import haxe.macro.Type;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import craxe.common.ast.EnumInfo;
import craxe.common.ast.ClassInfo;
import craxe.common.ast.ArgumentInfo;
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
	 * SImple type map
	 */
	final simpleTypes = [
		"Bool" => "bool",
		"Int" => "int",
		"Float" => "float",
		"String" => "string",
		"Void" => "void"
	];

	/**
	 * Libs to include
	 */
	final includeLibs = ["NimBoot.nim"];

	/**
	 * Add libraries to out path
	 */
	function addLibraries(outPath:String) {
		var libPath = ContextMacro.resolvePath(".");
		for (lib in includeLibs) {
			var lowLib = lib.toLowerCase();
			var srcPath = Path.join([libPath, "craxe", "nim", lib]);
			var dstPath = Path.join([outPath, lowLib]);
			File.copy(srcPath, dstPath);
		}
	}

	/**
	 * Add code helpers to header
	 */
	function addCodeHelpers(sb:IndentStringBuilder) {
		var header = ContextMacro.getDefines().get("source-header");

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
	 * Return parameters as string
	 */
	function resolveParameters(params:Array<Type>):String {
		if (params.length > 0) {
			var sb = new IndentStringBuilder();

			sb.add("[");
			for (item in params) {
				generateCommonTypes(sb, item);
			}
			sb.add("]");

			return sb.toString();
		} else {
			return "";
		}
	}

	/**
	 * Check type is simple by type name
	 */
	function isSimpleType(name:String):Bool {
		return simpleTypes.exists(name);
	}

	/**
	 * Generate simple type
	 */
	function generateSimpleType(sb:IndentStringBuilder, type:String) {
		var res = simpleTypes.get(type);
		if (res != null) {
			sb.add(res);
		} else {
			throw 'Unsupported simple type ${type}';
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
	 * Generate TType
	 */
	function generateTType(sb:IndentStringBuilder, t:DefType, params:Array<Type>) {
		trace(t.name);
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
			if (params != null && params.length > 0) {
				sb.add("[");
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
				sb.add("]");
			}
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
	function generateTypeFields(sb:IndentStringBuilder, args:Array<ArgumentInfo>) {
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
	function generateFuncArguments(sb:IndentStringBuilder, args:Array<ArgumentInfo>) {
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
			case TType(t, params):
				generateTType(sb, t.get(), params);
			case v:
				throw 'Unsupported type ${v}';
		}
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
		sb.add('proc new${enumName}(');
		generateEnumArguments(sb, type);
		sb.add(') : ${enumName} {.inline.} =');
		sb.addNewLine(Inc);
		sb.add('${enumName}(index: ${index}');
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
		sb.addBreak();
	}

	/**
	 * Generate enum helpers
	 */
	function generateEnumHelpers(sb:IndentStringBuilder, enumName:String) {
		sb.add('proc `$`(this: ${enumName}) : string {.inline.} =');
		sb.addNewLine(Inc);
		sb.add("result = $this[]");
		sb.addBreak();

		sb.add('proc `==`(e1:${enumName}, e2:${enumName}) : bool {.inline.} =');
		sb.addNewLine(Inc);
		sb.add("result = e1[] == e2[]");
		sb.addBreak();
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
			var enumName = en.enumType.name;
			sb.add('${enumName} = ref object of HaxeEnum');
			sb.addNewLine(Same);
			sb.addNewLine(Same, true);
			for (constr in en.enumType.constructs) {
				sb.add('${enumName}${constr.name} = ref object of ${enumName}');
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

				generateEnumConstructor(sb, constr.index, enumName, constr.type);
				generateEnumHelpers(sb, enumName);
			}
		}
	}

	/**
	 * Build class fields
	 */
	function generateClassInfo(sb:IndentStringBuilder, cls:ClassInfo) {
		var clsName = cls.classType.name;
		var superName = if (cls.classType.superClass != null) {
			cls.classType.superClass.t.get().name;
		} else {
			"RootObj";
		}
		var line = '${clsName} = ref object of ${superName}';
		sb.add(line);
		sb.addNewLine(Same);

		var instanceFields = cls.instanceFields;
		var iargs = [];
		for (ifield in instanceFields) {
			switch (ifield.kind) {
				case FVar(read, write):
					iargs.push({
						name: ifield.name,
						opt: false,
						t: ifield.type
					});
				case FMethod(k):
			}
		}
		sb.addNewLine(Inc);
		generateTypeFields(sb, iargs);
		sb.addNewLine(Dec);
		sb.addNewLine(Same, true);

		var staticFields = cls.classType.statics.get();
		if (staticFields.length > 0) {
			var line = '${cls.classType.name}Static = ref object of RootObj';
			sb.add(line);
			sb.addNewLine();
		}
	}

	/**
	 * Build static class initialization
	 */
	function generateStaticClassInit(sb:IndentStringBuilder, cls:ClassInfo) {
		var staticFields = cls.classType.statics.get();
		if (staticFields.length < 1)
			return;

		var clsName = cls.classType.name;
		var hasStaticMethod = false;
		for (field in staticFields) {
			switch (field.kind) {
				case FMethod(k):
					hasStaticMethod = true;
					break;
				case v:
					throw 'Unsupported paramter ${v}';
			}
		}

		if (hasStaticMethod) {
			sb.add('let ${clsName}StaticInst = ${clsName}Static()');
			sb.addNewLine();
		}
	}

	/**
	 * Generate method body
	 */
	function generateMethodBody(sb:IndentStringBuilder, expression:TypedExprDef) {
		switch (expression) {
			case TFunction(tfunc):
				generateTypedAstExpression(sb, tfunc.expr.expr);
			case v:
				throw 'Unsupported paramter ${v}';
		}

		sb.addNewLine();
		sb.addNewLine(None, true);
	}

	/**
	 * Build class constructor
	 */
	function generateClassConstructor(sb:IndentStringBuilder, cls:ClassInfo) {
		if (cls.classType.constructor == null)
			return;

		var constructor = cls.classType.constructor.get();
		var className = cls.classType.name;
		var superName:String = null;
		var superConstructor:ClassField = null;

		if (cls.classType.superClass != null) {
			var superCls = cls.classType.superClass.t.get();
			superName = superCls.name;
			if (superCls.constructor != null)
				superConstructor = superCls.constructor.get();
		}

		switch (constructor.type) {
			case TFun(args, _):
				// Generate init proc for haxe "super(params)"
				sb.add('proc init${className}(this:${className}');
				if (args.length > 0) {
					sb.add(", ");
					generateFuncArguments(sb, args);
				}
				sb.add(') {.inline.} =');
				sb.addNewLine(Inc);

				if (superName != null) {
					// Add helper for super
					// TODO: find another way
					if (superConstructor != null) {
						sb.add('template super(');
						switch (superConstructor.type) {
							case TFun(args, ret):
								if (args.length > 0) {
									sb.add(args.map(x -> x.name).join(", "));
								}
								sb.add(") =");
								sb.addNewLine(Inc);
								sb.add('init${superName}(this');
								if (args.length > 0) {
									sb.add(", ");
									sb.add(args.map(x -> x.name).join(", "));
								}
								sb.add(")");
							case v:
								throw 'Unsupported paramter ${v}';
						}
						sb.addNewLine(Dec);
					}
				}

				generateMethodBody(sb, constructor.expr().expr);
				sb.addNewLine(Dec);

				// Generate constructor
				sb.add('proc new${className}(');
				generateFuncArguments(sb, args);
				sb.add(') : ${className} {.inline.} =');
				sb.addNewLine(Inc);
				sb.add('result = ${className}()');
				sb.addNewLine(Same);
				sb.add('init${className}(result');
				if (args.length > 0) {
					sb.add(", ");
					sb.add(args.map(x -> x.name).join(", "));
				}
				sb.add(')');
				sb.addBreak();
			case v:
				throw 'Unsupported paramter ${v}';
		}
	}

	/**
	 * Build class method
	 */
	function generateClassMethod(sb:IndentStringBuilder, cls:ClassInfo, method:ClassField, isStatic:Bool) {
		switch (method.type) {
			case TFun(args, ret):
				var clsName = !isStatic ? cls.classType.name : '${cls.classType.name}Static';
				sb.add('proc ${method.name}(this:${clsName}');
				if (args.length > 0) {
					sb.add(", ");
					generateFuncArguments(sb, args);
				}
				sb.add(") : ");
				generateCommonTypes(sb, ret);
				sb.add(" =");
				sb.addNewLine(Inc);

				generateMethodBody(sb, method.expr().expr);
			case v:
				throw 'Unsupported paramter ${v}';
		}
	}

	/**
	 * Build class methods and return entry point if found
	 */
	function generateClassMethods(sb:IndentStringBuilder, cls:ClassInfo) {
		for (method in cls.instanceMethods) {
			generateClassMethod(sb, cls, method, false);
		}

		for (method in cls.staticMethods) {
			generateClassMethod(sb, cls, method, true);
		}

		// Generate heplers
		var clsName = cls.classType.name;
		sb.add('proc `$`(this:${clsName}) : string {.inline.} = ');
		sb.addNewLine(Inc);
		sb.add('result = "${clsName}"' + " & $this[]");
		sb.addBreak();
	}

	/**
	 * Build classes code
	 */
	function buildClasses(sb:IndentStringBuilder, classes:Array<ClassInfo>) {
		if (types.classes.length > 0) {
			sb.add("type ");
			sb.addNewLine(Inc);
		}

		for (c in types.classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					generateClassInfo(sb, c);
				}
			}
		}

		sb.addNewLine(None, true);

		// Init static classes
		for (c in types.classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					generateStaticClassInit(sb, c);
				}
			}
		}

		sb.addNewLine(None, true);
		for (c in types.classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					generateClassConstructor(sb, c);
					generateClassMethods(sb, c);
				}
			}
		}
	}

	/**
	 * Generate entry point
	 */
	function buildEntryPointMain(sb:IndentStringBuilder, entryPoint:EntryPointInfo) {
		sb.addNewLine(None);
		var clsName = entryPoint.classInfo.classType.name;
		var methodName = entryPoint.method.name;
		sb.add('${clsName}StaticInst.${methodName}()');
	}

	/**
	 * Build sources
	 */
	override function build() {
		trace("Classes: " + types.classes.map(x -> x.classType.name).join("\n"));
		trace("Enums " + types.enums.map(x -> x.enumType.name).join("\n"));

		var nimOut = ContextMacro.getDefines().get("nim-out");
		if (nimOut == null)
			nimOut = DEFAULT_OUT;

		var filename = Path.normalize(nimOut);
		var outPath = Path.directory(filename);
		FileSystem.createDirectory(outPath);

		var sb = new IndentStringBuilder();

		addLibraries(outPath);
		addCodeHelpers(sb);

		buildEnums(sb, types.enums);
		buildClasses(sb, types.classes);

		if (types.entryPoint != null) {
			sb.addNewLine();
			buildEntryPointMain(sb, types.entryPoint);
		}

		File.saveContent(filename, sb.toString());
	}
}
