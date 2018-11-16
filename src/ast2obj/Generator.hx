package ast2obj;

import ast2obj.builders.BaseBuilder;
import haxe.macro.Compiler;
import ast2obj.builders.CrystalBuilder;
import ast2obj.builders.NimBuilder;
import haxe.macro.Expr.Binop;
import haxe.macro.Expr.Unop;
import haxe.macro.ExprTools;
import haxe.macro.Type;

class Generator {
	#if macro
	public static function generate() {
		haxe.macro.Context.onGenerate(onGenerate);
	}
	#end

	public static function onGenerate(types:Array<Type>):Void {
		var classes = new Array<OClass>();

		for (t in types) {
			switch (t) {
				case TInst(c, params):
					var oclass = buildClass(c, params);
					if (oclass != null) {
						classes.push(oclass);
					}
				default:
					// trace(t);
			}
		}
		
		var builder : BaseBuilder = null;
		#if crystal
			builder = new CrystalBuilder(classes);
		#end
		#if nim
			builder = new NimBuilder(classes);
		#end

		if (builder == null)
			throw "Not supported builder type";
			
		builder.build();

		// var libraries:Array<String> = ArduinoCPPBuilder.libraries;
		// Compiler.compile(ArduinoCPPBuilder.srcPath, ArduinoCPPBuilder.includePath, ArduinoCPPBuilder.outPath, libraries);
	}

	private static function buildClass(c:Ref<ClassType>, params:Array<Type>):OClass {
		var typeName = c.toString();
		// TODO: filter
		if (
			typeName == "Array" || typeName == "Std" || typeName == "EReg" || typeName == "ArrayAccess" || typeName == "String" || typeName == "IntIterator" || typeName == "StringBuf" || typeName == "StringTools" || typeName == "Type" || StringTools
				.startsWith(c.toString(), "haxe.")) {
			// trace("Skipping: " + c.toString());
			return null;
		} else {
			// trace("Generating: " + c.toString());
		}

		var oclass = new OClass();
		oclass.fullName = c.toString();
		if (c.get().superClass != null) {
			oclass.superClass = new OClass();
			oclass.superClass.fullName = c.get().superClass.t.toString();
		}
		oclass.isExtern = c.get().isExtern;
		if (oclass.isExtern == true) {
			oclass.externIncludes = extractMetaValues(c.get().meta, ":include");
			oclass.externName = extractMetaValue(c.get().meta, ":native");
		}
		oclass.stackOnly = hasMeta(c.get().meta, ":stackOnly");

		var classType:ClassType = c.get();
		for (f in classType.fields.get()) {
			switch (f.kind) {
				case FMethod(k):					
					var omethod = buildMethod(oclass, f.expr());
					if (omethod != null) {
						omethod.cls = oclass;
						omethod.name = f.name;
						oclass.methods.push(omethod);
					}
				case FVar(read, write):
					var oclassvar = buildClassVar(oclass, f.expr());
					if (oclassvar != null) {
						oclassvar.type = buildType(f.type);
						oclassvar.cls = oclass;
						oclassvar.name = f.name;
						oclass.classVars.push(oclassvar);
					}
				case _:
					trace("buildClass not impl: " + f.kind);
			}
		}

		for (f in classType.statics.get()) {
			switch (f.kind) {
				case FMethod(k):
					var omethod = buildMethod(oclass, f.expr(), true);
					if (omethod != null) {
						omethod.cls = oclass;
						omethod.name = f.name;
						oclass.methods.push(omethod);
					}
				case FVar(read, write):
					trace(read);
				case _:
					trace("buildClass not impl: " + f.kind);
			}
		}
		return oclass;
	}

	private static function buildClassVar(oclass:OClass, e:TypedExpr):OClassVar {
		var oclassvar = new OClassVar();
		oclassvar.expression = buildExpression(e, null);
		return oclassvar;
	}

	private static function buildMethod(oclass:OClass, e:TypedExpr, isStatic:Bool = false):OMethod {
		var omethod:OMethod = null;

		if (e != null) {
			switch (e.expr) {
				case TFunction(tfunc):
					omethod = new OMethod();
					omethod.type = buildType(tfunc.t);
					omethod.isStatic = isStatic;
					for (arg in tfunc.args) {						
						var omethodarg = new OMethodArg();						
						omethodarg.name = arg.v.name;
						omethodarg.type = buildType(arg.v.t);
						omethodarg.value = buildConstant(arg.value);
						omethodarg.id = arg.v.id;
						omethod.args.push(omethodarg);
					}
					omethod.expression = buildExpression(tfunc.expr, null);
				case _:
			}
		}

		return omethod;
	}

	private static function buildExpression(e:TypedExpr, prevExpression:OExpression):OExpression {
		if (e == null) {
			return null;
		}

		var oexpr:OExpression = null;

		switch (e.expr) {
			case TBlock(el):
				oexpr = new OBlock();
				for (e in el) {
					cast(oexpr, OBlock).expressions.push(buildExpression(e, oexpr));
				}
			case TReturn(e):
				oexpr = new OReturn();
				oexpr.nextExpression = buildExpression(e, oexpr);
			case TConst(c):
				oexpr = buildConstant(c);

				// so basically doing some really hacky crap here. If you have an untyped static int like:
				// public static inline var LED_BUILTIN:Int = untyped 'LED_BUILTIN';
				// Then the type and the expr dont match (one is string, one is int), so we'll make the
				// awful assumption its supposed to be an int constant... will likely go completely wrong
				// somewhere
				if (cast(oexpr, OConstant).type != "this") {
					switch (e.t) {
						case TAbstract(t, params):
							if (cast(oexpr, OConstant).type != t.toString()) {
								var constantName:String = cast(oexpr, OConstant).value;
								oexpr = new OConstantIdentifier();
								cast(oexpr, OConstantIdentifier).name = constantName;
							}
						case TInst(t, params):
							if (cast(oexpr, OConstant).type != t.toString()) {
								var constantName:String = cast(oexpr, OConstant).value;
								oexpr = new OConstantIdentifier();
								cast(oexpr, OConstantIdentifier).name = constantName;
							}
						case _:
					}
				}

			case TVar(v, e):
				oexpr = new OVar();
				cast(oexpr, OVar).name = v.name;
				cast(oexpr, OVar).type = buildType(v.t);
				oexpr.nextExpression = buildExpression(e, oexpr);
			case TBinop(op, e1, e2):
				oexpr = new OBinOp();
				cast(oexpr, OBinOp).op = buildBinOp(op);
				cast(oexpr, OBinOp).expression = buildExpression(e1, oexpr);
				oexpr.nextExpression = buildExpression(e2, oexpr);
			case TLocal(v):
				oexpr = new OLocal();
				oexpr.id = v.id;
				cast(oexpr, OLocal).name = v.name;
				cast(oexpr, OLocal).type = buildType(v.t);
			case TIf(econd, eif, null):
				oexpr = new OIf();
				cast(oexpr, OIf).conditionExpression = buildExpression(econd, oexpr);
				cast(oexpr, OIf).ifExpression = buildExpression(eif, oexpr);
			case TParenthesis(e):
				oexpr = new OParenthesis();
				oexpr.nextExpression = buildExpression(e, oexpr);
			case TArrayDecl(el):
				oexpr = new OArrayDecl();
				for (e in el) {
					cast(oexpr, OArrayDecl).expressions.push(buildExpression(e, oexpr));
				}
			case TWhile(econd, e, true):
				oexpr = new OWhile();
				cast(oexpr, OWhile).conditionExpression = buildExpression(econd, oexpr);
				oexpr.nextExpression = buildExpression(e, oexpr);
			case TField(e, FInstance(c, params, cf)):
				oexpr = new OFieldInstance();
				cast(oexpr, OFieldInstance).cls = new OClass();
				cast(oexpr, OFieldInstance).field = cf.get().name;
				cast(oexpr, OFieldInstance).cls.fullName += c.toString();
				oexpr.nextExpression = buildExpression(e, oexpr);
			case TField(e, FStatic(c, cf)):
				oexpr = new OFieldStatic();
				cast(oexpr, OFieldStatic).cls = new OClass();
				cast(oexpr, OFieldStatic).cls.fullName += c.toString();
				cast(oexpr, OFieldStatic).cls.isExtern = c.get().isExtern;
				if (cast(oexpr, OFieldStatic).cls.isExtern) {
					cast(oexpr, OFieldStatic).cls.externIncludes = extractMetaValues(c.get().meta, ":include");
					cast(oexpr, OFieldStatic).cls.externName = extractMetaValue(c.get().meta, ":native");
				}
				cast(oexpr, OFieldStatic).field = cf.get().name;
				oexpr.nextExpression = buildExpression(e, oexpr);
			case TArray(e1, e2):
				oexpr = new OArray();
				cast(oexpr, OArray).varExpression = buildExpression(e1, oexpr);
				oexpr.nextExpression = buildExpression(e2, oexpr);
			case TUnop(op, postFix, e):
				oexpr = new OUnOp();
				cast(oexpr, OUnOp).op = buildUnOp(op);
				cast(oexpr, OUnOp).post = postFix;
				oexpr.nextExpression = buildExpression(e, oexpr);
			case TNew(c, params, el):
				oexpr = new ONew();
				cast(oexpr, ONew).cls = new OClass();
				cast(oexpr, ONew).cls.fullName += c.toString();
				for (e in el) {
					cast(oexpr, ONew).expressions.push(buildExpression(e, oexpr));
				}
			case TCall(e, el):
				oexpr = new OCall();
				oexpr.nextExpression = buildExpression(e, oexpr);
				for (e in el) {
					cast(oexpr, OCall).expressions.push(buildExpression(e, oexpr));
				}
			case TTypeExpr(TClassDecl(c)):
				oexpr = new OTypeExprClass();
				cast(oexpr, OTypeExprClass).cls = new OClass();
				cast(oexpr, OTypeExprClass).cls.fullName += c.toString();
			case _:
				trace("buildExpression not impl: " + e.expr);
		}

		if (oexpr != null) {
			oexpr.prevExpression = prevExpression;
		}

		return oexpr;
	}

	private static function buildConstant(c:Null<TConstant>):OConstant {
		if (c == null) {
			return null;
		}

		var oconstant:OConstant = new OConstant();

		switch (c) {
			case TInt(i):
				oconstant.type = "Int";
				oconstant.value = i;
			case TString(s):
				oconstant.type = "String";
				oconstant.value = s;
			case TThis:
				oconstant.type = "this";
			case TNull:
				oconstant.type = "null";
			case _:
				trace("buildConstant not impl: " + c);
		}

		return oconstant;
	}

	private static function buildType(t:Type):OType {
		var otype = new OType();

		switch (t) {
			case TAbstract(t, params):
				otype.name = t.toString();
			case TInst(t, params):
				otype.name = t.toString();
				for (p in params) {
					otype.typeParameters.push(buildType(p));
				}
			case _:
				trace("buildType not impl: " + t);
		}

		return otype;
	}

	private static function extractMetaValue(meta:MetaAccess, name:String):String {
		var metaValue = null;

		if (meta.extract(name) != null && meta.extract(name).length > 0) {
			metaValue = ExprTools.toString(meta.extract(name)[0].params[0]);
			metaValue = StringTools.replace(metaValue, "\"", "");
		}

		if (name == ":include" && metaValue != null) {
			metaValue = StringTools.replace(metaValue, ".h", "");
		}

		return metaValue;
	}

	private static function extractMetaValues(meta:MetaAccess, name:String):Array<String> {
		var metaValues = null;

		if (meta.extract(name) != null && meta.extract(name).length > 0) {
			metaValues = [];
			var metaEntries = meta.extract(name);
			for (m in metaEntries) {
				var metaValue:String = ExprTools.toString(m.params[0]);
				metaValue = StringTools.replace(metaValue, "\"", "");
				metaValues.push(metaValue);
			}
		}

		return metaValues;
	}

	private static function hasMeta(meta:MetaAccess, name:String):Bool {
		var b = false;

		if (meta.extract(name) != null && meta.extract(name).length > 0) {
			b = true;
		}

		return b;
	}

	private static function buildBinOp(op:Binop)
		return switch (op) {
			case OpAdd: "+";
			case OpMult: "*";
			case OpDiv: "/";
			case OpSub: "-";
			case OpAssign: "=";
			case OpEq: "==";
			case OpNotEq: "!=";
			case OpGt: ">";
			case OpGte: ">=";
			case OpLt: "<";
			case OpLte: "<=";
			case OpAnd: "&";
			case OpOr: "|";
			case OpXor: "^";
			case OpBoolOr: "||";
			case OpBoolAnd: "&&";
			case OpShl: "<<";
			case OpShr: ">>";
			case OpUShr: ">>>";
			case OpMod: "%";
			case OpInterval: "...";
			case OpArrow: "=>";
			// case OpIn: " in ";
			case OpAssignOp(op):
				buildBinOp(op) + "=";
			case _:
				trace("buildBinOp not impl: " + op);
				return "";
		}

	private static function buildUnOp(op:Unop)
		return switch (op) {
			case OpIncrement: "++";
			case OpDecrement: "--";
			case OpNot: "!";
			case OpNeg: "-";
			case OpNegBits: "~";
		}
}
