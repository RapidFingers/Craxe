package craxe.generators.nim.type;

import craxe.common.ast.ArgumentInfo;
import craxe.common.ast.ResolvedArgumentInfo;
import haxe.macro.Type;
import haxe.macro.Type.EnumType;
import haxe.macro.Type.AbstractType;
import haxe.macro.Type.ClassType;

/**
 * AST type resolver
 */
class TypeResolver {
	/**
	 * Simple type map
	 */
	static final simpleTypes = [
		"Bool" => "bool",
		"Int" => "int",
		"Float" => "float",
		"String" => "string",
		"Void" => "void"
	];

	/**
	 * Context with all types
	 */
	final context:TypeContext;

	/**
	 * Check type is simple by type name
	 */
	function isSimpleType(name:String):Bool {
		return simpleTypes.exists(name);
	}

	/**
	 * Generate simple type
	 */
	function generateSimpleType(sb:StringBuf, type:String):Bool {
		var res = simpleTypes.get(type);
		if (res != null) {
			sb.add(res);
			return true;
		}

		return false;
	}	

	/**
	 * Generate code for pass modificator	 
	 */
	function generatePassModificator(sb:StringBuf, t:AbstractType, params:Array<Type>):Bool {
		if (t.name == "Var") {
			sb.add("var ");
			for (par in params) {
				sb.add(resolve(par));
			}
			return true;
		}
		return false;
	}

	/**
	 * Generate TEnum
	 */
	function generateTEnum(sb:StringBuf, enumType:EnumType, params:Array<Type>) {
		sb.add(getFixedTypeName(enumType.name));
	}

	/**
	 * Generate TAbstract
	 */
	function generateTAbstract(sb:StringBuf, t:AbstractType, params:Array<Type>) {
		if (generateSimpleType(sb, t.name))
			return;

		if (generatePassModificator(sb, t, params))
			return;

		throw 'Unsupported ${t}';
	}

	/**
	 * Generate TInst
	 */
	function generateTInst(sb:StringBuf, t:ClassType, params:Array<Type>) {
		if (generateSimpleType(sb, t.name))
			return;

		var typeName = getFixedTypeName(t.name);
		sb.add(typeName);
		if (params != null && params.length > 0) {
			sb.add("[");
			for (par in params) {
				switch (par) {
					case TInst(t, params):
						generateTInst(sb, t.get(), params);
					case TAbstract(t, params):
						generateTAbstract(sb, t.get(), params);
					case TEnum(t, params):
						generateTEnum(sb, t.get(), params);
					case v:						
						throw 'Unsupported paramter ${v}';
				}
			}
			sb.add("]");
		}
	}

	/**
	 * Generate TType
	 */
	function generateTType(sb:StringBuf, t:DefType, params:Array<Type>) {
		sb.add(t.name);
	}

	/**
	 * Generate TFun	 
	 */
	function generateTFun(sb:StringBuf, args:Array<ArgumentInfo>, ret:Type) {
		sb.add("proc(");
		sb.add(args.map(x-> '${x.name}:${resolve(x.t)}').join(", "));
		sb.add("):");
		sb.add(resolve(ret));
	}

	/**
	 * Generate TAnonymous
	 */
	function generateTAnonymous(sb:StringBuf, anon: AnonType) {
		var anonInfo = context.getAnonymousInfo(anon);
		sb.add(anonInfo.name);
	}

	/**
	 * Constructor
	 */
	public function new(context:TypeContext) {
		this.context = context;
	}

	/**
	 * Return fixed type name
	 * @param name
	 */
	public function getFixedTypeName(name:String) {
		switch name {
			case "Array":
				return "HaxeArray";
			case "Bytes":
				return "HaxeBytes";
		}

		return name;
	}

	/**
	 * Return type parameters as string
	 */
	public function resolveParameters(params:Array<Type>):String {
		if (params.length > 0) {
			var sb = new StringBuf();

			sb.add("[");
			for (item in params) {
				sb.add(resolve(item));
			}
			sb.add("]");

			return sb.toString();
		} else {
			return "";
		}
	}

	/**
	 * Resolve arguments to resolved arguments
	 */
	public function resolveArguments(args:Array<ArgumentInfo>):Array<ResolvedArgumentInfo> {
		return args.map(x -> {
			return {
				name: x.name,
				opt: x.opt,
				t: resolve(x.t)
			}
		});
	}

	/**
	 * Resolve types to string
	 */
	public function resolve(type:Type):String {
		var sb = new StringBuf();
		switch (type) {
			case TEnum(t, params):
				generateTEnum(sb, t.get(), params);
			case TInst(t, params):
				generateTInst(sb, t.get(), params);
			case TAbstract(t, params):
				generateTAbstract(sb, t.get(), params);
			case TType(t, params):
				generateTType(sb, t.get(), params);
			case TFun(args, ret):
				generateTFun(sb, args, ret);
			case TAnonymous(a):
				generateTAnonymous(sb, a.get());
			case v:
				throw 'Unsupported type ${v}';
		}

		return sb.toString();
	}
}
