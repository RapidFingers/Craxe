package craxe.builders.nim;

import sys.io.File;
import haxe.io.Path;
import craxe.ast2obj.*;
import craxe.util.IndentStringBuilder;

/**
 * Builder for nim code
 */
class NimBuilder extends BaseBuilder {
	/**
	 * Entry point
	 */
	var mainMethod:OMethod;

	/**
	 * Fix _ in name
	 */
	inline function fixVarName(name:String):String {
		return StringTools.replace(name, "_", "VAR");
	}

	/**
	 * Return resolved type name
	 */
	function resolveTypeName(name:String):String {
		switch (name) {
			case "Void":
				return "void";
			case "String":
				return "string";
			case "Int":
				return "int";
			case "Array":
				return "HaxeArray";
			case "Float":
				return "float";
			default:
				return name;
		}
	}

	/**
	 * Build constant
	 */
	static function buildConstant(sb:IndentStringBuilder, const:OConstant) {
		switch (const.type) {
			case "Int":
				sb.add(const.value);
			case "String":
				sb.add('"' + const.value + '"');
			case "this":
				sb.add("self");
			case "null":
				sb.add("nil");
			case _:
				trace("buildConstant not impl: " + const.type);
		}
	}

	/**
	 * Substitute some statics
	 * @param className
	 * @param fieldName
	 * @return String
	 */
	function substStaticFieldName(className:String, fieldName:String):String {
		trace(className);
		trace(fieldName);
		if (className == "Std") {
			switch (fieldName) {
				case "string":
					return "$";
			}
		} else if (className == "haxe_Log" && fieldName == "trace") {
			return "echo";
		}
		return null;
	}

	/**
	 * Return class type as string
	 */
	function getClassType(cls:OClass):String {
		if (cls.params != null) {
			var clsType = resolveTypeName(cls.safeName);
			var params = cls.params.map(x -> {
				resolveTypeName(x);
			});

			var pars = params.join(",");
			return '${clsType}[${pars}]';
		}
		return cls.safeName;
	}

	/**
	 * Build entry point
	 */
	function buildMain(sb:IndentStringBuilder) {
		sb.addNewLine(None);
		sb.add('${mainMethod.cls.safeName}StaticInst.${mainMethod.name}()');
	}

	/**
	 * Build class fields
	 * @param cls
	 */
	function buildClassInfo(sb:IndentStringBuilder, cls:OClass) {
		var line = '${cls.safeName} = ref object of RootObj';
		sb.add(line);
		sb.addNewLine(Same);

		var instanceVars = cls.classVars.filter((x) -> !x.isStatic);
		if (instanceVars.length > 0) {
			sb.inc();
			buildFields(sb, instanceVars);
			sb.dec();
		}

		var hasStatic = false;
		var classVars = cls.classVars.filter((x) -> x.isStatic);
		if (classVars.length > 0) {
			sb.inc();
			buildFields(sb, classVars);
			hasStatic = true;
			sb.dec();
		}

		// Has static
		// TODO: remove
		if (cls.methods.filter((x) -> x.isStatic).length > 0) {
			hasStatic = true;
		}

		if (hasStatic) {
			var line = '${cls.safeName}Static = ref object of RootObj';
			sb.add(line);
			sb.addNewLine();
		}
	}

	/**
	 * Build fields
	 */
	function buildFields(sb:IndentStringBuilder, vars:Array<OClassVar>) {
		for (classVar in vars) {
			sb.add(classVar.name);
			sb.add(" : ");
			sb.add(resolveTypeName(classVar.type.safeName));
			sb.addNewLine(Same);
		}

		sb.addNewLine(Same, true);
	}

	/**
	 * Build static class initialization
	 * @param sb
	 * @param cls
	 */
	function buildInitStaticClass(sb:IndentStringBuilder, cls:OClass) {
		if (cls.methods.filter((x) -> x.isStatic).length > 0) {
			sb.add('let ${cls.safeName}StaticInst = ${cls.safeName}Static()');
			sb.addNewLine();
		}
	}

	/**
	 * Build class constructor
	 */
	function buildConstructor(sb:IndentStringBuilder, cls:OClass) {
		if (cls.constructor == null)
			return;

		sb.add('proc new${cls.safeName}(');
		for (i in 0...cls.constructor.args.length) {
			var oarg = cls.constructor.args[i];
			var varTypeName = oarg.type.safeName;
			sb.add(oarg.name);
			sb.add(" : ");
			sb.add(resolveTypeName(varTypeName));
			if (i < cls.constructor.args.length - 1)
				sb.add(", ");
		}

		sb.add('): ${cls.safeName} {.inline.} =');
		sb.addNewLine(Inc);
		sb.add('let this = ${cls.safeName}()');
		sb.addNewLine(Same);
		sb.add('result = this');
		sb.addNewLine(Same);
		buildExpression(sb, cls.constructor.expression);
		sb.addNewLine(Same);
		sb.addNewLine();
		sb.addNewLine(None, true);
	}

	/**
	 * Build class methods
	 */
	function buildClassMethods(sb:IndentStringBuilder, cls:OClass) {
		for (method in cls.methods) {
			if (method.isStatic && method.name == BaseBuilder.MAIN_METHOD) {
				mainMethod = method;
			}

			var clsName = !method.isStatic ? cls.safeName : '${cls.safeName}Static';

			sb.add('proc ${method.name}(this : ${clsName}');
			if (method.args.length > 0) {
				sb.add(", ");
				for (i in 0...method.args.length) {
					var arg = method.args[i];
					var varTypeName = arg.type.safeName;
					sb.add(arg.name);
					sb.add(" : ");
					sb.add(resolveTypeName(varTypeName));

					if (i < method.args.length - 1)
						sb.add(", ");
				}
			}
			sb.add(") : ");
			sb.add(resolveTypeName(method.type.safeName));
			sb.add(" =");
			sb.addNewLine(Inc);

			buildExpression(sb, method.expression);
			sb.addNewLine(None, true);
		}

		// Add to string proc
		sb.add('proc `$`(this : ${cls.safeName}):string {.inline.} =');
		sb.addNewLine(Inc);
		sb.add('result = "${cls.safeName}"' + " & $this[]");
		sb.addNewLine();
		sb.addNewLine(None, true);
	}

	/**
	 * Build expression
	 * @param sb
	 */
	function buildExpression(sb:IndentStringBuilder, expression:OExpression) {
		trace(expression);
		if ((expression is OBlock)) {
			buildExpressionOblock(sb, cast(expression, OBlock));
		} else if ((expression is OVar)) {
			buildExpressionOVar(sb, cast(expression, OVar));
		} else if ((expression is OBinOp)) {
			buildExpressionOBinOp(sb, cast(expression, OBinOp));
		} else if ((expression is OLocal)) {
			buildExpressionOLocal(sb, cast(expression, OLocal));
		} else if ((expression is OFieldInstance)) {
			buildExpressionOFieldInstance(sb, cast(expression, OFieldInstance));
		} else if ((expression is OConstant)) {
			buildConstant(sb, cast(expression, OConstant));
			if (expression.nextExpression != null)
				buildExpression(sb, expression.nextExpression);
		} else if ((expression is OCall)) {
			buildExpressionOCall(sb, cast(expression, OCall));
		} else if ((expression is OFieldStatic)) {
			buildExpressionOFieldStatic(sb, cast(expression, OFieldStatic));
		} else if ((expression is ONew)) {
			buildExpressionONew(sb, cast(expression, ONew));
		} else if ((expression is OWhile)) {
			buildExpressionOWhile(sb, cast(expression, OWhile));
		} else if ((expression is OParenthesis)) {
			buildExpressionOParenthesis(sb, cast(expression, OParenthesis));
		} else if ((expression is OUnOp)) {
			buildExpressionOUnOp(sb, cast(expression, OUnOp));
		} else if ((expression is OIf)) {
			buildExpressionOIf(sb, cast(expression, OIf));
		} else if ((expression is OReturn)) {
			buildExpressionOReturn(sb, cast(expression, OReturn));
		} else if ((expression is OArray)) {
			buildExpressionOArray(sb, cast(expression, OArray));
		} else if ((expression is OArrayDecl)) {
			buildExpressionOArrayDecl(sb, cast(expression, OArrayDecl));
		}
	}

	/**
	 * Build expression OBlock
	 */
	function buildExpressionOblock(sb:IndentStringBuilder, expression:OBlock) {
		for (expr in expression.expressions) {
			buildExpression(sb, expr);
			sb.addNewLine(Same);
		}
	}

	/**
	 * Build expression OVar
	 */
	function buildExpressionOVar(sb:IndentStringBuilder, expression:OVar) {
		sb.add("var ");

		var name = fixVarName(expression.name);
		sb.add(name);

		if (expression.nextExpression != null) {
			sb.add(" = ");
			buildExpression(sb, expression.nextExpression);
		}
	}

	/**
	 * Build expression OBinOp
	 */
	function buildExpressionOBinOp(sb:IndentStringBuilder, expression:OBinOp) {
		buildExpression(sb, expression.expression);
		sb.add(" ");
		sb.add(expression.op);
		sb.add(" ");
		if (expression.nextExpression != null)
			buildExpression(sb, expression.nextExpression);
	}

	/**
	 * Build expression OLocal
	 */
	function buildExpressionOLocal(sb:IndentStringBuilder, expression:OLocal) {
		var name = fixVarName(expression.name);
		sb.add(name);
		if (expression.nextExpression != null)
			buildExpression(sb, expression.nextExpression);
	}

	/**
	 * Build expression OFieldInstance
	 */
	function buildExpressionOFieldInstance(sb:IndentStringBuilder, expression:OFieldInstance) {
		var nsb = new IndentStringBuilder();
		if (expression.nextExpression != null)
			buildExpression(nsb, expression.nextExpression);

		var name = nsb.toString();
		if (name == "self") {
			sb.add("this.");
			sb.add(expression.field);
		} else {
			sb.add(name);
			sb.add(".");
			sb.add(expression.field);
		}
	}

	/**
	 * Build expression OCall
	 */
	function buildExpressionOCall(sb:IndentStringBuilder, expression:OCall) {
		buildExpression(sb, expression.nextExpression);
		sb.add("(");
		var data = [];
		for (i in 0...expression.expressions.length) {
			var nsb = new IndentStringBuilder();
			buildExpression(nsb, expression.expressions[i]);
			var content = nsb.toString();
			if (content != "")
				data.push(content);
		}
		sb.add(data.join(", "));
		sb.add(")");
	}

	/**
	 * Build expression OFieldStatic
	 */
	function buildExpressionOFieldStatic(sb:IndentStringBuilder, expression:OFieldStatic) {
		buildExpression(sb, expression.nextExpression);
		var substName = substStaticFieldName(expression.cls.safeName, expression.field);
		if (substName != null) {
			if (substName == "echo") {
				sb.add(substName);
			} else {
				sb.add(substName);
			}
		} else {
			sb.add('${expression.cls.safeName}StaticInst.${expression.field}');
		}
	}

	/**
	 * Build expression ONew
	 */
	function buildExpressionONew(sb:IndentStringBuilder, expression:ONew) {
		var onew = cast(expression, ONew);
		var varTypeName = "new" + getClassType(onew.cls);

		sb.add(varTypeName);
		sb.add("(");
		for (i in 0...onew.expressions.length) {
			var expr = onew.expressions[i];
			buildExpression(sb, expr);
			if (i + 1 < onew.expressions.length)
				sb.add(", ");
		}
		sb.add(")");
	}

	/**
	 * Build expression OWhile
	 */
	function buildExpressionOWhile(sb:IndentStringBuilder, expression:OWhile) {
		sb.add("while ");
		buildExpression(sb, expression.conditionExpression);
		sb.add(":");
		sb.addNewLine(Inc);
		buildExpression(sb, expression.nextExpression);
		sb.addNewLine(Dec);
	}

	/**
	 * Build expression OParenthesis
	 */
	function buildExpressionOParenthesis(sb:IndentStringBuilder, expression:OParenthesis) {
		buildExpression(sb, expression.nextExpression);
	}

	/**
	 * Build expression OUnOp
	 */
	function buildExpressionOUnOp(sb:IndentStringBuilder, expression:OUnOp) {
		if (expression.post == true) {
			switch (expression.op) {
				case "++":
					sb.add("apOperator(");
					buildExpression(sb, expression.nextExpression);
					sb.add(")");
				default:
					buildExpression(sb, expression.nextExpression);
					sb.add(expression.op);
			}
		} else {
			switch (expression.op) {
				case "++":
					sb.add("bpOperator(");
					buildExpression(sb, expression.nextExpression);
					sb.add(")");
				default:
					sb.add(expression.op);
					buildExpression(sb, expression.nextExpression);
			}
		}
	}

	/**
	 * Build expression OIf
	 */
	function buildExpressionOIf(sb:IndentStringBuilder, expression:OIf) {
		sb.add("if ");
		buildExpression(sb, expression.conditionExpression);
		sb.add(":");
		sb.addNewLine(Inc);

		buildExpression(sb, expression.ifExpression);
		if (expression.elseExpression != null) {
			sb.add("else:");
			buildExpression(sb, expression.elseExpression);
		}
		sb.addNewLine(Dec);
	}

	/**
	 * Build expression OReturn
	 */
	function buildExpressionOReturn(sb:IndentStringBuilder, expression:OReturn) {
		sb.add("return ");
		buildExpression(sb, expression.nextExpression);
	}

	/**
	 * Build expression OArray
	 */
	function buildExpressionOArray(sb:IndentStringBuilder, expression:OArray) {
		var oarray = cast(expression, OArray);
		buildExpression(sb, oarray.varExpression);
		sb.add(".get(");
		buildExpression(sb, oarray.nextExpression);
		sb.add(")");
	}

	/**
	 * Build expression OArrayDecl
	 */
	function buildExpressionOArrayDecl(sb:IndentStringBuilder, expression:OArrayDecl) {
		sb.add("@[");
		for (i in 0...expression.expressions.length) {
			var expr = expression.expressions[i];
			buildExpression(sb, expr);	
			if (i + 1 < expression.expressions.length)
				sb.add(", ");
		}
		sb.add("]");
	}

	/**
	 * Build system functions and types
	 */
	function addHelpers(sb:IndentStringBuilder) {
		sb.add("# Generated by Mighty Craxe");
		sb.addNewLine();
		sb.add('{.experimental: "codeReordering".}');
		sb.addNewLine(None, true);
		sb.addNewLine(None, true);

		final content = File.getContent("./src/craxe/builders/nim/NimBoot.nim");
		sb.add(content);
		sb.addNewLine(None, true);
		sb.addNewLine(None, true);
	}

	/**
	 * Build sources
	 */
	public override function build() {
		var filename = Path.normalize("main.nim");
		var sb = new IndentStringBuilder();

		addHelpers(sb);

		if (classes.length > 0) {
			sb.add("type ");
			sb.addNewLine();
		}

		sb.inc();
		for (c in classes) {
			if (c.isExtern == false) {
				buildClassInfo(sb, c);
			}
		}

		sb.addNewLine(None, true);

		// Init static classes
		for (c in classes) {
			if (c.isExtern == false) {
				buildInitStaticClass(sb, c);
			}
		}

		sb.addNewLine(None, true);
		for (c in classes) {
			if (c.isExtern == false) {
				buildConstructor(sb, c);
				buildClassMethods(sb, c);
			}
		}

		buildMain(sb);

		File.saveContent(filename, sb.toString());
	}
}
