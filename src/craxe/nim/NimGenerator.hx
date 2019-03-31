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

using StringTools;

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
	 * Fix local var name
	 */
	inline function fixLocalVarName(name:String):String {
		return name.replace("_", "loc");
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
	 * Generate code for ESwitch
	 */
	function generateTSwitch(sb:IndentStringBuilder, expression:TypedExpr, cases:Array<{values:Array<TypedExpr>, expr:TypedExpr}>, edef:TypedExpr) {
		var ifname = "if ";
		for (cs in cases) {
			for (val in cs.values) {
				sb.add(ifname);
				generateTypedAstExpression(sb, expression.expr);
				sb.add(" == ");
				generateTypedAstExpression(sb, val.expr);
				sb.add(":");
				sb.addNewLine(Inc);
				generateTypedAstExpression(sb, cs.expr.expr);
				sb.addNewLine(Dec);
			}
			ifname = "elif ";
		}
		// generateAstExpression(sb, expression);
	}

	/**
	 * Generate code for TBlock
	 */
	function generateTBlock(sb:IndentStringBuilder, expressions:Array<TypedExpr>) {
		for (expr in expressions) {
			generateTypedAstExpression(sb, expr.expr);
			sb.addNewLine(Same);
		}
	}

	/**
	 * Generate code for TIf
	 */
	function geterateTIf(sb:IndentStringBuilder, econd:TypedExpr, eif:TypedExpr, eelse:TypedExpr) {
		sb.add("if ");
		generateTypedAstExpression(sb, econd.expr);
		sb.add(":");
		sb.addNewLine(Inc);

		generateTypedAstExpression(sb, eif.expr);
		if (eelse != null) {
			switch (eelse.expr) {
				case TBlock(el):
					if (el.length > 0) {
						sb.addNewLine(Dec);
						sb.add("else:");
						generateTypedAstExpression(sb, eelse.expr);
					}
				case _:
					throw "Unsupported expression";
			}
		}
		sb.addNewLine(Dec);
	}

	/**
	 * Generate code for TWhile
	 */
	function generateTWhile(sb:IndentStringBuilder, econd:TypedExpr, whileExpression:TypedExpr, isNormal:Bool) {
		sb.add("while ");
		generateTypedAstExpression(sb, econd.expr);
		sb.add(":");
		sb.addNewLine(Inc);
		generateTypedAstExpression(sb, whileExpression.expr);
		sb.addNewLine(Dec, true);
	}

	/**
	 * Generate code for TCall
	 */
	function generateTCall(sb:IndentStringBuilder, expression:TypedExpr, expressions:Array<TypedExpr>) {
		switch (expression.expr) {
			case TField(_, FEnum(c, ef)):
				var name = c.get().name;
				sb.add('new${name}${ef.name}');
			case _:
				generateTypedAstExpression(sb, expression.expr);
		}

		sb.add("(");
		for (i in 0...expressions.length) {
			var expr = expressions[i].expr;
			generateTypedAstExpression(sb, expr);
			if (i + 1 < expressions.length)
				sb.add(", ");
		}

		sb.add(")");
	}

	/**
	 * Generate code for TNew
	 */
	function generateTNew(sb:IndentStringBuilder, classType:ClassType, params:Array<Type>, elements:Array<TypedExpr>) {
		var typeName = fixTypeName(classType.name);
		var typeParams = resolveParameters(params);
		var varTypeName = 'new${typeName}${typeParams}';

		sb.add(varTypeName);
		sb.add("(");
		for (i in 0...elements.length) {
			var expr = elements[i];
			generateTypedAstExpression(sb, expr.expr);
			if (i + 1 < elements.length)
				sb.add(", ");
		}
		sb.add(")");
	}

	/**
	 * Generate code for TField
	 */
	function generateTField(sb:IndentStringBuilder, expression:TypedExpr, access:FieldAccess) {
		switch (expression.expr) {
			case TTypeExpr(v):
				trace(v);
			case _:
				generateTypedAstExpression(sb, expression.expr);
		}

		switch (access) {
			case FInstance(c, params, cf):
				sb.add(".");
				sb.add(cf.toString());
			case FStatic(c, cf):
				var name = c.get().name;
				sb.add('${name}StaticInst.');
				var fieldName = cf.toString();
				sb.add(fieldName);
			case FAnon(cf):
			case FDynamic(s):
			case FClosure(c, cf):
			case FEnum(e, ef):
				var name = e.get().name;
				sb.add('new${name}${ef.name}()');
		}
	}

	/**
	 * Generate code for TTypeExpr
	 */
	function generateTTypeExpr(sb:IndentStringBuilder, module:ModuleType) {
		switch module {
			case TClassDecl(c):
				sb.add(c.toString());
			case v:
				throw 'Unsupported simple type ${v}';
		}
	}

	/**
	 * Generate code for TVar
	 */
	function generateTVar(sb:IndentStringBuilder, vr:TVar, expr:TypedExpr) {
		sb.add("var ");
		var name = fixTypeName(vr.name);
		name = fixLocalVarName(name);
		sb.add(name);
		if (expr != null) {
			sb.add(" = ");
			generateTypedAstExpression(sb, expr.expr);
		}
	}

	/**
	 * Generate code for TConstant
	 */
	function generateTConst(sb:IndentStringBuilder, con:TConstant) {
		switch (con) {
			case TInt(i):
				sb.add(Std.string(i));
			case TFloat(s):
				sb.add(Std.string(s));
			case TString(s):
				sb.add('"${Std.string(s)}"');
			case TBool(b):
				sb.add(Std.string(b));
			case TNull:
				sb.add("nil");
			case TThis:
				sb.add("this");
			case TSuper:
				sb.add("super");
		}
	}

	/**
	 * Generate code for TLocal
	 */
	function genecrateTLocal(sb:IndentStringBuilder, vr:TVar) {
		var name = fixLocalVarName(vr.name);
		sb.add(name);
	}

	/**
	 * Generate code for TArray
	 * Array access arr[it]
	 */
	function generateTArray(sb:IndentStringBuilder, e1:TypedExpr, e2:TypedExpr) {
		generateTypedAstExpression(sb, e1.expr);
		sb.add(".get(");
		generateTypedAstExpression(sb, e2.expr);
		sb.add(")");
	}

	/**
	 * Generate code for TArrayDecl
	 * An array declaration `[el]`
	 */
	function generateTArrayDecl(sb:IndentStringBuilder, elements:Array<TypedExpr>) {
		sb.add("@[");
		for (i in 0...elements.length) {
			var expr = elements[i];
			generateTypedAstExpression(sb, expr.expr);
			if (i + 1 < elements.length)
				sb.add(", ");
		}
		sb.add("]");
	}

	/**
	 * Generate code for TBinop
	 */
	function generateTBinop(sb:IndentStringBuilder, op:Binop, e1:TypedExpr, e2:TypedExpr) {
		generateTypedAstExpression(sb, e1.expr);
		sb.add(" ");
		switch (op) {
			case OpAdd:
				sb.add("+");
			case OpMult:
				sb.add("*");
			case OpDiv:
				sb.add("div");
			case OpSub:
				sb.add("-");
			case OpAssign:
				sb.add("=");
			case OpEq:
				sb.add("==");
			case OpNotEq:
				sb.add("!=");
			case OpGt:
				sb.add(">");
			case OpGte:
				sb.add(">=");
			case OpLt:
				sb.add("<");
			case OpLte:
				sb.add("<=");
			case OpAnd:
				sb.add("and");
			case OpOr:
				sb.add("or");
			case OpXor:
				sb.add("xor");
			case OpBoolAnd:
			case OpBoolOr:
			case OpShl:
				sb.add("<<");
			case OpShr:
				sb.add(">>");
			case OpUShr:
			case OpMod:
				sb.add("%");
			case OpAssignOp(op):
			case OpInterval:
			case OpArrow:
			case OpIn:
		}
		sb.add(" ");

		if (e2.expr != null)
			generateTypedAstExpression(sb, e2.expr);
	}

	/**
	 * Generate code for TUnop
	 */
	function generateTUnop(sb:IndentStringBuilder, op:Unop, post:Bool, expr:TypedExpr) {
		switch (op) {
			case OpIncrement:
				if (post) {
					sb.add("apOperator(");
				} else {
					sb.add("bpOperator(");
				}
				generateTypedAstExpression(sb, expr.expr);
				sb.add(")");
			case OpDecrement:
			case OpNot:
			case OpNeg:
			case OpNegBits:
		}
	}

	/**
	 * Generate code for TReturn
	 */
	function generateTReturn(sb:IndentStringBuilder, expression:TypedExpr) {
		sb.add("return ");
		generateTypedAstExpression(sb, expression.expr);
	}

	/**
	 * Generate code for TMeta
	 */
	function generateTMeta(sb:IndentStringBuilder, meta:MetadataEntry, expression:TypedExpr) {
		generateTypedAstExpression(sb, expression.expr);
	}

	/**
	 * Generate code for TEnumParameter
	 */
	function generateTEnumParameter(sb:IndentStringBuilder, expression:TypedExpr, enumField:EnumField, index:Int) {
		generateTypedAstExpression(sb, expression.expr);
		switch (enumField.type) {
			case TFun(args, _):
				sb.add('.${args[0].name}');
			case v:
				generateCommonTypes(sb, v);
		}
	}

	/**
	 * Generate code for TMeta
	 */
	function generateTEnumIndex(sb:IndentStringBuilder, expression:TypedExpr) {
		generateTypedAstExpression(sb, expression.expr);
	}

	/**
	 * Generate code for TObjectDecl
	 */
	function generateTObjectDecl(sb:IndentStringBuilder, fields:Array<{name:String, expr:TypedExpr}>) {
		for (i in 0...fields.length) {
			var field = fields[i];
			generateTypedAstExpression(sb, field.expr.expr);
			if (i + 1 < fields.length)
				sb.add(", ");
		}
	}

	/**
	 * Generate common expression
	 */
	function generateTypedAstExpression(sb:IndentStringBuilder, expr:TypedExprDef) {
		trace(expr.getName());
		switch (expr) {
			case TConst(c):
				generateTConst(sb, c);
			case TLocal(v):
				genecrateTLocal(sb, v);
			case TArray(e1, e2):
				generateTArray(sb, e1, e2);
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case TTypeExpr(m):
				generateTTypeExpr(sb, m);
			case TParenthesis(e):
				generateTypedAstExpression(sb, e.expr);
			case TObjectDecl(fields):
				generateTObjectDecl(sb, fields);
			case TArrayDecl(el):
				generateTArrayDecl(sb, el);
			case TCall(e, el):
				generateTCall(sb, e, el);
			case TNew(c, params, el):
				generateTNew(sb, c.get(), params, el);
			case TUnop(op, postFix, e):
				generateTUnop(sb, op, postFix, e);
			case TFunction(tfunc):
			case TVar(v, expr):
				generateTVar(sb, v, expr);
			case TBlock(el):
				generateTBlock(sb, el);
			case TFor(v, e1, e2):
			case TIf(econd, eif, eelse):
				geterateTIf(sb, econd, eif, eelse);
			case TWhile(econd, e, normalWhile):
				generateTWhile(sb, econd, e, normalWhile);
			case TSwitch(e, cases, edef):
				generateTSwitch(sb, e, cases, edef);
			case TTry(e, catches):
			case TReturn(e):
				generateTReturn(sb, e);
			case TBreak:
			case TContinue:
			case TThrow(e):
			case TCast(e, m):
			case TMeta(m, e1):
				generateTMeta(sb, m, e1);
			case TEnumParameter(e1, ef, index):
				generateTEnumParameter(sb, e1, ef, index);
			case TEnumIndex(e1):
				generateTEnumIndex(sb, e1);
			case TIdent(s):
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
		var line = '${clsName} = ref object of RootObj';
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
		sb.add('proc new${className}(');
		switch (constructor.type) {
			case TFun(args, _):
				generateFuncArguments(sb, args);
				sb.add(') : ${className} {.inline.} =');
				sb.addNewLine(Inc);
				sb.add('let this = ${className}()');
				sb.addNewLine(Same);
				sb.add('result = this');
				sb.addNewLine(Same);
				generateMethodBody(sb, constructor.expr().expr);
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
				generateClassInfo(sb, c);
			}
		}

		sb.addNewLine(None, true);

		// Init static classes
		for (c in types.classes) {
			if (c.classType.isExtern == false) {
				generateStaticClassInit(sb, c);
			}
		}

		sb.addNewLine(None, true);
		for (c in types.classes) {
			if (c.classType.isExtern == false) {
				generateClassConstructor(sb, c);
				generateClassMethods(sb, c);
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
