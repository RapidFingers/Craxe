package craxe.nim;

import craxe.common.ast.ClassInfo;
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
import craxe.nim.type.*;

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
	 * Fix local var name
	 */
	inline function fixLocalVarName(name:String):String {
		return name.replace("_", "loc");
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
		if (expressions.length > 0) {
			for (expr in expressions) {
				generateTypedAstExpression(sb, expr.expr);
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
				sb.add("(");
			case TConst(TSuper):
				if (classContext.classType.superClass != null) {
					var superCls = classContext.classType.superClass.t.get();
					var superName = superCls.name;
					sb.add('init${superName}(this, ');
				}
			case _:
				generateTypedAstExpression(sb, expression.expr);
				sb.add("(");
		}

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
		var typeName = typeResolver.getFixedTypeName(classType.name);
		var typeParams = typeResolver.resolveParameters(params);
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
				var inst = c.get();
				var field = cf.get();
				var name = typeResolver.getFixedTypeName(field.name);
				sb.add(".");
				if (inst.isInterface) {
					switch (field.kind) {
						case FVar(_, _):
							sb.add('${name}[]');
						case FMethod(_):
							sb.add(name);
					}
				} else {	
					sb.add(name);
				}
			case FStatic(c, cf):
				var name = typeResolver.getFixedTypeName(c.get().name);
				sb.add('${name}StaticInst.');
				var fieldName = cf.toString();
				sb.add(fieldName);
			case FAnon(cf):
			case FDynamic(s):
			case FClosure(c, cf):
			case FEnum(e, ef):
				var name = typeResolver.getFixedTypeName(e.get().name);
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
		var name = typeResolver.getFixedTypeName(vr.name);
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
				throw "Unsupported super";
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
				var resolved = typeResolver.resolve(v);
				sb.add(resolved);
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
	public function generate(sb:IndentStringBuilder, expression:TypedExprDef) {
		generateTypedAstExpression(sb, expression);
	}
}
