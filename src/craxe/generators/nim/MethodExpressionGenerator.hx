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
class MethodExpressionGenerator {
	/**
	 * Minimal string size for checking
	 */
	static inline final MIN_STRING_CHECK_SIZE = 100;

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
	 * Generate code for TMeta
	 */
	function generateTMeta(sb:IndentStringBuilder, meta:MetadataEntry, expression:TypedExpr) {
		switch (expression.expr) {
			case TConst(c):
				generateTConst(sb, c);
			case TLocal(v):
				generateTLocal(sb, v);
			case TSwitch(e, cases, edef):				
				generateTSwitch(sb, e, cases, edef);				
			case TEnumIndex(e1):
				generateTEnumIndex(sb, e1);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case TIf(econd, eif, eelse):
				generateTIf(sb, econd, eif, eelse);
			case TBlock(el):				
				generateTBlock(sb, el);
			case v:
				throw 'Unsupported ${v}';
		}
	}	

	/**
	 * Generate code for TMeta
	 */
	function generateTEnumIndex(sb:IndentStringBuilder, expression:TypedExpr) {
		switch (expression.expr) {
			case TLocal(v):
				generateTLocal(sb, v);
			case v:
				throw 'Unsupported ${v}';
		}
	}

	/**
	 * Generate custom code for getting enum values
	 * cast[EnumType](enum).value
	 * TODO: minimize casts
	 * Return true if it was processed
	 */
	function generateCustomEnumParameterCall(sb:IndentStringBuilder, e1:TypedExpr, ef:EnumField, index:Int):Bool {
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
		return false;
	}

	/**
	 * Generate code for TEnumParameter
	 */
	function generateTEnumParameter(sb:IndentStringBuilder, expression:TypedExpr, enumField:EnumField, index:Int) {
		switch (expression.expr) {
			case TLocal(v):
				generateTLocal(sb, v);
			case v:
				throw 'Unsupported ${v}';
		}
	}

	/**
	 * Generate code for TSwitch
	 */
	function generateTSwitch(sb:IndentStringBuilder, expression:TypedExpr, cases:Array<{values:Array<TypedExpr>, expr:TypedExpr}>, edef:TypedExpr) {
		var ifname = "if ";
		for (cs in cases) {
			for (val in cs.values) {
				sb.add(ifname);
				switch (expression.expr) {
					case TParenthesis(e):
						switch (e.expr) {
							case TLocal(v):
								generateTLocal(sb, v);
							case TMeta(m, e1):
								generateTMeta(sb, m, e1);
							case v:
								throw 'Unsupported ${v}';
						}
					case v:
						throw 'Unsupported ${v}';
				}
				sb.add(" == ");

				switch (val.expr) {
					case TConst(c):
						generateTConst(sb, c);
					case v:
						throw 'Unsupported ${v}';
				}

				sb.add(":");
				sb.addNewLine(Inc);

				switch (cs.expr.expr) {
					case TCall(e, el):
						generateBlockTCall(sb, e, el);
					case TReturn(e):
						generateTReturn(sb, e);
					case TBlock(el):
						generateTBlock(sb, el);
					case v:
						throw 'Unsupported ${v}';
				}

				sb.addNewLine(Dec);
			}
			ifname = "elif ";
		}
	}

	/**
	 * Return proper type name and it's field
	 */
	function getStaticTFieldData(classType:ClassType, classField:ClassField):{
		className:String,
		fieldName:String,
		totalName:String
	} {
		var className = "";

		var fieldName = classField.name;
		var totalName = "";

		if (classType.isExtern) {
			var isTop = classField.meta.has(":topFunction");
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

			if (isTop) {
				var topName = classField.meta.getMetaValue(":native");
				if (topName != null)
					fieldName = topName;
			}

			totalName = if (isTop) {
				fieldName;
			} else {
				'${className}.${fieldName}';
			}
		} else {
			typeResolver.getFixedTypeName(classType.name);
			var name = typeResolver.getFixedTypeName(classType.name);

			switch classType.kind {
				case KNormal:
					className = '${name}StaticInst';
					totalName = '${className}.${fieldName}';
				case KAbstractImpl(a):
					var abstr = a.get();
					className = '${abstr.name}Abstr';
					fieldName = fieldName.replace("_", "");
					totalName = '${fieldName}${className}';
				case v:
					throw 'Unsupported ${v}';
			}
		}

		if (totalName == "Std.string")
			totalName = "$";

		return {
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
				if (s.length < MIN_STRING_CHECK_SIZE && s.indexOf("\n") < 0) {
					sb.add('"${Std.string(s)}"');
				} else {
					sb.add('"""${Std.string(s)}"""');
				}
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
				case TUnop(op, postFix, e):
					generateTUnop(sb, op, postFix, e);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TConst(c):
					generateTConst(sb, c);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TLocal(v):
					generateTLocal(sb, v);
				case TArray(e1, e2):
					generateTArray(sb, e1, e2);
				case TArrayDecl(el):
					generateTArrayDecl(sb, el);
				case TObjectDecl(fields):
					generateTObjectDecl(sb, fields, vr.t);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case TEnumParameter(e1, ef, index):
					if (!generateCustomEnumParameterCall(sb, e1, ef, index))
						generateTEnumParameter(sb, e1, ef, index);
				case TMeta(m, e1):
					generateTMeta(sb, m, e1);
				case TCast(e, m):
					generateTCast(sb, e, m);
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TBlock(el):
					generateTBlockInline(sb, el);
				case v:
					throw 'Unsupported ${v}';
			}
		} else {
			sb.add(':${typeResolver.resolve(vr.t)}');
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
					generateTConst(sb, c);
				case TLocal(v):
					generateTLocal(sb, v);
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
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
	 * Generate code for access Bytes data
	 * Fixes inline access to seq[byte]	of HaxeBytes
	 */
	function generateCustomBytesAccess(sb:IndentStringBuilder, expression:TypedExprDef) {
		switch expression {
			case TField(e, _):
				switch (e.t) {
					case TInst(t, _):
						if (t.get().name == "Bytes") {
							switch (e.expr) {
								case TField(e, fa):
									generateTField(sb, e, fa);
								case TLocal(v):
									generateTLocal(sb, v);
								case v:
									throw 'Unsupported ${v}';
							}
							return true;
						}
					default:
				}
			default:
		}

		return false;
	}

	/**
	 * Generate code for TArray
	 * Array access arr[it]
	 */
	function generateTArray(sb:IndentStringBuilder, e1:TypedExpr, e2:TypedExpr) {
		if (!generateCustomBytesAccess(sb, e1.expr)) {
			switch (e1.expr) {
				case TLocal(v):
					generateTLocal(sb, v);
				case v:
					throw 'Unsupported ${v}';
			}
		}

		sb.add("[");
		switch (e2.expr) {
			case TConst(c):
				generateTConst(sb, c);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case TLocal(v):
				generateTLocal(sb, v);
			case v:
				throw 'Unsupported ${v}';
		}
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

			switch (expr.expr) {
				case TConst(c):
					generateTConst(sb, c);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case v:
					throw 'Unsupported ${v}';
			}

			if (i + 1 < elements.length)
				sb.add(", ");
		}
		sb.add("]");
	}

	/**
	 * Generate code for TObjectDecl for trace
	 */
	function generateTObjectDeclTrace(sb:IndentStringBuilder, fields:Array<{name:String, expr:TypedExpr}>) {
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
	 * Generate code for TObjectDecl
	 */
	function generateTObjectDecl(sb:IndentStringBuilder, fields:Array<{name:String, expr:TypedExpr}>, type:Type = null) {
		var object = if (type != null) {
			switch (type) {
				case TType(t, _):
					context.getObjectTypeByName(t.get().name);
				case TAnonymous(a):
					var flds = a.get().fields.map(x -> {
						return {
							name: x.name,
							type: x.type
						};
					});
					context.getObjectTypeByFields(flds);
				case v:
					throw 'Unsupported ${v}';
			}
		} else {
			context.getObjectTypeByFields(fields.map(x -> {
				name: x.name,
				type: x.expr.t
			}));
		}

		var name = '${object.name}Anon';
		sb.add('to${name}(');
		sb.add('${object.name}(');
		for (i in 0...fields.length) {
			var field = fields[i];
			sb.add('${field.name}: ');
			switch field.expr.expr {
				case TConst(c):
					generateTConst(sb, c);
				case TLocal(v):
					generateTLocal(sb, v);
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case v:
					throw 'Unsupported ${v}';
			}
			if (i + 1 < fields.length)
				sb.add(", ");
		}
		sb.add('))');
	}

	/**
	 * Genertate TCast
	 */
	function generateTCast(sb:IndentStringBuilder, expression:TypedExpr, module:ModuleType) {
		// TODO: normal cast
		switch (expression.expr) {
			case TLocal(v):
				if (v.name == "this1")
					sb.add("this1");
			case TConst(c):
				generateTConst(sb, c);
			case TBlock(el):
				generateTBlock(sb, el);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case v:
				throw 'Unsupported ${v}';
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

		switch (func.expr.expr) {
			case TBlock(el):
				generateTBlock(sb, el);
			case v:
				throw 'Unsupported ${v}';
		}

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
				case TBlock(e):
					generateTBlock(sb, e);
				case TReturn(e):
					generateTReturn(sb, e);
				case TCall(e, el):
					sb.add("return ");
					generateCommonTCall(sb, e, el);
				case TNew(c, params, el):
					sb.add("return ");
					generateTNew(sb, c.get(), params, el);
				case TConst(c):
					sb.add("return ");
					generateTConst(sb, c);
				case TFunction(tfunc):
					sb.add("return ");
					generateTFunction(sb, tfunc);
				case TBinop(op, e1, e2):
					sb.add("return ");
					generateTBinop(sb, op, e1, e2);
				case TUnop(op, postFix, e):
					sb.add("return ");
					generateTUnop(sb, op, postFix, e);
				case TArray(e1, e2):
					sb.add("return ");
					generateTArray(sb, e1, e2);
				case TLocal(v):
					sb.add("return ");
					generateTLocal(sb, v);
				case TObjectDecl(fields):
					sb.add("return ");
					generateTObjectDecl(sb, fields);
				case TCast(e, m):
					sb.add("return ");
					generateTCast(sb, e, m);
				case TField(e, fa):
					sb.add("return ");
					generateTField(sb, e, fa);
				case TMeta(m, e1):					
					generateTMeta(sb, m, e1);						
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
			case TConst(c):
				generateTConst(sb, c);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TLocal(v):
				generateTLocal(sb, v);
			case TArray(e1, e2):
				generateTArray(sb, e1, e2);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case TBlock(el):
				generateTBlockInline(sb, el);
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
				case TConst(c):
					generateTConst(sb, c);
				case TLocal(v):
					generateTLocal(sb, v);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TBlock(el):
					generateTBlockInline(sb, el);
				case v:
					throw 'Unsupported ${v}';
			}
		}
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

				switch (expr.expr) {
					case TLocal(v):
						generateTLocal(sb, v);
					case TField(e, fa):
						generateTField(sb, e, fa);
					case v:
						throw 'Unsupported ${v}';
				}

				sb.add(")");
			case OpDecrement:
			case OpNot:
			case OpNeg:
			case OpNegBits:
		}
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
	 * Generate code for calling base class field
	 */
	function generateSuperCall(sb:IndentStringBuilder, classType:ClassType, classField:ClassField) {
		var name = classType.name;
		sb.add('cast[${name}](this)');
	}

	/**
	 * Generate code for calling field
	 */
	function generateTCallTField(sb:IndentStringBuilder, expression:TypedExpr, access:FieldAccess) {
		switch (expression.expr) {
			case TTypeExpr(_):
			case TConst(TSuper):
				switch (access) {
					case FInstance(c, params, cf):
						generateSuperCall(sb, c.get(), cf.get());
					case v:
						throw 'Unsupported ${v}';
				}
			case TConst(c):
				generateTConst(sb, c);
			case TNew(c, params, el):
				generateTNew(sb, c.get(), params, el);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case TLocal(v):
				generateTLocal(sb, v);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case v:
				throw 'Unsupported ${v}';
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
	 * Generate field of object
	 */
	function generateTField(sb:IndentStringBuilder, expression:TypedExpr, access:FieldAccess) {
		switch (expression.expr) {
			case TTypeExpr(_):
			case TConst(c):
				generateTConst(sb, c);
			case TLocal(v):
				generateTLocal(sb, v);
			case TField(e, fa):
				generateTField(sb, e, fa);
			case v:
				throw 'Unsupported ${v}';
		}

		switch (access) {
			case FInstance(c, params, cf):
				generateTFieldFInstance(sb, c.get(), params, cf.get());
			case FStatic(c, cf):
				generateTFieldFStatic(sb, c.get(), cf.get());
			case FEnum(e, ef):
				var name = typeResolver.getFixedTypeName(e.get().name);
				sb.add('new${name}${ef.name}()');
			case FAnon(cf):
				sb.add('.${cf.get().name}[]');
			case v:
				throw 'Unsupported ${v}';
		}
	}

	/**
	 * Generate code for common TCall
	 */
	// TODO: refactor that
	function generateCommonTCall(sb:IndentStringBuilder, expression:TypedExpr, expressions:Array<TypedExpr>) {
		var isTraceCall = false;
		var isAsync = false;
		switch (expression.expr) {
			case TField(_, FEnum(c, ef)):
				var name = c.get().name;
				sb.add('new${name}${ef.name}');
				sb.add("(");
			case TField(e, fa):				
				switch (e.expr) {
					case TTypeExpr(m):						
						switch (m) {
							case TClassDecl(c):
								switch c.get().name {
									case "Log":
										isTraceCall = true;	
									case "Async_Impl_":
										isAsync = true;
								}
							case _:
						}
					case _:
				}

				if (!isAsync) {
					generateTCallTField(sb, e, fa);
					sb.add("(");
				}
			case TConst(TSuper):
				if (classContext.classType.superClass != null) {
					var superCls = classContext.classType.superClass.t.get();
					var superName = superCls.name;
					sb.add('init${superName}(this, ');
				}
			case TLocal(v):
				generateTLocal(sb, v);
				sb.add("(");
			case v:
				throw 'Unsupported ${v}';
		}

		var funArgs = switch (expression.t) {
			case TFun(args, _):
				args;
			case _:
				null;
		}

		var wasConverter = false;
		for (i in 0...expressions.length) {
			var expr = expressions[i];
			var farg = if (funArgs != null) {
				funArgs[i];
			} else null;

			switch (expr.expr) {
				case TConst(c):
					generateTConst(sb, c);
				case TObjectDecl(e):
					if (isTraceCall) {
						generateTObjectDeclTrace(sb, e);
					} else
						generateTObjectDecl(sb, e);
				case TFunction(tfunc):
					generateTFunction(sb, tfunc);
				case TLocal(v):
					if (farg != null) {
						switch v.t {
							case TInst(t, params):
								switch farg.t {
									case TType(t, _):
										var name = t.get().name;
										sb.add('to${name}Anon(');
										wasConverter = true;
									case TAnonymous(a):
										var an = a.get();
										var obj = context.getObjectTypeByFields(an.fields.map(x -> {
											name: x.name,
											type: x.type
										}));
										sb.add('to${obj.name}Anon(');
										wasConverter = true;
									case _:
								}
							case _:
						}
					}
					generateTLocal(sb, v);
				case TNew(c, params, el):
					generateTNew(sb, c.get(), params, el);
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TField(e, fa):
					generateTField(sb, e, fa);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TArray(e1, e2):
					generateTArray(sb, e1, e2);
				case TCast(e, m):
					generateTCast(sb, e, m);
				case TBlock(el):
					generateTBlock(sb, el);
				case v:
					throw 'Unsupported ${v}';
			}

			// generateTypedAstExpression(sb, expr);
			if (i + 1 < expressions.length)
				sb.add(", ");
		}

		if (!isAsync)
			sb.add(")");

		if (wasConverter)
			sb.add(")");
	}

	/**
	 * Generate code for root TCall in block
	 */
	function generateBlockTCall(sb:IndentStringBuilder, expression:TypedExpr, expressions:Array<TypedExpr>, checkReturn = true) {
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

				if (hasReturn && checkReturn) {
					sb.add('discard ');
				}
			case _:
		}

		generateCommonTCall(sb, expression, expressions);
	}

	/**
	 * Generate code for TIf
	 */
	function generateTIf(sb:IndentStringBuilder, econd:TypedExpr, eif:TypedExpr, eelse:TypedExpr) {
		sb.add("if ");

		switch (econd.expr) {
			case TParenthesis(e):
				switch e.expr {
					case TBinop(op, e1, e2):
						generateTBinop(sb, op, e1, e2);
					case v:
						throw 'Unsupported ${v}';
				}
			case v:
				throw 'Unsupported ${v}';
		}

		sb.add(":");
		sb.addNewLine(Inc);

		switch (eif.expr) {
			case TConst(c):
				generateTConst(sb, c);
			case TReturn(e):
				generateTReturn(sb, e);
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case TMeta(m, e1):
				generateTMeta(sb, m, e1);			
			case v:
				throw 'Unsupported ${v}';
		}

		if (eelse != null) {
			sb.addNewLine(Dec);
			sb.add("else:");
			sb.addNewLine(Inc);

			switch (eelse.expr) {
				case TConst(c):
					generateTConst(sb, c);
				case TBlock(el):
					if (el.length > 0) {
						switch (eelse.expr) {
							case v:
								throw 'Unsupported ${v}';
						}
					}
				case TBinop(op, e1, e2):
					generateTBinop(sb, op, e1, e2);
				case TCall(e, el):
					generateCommonTCall(sb, e, el);
				case TMeta(m, e1):
					generateTMeta(sb, m, e1);
				case v:
					throw 'Unsupported ${v}';
			}
		}
		sb.addNewLine(Dec);
	}

	/**
	 * Generate code for TWhile
	 */
	function generateTWhile(sb:IndentStringBuilder, econd:TypedExpr, whileExpression:TypedExpr, isNormal:Bool) {
		sb.add("while ");
		switch (econd.expr) {
			case TParenthesis(e):
				switch (e.expr) {
					case TBinop(op, e1, e2):
						generateTBinop(sb, op, e1, e2);
					case v:
						throw 'Unsupported ${v}';
				}
			case v:
				throw 'Unsupported ${v}';
		}
		sb.add(":");
		sb.addNewLine(Inc);

		switch (whileExpression.expr) {
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TBlock(el):
				generateTBlock(sb, el);
			case TCall(e, el):
				generateCommonTCall(sb, e, el);
			case v:
				throw 'Unsupported ${v}';
		}

		sb.addNewLine(Dec, true);
	}

	/**
	 * Generate single expression from TBlock
	 */
	function generateTBlockSingleExpression(sb:IndentStringBuilder, expr:TypedExpr) {
		switch (expr.expr) {
			case TConst(c):
			// TODO: handle THIS
			// generateTConst(sb, c);
			case TVar(v, expr):
				generateTVar(sb, v, expr);
			case TCall(e, el):
				generateBlockTCall(sb, e, el);
			case TReturn(e):
				generateTReturn(sb, e);
			case TBinop(op, e1, e2):
				generateTBinop(sb, op, e1, e2);
			case TBlock(el):
				generateTBlock(sb, el);
			case TIf(econd, eif, eelse):
				generateTIf(sb, econd, eif, eelse);
			case TWhile(econd, e, normalWhile):
				generateTWhile(sb, econd, e, normalWhile);
			case TMeta(m, e1):
				generateTMeta(sb, m, e1);
			case TUnop(op, postFix, e):
				generateTUnop(sb, op, postFix, e);
			case TCast(e, m):
				generateTCast(sb, e, m);
			case v:
				throw 'Unsupported ${v}';
		}

		sb.addNewLine(Same);
	}

	/**
	 * Generate code for TBlock
	 */
	function generateTBlock(sb:IndentStringBuilder, expressions:Array<TypedExpr>) {
		if (expressions.length > 0) {
			for (expr in expressions) {
				generateTBlockSingleExpression(sb, expr);
			}
		} else {
			sb.add("discard");
		}
	}

	/**
	 * Generate inline block like
	 * (block:
	 * 		expressions
	 * )
	 */
	function generateTBlockInline(sb:IndentStringBuilder, expressions:Array<TypedExpr>) {
		sb.add("(block:");
		sb.addNewLine(Inc);
		if (expressions.length > 0) {
			for (i in 0...expressions.length) {
				var expr = expressions[i];
				if (i + 1 < expressions.length) {
					generateTBlockSingleExpression(sb, expr);
				} else {
					switch (expr.expr) {
						case TCall(e, el):
							generateBlockTCall(sb, e, el, false);
						case TLocal(v):
							generateTLocal(sb, v);
						case v:
							throw 'Unsupported ${v}';
					}
				}
			}
		}

		sb.addNewLine(Dec);
		sb.add(")");
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
