package craxe.generators.nim;

import haxe.ds.StringMap;
import craxe.common.ast.ArgumentInfo;
import craxe.common.ast.PreprocessedTypes;
import craxe.common.ast.EntryPointInfo;
import craxe.common.ContextMacro;
import haxe.macro.Type;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import craxe.common.ast.type.*;
import craxe.common.IndentStringBuilder;
import craxe.common.generator.BaseGenerator;
import craxe.generators.nim.type.*;
import craxe.generators.nim.*;

using craxe.common.ast.MetaHelper;

/**
 * Builder for nim code
 */
class NimGenerator extends BaseGenerator {
	/**
	 * Default out file
	 */
	static inline final DEFAULT_OUT = "main.nim";

	/**
	 * Type context
	 */
	final typeContext:TypeContext;

	/**
	 * Type resolver
	 */
	final typeResolver:TypeResolver;

	/**
	 * Code generator for expressions
	 */
	final expressionGenerator:MethodExpressionGenerator;

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
			var srcPath = Path.join([libPath, "craxe", "generators", "nim", lib]);
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
		sb.addBreak();

		for (lib in includeLibs) {
			var name = Path.withoutExtension(lib).toLowerCase();
			sb.add('import ${name}');
			sb.addNewLine();
		}

		var reqHash = new StringMap<String>();
		for (item in types.classes) {
			var req = item.classType.meta.getMetaValue(":require");
			if (req != null)
				reqHash.set(req, req);
		}
		for (key => _ in reqHash) {
			sb.add('import ${key}');
			sb.addNewLine();
		}

		sb.addBreak();
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
			sb.add(typeResolver.resolve(arg.t));
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
			sb.add(typeResolver.resolve(arg.t));
			if (i + 1 < args.length)
				sb.add(", ");
		}
	}

	/**
	 * Generate function arguments for Abstract type
	 */
	function generateFuncArgumentsAbstract(sb:IndentStringBuilder, abstr:AbstractType, args:Array<ArgumentInfo>) {
		for (i in 0...args.length) {
			var arg = args[i];			
			if (arg.name.indexOf("this") >= 0) {				
				sb.add('${arg.name}1');
			} else {
				sb.add(arg.name);
			}
			sb.add(":");
			if (arg.name == "this") {
				sb.add('${abstr.name}Abstr');
			} else {
				sb.add(typeResolver.resolve(arg.t));
			}
			if (i + 1 < args.length)
				sb.add(", ");
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
				sb.add(typeResolver.resolve(v));
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
				sb.add(typeResolver.resolve(v));
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
	 * Generate code for enums
	 */
	function buildEnums(sb:IndentStringBuilder) {
		var enums = types.enums;
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
	 * Generate code for interfaces
	 */
	function buildInterfaces(sb:IndentStringBuilder) {
		if (!typeContext.hasInterfaces)
			return;

		// Generate types for enums
		sb.add("type ");
		sb.addNewLine(Inc);

		var interGenerateor = new InterfaceGenerator();
		for (inter in typeContext.interfaceIterator()) {
			interGenerateor.generateInterfaceObject(sb, inter, typeResolver);
		}

		sb.addBreak();

		for (cls in typeContext.classIterator()) {
			for (inter in cls.classType.interfaces) {
				var cinter = typeContext.getInterfaceByName(inter.t.get().name);
				interGenerateor.generateInterfaceConverter(sb, cls, cinter, typeResolver);
			}
		}

		sb.addBreak();
	}

	/**
	 * Build typedefs
	 */
	function buildTypedefs(sb:IndentStringBuilder) {
		var typedefs = types.typedefs;
		var anons = typeContext.allAnonymous();
		if (typedefs.length < 1 && anons.length < 1)
			return;

		sb.add("type ");
		sb.addNewLine(Inc);

		for (td in typedefs) {
			switch (td.typedefInfo.type) {
				case TInst(t, _):
					sb.add('${td.typedefInfo.name} = ${t.get().name}');
					sb.addNewLine(Same);
				case TFun(_, _):
					var tpname = typeResolver.resolve(td.typedefInfo.type);
					sb.add('${td.typedefInfo.name} = ${tpname}');
					sb.addNewLine(Same);
				case TAbstract(_, _):
					var tpname = typeResolver.resolve(td.typedefInfo.type);
					sb.add('${td.typedefInfo.name} = ${tpname}');
					sb.addNewLine(Same);
				case TAnonymous(a):
				case v:
					throw 'Unsupported ${v}';
			}
		}

		for (an in anons) {
			sb.add('${an.name} = ref object of RootObj');
			sb.addNewLine(Inc);
			for (fld in an.fields) {
				var ftp = typeResolver.resolve(fld.type);
				sb.add('${fld.name}:${ftp}');
				sb.addNewLine(Same);
			}
			sb.addNewLine(Dec);
			sb.addNewLine(Same, true);

			sb.add('${an.name}Anon = object');
			sb.addNewLine(Inc);
			sb.add("obj:ref RootObj");
			sb.addNewLine(Same);
			for (fld in an.fields) {
				var ftp = typeResolver.resolve(fld.type);
				sb.add('${fld.name}:ptr ${ftp}');
				sb.addNewLine(Same);
			}
			sb.addNewLine(Dec);
			sb.addNewLine(Same, true);
		}

		sb.addNewLine();
	}

	/**
	 * Generate anon converters for types
	 */
	function buildAnonConverters(sb:IndentStringBuilder) {
		var anons = typeContext.allAnonymous();
		if (anons.length < 1)
			return;

		for (an in anons) {
			var name = an.name;
			var anonName = '${name}Anon';
			sb.add('proc to${anonName}[T](this:T):${anonName} {.inline.} =');
			sb.addNewLine(Inc);

			sb.add('${anonName}(');
			sb.add('obj:this');
			var args = an.fields.map(x -> '${x.name}:addr this.${x.name}').join(", ");
			if (args.length > 0)
				sb.add(', ${args}');
			sb.add(')');
			sb.addBreak();
		}

		sb.addBreak();
	}

	/**
	 * Generate code for instance fields
	 */
	function generateInstanceFields(sb:IndentStringBuilder, fields:Array<ClassField>) {
		var iargs = [];
		for (ifield in fields) {
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
	}

	/**
	 * Build class fields
	 */
	function generateClassInfo(sb:IndentStringBuilder, cls:ClassInfo) {
		var clsName = cls.classType.name;
		var params = typeResolver.resolveParameters(cls.params);		

		var superName = if (cls.classType.superClass != null) {
			var superType = cls.classType.superClass.t.get();
			var spname = superType.name;
			var spParams = typeResolver.resolveParameters(cls.classType.superClass.params);
			'${spname}${spParams}';
		} else {
			"RootObj";
		}
		
		var line = '${clsName}${params} = ref object of ${superName}';
		sb.add(line);
		sb.addNewLine(Same);

		generateInstanceFields(sb, cls.fields);

		var staticFields = cls.classType.statics.get();
		if (staticFields.length > 0) {
			var line = '${cls.classType.name}Static = object of RootObj';
			sb.add(line);
			sb.addNewLine(Same);
			sb.addNewLine(Same, true);
		}
	}

	/**
	 * Generate abstract impl code
	 */
	function generateAbstractImpl(sb:IndentStringBuilder, cls:ClassInfo, abstr:AbstractType) {
		var name = abstr.name;
		var typeName = typeResolver.resolve(abstr.type);
		var line = '${name}Abstr = ${typeName}';
		sb.add(line);
		sb.addNewLine(Same);
	}

	/**
	 * Generate structure info
	 */
	function generateStructureInfo(sb:IndentStringBuilder, cls:StructInfo) {
		var structName = cls.classType.name;
		var line = '${structName} = object of Struct';
		sb.add(line);
		sb.addNewLine(Same);

		generateInstanceFields(sb, cls.fields);
	}

	/**
	 * Build static class initialization
	 */
	function generateStaticClassInit(sb:IndentStringBuilder, cls:ClassInfo) {
		var staticFields = cls.classType.statics.get();
		if (staticFields.length < 1)
			return;

		var clsName = typeResolver.getFixedTypeName(cls.classType.name);
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
	function generateMethodBody(sb:IndentStringBuilder, expression:TypedExpr) {
		expressionGenerator.generateMethodBody(sb, expression);

		sb.addNewLine();
		sb.addNewLine(None, true);
	}

	/**
	 * Build class constructor
	 */
	function generateClassConstructor(sb:IndentStringBuilder, cls:ClassInfo) {
		if (cls.classType.constructor == null)
			return;

		expressionGenerator.setClassContext(cls);

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
				var constrExp = constructor.expr();
				var params = typeResolver.resolveParameters(cls.params);
				// Generate init proc for haxe "super(params)"
				sb.add('proc init${className}${params}(this:${className}${params}');
				if (args.length > 0) {
					sb.add(", ");
					generateFuncArguments(sb, args);
				}
				sb.add(') {.inline.} =');
				sb.addNewLine(Inc);

				generateMethodBody(sb, constrExp);
				sb.addNewLine(Dec);

				// Generate constructor
				sb.add('proc new${className}${params}(');
				generateFuncArguments(sb, args);
				sb.add(') : ${className}${params} {.inline.} =');
				sb.addNewLine(Inc);
				sb.add('result = ${className}${params}()');
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
				sb.add(typeResolver.resolve(ret));
				sb.add(" =");
				sb.addNewLine(Inc);

				generateMethodBody(sb, method.expr());
			case v:
				throw 'Unsupported paramter ${v}';
		}
	}

	/**
	 * Build class method for abstract
	 */
	function generateMethodAbstract(sb:IndentStringBuilder, cls:ClassInfo, abstr:AbstractType, method:ClassField, isStatic:Bool) {
		switch (method.type) {
			case TFun(args, ret):
				var name = abstr.name;
				var methname = StringTools.replace(method.name, "_", "");

				sb.add('proc ${methname}${name}Abstr(');
				if (args.length > 0) {
					generateFuncArgumentsAbstract(sb, abstr, args);
				}
				sb.add(") : ");
				sb.add(typeResolver.resolve(ret));
				sb.add(" =");
				sb.addNewLine(Inc);

				generateMethodBody(sb, method.expr());
			case v:
				throw 'Unsupported paramter ${v}';
		}
	}

	/**
	 * Build class methods and return entry point if found
	 */
	function generateClassMethods(sb:IndentStringBuilder, cls:ClassInfo) {
		for (method in cls.methods) {
			generateClassMethod(sb, cls, method, false);
		}

		for (method in cls.staticMethods) {
			switch (cls.classType.kind) {
				case KNormal:
					generateClassMethod(sb, cls, method, true);
				case KAbstractImpl(a):
					generateMethodAbstract(sb, cls, a.get(), method, true);
				case v:
					throw 'Unsupported ${v}';
			}
		}

		// Generate heplers
		switch cls.classType.kind {
			case KNormal:
				var clsName = cls.classType.name;
				sb.add('proc `$`(this:${clsName}) : string {.inline.} = ');
				sb.addNewLine(Inc);
				sb.add('result = "${clsName}"' + " & $this[]");
				sb.addBreak();
			case KAbstractImpl(a):
			case v:
				throw 'Unsupported ${v}';
		}
	}

	/**
	 * Build classes code
	 */
	function buildClassesAndStructures(sb:IndentStringBuilder) {
		var classes = types.classes;
		var structures = types.structures;

		if (classes.length > 0) {
			sb.add("type ");
			sb.addNewLine(Inc);
		}

		for (c in classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					switch (c.classType.kind) {
						case KNormal:
							generateClassInfo(sb, c);
						case KAbstractImpl(a):
							generateAbstractImpl(sb, c, a.get());
						case v:
							throw 'Unsupported ${v}';
					}
				}
			}
		}

		for (c in structures) {
			generateStructureInfo(sb, c);
		}

		sb.addNewLine(None, true);

		// Init static classes
		for (c in classes) {
			if (c.classType.isExtern == false) {
				if (!c.classType.isInterface) {
					switch (c.classType.kind) {
						case KNormal:
							generateStaticClassInit(sb, c);
						case KAbstractImpl(_):
						case v:
							throw 'Unsupported ${v}';
					}
				}
			}
		}

		sb.addNewLine(None, true);
		for (c in classes) {
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

	public function new(processed:PreprocessedTypes) {
		super(processed);
		typeContext = new TypeContext(processed);
		typeResolver = new TypeResolver(typeContext);
		expressionGenerator = new MethodExpressionGenerator(typeContext, typeResolver);
	}

	/**
	 * Build sources
	 */
	override function build() {
		var nimOut = ContextMacro.getDefines().get("nim-out");
		if (nimOut == null)
			nimOut = DEFAULT_OUT;

		var filename = Path.normalize(nimOut);
		var outPath = Path.directory(filename);
		FileSystem.createDirectory(outPath);

		addLibraries(outPath);

		var codeSb = new IndentStringBuilder();
		buildClassesAndStructures(codeSb);

		var headerSb = new IndentStringBuilder();

		addCodeHelpers(headerSb);
		buildEnums(headerSb);
		buildTypedefs(headerSb);
		buildAnonConverters(headerSb);
		buildInterfaces(headerSb);

		if (types.entryPoint != null) {
			codeSb.addNewLine();
			buildEntryPointMain(codeSb, types.entryPoint);
		}

		var buff = new StringBuf();
		buff.add(headerSb.toString());
		buff.add(codeSb.toString());

		File.saveContent(filename, buff.toString());
	}
}
