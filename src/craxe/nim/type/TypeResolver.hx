package craxe.nim.type;

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
	function generateSimpleType(sb:StringBuf, type:String) {
		var res = simpleTypes.get(type);
		if (res != null) {
			sb.add(res);
		} else {
			throw 'Unsupported simple type ${type}';
		}
	}

	/**
	 * Fix type name
	 */
	function fixTypeName(name:String):String {
		switch name {
			case "Array":
				return "HaxeArray";
		}

		return name;
	}

	/**
	 * Generate TEnum
	 */
	function generateTEnum(sb:StringBuf, enumType:EnumType, params:Array<Type>) {
		sb.add(enumType.name);
	}

	/**
	 * Generate TAbstract
	 */
	function generateTAbstract(sb:StringBuf, t:AbstractType, params:Array<Type>) {
		if (isSimpleType(t.name)) {
			generateSimpleType(sb, t.name);
		} else {
			throw 'Unsupported ${t}';
		}
	}

	/**
	 * Generate TInst
	 */
	function generateTInst(sb:StringBuf, t:ClassType, params:Array<Type>) {
		if (isSimpleType(t.name)) {
			generateSimpleType(sb, t.name);
		} else {
			var typeName = fixTypeName(t.name);
			sb.add(typeName);
			if (params != null && params.length > 0) {
				sb.add("[");
				for (par in params) {
					switch (par) {
						case TInst(t, params):
							generateTInst(sb, t.get(), params);
						case TAbstract(t, params):
							generateTAbstract(sb, t.get(), params);
						case v:
							throw 'Unsupported paramter ${v}';
					}
				}
				sb.add("]");
			}
		}
	}

	/**
	 * Generate TType
	 */
	function generateTType(sb:StringBuf, t:DefType, params:Array<Type>) {
		trace(t.name);
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
			case v:
				throw 'Unsupported type ${v}';
		}

		return sb.toString();
	}
}
