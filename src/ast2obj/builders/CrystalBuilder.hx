package ast2obj.builders;

import sys.io.File;
import haxe.io.Path;

class CrystalBuilder {
	/**
	 * Name of entry point
	 */
	public static inline final MAIN_METHOD = "main";

	/**
	 * Entry point
	 */
	private var mainMethod:OMethod;

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
				def self.string(v) : String
					v.to_s
				end
			end
		');
	}

	/**
	 * Build entry point
	 */
	private function buildMain(sb:StringBuf) {
		sb.add("\n");
		sb.add('${mainMethod.cls.safeName}.${mainMethod.name}()\n');
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
	private function buildClassVars(sb:StringBuf, cls:OClass) {
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
	 * Build methods
	 * @param sb
	 * @param cls
	 */
	private function buildMethods(sb:StringBuf, cls:OClass) {
		for (method in cls.methods) {
			if (method.isStatic && method.name == MAIN_METHOD) {
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

			sb.add("\n");

			buildExpression(sb, method.expression);

			sb.add("end");
			sb.add("\n");
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
	private function buildExpression(sb:StringBuf, expression:OExpression) {
		trace(expression);
		if ((expression is OBlock)) {
			var oblock = cast(expression, OBlock);
			for (expr in oblock.expressions) {
				buildExpression(sb, expr);
				sb.add("\n");
			}
		} else if ((expression is OReturn)) {
			sb.add("return ");
			buildExpression(sb, expression.nextExpression);
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
			var nsb = new StringBuf();
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
		} else if ((expression is OFieldStatic)) {
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
			var data = [];
			for (i in 0...ocall.expressions.length) {	
				var nsb = new StringBuf();				
				buildExpression(nsb, ocall.expressions[i]);
				var content = nsb.toString();
				if (content != "")
					data.push(content);				
			}
			sb.add(data.join(", "));
			sb.add(")");
		} else if ((expression is ONew)) {
			var onew = cast(expression, ONew);
			var varTypeName = onew.cls.safeName;
			sb.add(varTypeName);
			// TODO: arguments
			sb.add(".new()");
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

		buildMain(sb);
		File.saveContent(filename, sb.toString());
	}
}
