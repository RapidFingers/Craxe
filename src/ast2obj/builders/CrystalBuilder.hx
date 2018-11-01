package ast2obj.builders;

import sys.io.File;
import haxe.io.Path;

class CrystalBuilder {
	/**
	 * Classes to build source
	 */
	public final classes:Array<OClass>;

	/**
	 * Add helper data
	 * @param sb 
	 */
	private function addHelpers(sb:StringBuf) {
		sb.add('
			class HaxeStd
				def self.string(v)
					v.to_s
				end
			end
		');
	}

	/**
	 * Substitute some statics
	 * @param className
	 * @param fieldName
	 * @return String
	 */
	private function substStaticFieldName(className:String, fieldName:String):String {
		if (className == "Std") {
			switch (fieldName) {
				case "string":
					return "HaxeStd.string";
			}
		}
		return null;
	}

	/**
	 * Build class vars
	 * @param cls
	 * @param sb
	 */
	private function buildClassVars(sb:StringBuf, cls:OClass) {
		for (classVar in cls.classVars) {
			sb.add("@");
			sb.add(classVar.name);
			sb.add(" : ");
			sb.add(classVar.type.safeName);
			sb.add("\n");
		}
	}

	/**
	 * Build methods
	 * @param sb
	 * @param cls
	 */
	private function buildMethods(sb:StringBuf, cls:OClass) {
		for (method in cls.methods) {
			sb.add("def ");
			sb.add(method.name);
			sb.add("\n");

			buildExpression(sb, method.expression);

			sb.add("end\n");
		}
	}

	/**
	 * Build constant
	 * @param c
	 */
	private static function buildConstant(sb:StringBuf, const:OConstant) {
		switch (const.type) {
			case "Int":
				sb.add(const.value);
			case "String":
				sb.add("String(\"" + const.value + "\")");
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
	private function buildExpression(sb:StringBuf, expression:OExpression) {
		trace(expression);
		if ((expression is OBlock)) {
			var oblock = cast(expression, OBlock);
			for (expr in oblock.expressions) {
				buildExpression(sb, expr);
			}
		} else if ((expression is OReturn)) {
			sb.add("return ");
			buildExpression(sb, expression.nextExpression);
			sb.add("\n");
		} else if ((expression is OBinOp)) {
			var obinop = cast(expression, OBinOp);
			buildExpression(sb, obinop.expression);
			sb.add(" ");
			sb.add(obinop.op);
			sb.add(" ");
			if (obinop.nextExpression != null)
				buildExpression(sb, obinop.nextExpression);
		} else if ((expression is OVar)) {
			var ovar = cast(expression, OVar);
			sb.add(ovar.name);

			if (ovar.nextExpression != null) {
				sb.add(" = ");
				buildExpression(sb, ovar.nextExpression);
			}
			sb.add("\n");
		} else if ((expression is OConstant)) {
			buildConstant(sb, cast(expression, OConstant));
			if (expression.nextExpression != null)
				buildExpression(sb, expression.nextExpression);
		} else if ((expression is OLocal)) {
			var olocal = cast(expression, OLocal);
			sb.add(olocal.name);
			if (olocal.nextExpression != null)
				buildExpression(sb, olocal.nextExpression);
		} else if ((expression is OFieldInstance)) {
			var ofield = cast(expression, OFieldInstance);
			sb.add("@");
			sb.add(ofield.field);
		} else if (Std.is(expression, OFieldStatic)) {
			var ofield = cast(expression, OFieldStatic);
			buildExpression(sb, ofield.nextExpression);
			var substName = substStaticFieldName(ofield.cls.safeName, ofield.field);
			if (substName != null) {
				sb.add(substName);
			} else {
				sb.add(ofield.field);
			}			
		} else if ((expression is OCall)) {
			var ocall = cast(expression, OCall);
			buildExpression(sb, ocall.nextExpression);
			sb.add("(");
			for (i in 0...ocall.expressions.length) {
				buildExpression(sb, ocall.expressions[i]);
				if (i < ocall.expressions.length - 1) {
					sb.add(", ");
				}
			}
			sb.add(")\n");
		}
	}

	/**
	 * Build class
	 * @param cls
	 */
	private function buildClass(sb:StringBuf, cls:OClass) {
		sb.add("class ");
		sb.add(cls.safeName);
		sb.add("\n");

		if (cls.classVars.length > 0)
			buildClassVars(sb, cls);

		if (cls.methods.length > 0)
			buildMethods(sb, cls);

		sb.add("\n");
		sb.add("end\n");
	}

	/**
	 * Constructor
	 * @param classes
	 */
	public function new(classes:Array<OClass>) {
		this.classes = classes;
	}

	/**
	 * Build sources
	 */
	public function build() {
		var filename = Path.normalize("main.cr");

		var sb = new StringBuf();
		addHelpers(sb);

		for (c in classes) {
			if (c.isExtern == false) {
				buildClass(sb, c);
			}
		}

		File.saveContent(filename, sb.toString());
	}
}
