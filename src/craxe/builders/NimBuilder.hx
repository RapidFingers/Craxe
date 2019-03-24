package craxe.builders;

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
	 * @param name
	 */
	function resolveTypeName(name:String):String {
		switch (name) {
			case "Void":
				return "void";
			case "String":
				return "string";
			case "Int":
				return "int";
			case "Float":
				return "float";
			case "TFun":
				return "fun";			
			default:
				throw 'Unknown type ${name}';				
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
	 * Build entry point
	 */
	function buildMain(sb:IndentStringBuilder) {
		sb.addBreakLine();
		sb.addLine('${mainMethod.cls.safeName}StaticInst.${mainMethod.name}()');
	}

	/**
	 * Build class fields
	 * @param cls
	 */
	function buildClassInfo(sb:IndentStringBuilder, cls:OClass) {
		var line = '${cls.safeName} = ref object of RootObj';
		sb.addLine(line);

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
			sb.addLine(line);
		}
	}

	/**
	 * Build fields
	 */
	function buildFields(sb:IndentStringBuilder, vars:Array<OClassVar>) {
		for (classVar in vars) {
			sb.addWithIndent(classVar.name);
			sb.add(" : ");
			sb.add(resolveTypeName(classVar.type.safeName));
			sb.add("\n");
		}
	}

	/**
	 * Build static class initialization
	 * @param sb
	 * @param cls
	 */
	function buildInitStaticClass(sb:IndentStringBuilder, cls:OClass) {
		if (cls.methods.filter((x) -> x.isStatic).length > 0) {
			sb.addWithIndent('let ${cls.safeName}StaticInst = ${cls.safeName}Static()');
			sb.addBreakLine();
		}
	}

	/**
	 * Build class methods
	 * @param sb
	 * @param cls
	 */
	function buildClassMethods(sb:IndentStringBuilder, cls:OClass) {
		for (method in cls.methods) {
			if (method.isStatic && method.name == BaseBuilder.MAIN_METHOD) {
				mainMethod = method;
			}

			var clsName = !method.isStatic ? cls.safeName : '${cls.safeName}Static';

			sb.addWithIndent('proc ${method.name}(this : ${clsName}');
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
			sb.inc();
			sb.addBreakLine(true);

			buildExpression(sb, method.expression);
			sb.addBreakLine();
			sb.indent = 0;
		}
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
		}
	}

	/**
	 * Build expression OBlock
	 */
	function buildExpressionOblock(sb:IndentStringBuilder, expression:OBlock) {
		for (expr in expression.expressions) {
			buildExpression(sb, expr);
			//sb.addBreakLine();
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

		sb.addBreakLine(true);
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
		var varTypeName = expression.cls.safeName;
		sb.add(varTypeName);
		// TODO: arguments
		sb.add("()");
	}

	/**
	 * Build expression OWhile
	 */
	function buildExpressionOWhile(sb:IndentStringBuilder, expression:OWhile) {
		sb.add("while ");
		buildExpression(sb, expression.conditionExpression);
		sb.add(":");
		sb.addBreakLine();
		sb.inc();
		sb.addWithIndent("");
		buildExpression(sb, expression.nextExpression);
		sb.dec();
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
			switch(expression.op) {
				case "++":
					sb.add("incRet(");
					buildExpression(sb, expression.nextExpression);
					sb.add(")");
				default:
					buildExpression(sb, expression.nextExpression);
					sb.add(expression.op);
			}			
		} else {
			sb.add(expression.op);
			buildExpression(sb, expression.nextExpression);
		}
	}

	/**
	 * Build expression OIf
	 */
	function buildExpressionOIf(sb:IndentStringBuilder, expression:OIf) {
		sb.add("if ");
		buildExpression(sb, expression.conditionExpression);
		sb.add(":");
		sb.inc();
		sb.addBreakLine(true);

		buildExpression(sb, expression.ifExpression);
		if (expression.elseExpression != null) {
			sb.addLine("else:");
			buildExpression(sb, expression.elseExpression);
		}
		sb.dec();
	}

	/**
	 * Build expression OReturn
	 */
	function buildExpressionOReturn(sb:IndentStringBuilder, expression:OReturn) {
		sb.add("return ");		
		buildExpression(sb, expression.nextExpression);
		sb.dec();
		sb.addBreakLine(true);
	}

	/**
	 * Build system functions and types
	 */
	function buildSystem(sb:IndentStringBuilder) {
		sb.add("template incRet(val:var untyped):untyped =\n    inc(val)\n    val");

		sb.addBreakLine();
		sb.addBreakLine();
	}

	/**
	 * Build sources
	 */
	public override function build() {
		var filename = Path.normalize("main.nim");
		var sb = new IndentStringBuilder();

		buildSystem(sb);

		if (classes.length > 0) {
			sb.addLine("type ");
		}

		sb.inc();
		for (c in classes) {
			if (c.isExtern == false) {
				buildClassInfo(sb, c);
			}
		}

		sb.addBreakLine();
		sb.dec();

		// Init static classes
		for (c in classes) {
			if (c.isExtern == false) {
				buildInitStaticClass(sb, c);
			}
		}

		sb.addBreakLine();
		for (c in classes) {
			if (c.isExtern == false) {
				buildClassMethods(sb, c);
			}
		}

		buildMain(sb);

		File.saveContent(filename, sb.toString());
	}
}
