package ast2obj.builders;

import sys.io.File;
import haxe.io.Path;

/**
 * For string builder with indent
 */
class IndentStringBuilder {
	/**
	 * Count of spaces to indent
	 */
	private static inline final INDENT_SPACE_COUNT = 4;

	/**
	 * String builder
	 */
	private var buffer:StringBuf;

	/**
	 * Current indent
	 */
	private var indent:Int;

	/**
	 * Indent string
	 */
	private var indentStr:String;

	/**
	 * Calculate indent string
	 */
	private function calcIndent() {
		indentStr = "";
		for (i in 0...indent * INDENT_SPACE_COUNT)
			indentStr += " ";
	}

	/**
	 * Constructor
	 */
	public function new() {
		buffer = new StringBuf();
		indent = 0;
		indentStr = "";
	}

	/**
	 * Increment indent
	 */
	public inline function inc() {
		indent += 1;
		calcIndent();
	}

	/**
	 * Decrement indent
	 */
	public inline function dec() {
		if (indent == 0)
			return;

		indent -= 1;
		calcIndent();
	}

	/**
	 * Add value to buffer without indent
	 * @param value
	 */
	public inline function add(value:String) {
		buffer.add(value);
	}

	/**
	 * Add value to buffer with indent
	 * @param value
	 */
	public inline function addWithIndent(value:String) {
		buffer.add(indentStr);
		buffer.add(value);
	}

	/**
	 * Add value to buffer line with indent
	 * @param value
	 */
	public inline function addLine(value:String) {
		addWithIndent(value);
		buffer.add("\n");
	}

	/**
	 * Add break line
	 * @param value
	 */
	public inline function addBreakLine() {
		buffer.add("\n");
	}

	/**
	 * Return string
	 */
	public inline function toString() {
		return buffer.toString();
	}
}

/**
 * Builder for nim code
 */
class NimBuilder extends BaseBuilder {
	/**
	 * Entry point
	 */
	private var mainMethod:OMethod;

	/**
	 * Return resolved type name
	 * @param name
	 */
	private function resolveTypeName(name:String):String {
		switch (name) {
			case "Void":
				return "void";
			case "String":
				return "string";
			case "Int":
				return "int";
			case "Float":
				return "float";
			default:
				throw 'Unknown type ${name}';
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
	 * Substitute some statics
	 * @param className
	 * @param fieldName
	 * @return String
	 */
	private function substStaticFieldName(className:String, fieldName:String):String {
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
	private function buildMain(sb:IndentStringBuilder) {
		sb.addBreakLine();
		sb.addLine('${mainMethod.cls.safeName}StaticInst.${mainMethod.name}()');
	}

	/**
	 * Build class fields
	 * @param cls
	 */
	private function buildClassInfo(sb:IndentStringBuilder, cls:OClass) {
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
	 * @param cls
	 * @param sb
	 */
	private function buildFields(sb:IndentStringBuilder, vars:Array<OClassVar>) {
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
	private function buildInitStaticClass(sb:IndentStringBuilder, cls:OClass) {
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
	private function buildClassMethods(sb:IndentStringBuilder, cls:OClass) {
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
			sb.addBreakLine();
			sb.inc();
			sb.addWithIndent("");

			buildExpression(sb, method.expression);
			sb.addBreakLine();
			sb.dec();
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
		}
	}

	/**
	 * Build expression OBlock
	 */
	private function buildExpressionOblock(sb:IndentStringBuilder, expression:OBlock) {
		for (expr in expression.expressions) {
			buildExpression(sb, expr);
			sb.addBreakLine();
		}
	}

	/**
	 * Build expression OVar
	 */
	private function buildExpressionOVar(sb:IndentStringBuilder, expression:OVar) {
		sb.add("var ");
		sb.add(expression.name);

		if (expression.nextExpression != null) {
			sb.add(" = ");
			buildExpression(sb, expression.nextExpression);
		}
	}

	/**
	 * Build expression OBinOp
	 */
	private function buildExpressionOBinOp(sb:IndentStringBuilder, expression:OBinOp) {
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
	private function buildExpressionOLocal(sb:IndentStringBuilder, expression:OLocal) {
		sb.add(expression.name);
		if (expression.nextExpression != null)
			buildExpression(sb, expression.nextExpression);
	}

	/**
	 * Build expression OFieldInstance
	 */
	private function buildExpressionOFieldInstance(sb:IndentStringBuilder, expression:OFieldInstance) {
		var nsb = new IndentStringBuilder();
		if (expression.nextExpression != null)
			buildExpression(nsb, expression.nextExpression);

		var name = nsb.toString();
		if (name == "self") {
			sb.addWithIndent("this.");
			sb.add(expression.field);
		} else {
			sb.addWithIndent(name);
			sb.add(".");
			sb.add(expression.field);
		}
	}

	/**
	 * Build expression OCall
	 */
	private function buildExpressionOCall(sb:IndentStringBuilder, expression:OCall) {
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
	private function buildExpressionOFieldStatic(sb:IndentStringBuilder, expression:OFieldStatic) {
		buildExpression(sb, expression.nextExpression);
		var substName = substStaticFieldName(expression.cls.safeName, expression.field);
		if (substName != null) {
			if (substName == "echo") {
				sb.addWithIndent(substName);
			} else {
				sb.add(substName);
			}
		} else {
			sb.addWithIndent('${expression.cls.safeName}StaticInst.${expression.field}');
		}
	}

	/**
	 * Build expression ONew
	 */
	private function buildExpressionONew(sb:IndentStringBuilder, expression:ONew) {
		var varTypeName = expression.cls.safeName;
		sb.add(varTypeName);
		// TODO: arguments
		sb.add("()");
	}

	/**
	 * Build sources
	 */
	public override function build() {
		var filename = Path.normalize("main.nim");
		var sb = new IndentStringBuilder();

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
