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
	function traceExpressionInternal(expr:TypedExpr) {
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
				trace('TCall[expr: ${e.expr.getName()}, elements: ${el.map(x -> x.expr.getName()).join(", ")}]');
			case TNew(c, params, el):
				trace('TNew[name: ${c.get().name}, params: ${params.map(x -> x.getName()).join(", ")}, elements: ${el.map(x -> x.expr.getName()).join(", ")}]');
			case TUnop(op, postFix, e):
				trace('TUnop[name: ${op.getName()}, postFix: ${postFix}, expr: ${e.expr.getName()}]');
			case TFunction(tfunc):
				trace('TFunction[args: ${tfunc.args.map(x -> x.v.name).join(", ")}, ret: ${tfunc.t.getName()}, expr: ${tfunc.expr.expr.getName()}]');
			case TVar(v, expr):
				trace('TVar[name: ${v.name}, expr: ${expr.expr.getName()}]');
			case TBlock(el):
				trace('TBlock[elements: ${el.map(x -> x.expr.getName()).join(", ")}]');
			case TFor(v, e1, e2):
				trace('TFor[name: ${v.name}, e1: ${e1.expr.getName()}, e2: ${e2.expr.getName()}]');
			case TIf(econd, eif, eelse):
				var seelse = if (eelse != null) {
					eelse.expr.getName();
				} else "";
				trace('TWhile[econd: ${econd.expr.getName()}, eif: ${eif.expr.getName()}, eelse: ${seelse}]');
			case TWhile(econd, e, normalWhile):
				trace('TWhile[econd: ${econd.expr.getName()}, expr: ${e.expr.getName()}, normal: ${normalWhile}]');
			case TSwitch(e, cases, edef):
				var sedef = if (edef != null) {
					edef.expr.getName();
				} else "";
				trace('TSwitch[expr: ${e.expr.getName()}, cases: ${cases}, edef: ${sedef}]');
			case TTry(e, catches):
				trace('TTry[expr: ${e.expr.getName()}, catches: ${catches}}]');
			case TReturn(e):
				var exp = if (e != null) {
					e.expr.getName();
				} else "";
				trace('TReturn[expr: ${exp}]');
			case TBreak:
				trace('TBreak');
			case TContinue:
				trace('TContinue');
			case TThrow(e):
				trace('TThrow[expr: ${e.expr.getName()}]');
			case TCast(e, m):
				trace('TCast[expr: ${e.expr.getName()}, type: ${m.getName()}]');
			case TMeta(m, e1):
				trace('TMeta[name: ${m.name}, params: ${m.params.map(x -> x.expr.getName()).join(", ")}, expr: ${e1.expr.getName()}]');
			case TEnumParameter(e1, ef, index):
				trace('TEnumParameter[expr: ${e1.expr.getName()}, field: ${ef.name}, index: ${index}]');
			case TEnumIndex(e1):
				trace('TEnumIndex[expr: ${e1.expr.getName()}]');
			case TIdent(s):
				trace('TIdent[${s}]');
		}
	}

	/**
	 * Trace expression
	 */
	inline function traceExpression(expr:TypedExpr) {
		#if debug_gen
		traceExpressionInternal(expr);
		#end
	}

	/**
	 * Fix local var name
	 */
	inline function fixLocalVarName(name:String):String {
		return name.replace("_", "loc");
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
	 * Generate code for TVar
	 */
	function generateTVar(sb:IndentStringBuilder, vr:TVar, expr:TypedExpr) {
		sb.add("var ");

		var name = typeResolver.getFixedTypeName(vr.name);
		name = fixLocalVarName(name);
		sb.add(name);
		if (expr != null) {
			sb.add(" = ");

			switch expr.expr {
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TConst(c):
					generateTConst(sb, c);
				case v:
					throw 'Unsupported ${v}';
					// case TCall(e, el):
					// 	generateTCall(sb, e, el, false);
					// case _:
					// 	if (!generateCustomEnumParameterCall(sb, expr.expr))
					// 		generateTypedAstExpression(sb, expr);
			}
		}
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

			switch (expr.expr) {
				case TConst(c):

				case v:
					throw 'Unsupported ${v}';
			}

			if (i + 1 < elements.length)
				sb.add(", ");
		}
		sb.add(")");
	}

	/**
	 * Generate code for TLocal
	 */
	function generateTLocal(sb:IndentStringBuilder, vr:TVar) {
		var name = fixLocalVarName(vr.name);
		sb.add(name);
	}

	/**
	 * Generate code for TObjectDecl
	 */
	function generateTObjectDecl(sb:IndentStringBuilder, fields:Array<{name:String, expr:TypedExpr}>) {
		for (i in 0...fields.length) {
			var field = fields[i];
			switch field.expr.expr {
				case TConst(c):
					generateTConst(sb, c);
				case v:
					throw 'Unsupported ${v}';
			}
			if (i + 1 < fields.length)
				sb.add(", ");
		}
	}

	/**
	 * Generate code for TReturn
	 */
	function generateTReturn(sb:IndentStringBuilder, expression:TypedExpr) {
		if (expression == null || expression.expr == null) {
			sb.add("return");
		} else {
			switch (expression.expr) {
				case TBlock(e):
					generateTBlock(sb, e);
				case TReturn(e):
					generateTReturn(sb, expression);
				case TCall(e, el):
					sb.add("return ");
				// generateTCall(sb, e, el, false);
				case TNew(c, params, el):
					sb.add("return ");
					generateTNew(sb, c.get(), params, el);
				case TConst(c):
					sb.add("return ");
					generateTConst(sb, c);
				case v:
					throw 'Unsupported ${v}';
			}
		}
	}

	/**
	 * Generate code for TBinop
	 */
	function generateTBinop(sb:IndentStringBuilder, op:Binop, e1:TypedExpr, e2:TypedExpr) {
		switch e1.expr {
			case v:
				throw 'Unsupported ${v}';
		}

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

		if (e2.expr != null) {
			switch e2.expr {
				case v:
					throw 'Unsupported ${v}';
			}
		}
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
	 * Generate code for calling field
	 */
	function generateTCallTField(sb:IndentStringBuilder, expression:TypedExpr, access:FieldAccess) {
		switch (expression.expr) {
			case TTypeExpr(_):
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case TLocal(v):
				generateTLocal(sb, v);
			case v:
				throw 'Unsupported ${v}';
				// generateTypedAstExpression(sb, expression);
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
	 * Generate code for common TCall
	 */
	function generateCommonTCall(sb:IndentStringBuilder, expression:TypedExpr, expressions:Array<TypedExpr>) {
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
			case v:
				throw 'Unsupported ${v}';
				// generateTypedAstExpression(sb, expression);
				// sb.add("(");
		}

		for (i in 0...expressions.length) {
			var expr = expressions[i];
			switch (expr.expr) {
				case TConst(c):
					generateTConst(sb, c);
				case TObjectDecl(e):
					generateTObjectDecl(sb, e);
				case v:
					throw 'Unsupported ${v}';
			}

			// generateTypedAstExpression(sb, expr);
			if (i + 1 < expressions.length)
				sb.add(", ");
		}

		sb.add(")");
	}

	/**
	 * Generate code for root TCall in block
	 */
	function generateBlockTCall(sb:IndentStringBuilder, expression:TypedExpr, expressions:Array<TypedExpr>) {
		// Detect if need discard type
		switch (expression.expr) {
			case TField(_, fa):
				var cfield:ClassField = null;
				switch (fa) {
					case FInstance(_, _, cf):
						cfield = cf.get();
					case FStatic(_, cf):
						cfield = cf.get();
					case _:
				}

				var hasReturn = false;
				switch (cfield.type) {
					case TFun(_, ret):
						trace(ret);
						switch (ret) {
							case TInst(t, _):
								hasReturn = true;
							case TAbstract(t, _):
								if (t.get().name != "Void")
									hasReturn = true;
							case _:
						}
					case _:
				}

				if (hasReturn) {
					sb.add('discard ');
				}
			case _:
		}

		generateCommonTCall(sb, expression, expressions);
	}

	/**
	 * Generate code for TBlock
	 */
	function generateTBlock(sb:IndentStringBuilder, expressions:Array<TypedExpr>) {
		if (expressions.length > 0) {
			for (expr in expressions) {
				traceExpression(expr);
				switch (expr.expr) {
					case TVar(v, expr):
						generateTVar(sb, v, expr);
					case TCall(e, el):
						generateBlockTCall(sb, e, el);
					case TReturn(e):
						generateTReturn(sb, e);
					case TBinop(op, e1, e2):

					case v:
						throw 'Unsupported ${v}';
				}

				sb.addNewLine(Same);
			}
		} else {
			sb.add("discard");
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
	 * Generate method body
	 */
	public function generateMethodBody(sb:IndentStringBuilder, expression:TypedExpr) {
		traceExpression(expression);
		switch (expression.expr) {
			case TFunction(tfunc):
				switch (tfunc.expr.expr) {
					case TBlock(el):
						generateTBlock(sb, el);
					case v:
						throw 'Unsupported paramter ${v}';
				}
			case v:
				throw 'Unsupported paramter ${v}';
		}
	}
}
