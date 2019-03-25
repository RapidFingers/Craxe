package craxe.builders.crystal;

import sys.io.File;
import haxe.io.Path;
import craxe.ast2obj.*;
import craxe.util.IndentStringBuilder;

/**
 * Builder of crystal code
 */
class CrystalBuilder extends BaseBuilder {
	/**
	 * Count of spaces to indent
	 */
	static inline final CRYSTAL_INDENT = 2;

	/**
	 * Entry point
	 */
	private var mainMethod:OMethod;

	/**
	 * Add helper data
	 * @param sb
	 */
	private function addHelpers(sb:IndentStringBuilder) {
		final content = File.getContent("./src/craxe/builders/crystal/CrystalBoot.cr");
		sb.add(content);
		sb.addNewLine();
	}

	/**
	 * Build entry point
	 */
	function buildMain(sb:IndentStringBuilder) {
		sb.add('${mainMethod.cls.safeName}.${mainMethod.name}');
		sb.addNewLine();
	}

	/**
	 * Add end
	 */
	function addEnd(sb:IndentStringBuilder, br:Bool = true) {
		function processIndend(ind) {
			switch ind {
				case Same:
					sb.dec();
				default:
			}
		}

		switch sb.currentItem {
			case Line(v):
				processIndend(v);
			case Indent(v):
				processIndend(v);
			default:
				sb.addNewLine(Dec);
		}

		sb.add("end");
		sb.addNewLine(Same);
		if (br)
			sb.addNewLine(Same, true);
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
					return "HaxeStd.string";
			}
		} else if (className == "haxe_Log" && fieldName == "trace") {
			return "pp";
		}
		return null;
	}

	/**
	 * Build class vars
	 * @param cls
	 * @param sb
	 */
	private function buildClassVars(sb:IndentStringBuilder, cls:OClass) {
		for (classVar in cls.classVars) {
			sb.add("property ");
			sb.add(classVar.name);
			sb.add(" : ");
			sb.add(classVar.type.safeName);
			switch (classVar.type.safeName) {
				case "String":
					sb.add(' = ""');
			}

			sb.add("\n");
		}
	}

	/**
	 * Build constant
	 * @param c
	 */
	private static function buildConstant(sb:IndentStringBuilder, const:OConstant) {
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
	 * Build expression
	 * @param sb
	 */
	private function buildExpression(sb:IndentStringBuilder, expression:OExpression) {
		trace(expression);
		if ((expression is OBlock)) {
			buildExpressionOblock(sb, cast(expression, OBlock));
		} else if ((expression is OBinOp)) {
			buildExpressionOBinOp(sb, cast(expression, OBinOp));
		} else if ((expression is OVar)) {
			buildExpressionOVar(sb, cast(expression, OVar));
		} else if ((expression is OConstant)) {
			buildConstant(sb, cast(expression, OConstant));
			if (expression.nextExpression != null)
				buildExpression(sb, expression.nextExpression);
		} else if ((expression is OLocal)) {
			buildExpressionOLocal(sb, cast(expression, OLocal));
		} else if ((expression is OFieldInstance)) {
			buildExpressionOFieldInstance(sb, cast(expression, OFieldInstance));
		} else if ((expression is OFieldStatic)) {
			buildExpressionOFieldStatic(sb, cast(expression, OFieldStatic));
		} else if ((expression is OCall)) {
			buildExpressionOCall(sb, cast(expression, OCall));
		} else if ((expression is ONew)) {
			buildExpressionONew(sb, cast(expression, ONew));
		} else if ((expression is OIf)) {
			buildExpressionOIf(sb, cast(expression, OIf));
		} else if ((expression is OParenthesis)) {
			buildExpressionOParenthesis(sb, cast(expression, OParenthesis));
		} else if ((expression is OUnOp)) {
			buildExpressionOUnOp(sb, cast(expression, OUnOp));
		} else if ((expression is OReturn)) {
			buildExpressionOReturn(sb, cast(expression, OReturn));
		} else if ((expression is OWhile)) {
			buildExpressionOWhile(sb, cast(expression, OWhile));
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
	 * Build expression OVar
	 */
	function buildExpressionOVar(sb:IndentStringBuilder, expression:OVar) {
		sb.add(expression.name);

		if (expression.nextExpression != null) {
			sb.add(" = ");
			buildExpression(sb, expression.nextExpression);
		}

		sb.addNewLine(Same);
	}

	/**
	 * Build expression OLocal
	 */
	function buildExpressionOLocal(sb:IndentStringBuilder, expression:OLocal) {
		sb.add(expression.name);
		if (expression.nextExpression != null)
			buildExpression(sb, expression.nextExpression);
	}

	/**
	 * Build expression OFieldInstance
	 */
	function buildExpressionOFieldInstance(sb:IndentStringBuilder, expression:OFieldInstance) {
		var ofield = cast(expression, OFieldInstance);
		var nsb = new IndentStringBuilder();
		if (ofield.nextExpression != null)
			buildExpression(nsb, ofield.nextExpression);

		var name = nsb.toString();
		if (name == "self") {
			sb.add("@");
			sb.add(ofield.field);
		} else {
			sb.add(name);
			sb.add(".");
			sb.add(ofield.field);
		}
	}

	/**
	 * Build expression OFieldStatic
	 */
	function buildExpressionOFieldStatic(sb:IndentStringBuilder, expression:OFieldStatic) {
		var ofield = cast(expression, OFieldStatic);
		buildExpression(sb, ofield.nextExpression);
		var substName = substStaticFieldName(ofield.cls.safeName, ofield.field);
		if (substName != null) {
			sb.add(substName);
		} else {
			sb.add(ofield.field);
		}
	}

	/**
	 * Build expression OCall
	 */
	function buildExpressionOCall(sb:IndentStringBuilder, expression:OCall) {
		var ocall = cast(expression, OCall);
		buildExpression(sb, ocall.nextExpression);
		sb.add("(");
		var data = [];
		for (i in 0...ocall.expressions.length) {
			var nsb = new IndentStringBuilder();
			buildExpression(nsb, ocall.expressions[i]);
			var content = nsb.toString();
			if (content != "")
				data.push(content);
		}
		sb.add(data.join(", "));
		sb.add(")");
	}

	/**
	 * Build expression ONew
	 */
	function buildExpressionONew(sb:IndentStringBuilder, expression:ONew) {
		var onew = cast(expression, ONew);
		var varTypeName = onew.cls.safeName;
		sb.add(varTypeName);
		// TODO: arguments
		sb.add(".new()");
	}

	/**
	 * Build expression OIf
	 */
	function buildExpressionOIf(sb:IndentStringBuilder, expression:OIf) {
		sb.add("if ");
		buildExpression(sb, expression.conditionExpression);

		sb.addNewLine(Inc);

		buildExpression(sb, expression.ifExpression);
		if (expression.elseExpression != null) {
			sb.add("else");
			buildExpression(sb, expression.elseExpression);
		}

		addEnd(sb);
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
					buildExpression(sb, expression.nextExpression);
					sb.add(" += 1");
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
	 * Build expression OReturn
	 */
	function buildExpressionOReturn(sb:IndentStringBuilder, expression:OReturn) {
		sb.add("return ");
		buildExpression(sb, expression.nextExpression);
		sb.addNewLine(Same);
	}

	/**
	 * Build expression OWhile
	 */
	function buildExpressionOWhile(sb:IndentStringBuilder, expression:OWhile) {
		sb.add("while ");
		buildExpression(sb, expression.conditionExpression);
		sb.addNewLine(Inc);
		buildExpression(sb, expression.nextExpression);
		addEnd(sb, false);
	}

	/**
	 * Build methods
	 */
	private function buildMethods(sb:IndentStringBuilder, cls:OClass) {
		for (i in 0...cls.methods.length) {
			var method = cls.methods[i];
			trace(method);
			if (method.isStatic && method.name == BaseBuilder.MAIN_METHOD) {
				mainMethod = method;
			}

			if (method.isStatic) {
				sb.add("def self.");
			} else {
				sb.add("def ");
			}

			sb.add(method.name);

			if (method.args.length > 0) {
				sb.add("(");
				for (i in 0...method.args.length) {
					var arg = method.args[i];
					var varTypeName = arg.type.safeName;
					sb.add(arg.name);
					sb.add(" : ");
					sb.add(varTypeName);

					if (i < method.args.length - 1)
						sb.add(", ");
				}
				sb.add(")");
			}

			sb.addNewLine(Inc);

			buildExpression(sb, method.expression);

			if (i + 1 < cls.methods.length) {
				addEnd(sb);
			} else {
				addEnd(sb, false);
			}
		}
	}

	/**
	 * Build class
	 * @param cls
	 */
	private function buildClass(sb:IndentStringBuilder, cls:OClass) {
		sb.add("class ");
		sb.add(cls.safeName);
		sb.addNewLine(Inc);

		if (cls.classVars.length > 0)
			buildClassVars(sb, cls);

		if (cls.methods.length > 0)
			buildMethods(sb, cls);

		addEnd(sb);
	}

	/**
	 * Build sources
	 */
	public override function build() {
		var sb = new IndentStringBuilder(CRYSTAL_INDENT);
		var filename = Path.normalize("main.cr");
		addHelpers(sb);

		for (c in classes) {
			if (c.isExtern == false) {
				buildClass(sb, c);
			} else {
				trace(c.fullName);
			}
		}

		buildMain(sb);
		File.saveContent(filename, sb.toString());
	}
}
