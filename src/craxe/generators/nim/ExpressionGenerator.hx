package craxe.generators.nim;

import craxe.common.ast.type.*;
import haxe.macro.Type;
import haxe.macro.Type.EnumField;
import haxe.macro.Expr.MetadataEntry;
import haxe.macro.Expr.Unop;
import haxe.macro.Expr.Binop;
import haxe.macro.Type.TConstant;
import haxe.macro.Type.TVar;
import haxe.macro.Type.ModuleType;
import haxe.macro.Type.FieldAccess;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.TypedExpr;
import haxe.macro.Type.TypedExprDef;
import craxe.common.IndentStringBuilder;
import craxe.generators.nim.type.*;

using craxe.common.ast.MetaHelper;
using StringTools;

/**
 * Generate code for expression
 */
class ExpressionGenerator {
	/**
	 * Type resolver
	 */
	final context:TypeContext;

	/**
	 * Type resolver
	 */
	final typeResolver:TypeResolver;

	/**
	 * Class context
	 */
	var classContext:ClassInfo;

	/**
	 * Trace expression for debug
	 */
	function traceExpression(expr:TypedExpr) {		
		trace(expr.pos);
		switch (expr.expr) {
			case TConst(c):
				trace('TConst[${c}]');
			case TLocal(v):
				trace('TLocal[name: ${v.name}]');
			case TArray(e1, e2):
			case TBinop(op, e1, e2):
				trace('TBinop[name: ${op.getName()}, expr1: ${e1.expr.getName()}, expr2: ${e2.expr.getName()}]');
			case TField(e, fa):
				trace('TField[name: ${e.t.getName()}${e.t.getParameters()}, access: ${fa.getName()}${fa.getParameters()}]');
			case TTypeExpr(m):
			case TParenthesis(e):
				trace('TParenthesis: ${e.expr.getName()}');
			case TObjectDecl(fields):
			case TArrayDecl(el):
			case TCall(e, el):
				trace('TCall[expr: ${e.expr.getName()}, elements: ${el.map(x->x.expr.getName()).join(", ")}]');
			case TNew(c, params, el):
				trace('TNew[name: ${c.get().name}, params: ${params.map(x->x.getName()).join(", ")}, elements: ${el.map(x->x.expr.getName()).join(", ")}]');
			case TUnop(op, postFix, e):
			case TFunction(tfunc):
			case TVar(v, expr):
			case TBlock(el):
			case TFor(v, e1, e2):
			case TIf(econd, eif, eelse):
			case TWhile(econd, e, normalWhile):
			case TSwitch(e, cases, edef):
			case TTry(e, catches):
			case TReturn(e):
			case TBreak:
			case TContinue:
			case TThrow(e):
			case TCast(e, m):
			case TMeta(m, e1):
			case TEnumParameter(e1, ef, index):
			case TEnumIndex(e1):
			case TIdent(s):
		}
	}

	/**
	 * Fix local var name
	 */
	inline function fixLocalVarName(name:String):String {
		return name.replace("_", "loc");
	}

	/**
	 * Generate custom code for getting enum values
	 * cast[EnumType](enum).value
	 * TODO: minimize casts
	 * Return true if it was processed
	 */
	function generateCustomEnumParameterCall(sb:IndentStringBuilder, expr:TypedExprDef):Bool {
		// Cast enum
		switch (expr) {
			case TEnumParameter(e1, ef, _):
				switch (e1.expr) {
					case TLocal(v):
						switch (v.t) {
							case TEnum(t, _):
								var enumName = t.get().name;
								var en = context.getEnumByName(enumName);
								var instName = en.enumType.names[ef.index];
								sb.add('cast[${enumName}${instName}](');
								sb.add(v.name);
								sb.add(')');
								switch (ef.type) {
									case TFun(args, _):
										sb.add('.${args[0].name}');
									case v:
										var resolved = typeResolver.resolve(v);
										sb.add(resolved);
								}
								return true;
							default:
						}
					default:
				}
			default:
		}

		return false;
	}

	/**
	 * Generate code for access Bytes data
	 * Fixes inline access to seq[byte]	of HaxeBytes
	 */
	function generateCustomBytesAccess(sb:IndentStringBuilder, expression:TypedExprDef) {
		switch expression {
			case TField(e, _):
				switch (e.t) {
					case TInst(t, _):
						if (t.get().name == "Bytes") {
							generateTypedAstExpression(sb, e);
							return true;
						}
					default:
				}
			default:
		}

		return false;
	}

	/**
	 * Generate code for ESwitch
	 */
	function generateTSwitch(sb:IndentStringBuilder, expression:TypedExpr, cases:Array<{values:Array<TypedExpr>, expr:TypedExpr}>, edef:TypedExpr) {
		var ifname = "if ";
		for (cs in cases) {
			for (val in cs.values) {
				sb.add(ifname);
				generateTypedAstExpression(sb, expression);
				sb.add(" == ");
				generateTypedAstExpression(sb, val);
				sb.add(":");
				sb.addNewLine(Inc);
				generateTypedAstExpression(sb, cs.expr);
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
		if (expressions.length > 0) {
			for (expr in expressions) {
				generateTypedAstExpression(sb, expr);
				sb.addNewLine(Same);
			}
		} else {
			sb.add("discard");
		}
	}

	/**
	 * Generate code for TIf
	 */
	function geterateTIf(sb:IndentStringBuilder, econd:TypedExpr, eif:TypedExpr, eelse:TypedExpr) {
		sb.add("if ");
		generateTypedAstExpression(sb, econd);
		sb.add(":");
		sb.addNewLine(Inc);

		generateTypedAstExpression(sb, eif);
		if (eelse != null) {
			switch (eelse.expr) {
				case TBlock(el):
					if (el.length > 0) {
						sb.addNewLine(Dec);
						sb.add("else:");
						generateTypedAstExpression(sb, eelse);
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
		generateTypedAstExpression(sb, econd);
		sb.add(":");
		sb.addNewLine(Inc);
		generateTypedAstExpression(sb, whileExpression);
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
				sb.add("(");
			case TField(e, fa):
				generateTCallTField(sb, e, fa);
				sb.add("(");
			case TConst(TSuper):
				if (classContext.classType.superClass != null) {
					var superCls = classContext.classType.superClass.t.get();
					var superName = superCls.name;
					sb.add('init${superName}(this, ');
				}
			case _:
				generateTypedAstExpression(sb, expression);
				sb.add("(");
		}

		for (i in 0...expressions.length) {
			var expr = expressions[i];
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
		var typeName = typeResolver.getFixedTypeName(classType.name);
		var typeParams = typeResolver.resolveParameters(params);

		var varTypeName = if (classType.isExtern && classType.superClass != null && classType.superClass.t.get().name == "Distinct") {
			typeName;
		} else {
			'new${typeName}${typeParams}';
		}

		sb.add(varTypeName);
		sb.add("(");
		for (i in 0...elements.length) {
			var expr = elements[i];
			generateTypedAstExpression(sb, expr);
			if (i + 1 < elements.length)
				sb.add(", ");
		}
		sb.add(")");
	}

	/**
	 * Return proper type name and it's field
	 */
	function getStaticTFieldData(classType:ClassType, classField:ClassField):{
		isTop:Bool,
		className:String,
		fieldName:String,
		totalName:String
	} {
		var className = "";
		var isTop = false;

		if (classType.isExtern) {
			isTop = classField.meta.has(":topFunction");
			className = classType.meta.getMetaValue(":native");
			// Check it's top function
			if (className == null) {
				// TODO: make it better. Maybe getSystemFieldTotalName(classType, classField) ?
				if (classType.module.indexOf("sys.io.") > -1) {
					className = '${classType.name}StaticInst';
				} else {
					className = classType.name;
				}
			}
		} else {
			typeResolver.getFixedTypeName(classType.name);
			var name = typeResolver.getFixedTypeName(classType.name);
			className = '${name}StaticInst';
		}

		var fieldName = classField.name;

		if (isTop) {
			var topName = classField.meta.getMetaValue(":native");
			if (topName != null)
				fieldName = topName;
		}

		var totalName = if (isTop) {
			fieldName;
		} else {
			'${className}.${fieldName}';
		}

		if (totalName == "Std.string")
			totalName = "$";

		return {
			isTop: isTop,
			className: className,
			fieldName: fieldName,
			totalName: totalName
		}
	}

	/**
	 * Get instance field data
	 */
	function getInstanceTFieldData(classType:ClassType, params:Array<Type>, classField:ClassField):{
		className:String,
		fieldName:String,
		totalName:String
	} {
		var fieldName:String = null;
		var className = typeResolver.getFixedTypeName(classType.name);

		if (classType.isExtern) {
			fieldName = classField.meta.getMetaValue(":native");
		}

		if (fieldName == null)
			fieldName = typeResolver.getFixedTypeName(classField.name);

		if (classType.isInterface) {
			switch (classField.kind) {
				case FVar(_, _):
					fieldName = '${fieldName}[]';
				case FMethod(_):
			}
		}

		return {
			className: className,
			fieldName: fieldName,
			totalName: '${className}.${fieldName}'
		}
	}

	/**
	 * Generate code for static field call
	 */
	function generateTCallTFieldFStatic(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		var fieldData = getStaticTFieldData(classType, classField);		
		sb.add(fieldData.totalName);
	}

	/**
	 * Generate code for instance field call
	 */
	function generateTCallTFieldFInstance(sb:IndentStringBuilder, classType:ClassType, params:Array<Type>, classField:ClassField) {
		var fieldData = getInstanceTFieldData(classType, params, classField);

		sb.add(".");
		sb.add(fieldData.fieldName);
	}

	/**
	 * Generate code for instance field referrence
	 */
	function generateTFieldFInstance(sb:IndentStringBuilder, classType:ClassType, params:Array<Type>, classField:ClassField) {
		var fieldData = getInstanceTFieldData(classType, params, classField);

		sb.add(".");
		sb.add(fieldData.fieldName);
	}

	/**
	 * Generate code for static field referrence
	 */
	function generateTFieldFStatic(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		var fieldData = getStaticTFieldData(classType, classField);
		switch (classField.type) {
			case TFun(_, _):
				sb.add(typeResolver.resolve(classField.type));
				sb.add("=");
			case v:
				throw 'Unsupported ${v}';
		}

		sb.add(fieldData.totalName);
	}

	/**
	 * Generate field of object
	 */
	function generateTField(sb:IndentStringBuilder, expression:TypedExpr, access:FieldAccess) {
		switch (expression.expr) {
			case TTypeExpr(v):
			case _:
				generateTypedAstExpression(sb, expression);
		}

		switch (access) {
			case FInstance(c, params, cf):
				generateTFieldFInstance(sb, c.get(), params, cf.get());
			case FStatic(c, cf):
				generateTFieldFStatic(sb, c.get(), cf.get());
			case FAnon(cf):
			case FDynamic(s):
			case FClosure(c, cf):
			case FEnum(e, ef):
				var name = typeResolver.getFixedTypeName(e.get().name);
				sb.add('new${name}${ef.name}()');
		}
	}

	/**
	 * Generate code for calling field
	 */
	function generateTCallTField(sb:IndentStringBuilder, expression:TypedExpr, access:FieldAccess) {
		switch (expression.expr) {
			case TTypeExpr(_):
			case _:
				generateTypedAstExpression(sb, expression);
		}

		switch (access) {
			case FInstance(c, params, cf):
				generateTCallTFieldFInstance(sb, c.get(), params, cf.get());
			case FStatic(c, cf):
				generateTCallTFieldFStatic(sb, c.get(), cf.get());
			case v:
				throw 'Unsupported ${v}';
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

		var name = typeResolver.getFixedTypeName(vr.name);
		name = fixLocalVarName(name);
		sb.add(name);
		if (expr != null) {
			sb.add(" = ");

			if (!generateCustomEnumParameterCall(sb, expr.expr))
				generateTypedAstExpression(sb, expr);
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
				throw "Unsupported super";
		}
	}

	/**
	 * Generate code for TLocal
	 */
	function generateTLocal(sb:IndentStringBuilder, vr:TVar) {
		var name = fixLocalVarName(vr.name);
		sb.add(name);
	}

	/**
	 * Generate code for TArray
	 * Array access arr[it]
	 */
	function generateTArray(sb:IndentStringBuilder, e1:TypedExpr, e2:TypedExpr) {
		if (!generateCustomBytesAccess(sb, e1.expr))
			generateTypedAstExpression(sb, e1);

		sb.add("[");
		generateTypedAstExpression(sb, e2);
		sb.add("]");
	}

	/**
	 * Generate code for TArrayDecl
	 * An array declaration `[el]`
	 */
	function generateTArrayDecl(sb:IndentStringBuilder, elements:Array<TypedExpr>) {
		sb.add("@[");
		for (i in 0...elements.length) {
			var expr = elements[i];
			generateTypedAstExpression(sb, expr);
			if (i + 1 < elements.length)
				sb.add(", ");
		}
		sb.add("]");
	}

	/**
	 * Generate code for TBinop
	 */
	function generateTBinop(sb:IndentStringBuilder, op:Binop, e1:TypedExpr, e2:TypedExpr) {
		generateTypedAstExpression(sb, e1);
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
				switch op {
					case OpAdd:
						sb.add("+=");
					case OpDiv:
						sb.add("-=");
					case v:
						throw 'Unsupported ${v}';
				}
			case OpInterval:
			case OpArrow:
			case OpIn:
		}
		sb.add(" ");

		if (e2.expr != null)
			generateTypedAstExpression(sb, e2);
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
				generateTypedAstExpression(sb, expr);
				sb.add(")");
			case OpDecrement:
			case OpNot:
			case OpNeg:
			case OpNegBits:
		}
	}

	/**
	 * Generate TFunction
	 */
	function generateTFunction(sb:IndentStringBuilder, func:TFunc) {
		var args = "";
		if (func.args.length > 0) {
			args = func.args.map(x -> '${x.v.name}:${typeResolver.resolve(x.v.t)}').join(", ");
		}		

		sb.addNewLine(Inc);
		sb.add("proc(");

		sb.add(args);

		sb.add("):");
		sb.add(typeResolver.resolve(func.t));
		sb.add(" = ");
		sb.addNewLine(Inc);

		generateTypedAstExpression(sb, func.expr);

		sb.addNewLine(Dec);
		sb.addNewLine(Dec);
	}

	/**
	 * Generate code for TReturn
	 */
	function generateTReturn(sb:IndentStringBuilder, expression:TypedExpr) {
		if (expression == null || expression.expr == null) {			
			sb.add("return");
		} else {
			switch (expression.expr) {
				case TBlock(_):
				case TReturn(_):
				case _:
					sb.add("return ");
			}

			generateTypedAstExpression(sb, expression);
		}
	}

	/**
	 * Generate code for TMeta
	 */
	function generateTMeta(sb:IndentStringBuilder, meta:MetadataEntry, expression:TypedExpr) {
		generateTypedAstExpression(sb, expression);
	}

	/**
	 * Generate code for TEnumParameter
	 */
	function generateTEnumParameter(sb:IndentStringBuilder, expression:TypedExpr, enumField:EnumField, index:Int) {
		generateTypedAstExpression(sb, expression);
	}

	/**
	 * Generate code for TMeta
	 */
	function generateTEnumIndex(sb:IndentStringBuilder, expression:TypedExpr) {
		generateTypedAstExpression(sb, expression);
	}

	/**
	 * Generate code for TObjectDecl
	 */
	function generateTObjectDecl(sb:IndentStringBuilder, fields:Array<{name:String, expr:TypedExpr}>) {
		for (i in 0...fields.length) {
			var field = fields[i];
			generateTypedAstExpression(sb, field.expr);
			if (i + 1 < fields.length)
				sb.add(", ");
		}
	}

	/**
	 * Generate common expression
	 */
	function generateTypedAstExpression(sb:IndentStringBuilder, expr:TypedExpr) {		
		//#if debug_gen
		traceExpression(expr);
		//#end
		switch (expr.expr) {
			case TConst(c):
				generateTConst(sb, c);
			case TLocal(v):
				generateTLocal(sb, v);
			case TArray(e1, e2):
				generateTArray(sb, e1, e2);
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case TTypeExpr(m):
				generateTTypeExpr(sb, m);
			case TParenthesis(e):
				generateTypedAstExpression(sb, e);
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
				generateTFunction(sb, tfunc);
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
	 * Constructor
	 */
	public function new(context:TypeContext, typeResolver:TypeResolver) {
		this.context = context;
		this.typeResolver = typeResolver;
	}

	/**
	 * Set class context
	 */
	public function setClassContext(classContext:ClassInfo) {
		this.classContext = classContext;
	}

	/**
	 * Generate codes
	 */
	public function generate(sb:IndentStringBuilder, expression:TypedExpr) {
		generateTypedAstExpression(sb, expression);
	}
}
