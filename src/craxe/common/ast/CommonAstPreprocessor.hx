package craxe.common.ast;

import haxe.ds.StringMap;
import haxe.macro.Type;

/**
 * Common preprocessor for AST tree
 */
class CommonAstPreprocessor {
	/**
	 * Excluded types
	 */
	static final excludedTypes:StringMap<Bool> = [
		"Std" => true, "Array" => true, "Math" => true, "Reflect" => true, "Sys" => true, "EReg" => true, "ArrayAccess" => true, "String" => true,
		"IntIterator" => true, "StringBuf" => true, "StringTools" => true, "Type" => true, "_EnumValue.EnumValue_Impl_" => true, "ValueType" => true,
		"Encoding" => true, "Error" => true
	];

	/**
	 * Filter not needed type. Return true if filtered
	 */
	function filterType(name:String):Bool {
		if (excludedTypes.exists(name))
			return true;

		if (StringTools.startsWith(name, "haxe."))
			return true;

		return false;
	}

	/**
	 * Build class info
	 */
	function buildClass(c:ClassType, params:Array<Type>):ClassInfo {
		if (filterType(c.name)) {
			return null;
		}

		return {
			classType: c,
			params: params
		}
	}

	/**
	 * Build enum info
	 */
	function buildEnum(c:EnumType, params:Array<Type>):EnumInfo {
		if (filterType(c.name))
			return null;

		return {
			enumType: c,
			params: params
		}
	}

	/**
	 * Constructor
	 */
	public function new() {}

	/**
	 * Process AST and get types
	 */
	public function process(types:Array<Type>):PreprocessedTypes {
		var classes = new Array<ClassInfo>();
		var enums = new Array<EnumInfo>();

		for (t in types) {
			switch (t) {
				case TInst(c, params):
					var cls = buildClass(c.get(), params);
					if (cls != null)
						classes.push(cls);
				case TEnum(t, params):
					var enu = buildEnum(t.get(), params);
					if (enu != null)
						enums.push(enu);
				case _:
			}
		}

		var types:PreprocessedTypes = {
			classes: classes,
			enums: enums
		}

		return types;
	}
}
